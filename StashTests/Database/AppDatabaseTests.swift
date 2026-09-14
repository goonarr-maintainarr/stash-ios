import XCTest
import GRDB
@testable import Stash

final class AppDatabaseTests: XCTestCase {
    var appDb: AppDatabase!
    var stashDb: StashDatabase!
    var whisparrDb: WhisparrDatabase!
    
    override func setUp() async throws {
        // Use a fresh in-memory database for every test
        // Since StashDatabase and WhisparrDatabase are now non-isolated delegating actors 
        // that use AppDatabase.shared, we must swap the shared AppDatabase for testing.
        appDb = AppDatabase.testing()
        AppDatabase.shared = appDb
        
        stashDb = StashDatabase.shared
        whisparrDb = WhisparrDatabase.shared
    }
    
    override func tearDown() async throws {
        appDb = nil
        stashDb = nil
        whisparrDb = nil
        // Reset shared instance to avoid polluting other tests if necessary
    }
    
    // MARK: - Scene Unified Persistence Tests
    
    func testUnifiedScenePersistence() async throws {
        // 1. Save lightweight scene (list sync)
        let sceneId = "scene-123"
        let listScene = Scene.testScene(id: sceneId, title: "Initial Title")
        try await stashDb.saveScenes([listScene])
        
        // Verify core data saved
        let saved1 = try await stashDb.fetchAllScenes()
        XCTAssertEqual(saved1.count, 1)
        XCTAssertEqual(saved1.first?.title, "Initial Title")
        XCTAssertNil(saved1.first?.details)
        
        // 2. Save full details (detail fetch)
        // details is let, recreate scene
        let detailScene = Scene.testScene(
            id: sceneId, 
            title: "Initial Title",
            details: "Full descriptive details"
        ).withResumeTime(45.5)
        
        try await stashDb.saveSceneDetails(detailScene)
        
        // Verify merged data
        let result = try await stashDb.fetchSceneDetails(id: sceneId)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.scene.title, "Initial Title")
        XCTAssertEqual(result?.scene.details, "Full descriptive details")
        XCTAssertEqual(result?.scene.resume_time, 45.5)
        XCTAssertNotNil(result?.cachedAt)
        
        // 3. Update title via list sync again (should NOT wipe details)
        let updatedListScene = Scene.testScene(id: sceneId, title: "Updated Title")
        try await stashDb.saveScenes([updatedListScene])
        
        let saved2 = try await stashDb.fetchSceneDetails(id: sceneId)
        XCTAssertEqual(saved2?.scene.title, "Updated Title")
        XCTAssertEqual(saved2?.scene.details, "Full descriptive details")
    }
    
    // MARK: - Performer Unified Persistence Tests
    
    func testUnifiedPerformerPersistence() async throws {
        let perfId = "perf-1"
        let listPerf = Performer.testPerformer(id: perfId, name: "Performer Name")
        try await stashDb.savePerformers([listPerf])
        
        // Verify core
        let saved1 = try await stashDb.fetchAllPerformers()
        XCTAssertEqual(saved1.count, 1)
        
        // Save details
        let detailPerf = Performer.testPerformer(
            id: perfId, 
            name: "Performer Name",
            details: "Bio details"
        )
        let scenes = [Scene.testScene(id: "s1", title: "Scene 1")]
        try await stashDb.savePerformerDetails(detailPerf, scenes: scenes)
        
        // Verify merged
        let result = try await stashDb.fetchPerformerDetails(id: perfId)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.performer.details, "Bio details")
        XCTAssertEqual(result?.scenes.count, 1)
        XCTAssertEqual(result?.scenes.first?.title, "Scene 1")
    }
    
    // MARK: - Whisparr Renamed Table Tests
    
    func testWhisparrTableRenaming() async throws {
        let wScene = WhisparrScene.testScene(id: 1, title: "Whisparr Movie")
        try await whisparrDb.saveScenes([wScene])
        
        let count = try await whisparrDb.fetchSceneCount()
        XCTAssertEqual(count, 1)
        
        let fetched = try await whisparrDb.fetchAllScenes()
        XCTAssertEqual(fetched.first?.title, "Whisparr Movie")
    }
}

// MARK: - Test Helpers


