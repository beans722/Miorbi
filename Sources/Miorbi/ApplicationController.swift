import AppKit
import SwiftUI
import Combine

@MainActor
final class ApplicationController: NSObject, NSApplicationDelegate {
    private let store = AppStore()
    private var islandPanel: NSPanel?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var updates: AnyCancellable?
    private var hoverTimer: Timer?
    private var hoverState = HoverState()
    private var targetFrame: NSRect?
    // Developer-only visual check uses real playback, never fixture music.
    // Automatically returns to normal hover behavior after 20 seconds.
    private let verificationUntil = CommandLine.arguments.contains("--verify-expanded-layout") ? Date().addingTimeInterval(20) : Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createStatusItem()
        createIsland()
        // Non-activating panels can miss enter events over the menu bar.
        // Check only the pointer position, never keyboard input or screen data.
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let panel = self.islandPanel else { return }
                let stableFrame = self.targetFrame ?? panel.frame
                let hitArea = self.store.isExpanded ? stableFrame.insetBy(dx: -6, dy: -6) : stableFrame
                let inside = hitArea.contains(NSEvent.mouseLocation) || self.store.choosingFocusDuration || Date() < self.verificationUntil
                let expanded = self.hoverState.update(inside: inside, at: Date())
                if self.store.isExpanded != expanded { self.store.isExpanded = expanded }
                // The larger transparent canvas must not intercept clicks
                // outside the visible island.
                panel.ignoresMouseEvents = !inside
            }
        }
        updates = store.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.layoutIsland() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(pauseForLock), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(pauseForSleep), name: NSWorkspace.willSleepNotification, object: nil)
    }

    @objc private func pauseForLock() { store.pauseFocus() }
    @objc private func pauseForSleep() { store.pauseFocus() }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.menuBarIcon()
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings / 设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Miorbi", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items { item.target = self }
        item.menu = menu
        statusItem = item
    }

    // Transparent template artwork follows the menu bar's system tint.
    // The full-color tile remains the app icon, never the menu-bar background.
    static func menuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let outline = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 3, width: 19, height: 12), xRadius: 6, yRadius: 6)
            outline.lineWidth = 1.5
            outline.stroke()
            let lyrics = NSBezierPath()
            lyrics.lineWidth = 1.8
            lyrics.lineCapStyle = .round
            lyrics.move(to: NSPoint(x: 6, y: 10.5))
            lyrics.line(to: NSPoint(x: 16, y: 10.5))
            lyrics.move(to: NSPoint(x: 6, y: 7))
            lyrics.line(to: NSPoint(x: 12, y: 7))
            lyrics.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Miorbi"
        return image
    }

    private func createIsland() {
        guard let screen = NSScreen.main else { return }
        let width = notchWidth(screen)
        let height = max(28, screen.safeAreaInsets.top)
        let frame = NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        let host = IslandHostingView(rootView: AnyView(IslandView(store: store, notchWidth: width, barHeight: height, wingWidth: 72)))
        panel.contentView = host
        panel.orderFrontRegardless()
        islandPanel = panel
        layoutIsland()
    }

    private func notchWidth(_ screen: NSScreen) -> CGFloat {
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            return max(0, right.minX - left.maxX)
        }
        return 120
    }

    private func layoutIsland() {
        guard let panel = islandPanel, let screen = panel.screen ?? NSScreen.main else { return }
        let notch = notchWidth(screen)
        let top = max(28, screen.safeAreaInsets.top)
        // Reserve the camera and both wings independently. A total-width cap
        // must never steal space from the physical camera exclusion zone.
        let wing: CGFloat = 72
        let lyrics = store.neteaseLyricsEnabled && store.music.provider == .netease && store.music.playback != .stopped && ((store.focus.phase != .running && store.focus.phase != .paused) || store.showLyricsDuringFocus)
        let layout = IslandLayout(cameraWidth: notch, wingWidth: wing, topHeight: top, showsLyrics: lyrics, expanded: store.isExpanded)
        let width = layout.width
        let height = layout.height
        let showsCodex = store.codex.activity.displaysIndicator && (!store.music.isPlaying || store.codex.activity == .approval)
        let visibleWidth = !store.isExpanded && showsCodex ? notch + wing * 2 + 24 : width
        targetFrame = NSRect(x: screen.frame.midX - visibleWidth / 2, y: screen.frame.maxY - height, width: visibleWidth, height: height)
        let canvasWidth = notch + wing * 2 + 24
        let canvasHeight = top + 26 + 40
        let canvas = NSRect(x: screen.frame.midX - canvasWidth / 2, y: screen.frame.maxY - canvasHeight, width: canvasWidth, height: canvasHeight)
        if panel.frame != canvas {
            panel.setFrame(canvas, display: true)
            (panel.contentView as? IslandHostingView)?.rootView = AnyView(IslandView(store: store, notchWidth: notch, barHeight: top, wingWidth: wing))
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 530),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Miorbi Settings"
            window.center()
            window.contentView = NSHostingView(rootView: MiorbiSettingsView(store: store))
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

private final class IslandHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
