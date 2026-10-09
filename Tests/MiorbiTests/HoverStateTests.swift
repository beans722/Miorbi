import XCTest
@testable import Miorbi

final class HoverStateTests: XCTestCase {
    func testResizeExitAndBoundaryJitterDoNotCollapse() {
        var state = HoverState()
        let now = Date(timeIntervalSince1970: 1000)
        XCTAssertTrue(state.update(inside: true, at: now))
        XCTAssertTrue(state.update(inside: false, at: now.addingTimeInterval(0.1)))
        XCTAssertTrue(state.update(inside: true, at: now.addingTimeInterval(0.2)))
        XCTAssertTrue(state.update(inside: false, at: now.addingTimeInterval(0.3)))
        XCTAssertTrue(state.update(inside: false, at: now.addingTimeInterval(0.6)))
        XCTAssertFalse(state.update(inside: false, at: now.addingTimeInterval(0.7)))
    }
    func testCreditsAreNotPresentedAsLyrics() {
        let lines = SyncedLyrics.parse("[00:00]作词：名字\n[00:01]作曲 : 名字\n[00:02]真正歌词")
        XCTAssertEqual(SyncedLyrics.current(lines, at: 1.5), "")
        XCTAssertEqual(SyncedLyrics.current(lines, at: 2), "真正歌词")
    }
}
