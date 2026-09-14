import Foundation
import os

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "Stash"

    static let network = Logger(subsystem: subsystem, category: "Network")
    static let cache = Logger(subsystem: subsystem, category: "Cache")
    static let settings = Logger(subsystem: subsystem, category: "Settings")
    static let home = Logger(subsystem: subsystem, category: "Home")
    static let scenes = Logger(subsystem: subsystem, category: "Scenes")
    static let performers = Logger(subsystem: subsystem, category: "Performers")
    static let player = Logger(subsystem: subsystem, category: "Player")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let repository = Logger(subsystem: subsystem, category: "Repository")
    static let playback = Logger(subsystem: subsystem, category: "Playback")
}
