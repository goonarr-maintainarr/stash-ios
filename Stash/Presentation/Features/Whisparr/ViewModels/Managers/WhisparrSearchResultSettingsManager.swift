import Observation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrSearchResultSettingsManager")

/// Manages Whisparr settings (root folders and quality profiles) for search results.
@MainActor
@Observable
class WhisparrSearchResultSettingsManager: ErrorStateManaging {
    
    // MARK: - State
    
    /// The selected root folder.
    var selectedRootFolder: WhisparrRootFolder?
    
    /// The selected quality profile.
    var selectedQualityProfile: WhisparrQualityProfile?
    
    /// Whether settings are currently loading.
    var isLoading = false
    
    /// Error message if loading failed.
    var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let metadataStore: WhisparrMetadataService
    
    // MARK: - Initialization
    
    init(metadataStore: WhisparrMetadataService) {
        self.metadataStore = metadataStore
        logger.debug("🔧 WhisparrSearchResultSettingsManager initialized")
    }
    
    // MARK: - Public Methods
    
    /// Fetches root folders and quality profiles from the Whisparr API.
    func loadSettings() async {
        logger.info("📥 Loading Whisparr settings...")
        isLoading = true
        errorMessage = nil
        
        await metadataStore.ensureLoaded()
        
        // Auto-select first options if not already selected
        if selectedRootFolder == nil {
            selectedRootFolder = metadataStore.rootFolders.first
            if let folder = selectedRootFolder {
                logger.debug("📁 Auto-selected root folder: \(folder.path, privacy: .public)")
            }
        }
        
        if selectedQualityProfile == nil {
            selectedQualityProfile = metadataStore.qualityProfiles.first
            if let profile = selectedQualityProfile {
                logger.debug("⭐ Auto-selected quality profile: \(profile.name, privacy: .public)")
            }
        }
        
        if let error = metadataStore.error {
            setError(error)
            logger.error("❌ Failed to load settings: \(error, privacy: .public)")
        } else {
            logger.info("✅ Settings loaded successfully")
        }
        
        isLoading = false
    }
    
    /// Returns available root folders.
    var rootFolders: [WhisparrRootFolder] {
        metadataStore.rootFolders
    }
    
    /// Returns available quality profiles.
    var qualityProfiles: [WhisparrQualityProfile] {
        metadataStore.qualityProfiles
    }
}
