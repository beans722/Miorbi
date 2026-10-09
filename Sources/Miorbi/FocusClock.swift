import Foundation

enum FocusPet: String, CaseIterable, Codable {
    case bean
    case calf

    var requiredMinutes: Int { self == .bean ? 25 : 250 }
}

struct FocusClock: Codable, Equatable {
    enum Phase: String, Codable { case idle, running, paused, finished }

    private(set) var phase: Phase = .idle
    private(set) var durationMinutes: Int = 25
    private(set) var accumulatedSeconds: TimeInterval = 0
    private(set) var completedSeconds: TimeInterval = 0
    private(set) var startedAt: Date?
    private(set) var claimedPets: Set<FocusPet> = []

    var creditedMinutes: Int { Int(accumulatedSeconds / 60) }

    static func restoringLegacyTotal(seconds: Double, pets: Set<FocusPet>) -> FocusClock {
        var clock = FocusClock()
        clock.accumulatedSeconds = seconds.isFinite ? max(0, seconds) : 0
        clock.claimedPets = pets
        return clock
    }

    mutating func mergeLegacyTotal(seconds: Double, pets: Set<FocusPet>) {
        if seconds.isFinite { accumulatedSeconds = max(accumulatedSeconds, seconds) }
        claimedPets.formUnion(pets)
    }

    func remainingSeconds(at now: Date) -> TimeInterval {
        let elapsed = completedSeconds + (phase == .running ? max(0, now.timeIntervalSince(startedAt ?? now)) : 0)
        return max(0, Double(durationMinutes * 60) - elapsed)
    }

    func progress(at now: Date) -> Double {
        guard durationMinutes > 0 else { return 0 }
        return min(1, max(0, 1 - remainingSeconds(at: now) / Double(durationMinutes * 60)))
    }

    mutating func start(minutes: Int, at now: Date) {
        guard [15, 25, 60].contains(minutes) else { return }
        durationMinutes = minutes
        completedSeconds = 0
        startedAt = now
        phase = .running
    }

    mutating func pause(at now: Date) {
        guard phase == .running else { return }
        completedSeconds += max(0, now.timeIntervalSince(startedAt ?? now))
        startedAt = nil
        phase = .paused
    }

    mutating func suspendAfterRestart() {
        guard phase == .running else { return }
        // Persisted elapsed time is authoritative; app downtime is not focus time.
        startedAt = nil
        phase = .paused
    }

    mutating func checkpoint(at now: Date) {
        guard phase == .running else { return }
        completedSeconds += max(0, now.timeIntervalSince(startedAt ?? now))
        startedAt = now
    }

    mutating func resume(at now: Date) {
        guard phase == .paused else { return }
        startedAt = now
        phase = .running
    }

    @discardableResult
    mutating func finish(at now: Date) -> Bool {
        guard phase == .running || phase == .paused else { return false }
        if phase == .running {
            completedSeconds += max(0, now.timeIntervalSince(startedAt ?? now))
        }
        let credited = min(completedSeconds, Double(durationMinutes * 60))
        if credited >= 15 * 60 { accumulatedSeconds += credited }
        completedSeconds = 0
        startedAt = nil
        phase = .finished
        return credited >= 15 * 60
    }

    mutating func tick(at now: Date) -> Bool {
        guard phase == .running, remainingSeconds(at: now) <= 0 else { return false }
        _ = finish(at: now)
        return true
    }

    @discardableResult
    mutating func claim(_ pet: FocusPet) -> Bool {
        guard creditedMinutes >= pet.requiredMinutes else { return false }
        claimedPets.insert(pet)
        return true
    }
}
