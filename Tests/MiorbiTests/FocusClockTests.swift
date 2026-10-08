import XCTest
@testable import Miorbi

final class FocusClockTests: XCTestCase {
    func testShortSessionDoesNotCount() {
        var clock = FocusClock()
        let start = Date(timeIntervalSince1970: 1_000)
        clock.start(minutes: 25, at: start)
        XCTAssertFalse(clock.finish(at: start.addingTimeInterval(14 * 60 + 59)))
        XCTAssertEqual(clock.creditedMinutes, 0)
    }

    func testPauseExcludesLockedTimeAndCreditsAfterFifteenMinutes() {
        var clock = FocusClock()
        let start = Date(timeIntervalSince1970: 1_000)
        clock.start(minutes: 25, at: start)
        clock.pause(at: start.addingTimeInterval(10 * 60))
        clock.resume(at: start.addingTimeInterval(60 * 60))
        XCTAssertTrue(clock.finish(at: start.addingTimeInterval(66 * 60)))
        XCTAssertEqual(clock.creditedMinutes, 16)
    }

    func testClaimsDoNotSpendTime() {
        var clock = FocusClock()
        let start = Date(timeIntervalSince1970: 1_000)
        for index in 0..<10 {
            let next = start.addingTimeInterval(Double(index * 2_000))
            clock.start(minutes: 25, at: next)
            XCTAssertTrue(clock.tick(at: next.addingTimeInterval(1_500)))
        }
        XCTAssertEqual(clock.creditedMinutes, 250)
        XCTAssertTrue(clock.claim(.bean))
        XCTAssertTrue(clock.claim(.calf))
        XCTAssertEqual(clock.creditedMinutes, 250)
    }

    func testRestartDoesNotCreditOfflineTime() {
        var clock = FocusClock()
        let start = Date(timeIntervalSince1970: 1_000)
        clock.start(minutes: 25, at: start)
        clock.checkpoint(at: start.addingTimeInterval(10 * 60))
        clock.suspendAfterRestart()
        XCTAssertEqual(clock.phase, .paused)
        XCTAssertEqual(clock.remainingSeconds(at: start.addingTimeInterval(24 * 60 * 60)), 15 * 60)
    }
}
