import Foundation
import Observation
import SwiftUI
import os

@MainActor
@Observable
class StudioDetailViewModel {
    
    // MARK: - Properties
    
    var state: ViewState<Studio> = .loading
    
    private let repository: any StudioRepositoryProtocol
    private let studioId: String
    private let studioName: String? // For placeholder title
    
    private let logger = Logger(subsystem: "com.stash.app", category: "StudioDetailViewModel")
    
    // MARK: - Initialization
    
    init(repository: any StudioRepositoryProtocol, studioId: String, studioName: String? = nil) {
        self.repository = repository
        self.studioId = studioId
        self.studioName = studioName
    }
    
    // MARK: - Actions
    
    func loadStudio(forceRefresh: Bool = false) async {
        if forceRefresh {
            state = .loading
        }
        
        // If we already have loaded data and not forcing, keep showing it (or maybe show loading overlay?)
        // For Detail, usually we show what we have.
        
        do {
            logger.info("Loading detail for studio \(self.studioId)...")
            
            if let studio = try await repository.getStudio(id: studioId, forceRefresh: forceRefresh) {
                state = .content(studio)
                logger.info("✅ Loaded studio details for \(studio.name)")
            } else {
                state = .empty // Or error? "Studio not found"
                logger.warning("⚠️ Studio \(self.studioId) not found")
            }
        } catch {
            logger.error("❌ Failed to load studio detail: \(error.localizedDescription)")
            // Use AppError directly, assuming error string or localized description
            state = .error(error.localizedDescription) 
        }
    }
    
    func refresh() async {
        await loadStudio(forceRefresh: true)
    }
}
