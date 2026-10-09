import AppKit
import Foundation
import ApplicationServices

struct MusicSnapshot: Equatable, Sendable {
    enum Provider: Sendable { case appleMusic, netease }
    var provider: Provider = .appleMusic
    var trackID = ""
    var sampleDate = Date()
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
        if let netease = NetEasePlayback.read(), netease.isPlaying { return netease }
        guard NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == "com.apple.Music" }) else {
            return NetEasePlayback.read() ?? MusicSnapshot()
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

    static func command(_ action: Action, provider: MusicSnapshot.Provider = .appleMusic) -> String? {
        if provider == .netease { return neteaseCommand(action) }
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

    private static func neteaseCommand(_ action: Action) -> String? {
        guard AXIsProcessTrusted() else { return "请在系统设置中为 Miorbi 开启辅助功能，才能控制网易云播放" }
        guard let pid = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.netease.163music" })?.processIdentifier else { return "网易云音乐未运行" }
        func children(_ element: AXUIElement, _ attribute: CFString = kAXChildrenAttribute as CFString) -> [AXUIElement] {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return [] }
            return value as? [AXUIElement] ?? []
        }
        func title(_ element: AXUIElement) -> String {
            var value: CFTypeRef?
            _ = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value)
            return value as? String ?? ""
        }
        let app = AXUIElementCreateApplication(pid)
        var bar: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &bar) == .success, let bar else { return "无法读取网易云控制菜单" }
        let menuBar = bar as! AXUIElement
        guard let control = children(menuBar).first(where: { ["控制", "Controls", "Control"].contains(title($0)) }) else { return "未找到网易云控制菜单" }
        let names: Set<String>
        switch action {
        case .previous: names = ["上一个", "Previous", "Previous Track"]
        case .next: names = ["下一个", "Next", "Next Track"]
        case .toggle: names = ["播放", "暂停", "Play", "Pause"]
        }
        let items = children(control).flatMap { children($0) }
        guard let item = items.first(where: { names.contains(title($0)) }) else { return "网易云菜单没有对应控制项" }
        return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success ? nil : "网易云播放控制失败"
    }
}
