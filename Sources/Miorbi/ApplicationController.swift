import AppKit
import SwiftUI

@MainActor
final class ApplicationController: NSObject, NSApplicationDelegate {
    private let store = AppStore()
    private var islandPanel: NSPanel?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createStatusItem()
        createIsland()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(pauseForLock), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(pauseForSleep), name: NSWorkspace.willSleepNotification, object: nil)
    }

    @objc private func pauseForLock() { store.pauseFocus() }
    @objc private func pauseForSleep() { store.pauseFocus() }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "circle.hexagongrid", accessibilityDescription: "Miorbi")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings / 设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Miorbi", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items { item.target = self }
        item.menu = menu
        statusItem = item
    }

    private func createIsland() {
        guard let screen = NSScreen.main else { return }
        let width = min(590, screen.frame.width - 24)
        let height: CGFloat = 144
        let frame = NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: IslandView(store: store).frame(width: width, height: height))
        panel.orderFrontRegardless()
        islandPanel = panel
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
