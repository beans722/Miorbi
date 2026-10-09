import SwiftUI

struct MiorbiSettingsView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ScrollView { Form {
            HStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Miorbi").font(.title2.weight(.semibold))
                    Text(store.label("音乐 · 任务 · 专注", "Music · Activity · Focus"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Picker(store.label("界面语言", "Interface language"), selection: $store.language) {
                Text("简体中文").tag("zh")
                Text("English").tag("en")
            }
            .onChange(of: store.language) { _, _ in store.savePreferences() }

            Section(store.label("专注时间", "Focus time")) {
                Text(store.label("满 15 分钟才计入累计；兑换宠物不消耗时间。", "At least 15 minutes counts; claiming pets does not spend time."))
                    .font(.caption)
                Text(store.label("累计专注", "Total focus") + ": \(store.focus.creditedMinutes) min")
                Toggle(store.label("专注时显示歌词", "Lyrics during focus"), isOn: $store.showLyricsDuringFocus)
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

            Section("Codex") {
                Button(store.codexHooksConnected ? store.label("重新连接 Codex", "Reconnect Codex") : store.label("连接 Codex 本地事件", "Connect local Codex events")) {
                    store.connectCodex()
                }
                Text(store.label("仅记录事件类型与会话标识，不记录提示词或工具内容。", "Only event types and session identifiers are saved; prompts and tool contents are not."))
                    .font(.caption)
                Toggle(store.label("同步五小时与周限额（读取本机 Codex 凭据）", "Sync five-hour and weekly limits (reads local Codex credentials)"), isOn: $store.usageSyncEnabled)
                Text(store.label("默认关闭；开启后仅向 ChatGPT 用量接口发送访问令牌，不上传提示词。", "Off by default; when enabled, only the access token is sent to the ChatGPT usage endpoint. Prompts are never uploaded."))
                    .font(.caption)
            }

            Section(store.label("音乐", "Music")) {
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
                Text(store.music.error ?? store.label("播放状态将从 Apple Music 读取；系统会请求自动化权限。", "Playback state is read from Apple Music; macOS may request Automation permission."))
                    .font(.caption)
                Text(store.label("网易云：只读本地播放进度，按歌曲 ID 从 music.163.com 获取同步歌词，不发送账号或 Cookie。Apple Music 歌词仍在开发。", "NetEase: reads local playback state and requests synced lyrics from music.163.com by song ID, without accounts or cookies. Apple Music lyrics are still in development."))
                    .font(.caption)
            }

            Section(store.label("我要吐槽", "Feedback")) {
                Link(store.label("报告 Bug", "Report a bug"), destination: URL(string: "https://github.com/beans722/Miorbi/issues/new?template=bug_report.yml")!)
                Link(store.label("建议新功能", "Suggest a feature"), destination: URL(string: "https://github.com/beans722/Miorbi/issues/new?template=feature_request.yml")!)
                Text(store.label("GitHub 反馈公开可见。请勿发布账号、令牌、私人对话或日志。", "GitHub feedback is public. Do not post accounts, tokens, private chats, or logs."))
                    .font(.caption)
            }
        } }
        .padding(20)
        .onChange(of: store.showLyricsDuringFocus) { _, _ in store.savePreferences() }
        .onChange(of: store.alwaysShowFocusTime) { _, _ in store.savePreferences() }
        .onChange(of: store.usageSyncEnabled) { _, _ in store.savePreferences() }
        .onChange(of: store.neteaseLyricsEnabled) { _, _ in store.savePreferences() }
    }
}
