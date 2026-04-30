import Foundation

/// One SSE event emitted by the `breakdown` edge function. Stream goes:
/// `heartbeat` (always first) → either a terminal `question`/`hint`/`split`/`refused`
/// OR a sequence of `task` events followed by `done` → then the HTTP stream
/// closes. `error` can surface at any point.
enum BreakdownEvent: Equatable {
    case heartbeat
    case question(text: String, choices: [String], allowCustom: Bool)
    case task(order: Int, title: String)
    case hint(kind: String)
    case split(projects: [String])
    case refused(reason: String)
    case done(count: Int)
    case error(code: String)

    /// Parse one `data: { ... }` JSON blob from the SSE body. Returns nil
    /// for unrecognized types so the caller can skip and keep reading —
    /// we don't want to abort the stream on a future event type we haven't
    /// taught the client about yet.
    static func decode(from data: Data) -> BreakdownEvent? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else {
            return nil
        }
        switch type {
        case "heartbeat":
            return .heartbeat
        case "question":
            let text = obj["text"] as? String ?? ""
            let choices = obj["choices"] as? [String] ?? []
            let allowCustom = obj["allowCustom"] as? Bool ?? true
            guard !text.isEmpty, !choices.isEmpty else { return nil }
            return .question(text: text, choices: choices, allowCustom: allowCustom)
        case "task":
            let order = obj["order"] as? Int ?? 0
            let title = obj["title"] as? String ?? ""
            guard !title.isEmpty else { return nil }
            return .task(order: order, title: title)
        case "hint":
            let kind = obj["kind"] as? String ?? "single_task"
            return .hint(kind: kind)
        case "split":
            let projects = obj["projects"] as? [String] ?? []
            guard projects.count >= 2 else { return nil }
            return .split(projects: projects)
        case "refused":
            let reason = obj["reason"] as? String ?? "can't help with that."
            return .refused(reason: reason)
        case "done":
            let count = obj["count"] as? Int ?? 0
            return .done(count: count)
        case "error":
            let code = obj["code"] as? String ?? "internal"
            return .error(code: code)
        default:
            return nil
        }
    }
}

/// One Q/A pair sent back to the edge function on follow-up calls so the
/// model has the full conversation context (it's stateless server-side).
struct BreakdownAnswer: Codable, Equatable {
    let q: String
    let a: String
}

/// Errors surfaced by BreakdownService above the SSE event stream — these
/// happen before the first `heartbeat` arrives (auth, rate limit, bad
/// request). Once the stream is open, failures come through as `.error`
/// events in the event stream itself.
enum BreakdownError: Error, Equatable {
    case unauthorized
    case rateLimited(resetAt: Date?, used: Int, limit: Int)
    case badRequest(String)
    case network(String)
    case cancelled
}
