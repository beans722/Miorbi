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
    @Published var codexMonitoringMinutes: Int
    @Published var isExpanded = false
    @Published var choosingFocusDuration = false
    @Published var now = Date()
    @Published var banner: String?
    @Published var codex = CodexActivitySnapshot(activity: .idle, since: nil)
    @Published var codexHooksConnected = false
    @Published var music = MusicSnapshot()
    @Published var neteaseLyricsEnabled: Bool
    @Published var lyric = ""
    @Published var lyricError: String?
    private var lyricTrack = ""
    private var lyricLines: [LyricLine] = []
    private var lyricCache: [String: [LyricLine]] = [:]
    private var musicPollInFlight = false
    private var lastActivityPoll = Date.distantPast
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
        neteaseLyricsEnabled = defaults.bool(forKey: "neteaseLyricsEnabled")
        if let data = defaults.data(forKey: "focusClock"),
           let restored = try? JSONDecoder().decode(FocusClock.self, from: data) {
            var safe = restored
            if safe.phase == .running { safe.suspendAfterRestart() }
            focus = safe
        } else {
            let legacy = defaults == UserDefaults.standard ? UserDefaults.standard.persistentDomain(forName: "xyz.notchly.Notchly") : nil
            let pets = (legacy?["notchly.focus.claimedPets"] as? [String] ?? []).compactMap { name -> FocusPet? in
                name == "jumpingBean" ? .bean : (name == "calf" ? .calf : nil)
            }
            focus = FocusClock.restoringLegacyTotal(seconds: legacy?["notchly.focus.totalSeconds"] as? Double ?? 0, pets: Set(pets))
        }
        let duration = defaults.integer(forKey: "focusMinutes")
        selectedMinutes = [15, 25, 60].contains(duration) ? duration : 25
        selectedPet = defaults.string(forKey: "selectedPet").flatMap(FocusPet.init(rawValue:))
        language = defaults.string(forKey: "language") == "en" ? "en" : "zh"
        showLyricsDuringFocus = defaults.bool(forKey: "showLyricsDuringFocus")
        alwaysShowFocusTime = defaults.bool(forKey: "alwaysShowFocusTime")
        usageSyncEnabled = defaults.bool(forKey: "usageSyncEnabled")
        codexMonitoringMinutes = defaults.integer(forKey: "codexMonitoringMinutes") == 10 ? 10 : 5
        codexHooksConnected = defaults.bool(forKey: "codexHooksConnected")
        if defaults == UserDefaults.standard, !defaults.bool(forKey: "legacyFocusImported"),
           let legacy = defaults.persistentDomain(forName: "xyz.notchly.Notchly") {
            let names = legacy["notchly.focus.claimedPets"] as? [String] ?? []
            let pets = Set(names.compactMap { $0 == "jumpingBean" ? FocusPet.bean : ($0 == "calf" ? FocusPet.calf : nil) })
            focus.mergeLegacyTotal(seconds: legacy["notchly.focus.totalSeconds"] as? Double ?? 0, pets: pets)
            if selectedPet == nil, let name = legacy["notchly.focus.selectedPet"] as? String {
                selectedPet = name == "jumpingBean" ? .bean : (name == "calf" ? .calf : nil)
                defaults.set(selectedPet?.rawValue, forKey: "selectedPet")
            }
            defaults.set(true, forKey: "legacyFocusImported")
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        persistFocus()
    }

    func label(_ chinese: String, _ english: String) -> String {
        language == "zh" ? chinese : english
    }

    func tick() {
        now = Date()
        if CommandLine.arguments.contains("--debug-music") {
            let report: [String: Any] = ["time": now.timeIntervalSince1970, "title": music.title,
                "position": music.position, "playing": music.isPlaying, "lyric": lyric,
                "pollInFlight": musicPollInFlight, "lyricsEnabled": neteaseLyricsEnabled,
                "error": lyricError ?? music.error ?? "", "codexState": String(describing: codex.activity),
                "fiveHourRemaining": usage?.fiveHour?.remainingPercent ?? -1,
                "weeklyRemaining": usage?.weekly?.remainingPercent ?? -1,
                "usageError": usageError ?? "", "usageEnabled": usageSyncEnabled,
                "expanded": isExpanded, "frontmost": NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]) {
                try? data.write(to: URL(fileURLWithPath: "/private/tmp/miorbi-music-test.json"), options: .atomic)
            }
        }
        if now.timeIntervalSince(lastActivityPoll) >= 1 {
            lastActivityPoll = now
            codex = CodexActivitySnapshot.derive(from: CodexEventFile.recentEvents(), at: now, monitoringMinutes: codexMonitoringMinutes)
        }
        if usageSyncEnabled, codex.activity.displaysIndicator, !usagePollInFlight, now.timeIntervalSince(lastUsagePoll) >= 300 {
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
        if !musicPollInFlight, now.timeIntervalSince(lastMusicPoll) >= 0.2 {
            lastMusicPoll = now
            musicPollInFlight = true
            Task { [weak self] in
                let snapshot = await Task.detached(priority: .utility) { MusicBridge.read() }.value
                self?.music = snapshot
                self?.updateLyrics(snapshot)
                self?.musicPollInFlight = false
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

    private func updateLyrics(_ snapshot: MusicSnapshot) {
        let id = neteaseLyricsEnabled && snapshot.provider == .netease ? snapshot.trackID : ""
        if lyricTrack != id {
            lyricTrack = id
            lyricLines = lyricCache[id] ?? []
            lyric = ""
            lyricError = nil
            if !id.isEmpty, lyricCache[id] == nil {
                Task { [weak self] in
                    do {
                        let lines = try await SyncedLyrics.fetchNetEase(id: id)
                        guard let self else { return }
                        self.lyricCache[id] = lines
                        if self.lyricTrack == id {
                            self.lyricLines = lines
                            self.lyricError = lines.isEmpty ? self.label("这首歌暂无同步歌词", "No synced lyrics for this track") : nil
                        }
                    } catch {
                        if self?.lyricTrack == id { self?.lyricError = error.localizedDescription }
                    }
                }
            }
        }
        lyric = SyncedLyrics.current(lyricLines, at: snapshot.position)
    }

    func musicCommand(_ action: MusicBridge.Action) {
        let provider = music.provider
        Task { [weak self] in
            let error = await Task.detached(priority: .userInitiated) { MusicBridge.command(action, provider: provider) }.value
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
        defaults.set(codexMonitoringMinutes == 10 ? 10 : 5, forKey: "codexMonitoringMinutes")
        defaults.set(neteaseLyricsEnabled, forKey: "neteaseLyricsEnabled")
        if !usageSyncEnabled { usage = nil; usageError = nil }
    }

    private func persistFocus() {
        if let data = try? JSONEncoder().encode(focus) {
            defaults.set(data, forKey: "focusClock")
        }
    }
}
