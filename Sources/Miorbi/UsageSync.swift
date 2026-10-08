import Foundation

struct UsageWindow: Equatable {
    let usedPercent: Double
    let resetsAt: Date?

    var remainingPercent: Int { Int((100 - usedPercent).clamped(to: 0...100).rounded()) }
}

struct UsageSnapshot: Equatable {
    let fiveHour: UsageWindow?
    let weekly: UsageWindow?
    let fetchedAt: Date
}

enum UsageParser {
    static func parse(_ data: Data, at now: Date = Date()) -> UsageSnapshot? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rateLimit = root["rate_limit"] as? [String: Any] else { return nil }
        let primary = window(rateLimit["primary_window"])
        let secondary = window(rateLimit["secondary_window"])
        guard primary != nil || secondary != nil else { return nil }
        return UsageSnapshot(fiveHour: primary, weekly: secondary, fetchedAt: now)
    }

    private static func window(_ value: Any?) -> UsageWindow? {
        guard let dictionary = value as? [String: Any],
              let number = dictionary["used_percent"] as? NSNumber else { return nil }
        let reset = (dictionary["reset_at"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
        return UsageWindow(usedPercent: number.doubleValue.clamped(to: 0...100), resetsAt: reset)
    }
}

enum UsageSync {
    static func fetch() async throws -> UsageSnapshot {
        let authURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
        let data = try Data(contentsOf: authURL)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = root["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String,
              !token.isEmpty else { throw UsageError.credentialsUnavailable }
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UsageError.serverUnavailable
        }
        guard let snapshot = UsageParser.parse(responseData) else { throw UsageError.unrecognizedResponse }
        return snapshot
    }

    enum UsageError: LocalizedError {
        case credentialsUnavailable, serverUnavailable, unrecognizedResponse

        var errorDescription: String? {
            switch self {
            case .credentialsUnavailable: "Codex credentials unavailable"
            case .serverUnavailable: "Usage service unavailable"
            case .unrecognizedResponse: "Usage response format changed"
            }
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double { min(range.upperBound, max(range.lowerBound, self)) }
}
