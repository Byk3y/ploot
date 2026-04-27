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

    /// True between `start()` and the matching `stop()` / `cancel()`. The
    /// recognition-task callback inspects this to decide whether to auto-
    /// restart after a mid-session `isFinal` (silence-triggered finalization
    /// while the user is still holding the FAB).
    private var keepRunning: Bool = false
    /// Concatenated text of all *finalized* segments in this session. New
    /// partials append onto this so the user sees the running dictation
    /// across pauses.
    private var finalizedTranscript: String = ""

    init(locale: Locale = .current) {
        self.recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        refreshPermissionStateFromOS()
    }

    // MARK: - Permissions

    /// Read the current speech + mic authorization status from iOS and
    /// reconcile `permissionState`. Safe to call from the main actor at
    /// any time — both APIs are synchronous and don't trigger prompts.
    ///
    /// Why this matters: on a fresh app launch our `@Observable` state
    /// starts at `.unknown` even when iOS already remembers the user's
    /// prior grant. Without this reconcile we'd ask iOS again via
    /// `requestPermissions()` (which is fine for granted/denied paths
    /// because iOS just returns the cache), but the call is async so a
    /// quick long-press race can land in `.permissionDenied` after the
    /// user has already released the FAB. Doing it synchronously up
    /// front fixes both the cold-start case and any change made via
    /// Settings while the app was backgrounded.
    func refreshPermissionStateFromOS() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVAudioApplication.shared.recordPermission

        switch (speechStatus, micStatus) {
        case (.authorized, .granted):
            permissionState = .granted
        case (.denied, _), (.restricted, _):
            permissionState = .speechDenied
        case (.authorized, .denied):
            permissionState = .micDenied
        case (.notDetermined, _), (.authorized, .undetermined):
            permissionState = .unknown
        @unknown default:
            permissionState = .unknown
        }
    }

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
        finalizedTranscript = ""

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

        // The audio engine + tap are installed once per session and stay
        // running across recognizer restarts. The tap reads `self.recognitionRequest`
        // each call, so swapping the request mid-flight transparently routes
        // audio into the new task without losing buffers.
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

        keepRunning = true
        isRecording = true
        startRecognitionTask()
    }

    /// Build a fresh `SFSpeechAudioBufferRecognitionRequest` + task and
    /// wire up the result callback. Called once on `start()` and again
    /// whenever the recognizer auto-finalizes mid-session (a long-enough
    /// pause makes `isFinal` fire even though the user is still holding).
    /// Without this restart loop the dictation goes dead the moment the
    /// user pauses to think.
    private func startRecognitionTask() {
        guard let recognizer, recognizer.isAvailable, keepRunning else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 13.0, *) {
            // On-device recognition when the device supports it — no network,
            // no uploaded audio, lower latency. Falls back automatically on
            // older hardware.
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        }
        self.recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let segment = result.bestTranscription.formattedString
                    let combined = Self.join(self.finalizedTranscript, segment)
                    // SFSpeechRecognizer can briefly return shorter partial
                    // transcripts after pauses as it re-segments the audio
                    // (observed on iOS 17+ on-device recognition). Only
                    // accept new transcripts that are at least as long as
                    // what we had, or the final result — prevents flashing
                    // empty mid-dictation.
                    if combined.count >= self.transcript.count || result.isFinal {
                        self.transcript = combined
                    }
                    if result.isFinal {
                        self.finalizedTranscript = combined
                        // Drop the just-finished task and start a new one
                        // so the next words continue the same dictation
                        // session. The audio engine + tap stay running.
                        self.recognitionTask = nil
                        self.recognitionRequest = nil
                        if self.keepRunning {
                            self.startRecognitionTask()
                        } else {
                            self.teardown()
                        }
                        return
                    }
                }
                if error != nil {
                    self.recognitionTask = nil
                    self.recognitionRequest = nil
                    if self.keepRunning {
                        self.startRecognitionTask()
                    } else {
                        self.teardown()
                    }
                }
            }
        }
    }

    /// Concatenate two transcript fragments with a single space, trimming
    /// whitespace at the seam so we never produce double-spaces or stray
    /// leading/trailing whitespace.
    private static func join(_ a: String, _ b: String) -> String {
        let trimmedA = a.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedB = b.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedA.isEmpty { return trimmedB }
        if trimmedB.isEmpty { return trimmedA }
        return trimmedA + " " + trimmedB
    }

    /// Stop recognition cleanly. Transcript remains populated for the caller.
    func stop() {
        keepRunning = false
        guard isRecording else {
            teardown()
            return
        }
        recognitionRequest?.endAudio()
        teardown()
    }

    /// Cancel recognition and clear the transcript (user slid-away-to-cancel).
    func cancel() {
        keepRunning = false
        recognitionTask?.cancel()
        teardown()
        transcript = ""
        finalizedTranscript = ""
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
