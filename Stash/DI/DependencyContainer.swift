import Foundation
import SwiftUI
import Combine

/// Central container for application dependencies to replace singletons
/// Central container for application dependencies to replace singletons
@MainActor
class DependencyContainer: ObservableObject {
    @Published var settingsStore: SettingsStore
    
    // Private storage for injections
    private let _injectedDatabase: AppDatabase?
    private let _injectedStashDatabase: StashDatabase?
    private let _injectedWhisparrDatabase: WhisparrDatabase?
    private let _injectedGraphQLClient: StashClientProtocol?
    private let _injectedWhisparrClient: WhisparrClientProtocol?
    private let _injectedStashDBClient: StashDBClientProtocol?
    private let _injectedStashSubscriptionService: StashSubscriptionService?
    private let _injectedImagePrefetchManager: ImagePrefetchService?
    private let _injectedFloatingVideoPlayerManager: FloatingVideoPlayerService?
    private let _injectedImageCache: ImageCacheService?
    private let _injectedSyncService: (any SyncServiceProtocol)?
    
    // Lazy Dependencies
    
    lazy var database: AppDatabase = {
        _injectedDatabase ?? AppDatabase.shared
    }()
    
    lazy var stashDatabase: StashDatabase = {
        _injectedStashDatabase ?? StashDatabase.shared
    }()
    
    lazy var whisparrDatabase: WhisparrDatabase = {
        _injectedWhisparrDatabase ?? WhisparrDatabase.shared
    }()
    
    lazy var graphQLClient: StashClientProtocol = {
        _injectedGraphQLClient ?? StashClient()
    }()
    
    lazy var whisparrClient: WhisparrClientProtocol = {
        _injectedWhisparrClient ?? WhisparrClient(settings: settingsStore)
    }()
    
    lazy var stashDBClient: StashDBClientProtocol = {
        _injectedStashDBClient ?? StashDBClient(
            apiKey: settingsStore.stashDBApiKey,
            baseURL: settingsStore.stashDBUrl
        )
    }()
    
    // Services - Managers
    
    lazy var imagePrefetchManager: ImagePrefetchService = {
        _injectedImagePrefetchManager ?? ImagePrefetchService.shared
    }()
    
    lazy var floatingVideoPlayerManager: FloatingVideoPlayerService = {
        _injectedFloatingVideoPlayerManager ?? FloatingVideoPlayerService.shared
    }()
    
    lazy var imageCache: ImageCacheService = {
        _injectedImageCache ?? ImageCacheService.shared
    }()
    
    // Services - Subscriptions
    
    lazy var stashSubscriptionService: StashSubscriptionService = {
        _injectedStashSubscriptionService ?? StashSubscriptionService.shared
    }()
    
    // Repositories (Lazy)
    
    lazy var sceneRepository: SceneRepository = {
        SceneRepository(apiClient: graphQLClient, database: stashDatabase, settings: settingsStore, imagePrefetchManager: imagePrefetchManager)
    }()
    
    lazy var performerRepository: PerformerRepository = {
        PerformerRepository(apiClient: graphQLClient, database: stashDatabase, settings: settingsStore, imagePrefetchManager: imagePrefetchManager)
    }()
    
    lazy var tagRepository: TagRepository = {
        TagRepository(apiClient: graphQLClient, database: stashDatabase, settings: settingsStore, imagePrefetchManager: imagePrefetchManager)
    }()
    
    lazy var whisparrRepository: WhisparrRepository = {
        WhisparrRepository(apiClient: whisparrClient, database: whisparrDatabase, settings: settingsStore)
    }()
    
    lazy var stashDBRepository: StashDBRepository = {
        StashDBRepository(stashDBClient: stashDBClient, whisparrDatabase: whisparrDatabase, stashDatabase: stashDatabase, settings: settingsStore)
    }()
    
    lazy var settingsRepository: SettingsRepository = {
        SettingsRepository(client: graphQLClient, settings: settingsStore)
    }()
    
    lazy var studioRepository: StudioRepository = {
        StudioRepository(apiClient: graphQLClient, database: stashDatabase, settings: settingsStore, imagePrefetchManager: imagePrefetchManager)
    }()
    
    // Services
    
    lazy var syncService: SyncService = {
        if let injected = _injectedSyncService as? SyncService {
            return injected
        }
        return SyncService(
            sceneRepository: sceneRepository,
            performerRepository: performerRepository,
            tagRepository: tagRepository
        )
    }()
    
    lazy var performerDataProvider: PerformerMatchServiceProtocol = {
        PerformerMatchService(stashDatabase: stashDatabase)
    }()
    
    lazy var studioMatchService: StudioMatchServiceProtocol = {
        StudioMatchService(stashDatabase: stashDatabase)
    }()
    
    @MainActor
    init(
        settingsStore: SettingsStore? = nil,
        database: AppDatabase? = nil,
        stashDatabase: StashDatabase? = nil,
        whisparrDatabase: WhisparrDatabase? = nil,
        graphQLClient: StashClientProtocol? = nil,
        whisparrClient: WhisparrClientProtocol? = nil,
        stashDBClient: StashDBClientProtocol? = nil,
        stashSubscriptionService: StashSubscriptionService? = nil,
        imagePrefetchManager: ImagePrefetchService? = nil,
        floatingVideoPlayerManager: FloatingVideoPlayerService? = nil,
        imageCache: ImageCacheService? = nil,
        syncService: (any SyncServiceProtocol)? = nil
    ) {
        let actualSettings = settingsStore ?? SettingsStore.shared
        self.settingsStore = actualSettings
        
        // Store injections
        self._injectedDatabase = database
        self._injectedStashDatabase = stashDatabase
        self._injectedWhisparrDatabase = whisparrDatabase
        self._injectedGraphQLClient = graphQLClient
        self._injectedWhisparrClient = whisparrClient
        self._injectedStashDBClient = stashDBClient
        self._injectedStashSubscriptionService = stashSubscriptionService
        self._injectedImagePrefetchManager = imagePrefetchManager
        self._injectedFloatingVideoPlayerManager = floatingVideoPlayerManager
        self._injectedImageCache = imageCache
        self._injectedSyncService = syncService
    }
    
    // MARK: - ViewModel Factory
    
    @MainActor
    func makeSceneListViewModel() -> SceneListViewModel {
        return SceneListViewModel(
            repository: sceneRepository,
            settings: settingsStore
        )
    }
    
    @MainActor
    func makeSceneDetailViewModel() -> SceneDetailViewModel {
        // Create managers locally
        let dataManager = SceneDataManager(sceneRepository: sceneRepository)
        let playerManager = ScenePlayerManager(
            sceneRepository: sceneRepository,
            settings: settingsStore
        )
        let whisparrIntegration = SceneWhisparrIntegration(
            whisparrRepository: whisparrRepository,
            settings: settingsStore
        )
        let scrapingManager = SceneScrapingManager(
            sceneRepository: sceneRepository
        )
        let performerManager = ScenePerformerManager(
            performerRepository: performerRepository,
            stashDBRepository: stashDBRepository,
            settings: settingsStore
        )
        let operationsManager = SceneOperationsManager(
            sceneRepository: sceneRepository,
            settings: settingsStore,
            whisparrIntegration: whisparrIntegration
        )
        
        return SceneDetailViewModel(
            dataManager: dataManager,
            playerManager: playerManager,
            whisparrIntegration: whisparrIntegration,
            scrapingManager: scrapingManager,
            performerManager: performerManager,
            operationsManager: operationsManager,
            sceneRepository: sceneRepository,
            settings: settingsStore
        )
    }
    
    @MainActor
    func makePerformerListViewModel() -> PerformerListViewModel {
        return PerformerListViewModel(
            repository: performerRepository,
            settings: settingsStore
        )
    }

    @MainActor
    func makePerformerDetailViewModel() -> PerformerDetailViewModel {
        let dataManager = PerformerDataManager(repository: performerRepository, database: stashDatabase, settings: settingsStore)
        let sceneSorter = PerformerSceneSorter()
        let stashIDManager = PerformerStashIDManager()
        let notificationManager = PerformerNotificationManager()
        
        return PerformerDetailViewModel(
            dataManager: dataManager,
            sceneSorter: sceneSorter,
            stashIDManager: stashIDManager,
            notificationManager: notificationManager,
            stashDBRepository: stashDBRepository,
            database: stashDatabase
        )
    }
    
    @MainActor
    func makeEditPerformerViewModel(performer: Performer) -> EditPerformerViewModel {
        return EditPerformerViewModel(
            performer: performer,
            performerRepository: performerRepository,
            stashDBRepository: stashDBRepository,
            settings: settingsStore,
            database: stashDatabase
        )
    }
    

    @MainActor
    func makeEditSceneViewModel(scene: Scene) -> EditSceneViewModel {
        return EditSceneViewModel(
            scene: scene,
            repository: sceneRepository,
            performerRepository: performerRepository,
            tagRepository: tagRepository
        )
    }
    
    @MainActor
    func makeHomeViewModel() -> HomeViewModel {
        return HomeViewModel(
            settings: settingsStore,
            sceneRepository: sceneRepository,
            performerRepository: performerRepository,
            tagRepository: tagRepository,
            syncService: syncService,
            stashDBRepository: stashDBRepository
        )
    }
    
    @MainActor
    func makeTagSelectionViewModel() -> TagSelectionViewModel {
        return TagSelectionViewModel(
            settings: settingsStore,
            database: stashDatabase,
            tagRepository: tagRepository
        )
    }
    
    @MainActor
    func makeStashDBPerformerScenesViewModel(performerId: String) -> StashDBPerformerScenesViewModel {
        return StashDBPerformerScenesViewModel(
            repository: stashDBRepository,
            whisparrRepository: whisparrRepository,
            performerId: performerId,
            settings: settingsStore
        )
    }

    @MainActor
    func makeStashDBPerformerDetailViewModel(performer: StashDBPerformer) -> StashDBPerformerDetailViewModel {
        return StashDBPerformerDetailViewModel(performer: performer, repository: stashDBRepository)
    }
    
    @MainActor
    func makeStashDBCategoryDetailViewModel(category: SceneCategory) -> StashDBCategoryDetailViewModel {
        return StashDBCategoryDetailViewModel(
            category: category,
            stashDBRepository: stashDBRepository,
            settings: settingsStore,
            whisparrDatabase: whisparrDatabase
        )
    }
    
    
    
    
    @MainActor
    func makeStashDBSceneDetailViewModel(scene: StashDBScene) -> StashDBSceneDetailViewModel {
        let whisparrManager = StashDBSceneWhisparrManager(
            whisparrRepository: whisparrRepository,
            whisparrDatabase: whisparrDatabase,
            settings: settingsStore
        )
        let performerManager = StashDBScenePerformerManager(
            stashDBRepository: stashDBRepository,
            performerDataProvider: performerDataProvider
        )
        let dataManager = StashDBSceneDataManager(stashDBRepository: stashDBRepository)
        
        return StashDBSceneDetailViewModel(
            scene: scene,
            whisparrManager: whisparrManager,
            performerManager: performerManager,
            dataManager: dataManager
        )
    }
    
    @MainActor
    func makeWhisparrSceneDetailViewModel(scene: WhisparrScene) -> WhisparrSceneDetailViewModel {
        let operationsManager = WhisparrSceneOperationsManager(repository: whisparrRepository)
        let performerManager = WhisparrScenePerformerManager(
            performerService: WhisparrPerformerService.shared,
            stashDatabase: stashDatabase,
            performerDataProvider: performerDataProvider
        )
        
        return WhisparrSceneDetailViewModel(
            scene: scene,
            operationsManager: operationsManager,
            performerManager: performerManager,
            studioMatchService: studioMatchService,
            repository: whisparrRepository
        )
    }
    
    
    @MainActor
    func makeWhisparrSceneListViewModel() -> WhisparrSceneListViewModel {
        return WhisparrSceneListViewModel(
            repository: whisparrRepository,
            studioMatchService: studioMatchService
        )
    }

    @MainActor
    func makeWhisparrSearchResultDetailViewModel(searchResult: WhisparrSearchResult) -> WhisparrSearchResultDetailViewModel {
        return WhisparrSearchResultDetailViewModel(
            searchResult: searchResult,
            settings: settingsStore,
            stashDatabase: stashDatabase,
            whisparrDatabase: whisparrDatabase,
            repository: whisparrRepository,
            performerDataProvider: performerDataProvider,
            studioMatchService: studioMatchService
        )
    }
    
    
    @MainActor
    func makeStatsViewModel() -> StatsViewModel {
        return StatsViewModel(
            repository: StatsRepository(graphQLClient: graphQLClient, settings: settingsStore)
        )
    }
    
    @MainActor
    func makeStudioListViewModel() -> StudioListViewModel {
        return StudioListViewModel(repository: studioRepository)
    }
    
    @MainActor
    func makeStudioDetailViewModel(studioId: String) -> StudioDetailViewModel {
        return StudioDetailViewModel(repository: studioRepository, studioId: studioId)
    }
    
    @MainActor
    func makeSettingsViewModel() -> SettingsViewModel {
        return SettingsViewModel(
            store: settingsStore,
            repository: settingsRepository,
            whisparrRepository: whisparrRepository
        )
    }
    
    @MainActor
    func makeSettingsCoordinator() -> SettingsCoordinator {
        return SettingsCoordinator(syncService: syncService)
    }
    // For Preview usage
    @MainActor
    static let preview = DependencyContainer()
}
