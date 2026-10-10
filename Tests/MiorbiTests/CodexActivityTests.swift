import XCTest
@testable import Miorbi

final class CodexActivityTests: XCTestCase {
    func testLimitsRemainDuringCompletionMonitoringAndDisappearOnIdle() {
        XCTAssertTrue(CodexActivity.running.displaysUsage)
        XCTAssertTrue(CodexActivity.approval.displaysUsage)
        XCTAssertTrue(CodexActivity.completed.displaysUsage)
        for state in [CodexActivity.settling, .interrupted, .idle] {
            XCTAssertFalse(state.displaysUsage)
        }
        XCTAssertFalse(CodexActivity.settling.displaysIndicator)
        XCTAssertTrue(CodexActivity.completed.displaysIndicator)
    }
    func testOtherSessionCompletingDoesNotHideActiveTask() {
        let now = Date()
        let working = CodexEvent(name: "PostToolUse", sessionID: "working", turnID: "a", timestamp: now.addingTimeInterval(-10))
        let completed = CodexEvent(name: "Stop", sessionID: "finished", turnID: "b", timestamp: now.addingTimeInterval(-1))
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [working, completed], at: now).activity, .running)
    }
    func testHookDropsPromptAndToolInput() throws {
        let json = Data(#"{"session_id":"s1","turn_id":"t1","prompt":"secret prompt","tool_input":{"token":"secret token"}}"#.utf8)
        let event = try XCTUnwrap(CodexEvent.fromHook(name: "UserPromptSubmit", input: json))
        let stored = String(data: try JSONEncoder().encode(event), encoding: .utf8)!
        XCTAssertFalse(stored.contains("secret"))
        XCTAssertEqual(event.sessionID, "s1")
    }

    func testApprovalIsNotShownImmediatelyAndClearsOnToolUse() {
        let now = Date(timeIntervalSince1970: 10_000)
        let start = CodexEvent(name: "UserPromptSubmit", sessionID: "s", turnID: "t", timestamp: now.addingTimeInterval(-10))
        let approval = CodexEvent(name: "PermissionRequest", sessionID: "s", turnID: "t", timestamp: now.addingTimeInterval(-1))
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [start, approval], at: now).activity, .running)
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [start, approval], at: now.addingTimeInterval(2)).activity, .approval)
        let used = CodexEvent(name: "PostToolUse", sessionID: "s", turnID: "t", timestamp: now.addingTimeInterval(3))
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [start, approval, used], at: now.addingTimeInterval(4)).activity, .running)
    }

    func testCompletionIsImmediateAndNewActivityResumes() {
        let now = Date(timeIntervalSince1970: 10_000)
        let start = CodexEvent(name: "UserPromptSubmit", sessionID: "s", turnID: "t", timestamp: now)
        let firstStop = CodexEvent(name: "Stop", sessionID: "s", turnID: "t", timestamp: now.addingTimeInterval(5))
        let resumed = CodexEvent(name: "PostToolUse", sessionID: "s", turnID: "t", timestamp: now.addingTimeInterval(15))
        let finalStop = CodexEvent(name: "Stop", sessionID: "s", turnID: "t", timestamp: now.addingTimeInterval(20))

        XCTAssertEqual(CodexActivitySnapshot.derive(from: [start, firstStop], at: now.addingTimeInterval(10)).activity, .completed)
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [start, firstStop, resumed], at: now.addingTimeInterval(17)).activity, .running)
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [start, firstStop, resumed, finalStop], at: now.addingTimeInterval(49)).activity, .completed)
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [start, firstStop, resumed, finalStop], at: now.addingTimeInterval(50)).activity, .completed)
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [start, firstStop, resumed, finalStop], at: now.addingTimeInterval(320)).activity, .idle)
    }
    func testFiveAndTenMinuteMonitoringDeadlines() {
        let now = Date(timeIntervalSince1970: 10_000)
        let stop = CodexEvent(name: "Stop", sessionID: "s", turnID: "t", timestamp: now)
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [stop], at: now.addingTimeInterval(299)).activity, .completed)
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [stop], at: now.addingTimeInterval(300)).activity, .idle)
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [stop], at: now.addingTimeInterval(599), monitoringMinutes: 10).activity, .completed)
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [stop], at: now.addingTimeInterval(600), monitoringMinutes: 10).activity, .idle)
        let start = CodexEvent(name: "UserPromptSubmit", sessionID: "s", turnID: "next", timestamp: now.addingTimeInterval(610))
        XCTAssertEqual(CodexActivitySnapshot.derive(from: [stop, start], at: now.addingTimeInterval(611)).activity, .running)
    }

}
