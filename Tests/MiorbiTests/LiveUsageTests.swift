import Foundation
import XCTest
@testable import Miorbi

final class LiveUsageTests: XCTestCase {
    func testAuthorizedLocalUsageConnection() async throws {
        guard ProcessInfo.processInfo.environment["MIORBI_LIVE_USAGE_TEST"] == "1" else { throw XCTSkip("Explicit opt-in required for live local credential test") }
        let snapshot = try await UsageSync.fetch()
        XCTAssertNotNil(snapshot.fiveHour)
        XCTAssertNotNil(snapshot.weekly)
        print("Verified remaining: 5h=\(snapshot.fiveHour?.remainingPercent ?? -1)%, week=\(snapshot.weekly?.remainingPercent ?? -1)%")
    }
}
