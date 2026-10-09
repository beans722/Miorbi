import AppKit
import XCTest
@testable import Miorbi

final class MenuBarIconTests: XCTestCase {
    @MainActor
    func testMenuIconIsTemplateAndHasTransparentCorners() async throws {
        let icon = ApplicationController.menuBarIcon()
        XCTAssertTrue(icon.isTemplate)
        XCTAssertEqual(icon.size, NSSize(width: 24, height: 20))
        let data = try XCTUnwrap(icon.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertEqual(bitmap.colorAt(x: 0, y: 0)?.alphaComponent, 0)
        XCTAssertEqual(bitmap.colorAt(x: bitmap.pixelsWide - 1, y: bitmap.pixelsHigh - 1)?.alphaComponent, 0)
        XCTAssertGreaterThan(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: 2)?.alphaComponent ?? 0, 0)
        if ProcessInfo.processInfo.environment["MIORBI_ICON_RENDER"] == "1" {
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: "/private/tmp/miorbi-menu-template.png"))
            let preview = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 192, pixelsHigh: 100,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: preview)
            NSColor(calibratedRed: 0.66, green: 0.84, blue: 0.94, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: 192, height: 100).fill()
            icon.draw(in: NSRect(x: 18, y: 40, width: 24, height: 20))
            icon.draw(in: NSRect(x: 70, y: 10, width: 96, height: 80))
            NSGraphicsContext.restoreGraphicsState()
            try XCTUnwrap(preview.representation(using: .png, properties: [:]))
                .write(to: URL(fileURLWithPath: "/private/tmp/miorbi-menu-preview.png"))
        }
    }
}
