import os
import Foundation
import Observation
import SwiftUI


private let logger = Logger(subsystem: "com.stash.app", category: "SettingsViewModel")

@MainActor
@Observable
class SettingsViewModel {
    let store: SettingsStoreProtocol  // Not @Published - already observed via @EnvironmentObject in view
    var testMessage: String?
    var testSuccess: Bool = false
    var isTestingStash: Bool = false
    
    var testStashDBMessage: String?
    var testStashDBSuccess: Bool = false
    var isTestingStashDB: Bool = false
    
    var availableRootFolders: [WhisparrRootFolder] = []
    var availableQualityProfiles: [WhisparrQualityProfile] = []
    var isLoadingWhisparrConfig: Bool = false
    var whisparrConfigError: String? = nil
    
    private let repository: any SettingsRepositoryProtocol
    private let whisparrRepository: any WhisparrRepositoryProtocol
    
    init(
        store: SettingsStoreProtocol,
        repository: any SettingsRepositoryProtocol,
        whisparrRepository: any WhisparrRepositoryProtocol
    ) {
        self.store = store
        self.repository = repository
        self.whisparrRepository = whisparrRepository
    }
    
    func testStashConnection() async {
        guard let url = store.url else {
            testMessage = "Invalid Server URL"
            testSuccess = false
            return
        }
        
        isTestingStash = true
        testMessage = "Testing..."
        
        do {
            try await repository.testStashConnection(url: url, apiKey: store.apiKey)
            testMessage = "Connection Successful!"
            testSuccess = true
            HapticManager.success()
        } catch {
            testMessage = "Failed: \(error.localizedDescription)"
            testSuccess = false
            HapticManager.error()
        }
        isTestingStash = false
    }
    
    func testStashDBConnection() async {
        isTestingStashDB = true
        testStashDBMessage = "Testing..."
        
        do {
            try await repository.testStashDBConnection(apiKey: store.stashDBApiKey)
            testStashDBMessage = "Connection Successful!"
            testStashDBSuccess = true
            HapticManager.success()
        } catch {
            testStashDBMessage = "Failed: \(error.localizedDescription)"
            testStashDBSuccess = false
            HapticManager.error()
        }
        isTestingStashDB = false
    }
    
    func fetchWhisparrConfig() async {
        guard !store.whisparrUrl.isEmpty && !store.whisparrApiKey.isEmpty else { return }
        
        // Skip if already loaded and not forcing refresh
        guard availableRootFolders.isEmpty || availableQualityProfiles.isEmpty else {
            logger.debug("⏭️ Whisparr config already loaded, skipping fetch")
            return
        }
        
        isLoadingWhisparrConfig = true
        whisparrConfigError = nil
        
        // Fetch independently so one failure doesn't block the other
        await withTaskGroup(of: Void.self) { group in
            // Root Folders
            group.addTask {
                do {
                    let folders = try await self.whisparrRepository.fetchRootFolders()
                    await MainActor.run {
                        // Only update if changed
                        if self.availableRootFolders != folders {
                            self.availableRootFolders = folders
                        }
                    }
                } catch {
                    logger.error("Failed to fetch Whisparr root folders: \(error)")
                    await MainActor.run {
                        self.whisparrConfigError = "Failed to load root folders. Check server accessibility."
                    }
                }
            }
            
            // Quality Profiles
            group.addTask {
                do {
                    let profiles = try await self.whisparrRepository.fetchQualityProfiles()
                    await MainActor.run {
                        // Only update if changed
                        if self.availableQualityProfiles != profiles {
                            self.availableQualityProfiles = profiles
                        }
                    }
                } catch {
                    logger.error("Failed to fetch Whisparr quality profiles: \(error)")
                    // Only override if no error yet
                    await MainActor.run {
                        if self.whisparrConfigError == nil {
                            self.whisparrConfigError = "Failed to load quality profiles."
                        }
                    }
                }
            }
        }
        
        isLoadingWhisparrConfig = false
    }
    
    func triggerScan() {
        Task {
            do {
                try await repository.triggerScan(options: store.scanOptions)
                HapticManager.success()
            } catch {
                logger.error("Scan failed: \(error)")
                HapticManager.error()
            }
        }
    }
    
    func triggerGeneration() {
        Task {
            do {
                try await repository.triggerGeneration(options: store.generationOptions)
                HapticManager.success()
            } catch {
                logger.error("Generation failed: \(error)")
                HapticManager.error()
            }
        }
    }
}
