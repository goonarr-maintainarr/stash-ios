//
//  StashApp.swift
//  Stash
//

import SwiftUI
import AVFoundation
import Nuke
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "App")

@main
struct StashApp: App {
    @StateObject private var container: DependencyContainer
    
    init() {
        do {
            // Set category to playback for PIP and background audio support,
            // but DO NOT activate it immediately to avoid interrupting other audio apps on launch.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            logger.error("Failed to set audio session category: \(error.localizedDescription, privacy: .public)")
        }
        
        // Initialize dependency container
        let container = DependencyContainer()
        _container = StateObject(wrappedValue: container)
        
        // Configure Nuke for aggressive image caching and prefetching
        configureImagePipeline()
    }
    
    private func configureImagePipeline() {
        // Use Nuke's default configuration with data cache
        // This gives us: 150MB memory cache, unlimited disk cache, 6 concurrent connections
        ImagePipeline.shared = ImagePipeline(configuration: .withDataCache)
        
        logger.info("⚙️ Configured Nuke with data cache for aggressive image caching")
    }
    
    var body: some SwiftUI.Scene {
        WindowGroup {
            MainTabView(container: container, floatingPlayerManager: container.floatingVideoPlayerManager)
                .environmentObject(container)
                .environmentObject(container.settingsStore)
        }
    }
}
