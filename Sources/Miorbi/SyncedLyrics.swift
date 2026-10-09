import Foundation

struct LyricLine: Equatable, Sendable {
    let time: Double
    let text: String
}

enum SyncedLyrics {
    static func parse(_ lrc: String) -> [LyricLine] {
        let expression = try! NSRegularExpression(pattern: #"\[(\d+):(\d+(?:\.\d+)?)\]"#)
        var lines: [LyricLine] = []
        for raw in lrc.components(separatedBy: .newlines) {
            let string = raw as NSString
            let matches = expression.matches(in: raw, range: NSRange(location: 0, length: string.length))
            guard let last = matches.last else { continue }
            let content = string.substring(from: last.range.location + last.range.length).trimmingCharacters(in: .whitespaces)
            let isCredit = content.range(of: #"^(作词|作曲|编曲|制作人|制作|和声|混音|母带|录音|词|曲|Lyrics by|Composed by|Arranged by)\s*[:：]"#, options: [.regularExpression, .caseInsensitive]) != nil
            let text = isCredit ? "" : content
            for match in matches {
                let minute = Double(string.substring(with: match.range(at: 1))) ?? 0
                let second = Double(string.substring(with: match.range(at: 2))) ?? 0
                lines.append(LyricLine(time: minute * 60 + second, text: text))
            }
        }
        return lines.sorted { $0.time < $1.time }
    }

    static func current(_ lines: [LyricLine], at position: Double) -> String {
        lines.last(where: { $0.time <= position })?.text ?? ""
    }

    static func fetchNetEase(id: String) async throws -> [LyricLine] {
        guard !id.isEmpty, id.allSatisfy(\.isNumber) else { return [] }
        let url = URL(string: "https://music.163.com/api/song/lyric?id=\(id)&lv=-1&kv=-1&tv=-1")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.httpShouldHandleCookies = false
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              data.count < 1_000_000,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lrc = json["lrc"] as? [String: Any], let text = lrc["lyric"] as? String else { return [] }
        return parse(text)
    }
}
