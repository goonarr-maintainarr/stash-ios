import Foundation

protocol StudioRepositoryProtocol: Repository {
    // Standard CRUD / Fetch
    func getStudios(
        searchText: String,
        page: Int,
        perPage: Int,
        sortBy: String,
        sortDirection: String,
        forceRefresh: Bool
    ) async throws -> (studios: [Studio], count: Int)
    
    func getStudio(id: String, forceRefresh: Bool) async throws -> Studio?
    
    // Sync
    func syncNewStudios(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Studio]
    func fullSync(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> (studios: [Studio], removedCount: Int)
}
