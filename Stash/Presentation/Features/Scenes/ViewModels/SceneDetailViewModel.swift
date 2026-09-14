import Observation
import AVKit
import os

/// A ViewModel responsible for managing the state and logic of the Scene Detail view.
///
/// `SceneDetailViewModel` orchestrates interactions between the UI and various managers
/// to support features like video playback, metadata scraping, scene editing, and performer management.
@MainActor
@Observable
final class SceneDetailViewModel {
    
    // MARK: - State
    
    /// The current state of the view model.
    var state: ViewState<Scene> = .loading
    
    var alertMessage: String?
    
    // MARK: - Managers
    
    private let dataManager: SceneDataManager
    private let playerManager: ScenePlayerManager
    private let whisparrIntegration: SceneWhisparrIntegration
    private let scrapingManager: SceneScrapingManager
    private let performerManager: ScenePerformerManager
    private let operationsManager: SceneOperationsManager
    
    // MARK: - Dependencies
    
    let sceneRepository: any SceneRepositoryProtocol
    private let settings: SettingsStoreProtocol
    private var streamFetchTask: Task<Void, Never>?
    
    // MARK: - Convenience Properties
    
    /// The currently loaded scene.
    var scene: Scene? { state.content }
    
    /// Whether the view is loading.
    var isLoading: Bool { state.isLoading }
    
    /// The current error message if in error state.
    var errorMessage: String? {
        get { state.errorMessage }
        set {
            if let message = newValue {
                state = .error(message)
            } else {
                state = .loading
            }
        }
    }
    
    // MARK: - Player Properties (delegated to PlayerManager)
    
    var player: AVPlayer? { playerManager.player }
    var isPlayerLoaded: Bool { playerManager.isLoaded }
    var availableStreams: [SceneStreamEndpoint] { playerManager.availableStreams }
    var selectedStream: SceneStreamEndpoint? { playerManager.selectedStream }
    var playerState: ScenePlayerManager.PlayerState { playerManager.state }
    
    // MARK: - Whisparr Properties (delegated to WhisparrIntegration)
    
    var whisparrMovieId: Int? { whisparrIntegration.movieId }
    var whisparrMovie: WhisparrScene? { whisparrIntegration.movie }
    var whisparrState: SceneWhisparrIntegration.WhisparrState { whisparrIntegration.state }
    
    // MARK: - Scraping Properties (delegated to ScrapingManager)
    
    var stashBoxes: [StashBox] { scrapingManager.stashBoxes }
    var scrapedResults: [ScrapedScene] { scrapingManager.scrapedResults }
    var scrapingState: SceneScrapingManager.ScrapingState { scrapingManager.state }
    
    var taggerConfig: TaggerConfig = .default
    
    // MARK: - Initialization
    
    init(
        dataManager: SceneDataManager,
        playerManager: ScenePlayerManager,
        whisparrIntegration: SceneWhisparrIntegration,
        scrapingManager: SceneScrapingManager,
        performerManager: ScenePerformerManager,
        operationsManager: SceneOperationsManager,
        sceneRepository: any SceneRepositoryProtocol,
        settings: SettingsStoreProtocol
    ) {
        self.sceneRepository = sceneRepository
        self.settings = settings
        
        // Injected managers
        self.dataManager = dataManager
        self.playerManager = playerManager
        self.whisparrIntegration = whisparrIntegration
        self.scrapingManager = scrapingManager
        self.performerManager = performerManager
        self.operationsManager = operationsManager
    }

    
    /// Optional start time override (e.g. from preview scrubbing).
    var initialStartTime: Double?
    
    // MARK: - Scene Operations
    
    /// Fetches details for a specific scene by ID.
    func fetchSceneDetails(id: String, forceRefresh: Bool = false) async {
        // Only set loading state if we don't have content, or if forcing refresh
        if case .loading = state { } else if forceRefresh {
            state = .loading
        } else if case .error = state {
            state = .loading
        }
        
        do {
            var scene = try await dataManager.fetchSceneDetails(
                id: id,
                forceRefresh: forceRefresh,
                onFreshData: { [weak self] freshScene in
                    // Silently update state when background refresh completes
                    self?.state = .content(freshScene)
                }
            )
            
            // Override resume time if initialStartTime is set
            if let start = initialStartTime {
                scene.resume_time = start
                // Consume the override
                self.initialStartTime = nil
            }
            
            state = .content(scene)
            playerManager.setupPlayer(for: scene)
            
            streamFetchTask?.cancel()
            streamFetchTask = Task {
                await fetchAvailableStreams()
            }
        } catch {
            Logger.scenes.error("❌ Failed to fetch scene details: \(error.localizedDescription)")
            state = .error("Failed to fetch scene details: \(error.localizedDescription)")
        }
    }
    
    /// Deletes the current scene and optionally its files.
    func deleteScene(deleteFile: Bool, deleteGenerated: Bool) async -> Bool {
        guard let scene = scene else { return false }
        let stashId = scene.stash_ids?.first?.stash_id
        
        do {
            return try await operationsManager.deleteScene(
                id: scene.id,
                stashId: stashId,
                deleteFile: deleteFile,
                deleteGenerated: deleteGenerated
            )
        } catch {
            errorMessage = "Failed to delete scene: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Increments the 'O-Counter' for the current scene.
    func incrementOCounter() async {
        guard let currentScene = scene else { return }
        let previousValue = currentScene.o_counter
        
        do {
            let updated = try await operationsManager.incrementOCounter(for: currentScene)
            state = .content(updated)
        } catch {
            // Revert on failure
            if var revert = scene {
                revert.o_counter = previousValue
                state = .content(revert)
            }
            Logger.scenes.error("Failed to increment O-Counter: \(error.localizedDescription)")
        }
    }
    
    /// Updates the rating for the current scene.
    func updateRating(_ newRating: Int) async {
        guard var currentScene = scene else { return }
        let previousRating = currentScene.rating100
        
        // Optimistic update
        currentScene.rating100 = newRating == 0 ? nil : newRating
        state = .content(currentScene)
        
        do {
            let updated = try await operationsManager.updateRating(for: currentScene, rating: newRating)
            state = .content(updated)
        } catch {
            // Revert on failure
            if var revert = scene {
                revert.rating100 = previousRating
                state = .content(revert)
            }
            Logger.scenes.error("Failed to update rating: \(error.localizedDescription)")
        }
    }
    
    /// Updates the title of the current scene.
    func updateTitle(_ title: String) async {
        guard let sceneId = scene?.id else { return }
        
        do {
            let updated = try await operationsManager.updateTitle(for: sceneId, title: title)
            state = .content(updated)
        } catch {
            self.state = .error("Failed to update title: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Player Operations (delegated to PlayerManager)
    
    func cleanup() {
        playerManager.cleanup()
    }
    
    func recreatePlayerIfNeeded() {
        guard let scene = scene else { return }
        playerManager.recreatePlayerIfNeeded(for: scene)
    }
    
    func setPlayerLoaded(_ isLoaded: Bool) {
        playerManager.setPlayerLoaded(isLoaded)
    }
    
    func fetchAvailableStreams() async {
        guard let sceneId = scene?.id else { return }
        await playerManager.fetchAvailableStreams(sceneId: sceneId, currentStreamPath: scene?.paths?.stream)
    }
    
    func selectStream(_ endpoint: SceneStreamEndpoint) {
        guard let scene = scene else { return }
        playerManager.selectStream(endpoint, scene: scene)
    }
    
    // MARK: - Whisparr Operations (delegated to WhisparrIntegration)
    
    func resolveWhisparrId() async {
        guard let scene = scene else { return }
        await whisparrIntegration.resolveWhisparrId(scene: scene)
    }
    
    // MARK: - Scraping Operations (delegated to ScrapingManager)
    
    func fetchStashBoxes() async {
        do {
            try await scrapingManager.fetchStashBoxes()
            // Also fetch tagger config
            let config = try await sceneRepository.fetchTaggerConfig()
            self.taggerConfig = config
        } catch {
            alertMessage = "Failed to fetch StashBoxes or config: \(error.localizedDescription)"
        }
    }
    
    func resetScrapeState() {
        scrapingManager.resetScrapeState()
    }
    
    func scrapeScene(using stashBox: StashBox, query: String? = nil) async {
        guard let scene = scene else { return }
        do {
            try await scrapingManager.scrapeScene(using: stashBox, query: query, scene: scene)
        } catch {
            Logger.scenes.error("❌ Scrape failed: \(error.localizedDescription)")
            alertMessage = "Scrape failed: \(error.localizedDescription)"
        }
    }
    
    func generateSearchQuery() -> String {
        guard let scene = scene else { return "" }
        return TaggerQueryService.prepareQueryString(
            for: scene,
            mode: taggerConfig.mode,
            blacklist: taggerConfig.blacklist
        )
    }
    
    func scrapeSceneByFragment(using stashBox: StashBox) async {
        guard let scene = scene else { return }
        do {
            try await scrapingManager.scrapeSceneByFragment(using: stashBox, scene: scene)
        } catch {
            Logger.scenes.error("❌ Fragment scrape failed: \(error.localizedDescription)")
            alertMessage = "Fragment scrape failed: \(error.localizedDescription)"
        }
    }
    
    func applyScrapeResult(
        _ result: ScrapedScene,
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
    ) async {
        guard let sceneId = scene?.id else { return }
        
        do {
            let updated = try await scrapingManager.applyScrapeResult(
                result,
                to: sceneId,
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
            state = .content(updated)
        } catch {
            alertMessage = "Failed to apply changes: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Performer Operations (delegated to PerformerManager)
    
    func fetchPerformerImages(name: String) async -> StashDBPerformer? {
        do {
            return try await performerManager.fetchPerformerImages(name: name)
        } catch {
            Logger.scenes.error("❌ Failed to fetch performer images for \(name): \(error.localizedDescription)")
            return nil
        }
    }
    
    func createPerformer(
        name: String,
        image: String?,
        details: String?,
        gender: String?,
        birth_date: String?,
        ethnicity: String?,
        country: String?,
        eye_color: String?,
        hair_color: String?,
        height: Int?,
        measurements: String?,
        breast_type: String?,
        career_start_year: Int?,
        career_end_year: Int?,
        tattoos: String?,
        piercings: String?
    ) async -> Bool {
        do {
            _ = try await performerManager.createPerformer(
                name: name,
                image: image,
                details: details,
                gender: gender,
                birth_date: birth_date,
                ethnicity: ethnicity,
                country: country,
                eye_color: eye_color,
                hair_color: hair_color,
                height: height,
                measurements: measurements,
                breast_type: breast_type,
                career_start_year: career_start_year,
                career_end_year: career_end_year,
                tattoos: tattoos,
                piercings: piercings
            )
            return true
        } catch {
            alertMessage = "Failed to create performer: \(error.localizedDescription)"
            return false
        }
    }
    
    func validateScrapedPerformers(_ scrapedPerformers: [ScrapedPerformer]) async -> Set<String> {
        return await performerManager.validateScrapedPerformers(scrapedPerformers)
    }
}
