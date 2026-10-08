import Foundation
import Testing
@testable import Miorbi

struct UsageParserTests {
    @Test func parsesBothWindows() {
        let data = Data(#"{"rate_limit":{"primary_window":{"used_percent":8,"reset_at":1770000000},"secondary_window":{"used_percent":46,"reset_at":1770500000}}}"#.utf8)
        let usage = UsageParser.parse(data)
        #expect(usage?.fiveHour?.remainingPercent == 92)
        #expect(usage?.weekly?.remainingPercent == 54)
    }

    @Test func rejectsUnknownShape() {
        #expect(UsageParser.parse(Data(#"{"hello":"world"}"#.utf8)) == nil)
    }
}
