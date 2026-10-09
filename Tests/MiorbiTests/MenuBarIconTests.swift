import AppKit
import XCTest
@testable import Miorbi

final class MenuBarIconTests: XCTestCase {
    @MainActor
    func testMenuIconIsTemplateAndHasTransparentCorners() async throws {
        let icon = ApplicationController.menuBarIcon()
        XCTAssertTrue(icon.isTemplate)
        XCTAssertEqual(icon.size, NSSize(width: 22, height: 18))
        let data = try XCTUnwrap(icon.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertEqual(bitmap.colorAt(x: 0, y: 0)?.alphaComponent, 0)
        XCTAssertEqual(bitmap.colorAt(x: bitmap.pixelsWide - 1, y: bitmap.pixelsHigh - 1)?.alphaComponent, 0)
        if ProcessInfo.processInfo.environment["MIORBI_ICON_RENDER"] == "1" {
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: "/private/tmp/miorbi-menu-template.png"))
        }
    }
}
