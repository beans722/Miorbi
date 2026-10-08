import SwiftUI

struct MiorbiSettingsView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        Form {
            Picker(store.label("界面语言", "Interface language"), selection: $store.language) {
                Text("简体中文").tag("zh")
                Text("English").tag("en")
            }
            .onChange(of: store.language) { _, _ in store.savePreferences() }

            Section(store.label("专注时间", "Focus time")) {
                Text(store.label("满 15 分钟才计入累计；兑换宠物不消耗时间。", "At least 15 minutes counts; claiming pets does not spend time."))
                    .font(.caption)
                Text(store.label("累计专注", "Total focus") + ": \(store.focus.creditedMinutes) min")
                Toggle(store.label("专注时显示歌词（开发中）", "Lyrics during focus (in development)"), isOn: $store.showLyricsDuringFocus)
                    .disabled(true)
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
                Text(store.music.error ?? store.label("播放状态将从 Apple Music 读取；系统会请求自动化权限。", "Playback state is read from Apple Music; macOS may request Automation permission."))
                    .font(.caption)
                Text(store.label("同步歌词尚未实现；测试版只提供 Apple Music 播放控制。", "Synchronized lyrics are not implemented yet; this beta provides Apple Music playback controls only."))
                    .font(.caption)
            }

            Section(store.label("我要吐槽", "Feedback")) {
                Link(store.label("报告 Bug", "Report a bug"), destination: URL(string: "https://github.com/beans722/Miorbi/issues/new?template=bug_report.yml")!)
                Link(store.label("建议新功能", "Suggest a feature"), destination: URL(string: "https://github.com/beans722/Miorbi/issues/new?template=feature_request.yml")!)
                Text(store.label("GitHub 反馈公开可见。请勿发布账号、令牌、私人对话或日志。", "GitHub feedback is public. Do not post accounts, tokens, private chats, or logs."))
                    .font(.caption)
            }
        }
        .padding(20)
        .onChange(of: store.showLyricsDuringFocus) { _, _ in store.savePreferences() }
        .onChange(of: store.alwaysShowFocusTime) { _, _ in store.savePreferences() }
        .onChange(of: store.usageSyncEnabled) { _, _ in store.savePreferences() }
    }
}
