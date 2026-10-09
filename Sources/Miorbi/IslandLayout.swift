import Foundation

// One source of truth for the panel and its SwiftUI content.
struct IslandLayout: Equatable {
    let cameraWidth: Double
    let wingWidth: Double
    let topHeight: Double
    let showsLyrics: Bool
    let expanded: Bool
    var showsActivity: Bool = false
    var showsMediaControls: Bool = false

    var width: Double { cameraWidth + (showsActivity ? 108 : 0) }
    var height: Double { topHeight + (expanded && showsMediaControls ? 34 : 0) + (showsLyrics ? 26 : 0) + (expanded ? 40 : 0) }
    var menuBarPaintWidth: Double { cameraWidth + (showsActivity ? 108 : 0) }
}
