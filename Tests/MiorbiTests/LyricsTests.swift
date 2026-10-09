import CommonCrypto
import Foundation
import XCTest
@testable import Miorbi

final class LyricsTests: XCTestCase {
    func testSelectionNeverShowsFutureLineAndClearsInstrumental() {
        let lines = SyncedLyrics.parse("[00:01.20]First\n[00:03.10]Second\n[00:04.00]\n[00:05.00][00:06.00]Repeat")
        XCTAssertEqual(SyncedLyrics.current(lines, at: 1.19), "")
        XCTAssertEqual(SyncedLyrics.current(lines, at: 1.2), "First")
        XCTAssertEqual(SyncedLyrics.current(lines, at: 3.09), "First")
        XCTAssertEqual(SyncedLyrics.current(lines, at: 3.1), "Second")
        XCTAssertEqual(SyncedLyrics.current(lines, at: 4.1), "")
        XCTAssertEqual(lines.count, 5)
        XCTAssertEqual(SyncedLyrics.current(lines, at: 1.3), "First") // backwards seek
    }

    func testReadOnlyRecordParserUsesLatestValidRecord() throws {
        func record(_ second: Int) throws -> Data {
            let json = Data("{\"current\":\(second),\"resourceDuration\":180,\"resourceId\":\"123\"}".utf8)
            let key = Array(")(13daqP@ssw0rd~".utf8)
            var output = [UInt8](repeating: 0, count: json.count + 16)
            var written = 0
            XCTAssertEqual(CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode), key, key.count, nil, [UInt8](json), json.count, &output, output.count, &written), CCCryptorStatus(kCCSuccess))
            let value = Data([1]) + Data(output.prefix(written)).base64EncodedData()
            var count = value.count
            var length = Data()
            repeat { let byte = UInt8(count & 127); count >>= 7; length.append(byte | (count > 0 ? 128 : 0)) } while count > 0
            return Data("lastPlaying".utf8) + length + value
        }
        let stream = try record(20) + record(22)
        XCTAssertEqual(NetEasePlayback.decodeRecord(stream)?.current, 22)
        XCTAssertNil(NetEasePlayback.decodeRecord(Data("lastPlaying\u{1}".utf8)))
    }
}
