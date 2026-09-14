import Foundation
@testable import Stash

// Helper structs for mutation results
private struct SceneIncrementOResult: Codable {
    let sceneIncrementO: Int?
}

private struct SceneUpdateResult: Codable {
    let sceneUpdate: Scene?
}

class MockStashClient: StashClientProtocol {
    var mockSceneListResult: SceneResultDTO?
    var mockPerformerListResult: PerformerResultDTO?
    var mockTagListResult: TagResultDTO?
    
    var shouldThrowError = false
    var fetchCallCount = 0
    var lastQuery: String?
    var lastVariables: [String: Any]?
    var recordedQueries: [String] = []
    
    private struct SaveResult: Codable {
        let sceneSaveActivity: Bool
        init(sceneSaveActivity: Bool) { self.sceneSaveActivity = sceneSaveActivity }
    }
    
    private struct IncrementResult: Codable {
        let sceneIncrementPlayCount: Int
        init(sceneIncrementPlayCount: Int) { self.sceneIncrementPlayCount = sceneIncrementPlayCount }
    }

    func fetch<T: Decodable>(query: String, variables: [String: Any]?, url: URL, apiKey: String) async throws -> T {
        fetchCallCount += 1
        lastQuery = query
        lastVariables = variables
        recordedQueries.append(query)
        
        if shouldThrowError {
            let urlError = URLError(.badServerResponse)
            throw StashAPIError.networkError(NetworkError.unknown(urlError))
        }
        
        // List Results
        if T.self == SceneResultDTO.self {
            guard let result = mockSceneListResult else {
                throw StashAPIError.invalidResponse
            }
            return result as! T
        } else if T.self == PerformerResultDTO.self {
            guard let result = mockPerformerListResult else {
                throw StashAPIError.invalidResponse
            }
            return result as! T
        } else if T.self == TagResultDTO.self {
            guard let result = mockTagListResult else {
                throw StashAPIError.invalidResponse
            }
            return result as! T
        }
        
        // Mutation Results
        if query.contains("sceneIncrementO") {
            return SceneIncrementOResult(sceneIncrementO: 1) as! T
        } else if query.contains("sceneUpdate") {
            let scene = Scene(
                id: "1", title: "Test Scene", details: nil, date: nil, rating100: 5, o_counter: nil, performers: nil, tags: nil, studio: nil
            )
            return SceneUpdateResult(sceneUpdate: scene) as! T
        } else if query.contains("sceneSaveActivity") {
             return SaveResult(sceneSaveActivity: true) as! T
        } else if query.contains("sceneIncrementPlayCount") {
             return IncrementResult(sceneIncrementPlayCount: 1) as! T
        }
        
        throw StashAPIError.invalidResponse
    }
    
    // Protocol requirements
    func fetchJobQueue(url: URL, apiKey: String) async throws -> [Job] { return [] }
    func fetchLogs(url: URL, apiKey: String) async throws -> [Log] { return [] }
    func fetchVersion(url: URL, apiKey: String) async throws -> String { return "1.0.0" }
    func fetchStats(url: URL, apiKey: String) async throws -> Stats {
        throw StashAPIError.invalidResponse
    }
}
