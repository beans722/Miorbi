import AppKit
import Foundation

struct MusicSnapshot: Equatable, Sendable {
    enum Playback: Sendable { case stopped, paused, playing }
    var playback: Playback = .stopped
    var title = ""
    var artist = ""
    var duration: TimeInterval = 0
    var position: TimeInterval = 0
    var error: String?

    var isPlaying: Bool { playback == .playing }
}

enum MusicBridge {
    static func read() -> MusicSnapshot {
        guard NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == "com.apple.Music" }) else {
            return MusicSnapshot()
        }
        let source = """
        tell application id "com.apple.Music"
            if player state is stopped then return "stopped"
            set t to current track
            return (player state as text) & "|||" & (name of t as text) & "|||" & (artist of t as text) & "|||" & (duration of t as text) & "|||" & (player position as text)
        end tell
        """
        var error: NSDictionary?
        guard let output = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue else {
            return MusicSnapshot(error: error?[NSAppleScript.errorMessage] as? String ?? "Music automation unavailable")
        }
        let parts = output.components(separatedBy: "|||")
        guard parts.count == 5 else { return MusicSnapshot() }
        var value = MusicSnapshot()
        value.playback = parts[0] == "playing" ? .playing : .paused
        value.title = parts[1]
        value.artist = parts[2]
        value.duration = Double(parts[3]) ?? 0
        value.position = Double(parts[4]) ?? 0
        return value
    }

    static func command(_ action: Action) -> String? {
        let verb: String
        switch action {
        case .previous: verb = "previous track"
        case .toggle: verb = "playpause"
        case .next: verb = "next track"
        }
        var error: NSDictionary?
        _ = NSAppleScript(source: "tell application id \"com.apple.Music\" to \(verb)")?.executeAndReturnError(&error)
        return error?[NSAppleScript.errorMessage] as? String
    }

    enum Action: Sendable { case previous, toggle, next }
}
