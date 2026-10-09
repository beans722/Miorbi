import AppKit
import Foundation

struct CodexEvent: Codable, Equatable {
    let name: String
    let sessionID: String
    let turnID: String
    let timestamp: Date

    static func fromHook(name: String, input: Data, at now: Date = Date()) -> CodexEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: input) as? [String: Any] else { return nil }
        let session = object["session_id"] as? String ?? ""
        let turn = object["turn_id"] as? String ?? ""
        guard !session.isEmpty else { return nil }
        return CodexEvent(name: name, sessionID: session, turnID: turn, timestamp: now)
    }
}

enum CodexActivity: Equatable {
    case idle
    case running
    case settling
    case approval
    case completed
    case interrupted
}

enum CodexEventFile {
    static var url: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Miorbi", isDirectory: true).appendingPathComponent("codex-events.jsonl")
    }

    static func append(_ event: CodexEvent) throws {
        let file = url
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                                withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let line = try JSONEncoder().encode(event) + Data([0x0A])
        if !FileManager.default.fileExists(atPath: file.path) {
            FileManager.default.createFile(atPath: file.path, contents: line,
                                           attributes: [.posixPermissions: 0o600])
        } else {
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        }
    }

    static func recentEvents() -> [CodexEvent] {
        guard let data = try? Data(contentsOf: url), data.count <= 5_000_000 else { return [] }
        return data.split(separator: 0x0A).suffix(200).compactMap {
            try? JSONDecoder().decode(CodexEvent.self, from: Data($0))
        }
    }
}

struct CodexActivitySnapshot: Equatable {
    let activity: CodexActivity
    let since: Date?

    // Stop ends a turn, not necessarily the user's whole task. Wait for a
    // quiet period so an automatic continuation can cancel the notice.
    static let completionQuietPeriod: TimeInterval = 30
    static let completionDisplayPeriod: TimeInterval = 5

    static func derive(from events: [CodexEvent], at now: Date = Date()) -> CodexActivitySnapshot {
        let valid = events.filter { now.timeIntervalSince($0.timestamp) >= 0 && now.timeIntervalSince($0.timestamp) < 7_200 }
        guard let latest = valid.last else { return .init(activity: .idle, since: nil) }
        let current = valid.filter { $0.sessionID == latest.sessionID && ($0.turnID == latest.turnID || latest.turnID.isEmpty) }
        guard let last = current.last else { return .init(activity: .idle, since: nil) }
        switch last.name {
        case "Stop":
            let age = now.timeIntervalSince(last.timestamp)
            if age < completionQuietPeriod {
                return .init(activity: .settling, since: last.timestamp)
            }
            if age < completionQuietPeriod + completionDisplayPeriod {
                return .init(activity: .completed, since: last.timestamp)
            }
            return .init(activity: .idle, since: nil)
        case "Interrupt":
            return now.timeIntervalSince(last.timestamp) < 5
                ? .init(activity: .interrupted, since: last.timestamp)
                : .init(activity: .idle, since: nil)
        case "PermissionRequest":
            let age = now.timeIntervalSince(last.timestamp)
            if age >= 2 && age < 90 { return .init(activity: .approval, since: last.timestamp) }
            return .init(activity: .running, since: last.timestamp)
        default:
            return .init(activity: .running, since: last.timestamp)
        }
    }
}

enum CodexHookInstaller {
    static let events = ["UserPromptSubmit", "PermissionRequest", "PostToolUse", "Stop", "Interrupt"]

    static var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/hooks.json")
    }

    static func install(executable: URL) throws {
        let url = configURL
        let existing = (try? Data(contentsOf: url)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        var root = existing
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for event in events {
            var groups = hooks[event] as? [[String: Any]] ?? []
            groups = groups.compactMap { original in
                var group = original
                guard let commands = group["hooks"] as? [[String: Any]] else { return group }
                let retained = commands.filter {
                    !($0["command"] as? String ?? "").contains("--miorbi-codex-event")
                }
                guard !retained.isEmpty else { return nil }
                group["hooks"] = retained
                return group
            }
            let safePath = executable.path.replacingOccurrences(of: "\\", with: "\\\\")
                                          .replacingOccurrences(of: "\"", with: "\\\"")
            let command = "\"\(safePath)\" --miorbi-codex-event \(event)"
            groups.append(["hooks": [["type": "command", "command": command, "timeout": 3]]])
            hooks[event] = groups
        }
        root["hooks"] = hooks
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
