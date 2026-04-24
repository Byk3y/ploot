import Foundation

/// One piece of structured intent extracted by the `intent` edge function
/// from a voice transcript. The client routes to different behaviors based
/// on which case fires.
enum VoiceIntent: Equatable {
    case task(VoiceTask)
    case tasks([VoiceTask])
    case project(title: String)
    case ambiguous

    /// Parse the JSON body the edge function returns.
    static func decode(from data: Data) -> VoiceIntent? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kind = obj["kind"] as? String else {
            return nil
        }
        switch kind {
        case "task":
            guard let t = obj["task"] as? [String: Any],
                  let parsed = VoiceTask.decode(from: t) else {
                return nil
            }
            return .task(parsed)
        case "tasks":
            let arr = obj["tasks"] as? [[String: Any]] ?? []
            let parsed = arr.compactMap(VoiceTask.decode(from:))
            guard !parsed.isEmpty else { return nil }
            return parsed.count == 1 ? .task(parsed[0]) : .tasks(parsed)
        case "project":
            guard let title = obj["projectTitle"] as? String, !title.isEmpty else { return nil }
            return .project(title: title)
        case "ambiguous":
            return .ambiguous
        default:
            return nil
        }
    }
}

struct VoiceTask: Equatable {
    let title: String
    let dueDate: Date?
    let projectSlug: String?
    let priority: VoicePriority?

    static func decode(from dict: [String: Any]) -> VoiceTask? {
        guard let title = dict["title"] as? String, !title.isEmpty else { return nil }
        var due: Date? = nil
        if let iso = dict["dueDate"] as? String, !iso.isEmpty {
            due = iso8601Parser.date(from: iso) ?? iso8601FallbackParser.date(from: iso)
        }
        let slug = dict["projectSlug"] as? String
        let priorityStr = dict["priority"] as? String
        return VoiceTask(
            title: title,
            dueDate: due,
            projectSlug: slug?.isEmpty == true ? nil : slug,
            priority: VoicePriority(rawValue: priorityStr ?? "")
        )
    }
}

enum VoicePriority: String {
    case urgent
    case high
    case normal
}

private let iso8601Parser: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private let iso8601FallbackParser: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

/// Errors returned by IntentService before or during the network call.
enum IntentError: Error, Equatable {
    case unauthorized
    case rateLimited(resetAt: Date?, used: Int, limit: Int)
    case network(String)
    case emptyTranscript
    case cancelled
}
