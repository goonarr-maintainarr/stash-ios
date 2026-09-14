import Foundation
import Observation
import Nuke
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrImagePrefetchManager")

/// Manages image prefetching for Whisparr scenes to improve scrolling performance.
@MainActor
@Observable
class WhisparrImagePrefetchManager {
    
    // MARK: - Dependencies
    
    private let imagePrefetcher = ImagePrefetcher()
    
    // MARK: - Initialization
    
    init() {
        logger.debug("🔧 WhisparrImagePrefetchManager initialized")
    }
    
    // MARK: - Prefetching
    
    /// Prefetches images for visible scenes (first page).
    ///
    /// - Parameter scenes: The list of scenes to prefetch images for (typically first 20).
    func prefetchVisibleImages(scenes: [WhisparrScene]) {
        let urlsToPrefetch = scenes.prefix(20).compactMap { scene -> URL? in
            guard let imageUrlString = scene.imageUrl else { return nil }
            return URL(string: imageUrlString)
        }
        
        guard !urlsToPrefetch.isEmpty else {
            logger.debug("⚠️ No visible images to prefetch")
            return
        }
        
        logger.info("🖼️ Prefetching \(urlsToPrefetch.count) visible scene images")
        imagePrefetcher.startPrefetching(with: urlsToPrefetch)
    }
    
    /// Prefetches images for upcoming scenes based on current scroll position.
    ///
    /// - Parameters:
    ///   - currentItem: The currently visible scene.
    ///   - allScenes: The complete list of displayed scenes.
    func prefetchUpcomingImages(currentItem: WhisparrScene, from allScenes: [WhisparrScene]) {
        guard let currentIndex = allScenes.firstIndex(where: { $0.id == currentItem.id }) else {
            logger.debug("⚠️ Current item not found for prefetching")
            return
        }
        
        // Prefetch next 10 scene images
        let prefetchCount = 10
        let startIndex = currentIndex + 1
        let endIndex = min(startIndex + prefetchCount, allScenes.count)
        
        guard startIndex < allScenes.count else {
            logger.debug("✅ At end of list, no upcoming images to prefetch")
            return
        }
        
        let scenesToPrefetch = Array(allScenes[startIndex..<endIndex])
        let urlsToPrefetch = scenesToPrefetch.compactMap { scene -> URL? in
            guard let imageUrlString = scene.imageUrl else { return nil }
            return URL(string: imageUrlString)
        }
        
        guard !urlsToPrefetch.isEmpty else {
            return
        }
        
        logger.debug("🖼️ Prefetching \(urlsToPrefetch.count) images for upcoming scenes (index \(startIndex)-\(endIndex))")
        imagePrefetcher.startPrefetching(with: urlsToPrefetch)
    }
    
    /// Stops all ongoing prefetch operations.
    func stopPrefetching() {
        logger.debug("⏹️ Stopping image prefetching")
        imagePrefetcher.stopPrefetching()
    }
}
