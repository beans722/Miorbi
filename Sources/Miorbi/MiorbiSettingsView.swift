import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case codex, lyrics, focus, feedback, about
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .codex: "terminal"
        case .lyrics: "text.quote"
        case .focus: "timer"
        case .feedback: "bubble.left.and.bubble.right"
        case .about: "info.circle"
        }
    }
    func title(language: String) -> String {
        let english = language == "en"
        switch self {
        case .codex: return english ? "Codex status" : "Codex 状态"
        case .lyrics: return english ? "Lyrics" : "歌词"
        case .focus: return english ? "Focus" : "专注"
        case .feedback: return english ? "Feedback" : "我要吐槽"
        case .about: return english ? "About" : "关于软件"
        }
    }
}

struct MiorbiSettingsView: View {
    @ObservedObject var store: AppStore
    @State private var selectedPage: SettingsPage = .codex

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 9) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable().frame(width: 32, height: 32)
                    Text("Miorbi").font(.headline)
                }.padding(.bottom, 18)
                ForEach(SettingsPage.allCases) { page in
                    Button {
                        selectedPage = page
                    } label: {
                        Label(page.title(language: store.language), systemImage: page.symbol)
                            .font(.system(size: 12, weight: selectedPage == page ? .semibold : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).padding(.vertical, 10)
                            .background(selectedPage == page ? Color.accentColor.opacity(0.15) : .clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-nav-" + page.rawValue)
                }
                Spacer()
            }
            .padding(16).frame(width: 175)
            .background(Color(nsColor: .windowBackgroundColor))
            Divider()
            VStack(alignment: .leading, spacing: 16) {
                Text(selectedPage.title(language: store.language))
                    .font(.title2.weight(.semibold))
                ScrollView {
                    Form {
                        switch selectedPage {
                        case .codex: codexPage
                        case .lyrics: lyricsPage
                        case .focus: focusPage
                        case .feedback: feedbackPage
                        case .about: aboutPage
                        }
                    }
                    .formStyle(.grouped)
                }
            }.padding(22).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onChange(of: store.language) { _, _ in store.savePreferences() }
        .onChange(of: store.showLyricsDuringFocus) { _, _ in store.savePreferences() }
        .onChange(of: store.alwaysShowFocusTime) { _, _ in store.savePreferences() }
        .onChange(of: store.usageSyncEnabled) { _, _ in store.savePreferences() }
        .onChange(of: store.codexMonitoringMinutes) { _, _ in store.savePreferences() }
        .onChange(of: store.neteaseLyricsEnabled) { _, _ in store.savePreferences() }
    }

    private var codexPage: some View {
            Section("Codex") {
                Picker(store.label("任务结束后继续监控", "Monitor after completion"), selection: $store.codexMonitoringMinutes) {
                    Text(store.label("5 分钟", "5 minutes")).tag(5)
                    Text(store.label("10 分钟", "10 minutes")).tag(10)
                }
                Text(store.label("结束后显示任务结束和 Zzz；无新任务达到时限后隐藏 Codex 与限额，仍监听新任务。音乐与专注不受影响。", "Shows Finished and Zzz after Stop; hides Codex/limits after the selected quiet window while listening for new tasks. Music and focus stay available."))
                    .font(.caption)
                LabeledContent(store.label("当前状态", "Current status"), value: codexStatus)
                LabeledContent(store.label("本地事件", "Local events"), value: store.codexHooksConnected ? store.label("已连接", "Connected") : store.label("未连接", "Not connected"))
                LabeledContent(store.label("五小时剩余", "Five-hour remaining"), value: store.usage?.fiveHour.map { "\($0.remainingPercent)%" } ?? "—")
                LabeledContent(store.label("每周剩余", "Weekly remaining"), value: store.usage?.weekly.map { "\($0.remainingPercent)%" } ?? "—")
                Button(store.codexHooksConnected ? store.label("重新连接 Codex", "Reconnect Codex") : store.label("连接 Codex 本地事件", "Connect local Codex events")) {
                    store.connectCodex()
                }
                Text(store.label("仅记录事件类型与会话标识，不记录提示词或工具内容。", "Only event types and session identifiers are saved; prompts and tool contents are not."))
                    .font(.caption)
                Toggle(store.label("同步五小时与周限额（读取本机 Codex 凭据）", "Sync five-hour and weekly limits (reads local Codex credentials)"), isOn: $store.usageSyncEnabled)
                Text(store.label("默认关闭；开启后仅向 ChatGPT 用量接口发送访问令牌，不上传提示词。", "Off by default; when enabled, only the access token is sent to the ChatGPT usage endpoint. Prompts are never uploaded."))
                    .font(.caption)
            }


    }

    private var lyricsPage: some View {
            Section(store.label("歌词与播放权限", "Lyrics and playback permissions")) {
                if let banner = store.banner { Text(banner).font(.caption).foregroundStyle(.secondary) }
                Button(store.label("连接网易云播放数据", "Connect NetEase playback data")) {
                    NSApp.activate(ignoringOtherApps: true)
                    store.music = MusicBridge.read()
                }
                Button(store.label("打开播放数据权限设置", "Open playback data permissions")) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")!)
                }
                Text(store.label("若读取被阻止：在“隐私与安全性 → 文件与文件夹 → Miorbi”开启网易云音乐。此权限仅影响网易云接入，不影响刘海布局或 Codex 限额。", "If access is blocked, enable NetEase under Privacy & Security → Files & Folders → Miorbi. This permission does not affect island layout or Codex limits."))
                    .font(.caption)
                Toggle(store.label("网易云同步歌词（仅向网易云发送歌曲 ID）", "NetEase synced lyrics (sends only song ID to NetEase)"), isOn: $store.neteaseLyricsEnabled)
                Toggle(store.label("专注时显示歌词", "Lyrics during focus"), isOn: $store.showLyricsDuringFocus)
                Text(store.music.error ?? store.label("播放状态将从 Apple Music 读取；系统会请求自动化权限。", "Playback state is read from Apple Music; macOS may request Automation permission."))
                    .font(.caption)
                Text(store.label("网易云：只读本地播放进度，按歌曲 ID 从 music.163.com 获取同步歌词，不发送账号或 Cookie。Apple Music 歌词仍在开发。", "NetEase: reads local playback state and requests synced lyrics from music.163.com by song ID, without accounts or cookies. Apple Music lyrics are still in development."))
                    .font(.caption)
            }


    }

    private var focusPage: some View {
            Section(store.label("专注时间", "Focus time")) {
                Text(store.label("满 15 分钟才计入累计；兑换宠物不消耗时间。", "At least 15 minutes counts; claiming pets does not spend time."))
                    .font(.caption)
                Text(store.label("累计专注", "Total focus") + ": \(store.focus.creditedMinutes) min")
                Toggle(store.label("时间常显", "Always show exact time"), isOn: $store.alwaysShowFocusTime)
                ForEach(FocusPet.allCases, id: \.self) { pet in
                    HStack {
                        Text(pet == .bean ? store.label("跳跃豆子", "Jumping Bean") : store.label("小牛", "Little Calf"))
                        Spacer()
                        Text("\(pet.requiredMinutes) min")
                            .foregroundStyle(.secondary)
                        if store.focus.claimedPets.contains(pet) {
                            Button(store.selectedPet == pet ? store.label("使用中", "Selected") : store.label("使用", "Use")) {
                                store.selectedPet = pet
                                store.savePreferences()
                            }
                        } else {
                            Button(store.label("兑换", "Claim")) { store.claim(pet) }
                                .disabled(store.focus.creditedMinutes < pet.requiredMinutes)
                        }
                    }
                }
            }


    }

    private var feedbackPage: some View {
            Section(store.label("我要吐槽", "Feedback")) {
                Link(store.label("报告 Bug", "Report a bug"), destination: URL(string: "https://github.com/beans722/Miorbi/issues/new?template=bug_report.yml")!)
                Link(store.label("建议新功能", "Suggest a feature"), destination: URL(string: "https://github.com/beans722/Miorbi/issues/new?template=feature_request.yml")!)
                Text(store.label("GitHub 反馈公开可见。请勿发布账号、令牌、私人对话或日志。", "GitHub feedback is public. Do not post accounts, tokens, private chats, or logs."))
                    .font(.caption)
            }

    }

    private var codexStatus: String {
        switch store.codex.activity {
        case .idle: store.label("空闲", "Idle")
        case .running: store.label("运行中", "Running")
        case .settling: store.label("收尾中", "Settling")
        case .approval: store.label("需要审批", "Approval needed")
        case .completed: store.label("任务结束 · 监控中", "Finished · Monitoring")
        case .interrupted: store.label("已中断", "Interrupted")
        }
    }

    private var aboutPage: some View {
        Group {
            Section("Miorbi") {
                HStack(spacing: 12) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable().frame(width: 54, height: 54)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Miorbi").font(.headline)
                        Text(store.label("音乐 · 任务 · 专注", "Music · Activity · Focus"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                LabeledContent(store.label("版本", "Version"),
                    value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? store.label("开发构建", "Development build"))
                LabeledContent(store.label("构建", "Build"),
                    value: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")
                LabeledContent(store.label("发布版本", "Release"),
                    value: Bundle.main.object(forInfoDictionaryKey: "MiorbiReleaseTag") as? String ?? "—")
            }
            Section(store.label("语言", "Language")) {
                Picker(store.label("界面语言", "Interface language"), selection: $store.language) {
                    Text("简体中文").tag("zh")
                    Text("English").tag("en")
                }
            }
            Section(store.label("项目与许可", "Project and license")) {
                Link(store.label("GitHub 项目", "GitHub repository"), destination: URL(string: "https://github.com/beans722/Miorbi")!)
                Link(store.label("下载与更新", "Downloads and updates"), destination: URL(string: "https://github.com/beans722/Miorbi/releases")!)
                Link("MPL-2.0", destination: URL(string: "https://github.com/beans722/Miorbi/blob/main/LICENSE")!)
                Text(store.label("无分析统计或自动上传日志。测试包未经 Apple 公证。", "No analytics or automatic log uploads. Beta packages are not Apple-notarized."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
