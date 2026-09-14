import Foundation
import OSLog
import Combine

@MainActor
final class WhisparrMetadataService: ObservableObject {
    static let shared = WhisparrMetadataService()
    
    @Published private(set) var rootFolders: [WhisparrRootFolder] = []
    @Published private(set) var qualityProfiles: [WhisparrQualityProfile] = []
    
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    
    private let logger = Logger(subsystem: "com.stash.app", category: "WhisparrMetadataService")
    private let settings: any SettingsStoreProtocol
    
    private var isLoaded = false
    
    private init(settings: any SettingsStoreProtocol = SettingsStore.shared) {
        self.settings = settings
    }
    
    
    /// Ensures metadata is loaded, fetching if necessary.
    func ensureLoaded() async {
        guard !isLoaded && !isLoading else {
            return
        }
        await reload()
    }
    
    /// Forces a reload of metadata from the Whisparr API.
    func reload() async {
        isLoading = true
        error = nil
        
        do {
            let client = WhisparrClient(settings: settings)
            
            async let folders = client.fetchRootFolders(url: settings.whisparrUrl, apiKey: settings.whisparrApiKey)
            async let profiles = client.fetchQualityProfiles(url: settings.whisparrUrl, apiKey: settings.whisparrApiKey)
            
            let (fetchedFolders, fetchedProfiles) = try await (folders, profiles)
            
            
            self.rootFolders = fetchedFolders
            self.qualityProfiles = fetchedProfiles
            self.isLoaded = true
            
            logger.info("Successfully loaded Whisparr metadata: \(fetchedFolders.count) folders, \(fetchedProfiles.count) profiles")
        } catch {
            self.error = "Failed to load Whisparr metadata: \(error.localizedDescription)"
            logger.error("Failed to load metadata: \(error)")
        }
        
        isLoading = false
    }
}
