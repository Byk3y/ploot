import Foundation

/// Calls the `intent` Supabase edge function with a transcript. The function
/// returns a single JSON object (not streamed); we decode and return a
/// typed `VoiceIntent` or throw `IntentError`.
///
/// No rate-limit bucket of its own — the edge function shares the
/// `ai_breakdown_usage` daily quota with `breakdown`. One pool, any AI call.
@MainActor
enum IntentService {
    private static var endpoint: URL {
        Secrets.supabaseURL.appendingPathComponent("functions/v1/intent")
    }

    static func classify(transcript: String) async throws -> VoiceIntent {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw IntentError.emptyTranscript }

        let session = try await Supa.client.auth.session
        let jwt = session.accessToken

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData

        struct Body: Encodable { let transcript: String }
        request.httpBody = try JSONEncoder().encode(Body(transcript: trimmed))

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            throw IntentError.cancelled
        } catch {
            throw IntentError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw IntentError.network("no http response")
        }

        switch http.statusCode {
        case 200:
            guard let intent = VoiceIntent.decode(from: data) else {
                throw IntentError.network("malformed response")
            }
            return intent
        case 401:
            throw IntentError.unauthorized
        case 429:
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let resetAt = (obj?["resetAt"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
            let used = obj?["used"] as? Int ?? 0
            let limit = obj?["limit"] as? Int ?? 10
            throw IntentError.rateLimited(resetAt: resetAt, used: used, limit: limit)
        default:
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw IntentError.network("\(http.statusCode): \(msg.prefix(120))")
        }
    }
}
