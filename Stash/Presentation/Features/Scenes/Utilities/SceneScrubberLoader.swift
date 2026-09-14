import UIKit
import os

/// Loads sprite sheet and VTT data for video scrubbing thumbnails.
///
/// Usage:
/// ```swift
/// let loader = SceneScrubberLoader(settings: settings)
/// if let manager = try await loader.loadScrubber(for: scene) {
///     let thumbnail = manager.thumbnail(for: 30.0)
/// }
/// ```
final class SceneScrubberLoader {
    
    enum LoadError: Error, LocalizedError {
        case missingPaths
        case invalidURL
        case invalidSprite
        case invalidVTT
        
        var errorDescription: String? {
            switch self {
            case .missingPaths: return "Scene does not have sprite paths"
            case .invalidURL: return "Invalid sprite or VTT URL"
            case .invalidSprite: return "Failed to load sprite image"
            case .invalidVTT: return "Failed to parse VTT file"
            }
        }
    }
    
    private let settings: SettingsStoreProtocol
    private static let logger = Logger(subsystem: "com.stash.app", category: "SceneScrubberLoader")
    
    init(settings: SettingsStoreProtocol) {
        self.settings = settings
    }
    
    /// Load sprite manager for a scene.
    /// - Parameter scene: Scene with sprite paths
    /// - Returns: SpriteManager if sprites available, nil otherwise
    func loadScrubber(for scene: Scene) async throws -> SpriteManager? {
        guard let spritePath = scene.paths?.sprite,
              let vttPath = scene.paths?.vtt else {
            Self.logger.debug("Scene \(scene.id) has no sprite paths")
            return nil
        }
        
        guard let spriteURL = settings.createImageUrl(path: spritePath),
              let vttURL = settings.createImageUrl(path: vttPath) else {
            Self.logger.error("Failed to create URLs for scene \(scene.id) sprites")
            throw LoadError.invalidURL
        }
        
        Self.logger.info("Loading sprites for scene \(scene.id)")
        return try await loadScrubber(spriteUrl: spriteURL, vttUrl: vttURL)
    }
    
    func loadScrubber(spriteUrl: URL, vttUrl: URL) async throws -> SpriteManager? {
        // Move all network and parsing operations to background thread
        return try await Task.detached(priority: .userInitiated) {
            // Download sprite image and VTT concurrently
            async let spriteDataTask = URLSession.shared.data(from: spriteUrl)
            async let vttDataTask = URLSession.shared.data(from: vttUrl)
            
            let (spriteData, _) = try await spriteDataTask
            let (vttData, _) = try await vttDataTask
            
            // Parse sprite image (CPU-intensive)
            guard let spriteImage = UIImage(data: spriteData) else {
                Self.logger.error("Failed to decode sprite image")
                throw LoadError.invalidSprite
            }
            
            // Parse VTT content
            guard let vttContent = String(data: vttData, encoding: .utf8) else {
                Self.logger.error("Failed to decode VTT content")
                throw LoadError.invalidVTT
            }
            
            let frames = VTTParser.parse(vttContent)
            
            if frames.isEmpty {
                Self.logger.warning("VTT parsed but no frames found")
                return nil
            }
            
            Self.logger.info("Loaded \(frames.count) sprite frames")
            
            return SpriteManager(spriteImage: spriteImage, frames: frames)
        }.value
    }
}
