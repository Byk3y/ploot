import Foundation
import Speech
import AVFoundation
import Observation

/// On-device speech recognition wrapper. Starts/stops an AVAudioEngine +
/// SFSpeechRecognizer pipeline, exposes the live partial transcript via
/// `@Observable` so SwiftUI can render it while the user is holding down
/// the FAB.
///
/// Permissions are requested lazily on first `start()` call and surfaced
/// via `permissionState`. If denied, the caller should fall back to the
/// manual QuickAddSheet.
@MainActor
@Observable
final class SpeechService {
    enum PermissionState: Equatable {
        case unknown
        case granted
        case denied
        case speechDenied
        case micDenied
    }

    enum ServiceError: Error {
        case recognizerUnavailable
        case audioEngineFailed(String)
    }

    /// Live partial transcript — updates as the user speaks.
    var transcript: String = ""
    /// Is recognition currently active?
    var isRecording: Bool = false
    /// Current permission state. Inspect after `requestPermissions()`.
    var permissionState: PermissionState = .unknown

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    init(locale: Locale = .current) {
        self.recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Permissions

    /// Ask for both speech + mic permissions. Returns the final state.
    /// Safe to call repeatedly — iOS returns cached results after first grant.
    func requestPermissions() async -> PermissionState {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechStatus == .authorized else {
            permissionState = .speechDenied
            return permissionState
        }

        let micGranted: Bool = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
        guard micGranted else {
            permissionState = .micDenied
            return permissionState
        }

        permissionState = .granted
        return permissionState
    }

    // MARK: - Start / stop

    /// Start recognition. Caller should have verified `permissionState == .granted` first.
    /// If no recognizer is available for the device locale, throws.
    func start() throws {
        guard let recognizer, recognizer.isAvailable else {
            throw ServiceError.recognizerUnavailable
        }

        stop()
        transcript = ""

        // .default mode (not .measurement) keeps AGC + signal conditioning
        // on, which produces cleaner transcripts for natural push-to-talk
        // speech. .measurement disables those and is designed for
        // scientific/VoIP audio measurement, not dictation.
        //
        // .allowBluetooth + .allowBluetoothA2DP make AirPods + Bluetooth
        // headsets work as the input source; without them, iOS falls back
        // to the built-in mic even when headphones are connected.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw ServiceError.audioEngineFailed("session: \(error.localizedDescription)")
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 13.0, *) {
            // On-device recognition when the device supports it — no network,
            // no uploaded audio, lower latency. Falls back automatically on
            // older hardware.
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        }
        self.recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            throw ServiceError.audioEngineFailed(error.localizedDescription)
        }

        isRecording = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let newText = result.bestTranscription.formattedString
                    // SFSpeechRecognizer can briefly return shorter partial
                    // transcripts after pauses as it re-segments the audio
                    // (observed on iOS 17+ on-device recognition). We only
                    // accept new transcripts that are at least as long as
                    // what we had, or the final result — prevents the
                    // visible text from flashing empty mid-dictation.
                    if newText.count >= self.transcript.count || result.isFinal {
                        self.transcript = newText
                    }
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.teardown()
                }
            }
        }
    }

    /// Stop recognition cleanly. Transcript remains populated for the caller.
    func stop() {
        guard isRecording else {
            teardown()
            return
        }
        recognitionRequest?.endAudio()
        teardown()
    }

    /// Cancel recognition and clear the transcript (user slid-away-to-cancel).
    func cancel() {
        recognitionTask?.cancel()
        teardown()
        transcript = ""
    }

    // MARK: - Private

    private func teardown() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
