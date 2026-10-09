import SwiftUI

struct IslandView: View {
    @ObservedObject var store: AppStore
    var notchWidth: CGFloat = 180
    var barHeight: CGFloat = 32
    var wingWidth: CGFloat = 96

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if store.isExpanded || codexVisible {
                HStack(spacing: 10) { leadingContent }
                    .buttonStyle(.plain)
                    .frame(width: wingWidth, alignment: .leading)
                Color.clear.frame(width: notchWidth)
                HStack(spacing: 0) {
                if codexVisible {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(codexStatus)
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if store.codex.activity.displaysUsage {
                        if let usage = store.usage {
                            HStack(spacing: 4) {
                            if let five = usage.fiveHour { Text("5h \(five.remainingPercent)%") }
                            if let week = usage.weekly { Text("7d \(week.remainingPercent)%") }
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        } else { Text(store.label("限额同步中", "Syncing limits")) }
                        }
                    }
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.9), radius: 2, x: 0, y: 1)
                } else if store.focus.phase == .running || store.focus.phase == .paused {
                    focusIndicator
                } else if store.music.playback != .stopped, let pet = store.selectedPet, store.focus.claimedPets.contains(pet) {
                    PetView(pet: pet, isActive: store.music.isPlaying, now: store.now)
                } else if codexVisible && (!store.music.isPlaying || store.codex.activity == .approval) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(codexStatus).font(.system(size: 9, weight: .medium))
                        if !store.music.isPlaying, let usage = store.usage {
                            VStack(alignment: .trailing, spacing: 0) {
                                if let five = usage.fiveHour { Text("5h \(five.remainingPercent)%") }
                                if let week = usage.weekly { Text("7d \(week.remainingPercent)%") }
                            }
                            .foregroundStyle(.white.opacity(0.7))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                }
                }
                .frame(width: wingWidth, alignment: .trailing)
                } else {
                    Color.clear.frame(width: notchWidth)
                }
            }
            .padding(.horizontal, store.isExpanded || codexVisible ? 12 : 0)
            .frame(height: barHeight)

            if store.music.provider == .netease, store.music.playback != .stopped,
               (store.focus.phase != .running && store.focus.phase != .paused) || store.showLyricsDuringFocus,
               store.neteaseLyricsEnabled {
                Text(store.lyric.isEmpty ? (store.lyricError ?? " ") : store.lyric)
                    .font(.system(size: 12, weight: .medium))
                    .shadow(color: .black.opacity(0.85), radius: 2, x: 0, y: 1)
                    .lineLimit(1)
                    .frame(width: (store.isExpanded ? notchWidth + wingWidth * 2 + 24 : notchWidth) - 36, alignment: .center)
                    .clipped()
                    .padding(.horizontal, 18)
                    .frame(height: 26)
                    .accessibilityIdentifier("currentLyric")
            }

            if store.isExpanded {
                HStack(spacing: 12) {
                    if store.focus.phase == .running {
                        Button(store.label("暂停", "Pause")) { store.pauseFocus() }
                        Spacer()
                        Button(store.label("结束", "Finish")) { store.finishFocus() }
                    } else if store.focus.phase == .paused {
                        Button(store.label("继续", "Resume")) { store.resumeFocus() }
                        Spacer()
                        Button(store.label("结束", "Finish")) { store.finishFocus() }
                    } else {
                        Button { store.startFocus() } label: {
                            Label(store.label("开始专注", "Start focus"), systemImage: "timer")
                                .foregroundStyle(.mint)
                        }
                        Spacer(minLength: 24)
                        Button { store.choosingFocusDuration.toggle() } label: {
                            HStack(spacing: 7) {
                                Text(store.language == "en" ? "\(store.selectedMinutes) min" : "\(store.selectedMinutes) 分钟")
                                    .monospacedDigit()
                                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 11)
                            .frame(height: 28)
                            .background(.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $store.choosingFocusDuration, arrowEdge: .bottom) {
                            VStack(spacing: 6) {
                                ForEach([15, 25, 60], id: \.self) { minutes in
                                    Button(store.language == "en" ? "\(minutes) min" : "\(minutes) 分钟") {
                                        store.selectedMinutes = minutes
                                        store.savePreferences()
                                        store.choosingFocusDuration = false
                                    }
                                    .buttonStyle(FocusActionStyle())
                                    .foregroundStyle(store.selectedMinutes == minutes ? .mint : .white)
                                }
                            }
                            .padding(10)
                            .preferredColorScheme(.dark)
                        }
                    }
                }
                .buttonStyle(FocusActionStyle())
                .padding(.horizontal, 16)
                .frame(height: 40)
                .transition(.opacity)
            }
        }
        .foregroundStyle(.white)
        .frame(width: store.isExpanded || codexVisible ? notchWidth + wingWidth * 2 + 24 : notchWidth)
        .background(alignment: .top) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black)
                .frame(width: store.isExpanded || codexVisible ? nil : notchWidth)
                .frame(height: store.isExpanded ? nil : barHeight)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: store.isExpanded)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var codexVisible: Bool {
        store.codex.activity.displaysIndicator && (!store.music.isPlaying || store.codex.activity == .approval)
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
        if !codexVisible && store.music.playback != .stopped {
            Button { store.musicCommand(.previous) } label: { Image(systemName: "backward.end.fill") }
            Button { store.musicCommand(.toggle) } label: {
                Image(systemName: store.music.isPlaying ? "pause.fill" : "play.fill")
            }
            Button { store.musicCommand(.next) } label: { Image(systemName: "forward.end.fill") }
        } else if codexVisible {
            if let pet = store.selectedPet, store.focus.claimedPets.contains(pet) {
                PetView(pet: pet, isActive: store.codex.activity == .running, now: store.now)
            } else {
                Image(systemName: store.codex.activity == .approval ? "exclamationmark.circle.fill" : "sparkle")
                    .foregroundStyle(store.codex.activity == .approval ? .orange : .mint)
                    .symbolEffect(.pulse, options: .repeating, isActive: store.codex.activity == .running)
            }
        } else {
            Color.clear.frame(width: 0, height: 0)
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

private struct FocusActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(.white.opacity(configuration.isPressed ? 0.14 : 0.06), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
