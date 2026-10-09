import XCTest
@testable import Miorbi

final class SettingsPageTests: XCTestCase {
    func testExactlyFiveDistinctPagesInRequestedOrder() {
        XCTAssertEqual(SettingsPage.allCases, [.codex, .lyrics, .focus, .feedback, .about])
        XCTAssertEqual(Set(SettingsPage.allCases.map(\.id)).count, 5)
        XCTAssertEqual(SettingsPage.allCases.map { $0.title(language: "zh") },
                       ["Codex 状态", "歌词", "专注", "我要吐槽", "关于软件"])
        XCTAssertEqual(SettingsPage.allCases.map { $0.title(language: "en") },
                       ["Codex status", "Lyrics", "Focus", "Feedback", "About"])
    }
}
