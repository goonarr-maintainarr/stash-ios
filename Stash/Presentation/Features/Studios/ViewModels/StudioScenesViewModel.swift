import Foundation
import Observation
import SwiftUI
import os

@MainActor
@Observable
class StudioScenesViewModel {
    
    // MARK: - Properties
    
    var state: ListViewState<Scene> = .loading
    var scenes: [Scene] = []
    
    // Pagination
    private var currentPage = 1
    private let pageSize = 40
    private var hasMore = true
    private var isLoadingMore = false
    
    private let repository: any SceneRepositoryProtocol
    private let studioId: String
    
    private let logger = Logger(subsystem: "com.stash.app", category: "StudioScenesViewModel")
    
    // MARK: - Initialization
    
    init(repository: any SceneRepositoryProtocol, studioId: String) {
        self.repository = repository
        self.studioId = studioId
    }
    
    // MARK: - Actions
    
    func loadScenes() async {
        guard scenes.isEmpty else { return } // Already loaded
        
        state = .loading
        
        do {
            logger.info("🎬 Loading scenes for studio \(self.studioId)...")
            let result = try await repository.getScenes(
                searchText: "",
                page: 1,
                perPage: pageSize,
                sortBy: .date, // Default to date descending
                sortDirection: "DESC",
                tagIds: nil,
                studioId: studioId,
                forceRefresh: false
            )
            
            self.scenes = result.scenes
            self.hasMore = result.hasMore
            self.currentPage = 1
            
            if scenes.isEmpty {
                state = .empty
            } else {
                state = .content(scenes)
            }
            logger.info("✅ Loaded \(self.scenes.count) scenes for studio")
            
        } catch {
            logger.error("❌ Failed to load studio scenes: \(error.localizedDescription)")
            state = .error(error.localizedDescription)
        }
    }
    
    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        
        isLoadingMore = true
        let nextPage = currentPage + 1
        
        do {
            logger.debug("📜 Loading page \(nextPage) of studio scenes...")
            let result = try await repository.getScenes(
                searchText: "",
                page: nextPage,
                perPage: pageSize,
                sortBy: .date,
                sortDirection: "DESC",
                tagIds: nil,
                studioId: studioId,
                forceRefresh: false
            )
            
            self.scenes.append(contentsOf: result.scenes)
            self.hasMore = result.hasMore
            self.currentPage = nextPage
            
            // Allow UI update
            if case .content = state {
                // state update trigger implicitly via scenes property, 
                // but if we want to force ViewState update (though .content just holds generic identifier usually)
                state = .content(self.scenes)
            }
             
            logger.debug("✅ Appended \(result.scenes.count) scenes")
            
        } catch {
            logger.error("❌ Failed to load more scenes: \(error.localizedDescription)")
            // Don't change main state to error, just log it? Or show toast?
        }
        
        isLoadingMore = false
    }
    
    func refresh() async {
        scenes.removeAll()
        await loadScenes()
    }
}
