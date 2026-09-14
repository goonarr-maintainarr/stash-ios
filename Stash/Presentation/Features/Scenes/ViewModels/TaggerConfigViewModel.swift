import Observation
import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "TaggerConfigViewModel")

@MainActor
@Observable
class TaggerConfigViewModel {
    var config: TaggerConfig
    var isLoading = false
    var errorMessage: String?
    
    private let repository: any SceneRepositoryProtocol
    
    init(repository: any SceneRepositoryProtocol, initialConfig: TaggerConfig) {
        self.repository = repository
        self.config = initialConfig
        logger.debug("🎬 Initialized TaggerConfigViewModel")
    }
    
    func save() async {
        logger.debug("💾 Starting save of tagger configuration")
        isLoading = true
        errorMessage = nil
        
        do {
            try await repository.saveTaggerConfig(config)
            logger.info("✅ Successfully saved tagger configuration")
            isLoading = false
        } catch {
            logger.error("❌ Failed to save tagger configuration: \(error.localizedDescription)")
            errorMessage = "Failed to save configuration: \(error.localizedDescription)"
            isLoading = false
        }
    }
}
