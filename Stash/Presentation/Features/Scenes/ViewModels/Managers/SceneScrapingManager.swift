import Observation
import Foundation
import Combine
import os

/// Manages metadata scraping operations for scenes.
@MainActor
@Observable
final class SceneScrapingManager {
    
    // MARK: - State
    
    /// Represents the metadata scraping state.
    struct ScrapingState: Equatable {
        var stashBoxes: [StashBox]
        var scrapedResults: [ScrapedScene]
        var isScraping: Bool
        
        static var initial: ScrapingState {
            ScrapingState(stashBoxes: [], scrapedResults: [], isScraping: false)
        }
    }
    
    private(set) var state: ScrapingState = .initial
    
    // MARK: - Dependencies
    
    private let sceneRepository: any SceneRepositoryProtocol
    
    // MARK: - Convenience Properties
    
    var stashBoxes: [StashBox] { state.stashBoxes }
    var scrapedResults: [ScrapedScene] { state.scrapedResults }
    var isScraping: Bool { state.isScraping }
    
    // MARK: - Initialization
    
    init(sceneRepository: any SceneRepositoryProtocol) {
        self.sceneRepository = sceneRepository
    }
    
    // MARK: - Scraping Operations
    
    /// Fetches the configured StashBox sources available for scraping.
    func fetchStashBoxes() async throws {
        let boxes = try await sceneRepository.fetchStashBoxes()
        state.stashBoxes = boxes
        Logger.scenes.info("📦 Fetched \(boxes.count) StashBoxes")
    }
    
    /// Resets the scraping UI state.
    func resetScrapeState() {
        state.scrapedResults = []
        state.isScraping = false
    }
    
    /// Initiates a scrape operation using the specified StashBox.
    ///
    /// - Parameter stashBox: The source to scrape from.
    /// - Parameter scene: The scene to scrape.
    func scrapeScene(using stashBox: StashBox, query: String? = nil, scene: Scene) async throws {
        state.isScraping = true
        state.scrapedResults = []
        
        defer {
            state.isScraping = false
        }
        
        let queryText = query ?? scene.title
        let results = try await sceneRepository.scrapeScene(id: scene.id, title: queryText, stashBox: stashBox)
        state.scrapedResults = results
        Logger.scenes.info("✅ Scrape returned \(results.count) results")
    }
    
    /// Initiates a fragment-based scrape operation using the scene's metadata.
    func scrapeSceneByFragment(using stashBox: StashBox, scene: Scene) async throws {
        state.isScraping = true
        state.scrapedResults = []
        
        defer {
            state.isScraping = false
        }
        
        // Construct fragment from scene
        let fragment = SceneFragmentInput(
            title: scene.title,
            code: scene.code,
            details: scene.details,
            director: scene.director,
            urls: scene.url != nil ? [scene.url!] : nil,
            date: scene.date,
            remote_site_id: nil 
        )
        
        let results = try await sceneRepository.scrapeSceneByFragment(fragment: fragment, stashBox: stashBox)
        state.scrapedResults = results
        Logger.scenes.info("✅ Fragment Scrape returned \(results.count) results")
    }
    
    /// Applies a scraped result to the current scene.
    ///
    /// Allows selective application of fields (title, details, image, etc.).
    ///
    /// - Parameters:
    ///   - result: The scraped data to apply.
    ///   - sceneId: The ID of the scene to update.
    ///   - useTitle: Whether to apply the title.
    ///   - useDetails: Whether to apply the details.
    ///   - usePerformers: Whether to apply the performers.
    ///   - useTags: Whether to apply the tags.
    ///   - useImage: Whether to apply the cover image.
    ///   - customTags: Optional custom mapping of tags to apply.
    /// - Returns: The updated scene.
    func applyScrapeResult(
        _ result: ScrapedScene,
        to sceneId: String,
        useTitle: Bool,
        useDetails: Bool,
        usePerformers: Bool,
        useTags: Bool,
        useImage: Bool,
        useStudio: Bool,
        useDirector: Bool,
        useCode: Bool,
        useUrl: Bool,
        customTags: [ScrapedTag]? = nil
    ) async throws -> Scene {
        let options = ScrapeApplyOptions(
            useTitle: useTitle,
            useDetails: useDetails,
            usePerformers: usePerformers,
            useTags: useTags,
            useImage: useImage,
            useStudio: useStudio,
            useDirector: useDirector,
            useCode: useCode,
            useUrl: useUrl,
            customTags: customTags
        )
        
        let updated = try await sceneRepository.applyScrapeResult(to: sceneId, result: result, options: options)
        Logger.scenes.info("✅ Applied scrape results to scene")
        return updated
    }
}
