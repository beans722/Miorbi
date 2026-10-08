import AppKit
import Combine
import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var focus: FocusClock
    @Published var selectedMinutes: Int
    @Published var selectedPet: FocusPet?
    @Published var language: String
    @Published var showLyricsDuringFocus: Bool
    @Published var alwaysShowFocusTime: Bool
    @Published var usageSyncEnabled: Bool
    @Published var isExpanded = false
    @Published var now = Date()
    @Published var banner: String?
    @Published var codex = CodexActivitySnapshot(activity: .idle, since: nil)
    @Published var codexHooksConnected = false
    @Published var music = MusicSnapshot()
    @Published var usage: UsageSnapshot?
    @Published var usageError: String?

    private var timer: Timer?
    private var lastMusicPoll = Date.distantPast
    private var lastUsagePoll = Date.distantPast
    private var usagePollInFlight = false
    private var lastFocusCheckpoint = Date.distantPast
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "focusClock"),
           let restored = try? JSONDecoder().decode(FocusClock.self, from: data) {
            var safe = restored
            if safe.phase == .running { safe.suspendAfterRestart() }
            focus = safe
        } else {
            focus = FocusClock()
        }
        let duration = defaults.integer(forKey: "focusMinutes")
        selectedMinutes = [15, 25, 60].contains(duration) ? duration : 25
        selectedPet = defaults.string(forKey: "selectedPet").flatMap(FocusPet.init(rawValue:))
        language = defaults.string(forKey: "language") == "en" ? "en" : "zh"
        showLyricsDuringFocus = defaults.bool(forKey: "showLyricsDuringFocus")
        alwaysShowFocusTime = defaults.bool(forKey: "alwaysShowFocusTime")
        usageSyncEnabled = defaults.bool(forKey: "usageSyncEnabled")
        codexHooksConnected = defaults.bool(forKey: "codexHooksConnected")
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        persistFocus()
    }

    func label(_ chinese: String, _ english: String) -> String {
        language == "zh" ? chinese : english
    }

    func tick() {
        now = Date()
        codex = CodexActivitySnapshot.derive(from: CodexEventFile.recentEvents(), at: now)
        if usageSyncEnabled, !usagePollInFlight, now.timeIntervalSince(lastUsagePoll) >= 300 {
            lastUsagePoll = now
            usagePollInFlight = true
            Task { [weak self] in
                do {
                    self?.usage = try await UsageSync.fetch()
                    self?.usageError = nil
                } catch {
                    self?.usageError = error.localizedDescription
                }
                self?.usagePollInFlight = false
            }
        }
        if now.timeIntervalSince(lastMusicPoll) >= 2 {
            lastMusicPoll = now
            Task { [weak self] in
                let snapshot = await Task.detached(priority: .utility) { MusicBridge.read() }.value
                self?.music = snapshot
            }
        }
        if focus.tick(at: now) {
            banner = label("专注完成", "Focus complete")
            persistFocus()
        } else if focus.phase == .running, now.timeIntervalSince(lastFocusCheckpoint) >= 30 {
            focus.checkpoint(at: now)
            lastFocusCheckpoint = now
            persistFocus()
        }
    }

    func musicCommand(_ action: MusicBridge.Action) {
        Task { [weak self] in
            let error = await Task.detached(priority: .userInitiated) { MusicBridge.command(action) }.value
            if let error { self?.banner = error }
            self?.music = await Task.detached(priority: .utility) { MusicBridge.read() }.value
        }
    }

    func connectCodex() {
        guard let executable = Bundle.main.executableURL else { return }
        do {
            try CodexHookInstaller.install(executable: executable)
            codexHooksConnected = true
            defaults.set(true, forKey: "codexHooksConnected")
            banner = label("Codex 已连接", "Codex connected")
        } catch {
            banner = label("连接失败：", "Connection failed: ") + error.localizedDescription
        }
    }

    func startFocus() {
        focus.start(minutes: selectedMinutes, at: Date())
        banner = nil
        persistFocus()
    }

    func pauseFocus() {
        focus.pause(at: Date())
        persistFocus()
    }

    func resumeFocus() {
        focus.resume(at: Date())
        persistFocus()
    }

    func finishFocus() {
        let credited = focus.finish(at: Date())
        banner = credited ? label("已计入累计专注", "Added to focus total") : label("未满 15 分钟，不计入累计", "Under 15 minutes; not counted")
        persistFocus()
    }

    func claim(_ pet: FocusPet) {
        if focus.claim(pet) { persistFocus() }
    }

    func savePreferences() {
        defaults.set(selectedMinutes, forKey: "focusMinutes")
        defaults.set(selectedPet?.rawValue, forKey: "selectedPet")
        defaults.set(language, forKey: "language")
        defaults.set(showLyricsDuringFocus, forKey: "showLyricsDuringFocus")
        defaults.set(alwaysShowFocusTime, forKey: "alwaysShowFocusTime")
        defaults.set(usageSyncEnabled, forKey: "usageSyncEnabled")
        if !usageSyncEnabled { usage = nil; usageError = nil }
    }

    private func persistFocus() {
        if let data = try? JSONEncoder().encode(focus) {
            defaults.set(data, forKey: "focusClock")
        }
    }
}
