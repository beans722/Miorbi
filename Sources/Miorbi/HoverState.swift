import Foundation

struct HoverState {
    private(set) var expanded = false
    private var leftAt: Date?

    mutating func update(inside: Bool, at now: Date) -> Bool {
        if inside {
            leftAt = nil
            expanded = true
        } else if expanded {
            if leftAt == nil { leftAt = now }
            if now.timeIntervalSince(leftAt!) >= 0.35 { expanded = false; leftAt = nil }
        }
        return expanded
    }
}
