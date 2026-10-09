import Foundation

// One source of truth for the panel and its SwiftUI content.
struct IslandLayout: Equatable {
    let cameraWidth: Double
    let wingWidth: Double
    let topHeight: Double
    let showsLyrics: Bool
    let expanded: Bool
    var showsActivity: Bool = false

    // Content may be wider ONLY below the menu-bar exclusion band.
    var width: Double { expanded || showsActivity ? max(cameraWidth, 320) : cameraWidth }
    var height: Double { topHeight + (showsActivity ? 38 : 0) + (showsLyrics ? 26 : 0) + (expanded ? 40 : 0) }
    var menuBarPaintWidth: Double { cameraWidth }
}
