import SwiftUI

struct IslandView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                leadingContent
                Spacer(minLength: 170)
                if store.focus.phase == .running || store.focus.phase == .paused {
                    focusIndicator
                } else if codexVisible && (!store.music.isPlaying || store.codex.activity == .approval) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(codexStatus)
                        if !store.music.isPlaying, let usage = store.usage {
                            HStack(spacing: 5) {
                                if let five = usage.fiveHour { Text("5h \(five.remainingPercent)%") }
                                if let week = usage.weekly { Text("7d \(week.remainingPercent)%") }
                            }
                            .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 64)

            if store.isExpanded {
                HStack(spacing: 12) {
                    if store.focus.phase == .running {
                        Button(store.label("暂停", "Pause")) { store.pauseFocus() }
                        Button(store.label("结束", "Finish")) { store.finishFocus() }
                    } else if store.focus.phase == .paused {
                        Button(store.label("继续", "Resume")) { store.resumeFocus() }
                        Button(store.label("结束", "Finish")) { store.finishFocus() }
                    } else {
                        Button(store.label("开始专注", "Start focus")) { store.startFocus() }
                        Picker("", selection: $store.selectedMinutes) {
                            Text("15 min").tag(15)
                            Text("25 min").tag(25)
                            Text("60 min").tag(60)
                        }
                        .frame(width: 90)
                        .onChange(of: store.selectedMinutes) { _, _ in store.savePreferences() }
                    }
                    Spacer()
                    if let banner = store.banner { Text(banner).font(.caption).foregroundStyle(.secondary) }
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 16)
                .frame(height: 56)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .frame(maxHeight: .infinity, alignment: .top)
        .onHover { store.isExpanded = $0 }
    }

    private var codexVisible: Bool {
        guard store.codex.activity != .idle else { return false }
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier != "com.openai.codex"
    }

    private var codexStatus: String {
        switch store.codex.activity {
        case .idle: ""
        case .running: store.label("运行中", "Running")
        case .settling: store.label("收尾中", "Wrapping up")
        case .approval: store.label("需要审批", "Approval needed")
        case .completed: store.label("任务完成", "Task complete")
        case .interrupted: store.label("已中断", "Interrupted")
        }
    }

    @ViewBuilder
    private var leadingContent: some View {
        if store.music.playback != .stopped {
            Button { store.musicCommand(.previous) } label: { Image(systemName: "backward.end.fill") }
            Button { store.musicCommand(.toggle) } label: {
                Image(systemName: store.music.isPlaying ? "pause.fill" : "play.fill")
            }
            Button { store.musicCommand(.next) } label: { Image(systemName: "forward.end.fill") }
            if let pet = store.selectedPet, store.focus.claimedPets.contains(pet) {
                PetView(pet: pet, isActive: store.music.isPlaying, now: store.now)
            }
            if store.isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.music.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text(store.music.artist).font(.system(size: 10)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                }
                .frame(maxWidth: 120, alignment: .leading)
            }
        } else if codexVisible {
            if let pet = store.selectedPet, store.focus.claimedPets.contains(pet) {
                PetView(pet: pet, isActive: store.codex.activity == .running, now: store.now)
            } else {
                Image(systemName: store.codex.activity == .approval ? "exclamationmark.circle.fill" : "sparkle")
                    .foregroundStyle(store.codex.activity == .approval ? .orange : .mint)
                    .symbolEffect(.pulse, options: .repeating, isActive: store.codex.activity == .running)
            }
            Text("Codex").font(.system(size: 14, weight: .semibold))
        } else {
            Image(systemName: "circle.hexagongrid.fill").foregroundStyle(.cyan)
            Text("Miorbi").font(.system(size: 14, weight: .semibold))
        }
    }

    private var focusIndicator: some View {
        let remaining = Int(store.focus.remainingSeconds(at: store.now))
        return HStack(spacing: 7) {
            ZStack {
                Circle().stroke(.white.opacity(0.25), lineWidth: 3)
                Circle().trim(from: 0, to: store.focus.progress(at: store.now))
                    .stroke(.mint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: store.focus.phase == .paused ? "pause.fill" : "timer")
                    .font(.system(size: 10))
            }
            .frame(width: 26, height: 26)
            if store.isExpanded || store.alwaysShowFocusTime {
                Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                    .monospacedDigit()
                    .font(.system(size: 12, weight: .semibold))
            }
        }
    }
}

private struct PetView: View {
    let pet: FocusPet
    let isActive: Bool
    let now: Date

    var body: some View {
        let name = pet == .bean ? "bean" : "calf"
        let lift = isActive ? -2 * abs(sin(now.timeIntervalSinceReferenceDate * 3)) : 0
        if let url = Bundle.module.url(forResource: name, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .offset(y: lift)
                .accessibilityLabel(pet == .bean ? "Jumping Bean" : "Little Calf")
        }
    }
}
