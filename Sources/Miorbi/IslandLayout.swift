import Foundation

// One source of truth for the panel and its SwiftUI content.
struct IslandLayout: Equatable {
    let cameraWidth: Double
    let wingWidth: Double
    let topHeight: Double
    let showsLyrics: Bool
    let expanded: Bool

    var width: Double { expanded ? cameraWidth + wingWidth * 2 + 24 : cameraWidth }
    var height: Double { topHeight + (showsLyrics ? 26 : 0) + (expanded ? 40 : 0) }
}
