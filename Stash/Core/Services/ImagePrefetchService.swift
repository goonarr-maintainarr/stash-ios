import Foundation
import Nuke
import os

// Global logger for prefetch tracking
nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "ImagePrefetchService")

/// A service for prefetching images using Nuke's `ImagePrefetcher`.
///
/// `ImagePrefetchService` optimizes the user experience by loading images into the memory cache
/// before they enter the viewport, ensuring smooth scrolling in lists and grids.
final class ImagePrefetchService: Sendable {
    
    /// The singleton instance for global access.
    public static let shared = ImagePrefetchService()
    
    /// The underlying Nuke image prefetcher.
    private let prefetcher: ImagePrefetcher
    private let settings: any SettingsStoreProtocol
    
    /// Initializes the prefetcher with low-priority settings to avoid interfering with user-visible loads.
    init(settings: any SettingsStoreProtocol = SettingsStore.shared) {
        self.settings = settings
        self.prefetcher = ImagePrefetcher(
            pipeline: ImagePipeline.shared,
            destination: .memoryCache,
            maxConcurrentRequestCount: 4
        )
        logger.debug("⚡️ ImagePrefetchService initialized")
    }
    
    // MARK: - Public API
    
    /// Starts prefetching images for a list of URLs.
    /// - Parameter urls: The URLs to begin loading.
    func prefetch(urls: [URL]) {
        let validUrls = urls.filter { !$0.absoluteString.isEmpty }
        guard !validUrls.isEmpty else {
            return
        }
        
        prefetcher.startPrefetching(with: validUrls)
    }
    
    /// Stops prefetching images for a list of URLs.
    /// - Parameter urls: The URLs to cancel.
    func cancelPrefetch(urls: [URL]) {
        guard !urls.isEmpty else { return }
        prefetcher.stopPrefetching(with: urls)
    }
    
    /// Stops all active prefetching operations.
    func cancelAll() {
        logger.debug("🚫 Canceling all active prefetch operations")
        prefetcher.stopPrefetching()
    }
    
    /// Convenience method to prefetch images from an array of URL strings.
    /// - Parameter urlStrings: Strings representing the source image locations.
    func prefetch(urlStrings: [String]) {
        let urls = urlStrings.compactMap { URL(string: $0) }
        prefetch(urls: urls)
    }
    
    /// Convenience method to cancel prefetching from an array of URL strings.
    /// - Parameter urlStrings: Strings representing the source image locations.
    func cancelPrefetch(urlStrings: [String]) {
        let urls = urlStrings.compactMap { URL(string: $0) }
        cancelPrefetch(urls: urls)
    }
}
