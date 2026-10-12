import Foundation
import XCTest
@testable import Miorbi

final class CodexRuntimeVerifierTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 10_000)

    func testMissingStopExpiresAtFiveOrTenMinutes() {
        for name in ["UserPromptSubmit", "PostToolUse", "PermissionRequest"] {
            let event = CodexEvent(name: name, sessionID: "s", turnID: "t", timestamp: now)
            XCTAssertEqual(CodexActivitySnapshot.derive(from: [event], at: now.addingTimeInterval(300)).activity, .idle)
            XCTAssertNotEqual(CodexActivitySnapshot.derive(from: [event], at: now.addingTimeInterval(599), monitoringMinutes: 10).activity, .idle)
            XCTAssertEqual(CodexActivitySnapshot.derive(from: [event], at: now.addingTimeInterval(600), monitoringMinutes: 10).activity, .idle)
        }
    }

    func testVerifiedLongRunningTaskDoesNotExpire() {
        let event = CodexEvent(name: "PostToolUse", sessionID: "s", turnID: "t", timestamp: now)
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [event], at: now.addingTimeInterval(10_000),
            runtime: [CodexRuntimeVerifier.key(event): .active]).activity, .running)
    }

    func testNativeCompletionOverridesMissingStopAndThenSleeps() {
        let event = CodexEvent(name: "PostToolUse", sessionID: "s", turnID: "t", timestamp: now)
        let evidence: [String: CodexRuntimeState] = [CodexRuntimeVerifier.key(event): .completed(now.addingTimeInterval(40))]
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [event], at: now.addingTimeInterval(41), runtime: evidence).activity, .completed)
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [event], at: now.addingTimeInterval(340), runtime: evidence).activity, .idle)
        let next = CodexEvent(name: "UserPromptSubmit", sessionID: "s", turnID: "next", timestamp: now.addingTimeInterval(350))
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [event, next], at: now.addingTimeInterval(351), runtime: evidence).activity, .running)
    }

    func testStaleSessionDoesNotMaskOtherSessionCompletion() {
        let stale = CodexEvent(name: "PostToolUse", sessionID: "stale", turnID: "x", timestamp: now.addingTimeInterval(-3600))
        let stop = CodexEvent(name: "Stop", sessionID: "finished", turnID: "y", timestamp: now.addingTimeInterval(-10))
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [stale, stop], at: now).activity, .completed)
    }

    func testLifecycleParserChecksExactTurnAndDoesNotNeedMessageText() throws {
        let event = CodexEvent(name: "PostToolUse", sessionID: "s", turnID: "t", timestamp: now.addingTimeInterval(-100))
        let stamp = ISO8601DateFormatter().string(from: now)
        let data = try JSONSerialization.data(withJSONObject: ["type": "event_msg", "timestamp": stamp,
            "payload": ["type": "task_complete", "turn_id": "t"]])
        XCTAssertEqual(CodexRuntimeVerifier.parseLifecycle(data, event: event, modifiedAt: now, at: now), .completed(now))
        let other = CodexEvent(name: "PostToolUse", sessionID: "s", turnID: "different", timestamp: event.timestamp)
        XCTAssertEqual(CodexRuntimeVerifier.parseLifecycle(data, event: other, modifiedAt: now, at: now), .unknown)
        let partial = Data("not-json\n".utf8) + data
        XCTAssertEqual(CodexRuntimeVerifier.parseLifecycle(partial, event: event, modifiedAt: now, at: now), .completed(now))
    }

    func testOldLogDoesNotRenewRunningLease() throws {
        let event = CodexEvent(name: "UserPromptSubmit", sessionID: "s", turnID: "t", timestamp: now.addingTimeInterval(-400))
        let stamp = ISO8601DateFormatter().string(from: event.timestamp)
        let data = try JSONSerialization.data(withJSONObject: ["type": "event_msg", "timestamp": stamp,
            "payload": ["type": "task_started", "turn_id": "t"]])
        XCTAssertEqual(CodexRuntimeVerifier.parseLifecycle(data, event: event, modifiedAt: now.addingTimeInterval(-100), at: now), .unknown)
        XCTAssertEqual(CodexRuntimeVerifier.parseLifecycle(data, event: event, modifiedAt: now, at: now), .active)
    }

    func testLocalMetadataVerificationWhenExplicitlyRequested() async throws {
        guard ProcessInfo.processInfo.environment["MIORBI_RUNTIME_TEST"] == "1" else {
            throw XCTSkip("Read-only local metadata check is opt-in")
        }
        let at = Date()
        let events = CodexEventFile.recentEvents()
        let evidence = await CodexRuntimeVerifier().read(events: events, at: at)
        let latest = Dictionary(grouping: events, by: \.sessionID).values.compactMap {
            $0.max { $0.timestamp < $1.timestamp }
        }
        var expired = 0
        for event in latest where at.timeIntervalSince(event.timestamp) >= 600 && !["Stop", "Interrupt"].contains(event.name) {
            let state = evidence[CodexRuntimeVerifier.key(event)] ?? .unknown
            if state == .unknown || state == .superseded {
                XCTAssertEqual(CodexActivitySnapshot.derive(from: [event], at: at,
                    monitoringMinutes: 10, runtime: evidence).activity, .idle)
                expired += 1
            }
        }
        print("Read-only runtime verification: expired stale sessions=\(expired); checked session metadata=\(latest.count)")
    }
}
