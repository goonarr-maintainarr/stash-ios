import UIKit

/// Manages sprite sheet image and provides thumbnail extraction for video scrubbing.
///
/// Usage:
/// ```swift
/// let manager = SpriteManager(spriteImage: image, frames: frames)
/// if let thumbnail = manager.thumbnail(for: 30.0) {
///     // Display thumbnail at 30 seconds
/// }
/// ```
final class SpriteManager {
    private let spriteImage: UIImage
    private let frames: [SpriteFrame]
    
    // Cache extracted thumbnails to avoid repeated cropping operations
    private var thumbnailCache: [Int: UIImage] = [:]
    private let cacheLock = NSLock()
    
    init(spriteImage: UIImage, frames: [SpriteFrame]) {
        self.spriteImage = spriteImage
        self.frames = frames
    }
    
    /// Get the index of the frame for a specific timestamp.
    /// - Parameter time: The playback time in seconds
    /// - Returns: Frame index, or nil if no frame matches
    func frameIndex(for time: TimeInterval) -> Int? {
        if let index = frames.firstIndex(where: { time >= $0.startTime && time < $0.endTime }) {
            return index
        }
        if let lastFrame = frames.last, time >= lastFrame.startTime {
            return frames.count - 1
        }
        return nil
    }
    
    /// Get thumbnail image for a specific timestamp.
    /// - Parameter time: The playback time in seconds
    /// - Returns: Cropped thumbnail image, or nil if no frame matches
    func thumbnail(for time: TimeInterval) -> UIImage? {
        // Find frame index using optimized lookup
        guard let index = frameIndex(for: time) else {
            return nil
        }
        
        // Check cache first
        cacheLock.lock()
        if let cached = thumbnailCache[index] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        
        // Extract and cache the thumbnail
        let frame = frames[index]
        guard let thumbnail = extractThumbnail(for: frame) else {
            return nil
        }
        
        cacheLock.lock()
        thumbnailCache[index] = thumbnail
        cacheLock.unlock()
        
        return thumbnail
    }
    
    /// Extract thumbnail from sprite sheet at given frame coordinates.
    /// - Note: CPU-intensive operation, results should be cached
    private func extractThumbnail(for frame: SpriteFrame) -> UIImage? {
        // Calculate rect accounting for image scale
        let scale = spriteImage.scale
        let rect = CGRect(
            x: frame.x * scale,
            y: frame.y * scale,
            width: frame.width * scale,
            height: frame.height * scale
        )
        
        // Crop the sprite to get the thumbnail (CPU-intensive)
        guard let cgImage = spriteImage.cgImage?.cropping(to: rect) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: scale, orientation: spriteImage.imageOrientation)
    }
    
    /// The number of thumbnail frames available.
    var frameCount: Int {
        frames.count
    }
    
    /// Whether sprite data is available.
    var hasSprites: Bool {
        !frames.isEmpty
    }
}
