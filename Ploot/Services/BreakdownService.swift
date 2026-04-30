import Foundation

/// Calls the `breakdown` Supabase edge function and exposes the resulting
/// Server-Sent Events as an `AsyncThrowingStream<BreakdownEvent, Error>`.
///
/// Pre-stream failures (no auth, 429, 400) throw `BreakdownError`. Once the
/// 200 response opens, everything — including upstream OpenRouter failures —
/// arrives as a `.error` event in-stream. Callers should treat the first
/// `heartbeat` as confirmation the pipe is healthy.
@MainActor
enum BreakdownService {
    private static var endpoint: URL {
        Secrets.supabaseURL.appendingPathComponent("functions/v1/breakdown")
    }

    /// Open a breakdown stream for the given project title + prior answers.
    ///
    /// The returned stream yields events in server order. On cancellation,
    /// the stream terminates cleanly and the underlying URLSession task is
    /// torn down. On non-2xx responses the stream throws before yielding
    /// anything.
    static func stream(
        title: String,
        answers: [BreakdownAnswer] = [],
        bio: String? = nil,
        projectContext: ProjectContext? = nil
    ) -> AsyncThrowingStream<BreakdownEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(
                        title: title,
                        answers: answers,
                        bio: bio,
                        projectContext: projectContext,
                        continuation: continuation
                    )
                } catch is CancellationError {
                    continuation.finish(throwing: BreakdownError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    struct ProjectContext: Encodable {
        let completed_projects: [String]
        let active_projects: [String]
        let avg_tasks_per_project: Int
    }

    private static func run(
        title: String,
        answers: [BreakdownAnswer],
        bio: String?,
        projectContext: ProjectContext?,
        continuation: AsyncThrowingStream<BreakdownEvent, Error>.Continuation
    ) async throws {
        let session = try await Supa.client.auth.session
        let jwt = session.accessToken

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60

        struct Body: Encodable {
            let title: String
            let answers: [BreakdownAnswer]
            // Caps the number of clarifying questions the edge function
            // is allowed to ask before it streams tasks. Drives the
            // `Settings → AI breakdown → Clarifying questions` pref —
            // 0 jumps straight to tasks, 5 is the upper bound.
            let max_questions: Int
            let bio: String?
            let project_context: ProjectContext?
        }

        request.httpBody = try JSONEncoder().encode(Body(
            title: title,
            answers: answers,
            max_questions: UserPrefs.breakdownQuestions,
            bio: bio,
            project_context: projectContext
        ))

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BreakdownError.network("no http response")
        }

        if http.statusCode != 200 {
            try await handleNon200(statusCode: http.statusCode, bytes: bytes)
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard !payload.isEmpty,
                  let data = payload.data(using: .utf8),
                  let event = BreakdownEvent.decode(from: data) else {
                continue
            }
            continuation.yield(event)

            if case .done = event { break }
            if case .refused = event { break }
            if case .hint = event { break }
            if case .split = event { break }
            if case .error = event { break }
        }

        continuation.finish()
    }

    private static func handleNon200(
        statusCode: Int,
        bytes: URLSession.AsyncBytes
    ) async throws -> Never {
        var raw = Data()
        for try await byte in bytes.prefix(4096) {
            raw.append(byte)
        }

        switch statusCode {
        case 401:
            throw BreakdownError.unauthorized
        case 429:
            let obj = try? JSONSerialization.jsonObject(with: raw) as? [String: Any]
            let resetAt = (obj?["resetAt"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
            let used = obj?["used"] as? Int ?? 0
            let limit = obj?["limit"] as? Int ?? 10
            throw BreakdownError.rateLimited(resetAt: resetAt, used: used, limit: limit)
        case 400:
            let obj = try? JSONSerialization.jsonObject(with: raw) as? [String: Any]
            let code = obj?["error"] as? String ?? "bad_request"
            throw BreakdownError.badRequest(code)
        default:
            let text = String(data: raw, encoding: .utf8) ?? ""
            throw BreakdownError.network("\(statusCode): \(text.prefix(120))")
        }
    }
}
