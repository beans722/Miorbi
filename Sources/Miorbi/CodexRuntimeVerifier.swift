import Foundation
import SQLite3

enum CodexRuntimeState: Equatable, Sendable {
    case active
    case completed(Date)
    case interrupted(Date)
    case superseded
    case unknown
}

// Read-only, local verification. Queries only status/timestamps and extracts
// lifecycle metadata from bounded log tails. Never stores or sends message text.
actor CodexRuntimeVerifier {
    private let historyURL: URL
    private let sessionsURL: URL
    private var paths: [String: [URL]] = [:]
    private var indexedAt = Date.distantPast
    private var indexedIDs = Set<String>()
    private var logCache: [String: (modified: Date, state: CodexRuntimeState)] = [:]

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        historyURL = home.appendingPathComponent(".codex/thread_history_1.sqlite")
        sessionsURL = home.appendingPathComponent(".codex/sessions")
    }

    static func key(_ event: CodexEvent) -> String { event.sessionID + ":" + event.turnID }

    func read(events: [CodexEvent], at now: Date) -> [String: CodexRuntimeState] {
        let current = Dictionary(grouping: events, by: \.sessionID).values.compactMap {
            $0.max { $0.timestamp < $1.timestamp }
        }.filter { now.timeIntervalSince($0.timestamp) >= 0 }
        let ids = Set(current.map(\.sessionID))
        if now.timeIntervalSince(indexedAt) >= 30 || ids != indexedIDs {
            paths = [:]
            if let files = FileManager.default.enumerator(at: sessionsURL,
                includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) {
                for case let file as URL in files where file.pathExtension == "jsonl" {
                    for id in ids where file.lastPathComponent.contains(id) {
                        paths[id, default: []].append(file)
                    }
                }
            }
            indexedIDs = ids
            indexedAt = now
        }
        return Dictionary(uniqueKeysWithValues: current.map { event in
            let terminal = historyTerminal(event)
            if terminal != .unknown { return (Self.key(event), terminal) }
            let files = (paths[event.sessionID] ?? []).sorted {
                modificationDate($0) > modificationDate($1)
            }
            return (Self.key(event), files.first.map { logState($0, event: event, at: now) } ?? .unknown)
        })
    }

    private func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func historyTerminal(_ event: CodexEvent) -> CodexRuntimeState {
        var database: OpaquePointer?
        guard sqlite3_open_v2(historyURL.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            if database != nil { sqlite3_close(database) }
            return .unknown
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 50)
        var query: OpaquePointer?
        guard sqlite3_prepare_v2(database,
            "SELECT status, completed_at FROM thread_turns WHERE thread_id=? AND turn_id=? LIMIT 1",
            -1, &query, nil) == SQLITE_OK else { return .unknown }
        defer { sqlite3_finalize(query) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(query, 1, event.sessionID, -1, transient)
        sqlite3_bind_text(query, 2, event.turnID, -1, transient)
        guard sqlite3_step(query) == SQLITE_ROW,
              let bytes = sqlite3_column_text(query, 0), sqlite3_column_type(query, 1) != SQLITE_NULL else { return .unknown }
        let status = String(cString: bytes)
        let date = Date(timeIntervalSince1970: sqlite3_column_double(query, 1))
        guard date >= event.timestamp.addingTimeInterval(-2) else { return .unknown }
        if status == "completed" { return .completed(date) }
        if ["interrupted", "failed"].contains(status) { return .interrupted(date) }
        return .unknown
    }

    private func logState(_ file: URL, event: CodexEvent, at now: Date) -> CodexRuntimeState {
        let key = Self.key(event)
        let modified = modificationDate(file)
        if let cached = logCache[key], cached.modified == modified {
            if cached.state == .active && now.timeIntervalSince(modified) >= 60 { return .unknown }
            return cached.state
        }
        guard let handle = try? FileHandle(forReadingFrom: file) else { return .unknown }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return .unknown }
        let offset = size > 131_072 ? size - 131_072 : 0
        guard (try? handle.seek(toOffset: offset)) != nil,
              let data = try? handle.read(upToCount: 131_072) else { return .unknown }
        let state = Self.parseLifecycle(data, event: event, modifiedAt: modified, at: now)
        logCache[key] = (modified, state)
        return state
    }

    static func parseLifecycle(_ data: Data, event: CodexEvent, modifiedAt: Date, at now: Date) -> CodexRuntimeState {
        var matching = false
        var terminal: CodexRuntimeState = .unknown
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        for line in data.split(separator: 0x0A) {
            guard let record = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  record["type"] as? String == "event_msg",
                  let payload = record["payload"] as? [String: Any],
                  let kind = payload["type"] as? String,
                  let turn = payload["turn_id"] as? String,
                  let stamp = record["timestamp"] as? String,
                  let date = fractional.date(from: stamp) ?? plain.date(from: stamp),
                  date <= now.addingTimeInterval(2) else { continue }
            if ["task_started", "turn_started"].contains(kind), turn != event.turnID, date > event.timestamp {
                return .superseded
            }
            guard turn == event.turnID else { continue }
            matching = true
            if ["task_complete", "task_completed", "turn_completed"].contains(kind), date >= event.timestamp {
                terminal = .completed(date)
            } else if ["turn_aborted", "turn_interrupted", "task_failed"].contains(kind), date >= event.timestamp {
                terminal = .interrupted(date)
            }
        }
        if terminal != .unknown { return terminal }
        // File freshness only confirms activity when this exact turn matches.
        // Old files, missing files and unsupported formats never renew a lease.
        if matching, now.timeIntervalSince(modifiedAt) >= 0, now.timeIntervalSince(modifiedAt) < 60 { return .active }
        return .unknown
    }
}
