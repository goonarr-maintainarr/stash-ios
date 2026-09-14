import Foundation
import Observation
import SwiftUI
import os

@MainActor
@Observable
class StudioPerformersViewModel {
    
    // MARK: - Properties
    
    var state: ListViewState<Performer> = .loading
    var performers: [Performer] = []
    
    // Pagination
    private var currentPage = 1
    private let pageSize = 40
    private var hasMore = true
    private var isLoadingMore = false
    
    private let repository: any PerformerRepositoryProtocol
    private let studioId: String
    
    private let logger = Logger(subsystem: "com.stash.app", category: "StudioPerformersViewModel")
    
    // MARK: - Initialization
    
    init(repository: any PerformerRepositoryProtocol, studioId: String) {
        self.repository = repository
        self.studioId = studioId
    }
    
    // MARK: - Actions
    
    func loadPerformers() async {
        guard performers.isEmpty else { return }
        
        state = .loading
        
        do {
            logger.info("💃 Loading performers for studio \(self.studioId)...")
            let result = try await repository.getPerformers(
                searchText: "",
                page: 1,
                perPage: pageSize,
                sortBy: .name,
                sortDirection: "ASC",
                studioId: studioId,
                forceRefresh: false
            )
            
            self.performers = result.performers
            self.hasMore = result.hasMore
            self.currentPage = 1
            
            if performers.isEmpty {
                state = .empty
            } else {
                state = .content(performers)
            }
            logger.info("✅ Loaded \(self.performers.count) performers for studio")
            
        } catch {
            logger.error("❌ Failed to load studio performers: \(error.localizedDescription)")
            state = .error(error.localizedDescription)
        }
    }
    
    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        
        isLoadingMore = true
        let nextPage = currentPage + 1
        
        do {
            logger.debug("📜 Loading page \(nextPage) of studio performers...")
            let result = try await repository.getPerformers(
                searchText: "",
                page: nextPage,
                perPage: pageSize,
                sortBy: .name,
                sortDirection: "ASC",
                studioId: studioId,
                forceRefresh: false
            )
            
            self.performers.append(contentsOf: result.performers)
            self.hasMore = result.hasMore
            self.currentPage = nextPage
            
            state = .content(self.performers)
            
            logger.debug("✅ Appended \(result.performers.count) performers")
            
        } catch {
            logger.error("❌ Failed to load more performers: \(error.localizedDescription)")
        }
        
        isLoadingMore = false
    }
    
    func refresh() async {
        performers.removeAll()
        await loadPerformers()
    }
}
