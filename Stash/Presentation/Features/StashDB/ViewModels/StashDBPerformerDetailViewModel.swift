import Foundation
import Observation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "StashDBPerformerDetail")

/// ViewModel for StashDB Performer Detail View.
/// Handles loading full details if only a stub is provided.
@MainActor
@Observable
final class StashDBPerformerDetailViewModel {
    var performer: StashDBPerformer
    var isLoading = false
    var errorMessage: String?
    
    private let repository: StashDBRepositoryProtocol
    
    init(performer: StashDBPerformer, repository: StashDBRepositoryProtocol) {
        self.performer = performer
        self.repository = repository
        
        // If it looks like a stub (no gender/image/career info), try to load full details
        if performer.gender == nil && performer.images == nil {
            Task {
                await loadDetails()
            }
        }
    }
    
    @MainActor
    func loadDetails() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            logger.info("📡 Fetching full details for StashDB performer: \(self.performer.id)")
            let fullPerformer = try await repository.fetchPerformerDetails(performerId: performer.id)
            self.performer = fullPerformer
            logger.info("✅ Successfully loaded StashDB performer: \(fullPerformer.name)")
        } catch {
            logger.error("❌ Failed to load StashDB performer details: \(error.localizedDescription)")
            errorMessage = "Failed to load details: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
