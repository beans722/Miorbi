import SwiftUI

struct IslandView: View {
    @ObservedObject var store: AppStore
    var notchWidth: CGFloat = 180
    var barHeight: CGFloat = 32
    var wingWidth: CGFloat = 96

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if compactActivity {
                    Group {
                        if codexVisible { leadingContent }
                        else if let pet = store.selectedPet, store.focus.claimedPets.contains(pet) {
                            PetView(pet: pet, isActive: store.focus.phase == .running, now: store.now)
                        } else { Image(systemName: store.music.isPlaying ? "music.note" : "timer").foregroundStyle(.mint) }
                    }.frame(width: 48)
                }
                Color.clear.frame(width: notchWidth)
                if compactActivity {
                    Group {
                        if codexVisible {
                            VStack(alignment: .trailing, spacing: 1) {
                                if store.codex.activity.displaysUsage, let usage = store.usage {
                                    if let five = usage.fiveHour { Text("5h \(five.remainingPercent)%") }
                                    if let week = usage.weekly { Text("7d \(week.remainingPercent)%") }
                                } else if store.codex.activity.displaysUsage {
                                    Text("5h —")
                                    Text("7d —")
                                } else {
                                    Image(systemName: store.codex.activity == .approval ? "exclamationmark.circle.fill" : "checkmark")
                                }
                            }
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .help(codexStatus)
                        } else if store.music.isPlaying && store.focus.phase != .running && store.focus.phase != .paused {
                            Image(systemName: "waveform").font(.system(size: 15))
                        } else {
                            VStack(spacing: 2) {
                                Circle().trim(from: 0, to: store.focus.progress(at: store.now))
                                    .stroke(.mint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                    .rotationEffect(.degrees(-90)).frame(width: 13, height: 13)
                                if store.alwaysShowFocusTime {
                                    let seconds = Int(store.focus.remainingSeconds(at: store.now))
                                    Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
                                        .font(.system(size: 8, weight: .semibold)).monospacedDigit()
                                }
                            }
                        }
                    }
                    .frame(width: 48)
                }
            }
                .padding(.horizontal, compactActivity ? 6 : 0)
                .frame(height: barHeight)
                .background {
                    if !store.isExpanded {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black)
                    }
                }

            VStack(spacing: 0) {
            if showsActivityRow {
                HStack(spacing: 12) {
                    leadingContent
                        .buttonStyle(.plain)
                    Spacer(minLength: 6)
                    Text(store.music.title)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1).foregroundStyle(.white.opacity(0.65))
                }
                .padding(.horizontal, 14)
                .frame(height: 34)
            }

            if store.music.provider == .netease, store.music.playback != .stopped,
               (store.focus.phase != .running && store.focus.phase != .paused) || store.showLyricsDuringFocus,
               store.neteaseLyricsEnabled {
                Text(store.lyric.isEmpty ? (store.lyricError ?? " ") : store.lyric)
                    .font(.system(size: 12, weight: .medium))
                    .shadow(color: .black.opacity(0.85), radius: 2, x: 0, y: 1)
                    .lineLimit(1)
                    .frame(width: contentWidth - 36, alignment: .center)
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
                            Label(compactFocusControls ? store.label("开始", "Start") : store.label("开始专注", "Start focus"), systemImage: "timer")
                                .foregroundStyle(.mint)
                        }
                        Spacer(minLength: compactFocusControls ? 4 : 24)
                        Button { store.choosingFocusDuration.toggle() } label: {
                            HStack(spacing: 7) {
                                Text(store.language == "en" ? "\(store.selectedMinutes) min" : "\(store.selectedMinutes)\(compactFocusControls ? "分" : " 分钟")")
                                    .monospacedDigit()
                                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, compactFocusControls ? 7 : 11)
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
                .buttonStyle(FocusActionStyle(compact: compactFocusControls))
                .padding(.horizontal, compactFocusControls ? 8 : 16)
                .frame(height: 40)
                .transition(.opacity)
            }
            }
            .frame(width: contentWidth)
            .background {
                if !store.isExpanded && showsActivityRow {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black)
                }
            }
        }
        .foregroundStyle(.white)
        .frame(width: contentWidth)
        .background {
            if store.isExpanded {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: store.isExpanded)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var showsActivityRow: Bool {
        store.isExpanded && !codexVisible && store.music.playback != .stopped
    }

    private var compactActivity: Bool {
        codexVisible || store.music.isPlaying || store.focus.phase == .running || store.focus.phase == .paused
    }

    private var contentWidth: CGFloat {
        notchWidth + (compactActivity || (store.isExpanded && store.music.playback != .stopped) ? 108 : 0)
    }

    private var compactFocusControls: Bool { !codexVisible && !store.music.isPlaying }

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
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 10 : 12, weight: .medium))
            .padding(.horizontal, compact ? 7 : 11)
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
