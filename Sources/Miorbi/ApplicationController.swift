import AppKit
import SwiftUI
import Combine

@MainActor
final class ApplicationController: NSObject, NSApplicationDelegate {
    private let store = AppStore()
    private var islandPanel: NSPanel?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var islandPopover: NSPopover?
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
                guard let self, let panel = self.islandPanel, panel.isVisible else { return }
                let stableFrame = self.targetFrame ?? panel.frame
                // Never claim input in the system menu bar outside the notch.
                let pointer = NSEvent.mouseLocation
                let menuFloor = panel.screen.map { $0.frame.maxY - $0.safeAreaInsets.top } ?? stableFrame.maxY
                let camera = panel.screen.map { self.notchWidth($0) } ?? 0
                let inMenu = pointer.y >= menuFloor
                let inCamera = abs(pointer.x - stableFrame.midX) <= camera / 2
                let hitArea = self.store.isExpanded ? stableFrame.insetBy(dx: -6, dy: -6) : stableFrame
                let inside = ((!inMenu || inCamera) && hitArea.contains(pointer)) || self.store.choosingFocusDuration || Date() < self.verificationUntil
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
        menu.addItem(NSMenuItem(title: "Open panel / 打开面板", action: #selector(openIslandPopover), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Miorbi", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items { item.target = self }
        item.menu = menu
        statusItem = item
    }

    // Transparent template artwork follows the menu bar's system tint.
    // The full-color tile remains the app icon, never the menu-bar background.
    static func menuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 24, height: 20), flipped: false) { _ in
            NSColor.black.setStroke()
            // Preserve the selected artwork's broken outer focus contour.
            // Its lower-right opening houses three progress ticks.
            let focus = NSBezierPath()
            focus.move(to: NSPoint(x: 15, y: 2.5))
            focus.line(to: NSPoint(x: 8, y: 2.5))
            focus.curve(to: NSPoint(x: 1.5, y: 10), controlPoint1: NSPoint(x: 3.7, y: 2.5), controlPoint2: NSPoint(x: 1.5, y: 5.7))
            focus.curve(to: NSPoint(x: 8, y: 17.5), controlPoint1: NSPoint(x: 1.5, y: 14.3), controlPoint2: NSPoint(x: 3.7, y: 17.5))
            focus.line(to: NSPoint(x: 16, y: 17.5))
            focus.curve(to: NSPoint(x: 22.5, y: 10), controlPoint1: NSPoint(x: 20.3, y: 17.5), controlPoint2: NSPoint(x: 22.5, y: 14.3))
            focus.curve(to: NSPoint(x: 21, y: 5), controlPoint1: NSPoint(x: 22.5, y: 8), controlPoint2: NSPoint(x: 22, y: 6.3))
            focus.lineWidth = 1.5
            focus.lineCapStyle = .round
            focus.stroke()
            let island = NSBezierPath(roundedRect: NSRect(x: 4, y: 5.5, width: 16, height: 9), xRadius: 4.5, yRadius: 4.5)
            island.lineWidth = 0.8
            island.stroke()
            let lyrics = NSBezierPath()
            lyrics.lineWidth = 1.7
            lyrics.lineCapStyle = .round
            lyrics.move(to: NSPoint(x: 7, y: 11.5))
            lyrics.line(to: NSPoint(x: 17, y: 11.5))
            lyrics.move(to: NSPoint(x: 7, y: 8.5))
            lyrics.line(to: NSPoint(x: 13.5, y: 8.5))
            lyrics.stroke()
            let ticks = NSBezierPath()
            ticks.lineWidth = 1.15
            ticks.lineCapStyle = .round
            for (x, height) in [(17.0, 1.1), (18.9, 1.7), (20.8, 2.3)] {
                ticks.move(to: NSPoint(x: x, y: 2.1))
                ticks.line(to: NSPoint(x: x, y: 2.1 + height))
            }
            ticks.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Miorbi — Lyric Focus"
        return image
    }

    private func createIsland() {
        guard let screen = NSScreen.main else { return }
        guard screen.safeAreaInsets.top > 0, notchWidth(screen) > 0 else { return }
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
        return 0
    }

    private func layoutIsland() {
        guard let screen = NSScreen.main else { return }
        guard screen.safeAreaInsets.top > 0, notchWidth(screen) > 0 else {
            islandPanel?.orderOut(nil)
            return
        }
        guard let panel = islandPanel else { createIsland(); return }
        panel.orderFrontRegardless()
        let notch = notchWidth(screen)
        let top = max(28, screen.safeAreaInsets.top)
        // Reserve the camera and both wings independently. A total-width cap
        // must never steal space from the physical camera exclusion zone.
        let wing: CGFloat = 72
        let lyrics = store.neteaseLyricsEnabled && store.music.provider == .netease && store.music.playback != .stopped && ((store.focus.phase != .running && store.focus.phase != .paused) || store.showLyricsDuringFocus)
        let showsCodex = store.codex.activity.displaysIndicator && (!store.music.isPlaying || store.codex.activity == .approval)
        let activity = showsCodex || store.focus.phase == .running || store.focus.phase == .paused || (store.isExpanded && store.music.playback != .stopped)
        let layout = IslandLayout(cameraWidth: notch, wingWidth: wing, topHeight: top, showsLyrics: lyrics, expanded: store.isExpanded, showsActivity: activity)
        let width = layout.width
        let height = layout.height
        targetFrame = NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
        let canvasWidth = max(notch, 320)
        let canvasHeight = top + 38 + 26 + 40
        let canvas = NSRect(x: screen.frame.midX - canvasWidth / 2, y: screen.frame.maxY - canvasHeight, width: canvasWidth, height: canvasHeight)
        if panel.frame != canvas {
            panel.setFrame(canvas, display: true)
            (panel.contentView as? IslandHostingView)?.rootView = AnyView(IslandView(store: store, notchWidth: notch, barHeight: top, wingWidth: wing))
        }
    }

    @objc private func openIslandPopover() {
        guard let button = statusItem?.button else { return }
        let popover = NSPopover()
        popover.behavior = .transient
        store.isExpanded = true
        popover.contentViewController = NSHostingController(rootView:
            IslandView(store: store, notchWidth: 320, barHeight: 0, wingWidth: 0)
                .frame(width: 320, height: 104))
        islandPopover = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
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
