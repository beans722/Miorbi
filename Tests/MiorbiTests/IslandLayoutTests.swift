import XCTest
import SwiftUI
@testable import Miorbi

final class IslandLayoutTests: XCTestCase {
    @MainActor
    func testRenderMusicLayoutWhenExplicitlyRequested() throws {
        guard ProcessInfo.processInfo.environment["MIORBI_LAYOUT_RENDER"] == "1" else {
            throw XCTSkip("Offline visual fixture is opt-in")
        }
        let preferences = UserDefaults(suiteName: "io.beans722.Miorbi.layout-fixture")!
        let store = AppStore(defaults: preferences)
        store.usageSyncEnabled = false
        store.neteaseLyricsEnabled = true
        store.music = MusicSnapshot(provider: .netease, playback: .playing, title: "Layout fixture")
        store.lyric = "布局测试：歌词必须完整位于黑色圆角内部"
        store.isExpanded = true
        let layout = IslandLayout(cameraWidth: 180, wingWidth: 96, topHeight: 32, showsLyrics: true, expanded: true)
        let view = IslandView(store: store, notchWidth: 180, barHeight: 32, wingWidth: 96)
            .frame(width: layout.width, height: layout.height)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Could not render the offline layout"); return
        }
        try png.write(to: URL(fileURLWithPath: "/private/tmp/miorbi-layout-fixture.png"))
        store.isExpanded = false
        let collapsed = IslandView(store: store, notchWidth: 180, barHeight: 32, wingWidth: 0)
            .frame(width: 180, height: 58)
        let collapsedRenderer = ImageRenderer(content: collapsed)
        collapsedRenderer.scale = 2
        guard let collapsedImage = collapsedRenderer.nsImage,
              let collapsedTIFF = collapsedImage.tiffRepresentation,
              let collapsedBitmap = NSBitmapImageRep(data: collapsedTIFF),
              let collapsedPNG = collapsedBitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Could not render transparent lyrics"); return
        }
        XCTAssertEqual(collapsedBitmap.colorAt(x: 8, y: 90)?.alphaComponent ?? 1, 0, accuracy: 0.01)
        try collapsedPNG.write(to: URL(fileURLWithPath: "/private/tmp/miorbi-transparent-lyrics.png"))
    }
    func testCameraAndControlsAlwaysHaveDedicatedSpace() {
        for camera in [120.0, 180, 220] {
            let layout = IslandLayout(cameraWidth: camera, wingWidth: 96, topHeight: 32, showsLyrics: true, expanded: true)
            XCTAssertEqual(layout.width - camera - 24, 192)
            XCTAssertEqual(layout.height, 98)
        }
    }
    func testCollapsedNeverExtendsBeyondHardwareNotchEvenWithMusic() {
        for camera in [120.0, 180, 220] {
            let layout = IslandLayout(cameraWidth: camera, wingWidth: 96, topHeight: 32, showsLyrics: true, expanded: false)
            XCTAssertEqual(layout.width, camera)
            XCTAssertEqual(layout.height, 58)
        }
    }

    func testLyricAndFocusRowsStayWithinSinglePanel() {
        let layout = IslandLayout(cameraWidth: 180, wingWidth: 96, topHeight: 32, showsLyrics: true, expanded: true)
        XCTAssertEqual(layout.height, 98)
        XCTAssertEqual(layout.width, 396)
        let withoutLyrics = IslandLayout(cameraWidth: 180, wingWidth: 96, topHeight: 32, showsLyrics: false, expanded: true)
        XCTAssertEqual(withoutLyrics.height, 72)
    }
}
