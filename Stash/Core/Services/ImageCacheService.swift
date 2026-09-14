import UIKit
import CryptoKit
import os

// Global logger for cache tracking
nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "ImageCacheService")

/// A thread-safe image caching service providing both memory and disk-based persistence.
///
/// `ImageCacheService` uses `NSCache` for high-performance in-memory storage and the device's
/// Caches directory for long-term storage across app launches.
final class ImageCacheService: Sendable {
    
    /// The singleton instance for global access
    public static let shared = ImageCacheService()
    
    private let settings: any SettingsStoreProtocol
    
    // MARK: - Properties
    
    private let cache = NSCache<NSURL, UIImage>()
    private let fileManager = FileManager.default
    private let diskCacheDirectory: URL
    
    // MARK: - Initialization
    
    init(settings: any SettingsStoreProtocol = SettingsStore.shared) {
        self.settings = settings
        // Configure memory cache limits: 100 images or 50MB
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024
        
        // Setup disk cache directory in Library/Caches
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        diskCacheDirectory = paths[0].appendingPathComponent("ImageCache")
        
        do {
            try fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
            logger.debug("📂 Image disk cache initialized at: \(self.diskCacheDirectory.path, privacy: .private)")
        } catch {
            logger.error("❌ Failed to create disk cache directory: \(error.localizedDescription, privacy: .public)")
        }
        
        // Clear memory cache on system memory warning
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            logger.warning("⚠️ Memory warning received: purging memory cache")
            self?.cache.removeAllObjects()
        }
    }
    
    
    // MARK: - Public API
    
    /// Inserts an image into both memory and disk caches.
    /// - Parameters:
    ///   - image: The image to cache
    ///   - url: The source URL used as the cache key
    func insert(_ image: UIImage, for url: URL) {
        // Calculate approximate cost in bytes (assuming 4 bytes per pixel)
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
        
        // Save to disk cache in background
        Task {
            saveToDisk(image, for: url)
        }
    }
    
    /// Retrieves an image from cache. Checks memory first, then falls back to disk.
    /// Disk I/O is performed asynchronously to avoid blocking the calling thread.
    /// - Parameter url: The source URL used as the cache key
    /// - Returns: The cached image, or nil if not found
    func image(for url: URL) async -> UIImage? {
        // 1. Check memory cache (fastest) - NSCache is thread-safe
        if let image = cache.object(forKey: url as NSURL) {
            return image
        }
        
        // 2. Check disk cache in background to avoid blocking main thread
        let diskImage = await Task.detached(priority: .userInitiated) { [self] in
            return self.loadFromDisk(for: url)
        }.value
        
        if let image = diskImage {
            // Restore to memory cache for subsequent fast access
            let cost = Int(image.size.width * image.size.height * 4)
            cache.setObject(image, forKey: url as NSURL, cost: cost)
            return image
        }
        
        return nil
    }
    
    /// Removes a specific image from both caches.
    /// - Parameter url: The source URL to remove
    func remove(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
        let fileURL = diskFileURL(for: url)
        try? fileManager.removeItem(at: fileURL)
        logger.debug("🗑️ Removed image for URL: \(url.absoluteString, privacy: .private)")
    }
    
    /// Clears all items from memory and disk caches.
    func clearCache() {
        logger.info("🧹 Clearing all image caches...")
        cache.removeAllObjects()
        do {
            try fileManager.removeItem(at: diskCacheDirectory)
            try fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
            logger.info("✅ Cache cleared")
        } catch {
            logger.error("❌ Error clearing disk cache: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: - Internal Helpers
    
    /// Saves the image to disk.
    nonisolated private func saveToDisk(_ image: UIImage, for url: URL) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let fileURL = diskFileURL(for: url)
        
        do {
            try data.write(to: fileURL)
        } catch {
            logger.error("❌ Failed to write image to disk: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// Loads the image from disk.
    nonisolated private func loadFromDisk(for url: URL) -> UIImage? {
        let fileURL = diskFileURL(for: url)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return UIImage(data: data)
        } catch {
            logger.error("❌ Failed to read image from disk: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    /// Generates a unique, deterministic file URL for a given source URL.
    nonisolated private func diskFileURL(for url: URL) -> URL {
        let hashedName = SHA256.hash(data: url.absoluteString.data(using: .utf8) ?? Data())
            .compactMap { String(format: "%02x", $0) }
            .joined()
        
        return diskCacheDirectory.appendingPathComponent(hashedName)
    }
}
