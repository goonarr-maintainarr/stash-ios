import XCTest
@testable import Stash

final class StatsModelTests: XCTestCase {
    
    // MARK: - JSON Decoding Tests
    
    func testDecode_FullStats_Succeeds() throws {
        let json = """
        {
            "scene_count": 9720,
            "scenes_size": 21946101744299,
            "scenes_duration": 21619989.92,
            "image_count": 0,
            "images_size": 0,
            "gallery_count": 0,
            "performer_count": 1137,
            "studio_count": 901,
            "group_count": 5,
            "movie_count": 5,
            "tag_count": 2236,
            "total_o_count": 770,
            "total_play_duration": 397769,
            "total_play_count": 1845,
            "scenes_played": 1336
        }
        """
        
        let data = json.data(using: .utf8)!
        let stats = try JSONDecoder().decode(Stats.self, from: data)
        
        XCTAssertEqual(stats.scene_count, 9720)
        XCTAssertEqual(stats.scenes_size, 21946101744299)
        XCTAssertEqual(stats.performer_count, 1137)
        XCTAssertEqual(stats.studio_count, 901)
        XCTAssertEqual(stats.tag_count, 2236)
        XCTAssertEqual(stats.total_o_count, 770)
        XCTAssertEqual(stats.total_play_count, 1845)
        XCTAssertEqual(stats.scenes_played, 1336)
    }
    
    // MARK: - Formatted Properties Tests
    
    func testFormattedScenesSize_FormatsCorrectly() throws {
        let stats = try createTestStats(scenes_size: 21946101744299) // ~21.9 TB
        
        // ByteCountFormatter output varies by locale, just verify it contains a size unit
        XCTAssertFalse(stats.formattedScenesSize.isEmpty)
        XCTAssertTrue(stats.formattedScenesSize.contains("TB") || stats.formattedScenesSize.contains("GB"))
    }
    
    func testFormattedScenesDuration_FormatsDays() throws {
        // 250 days in seconds = 21600000
        let stats = try createTestStats(scenes_duration: 21600000)
        
        XCTAssertTrue(stats.formattedScenesDuration.contains("d"))
    }
    
    func testFormattedScenesDuration_FormatsHours() throws {
        // 5 hours in seconds = 18000
        let stats = try createTestStats(scenes_duration: 18000)
        
        XCTAssertTrue(stats.formattedScenesDuration.contains("h"))
    }
    
    func testFormattedScenesDuration_FormatsMinutes() throws {
        // 45 minutes in seconds = 2700
        let stats = try createTestStats(scenes_duration: 2700)
        
        XCTAssertEqual(stats.formattedScenesDuration, "45m")
    }
    
    func testAverageSceneDuration_CalculatesCorrectly() throws {
        // 10 scenes, 3000 seconds total = 300 seconds avg = 5 minutes
        let stats = try createTestStats(scene_count: 10, scenes_duration: 3000)
        
        XCTAssertEqual(stats.averageSceneDuration, "5m")
    }
    
    func testAverageSceneDuration_ReturnsZero_WhenNoScenes() throws {
        let stats = try createTestStats(scene_count: 0, scenes_duration: 0)
        
        XCTAssertEqual(stats.averageSceneDuration, "0m")
    }
    
    func testPercentScenesPlayed_CalculatesCorrectly() throws {
        // 50 of 100 scenes played = 50%
        let stats = try createTestStats(scene_count: 100, scenes_played: 50)
        
        XCTAssertEqual(stats.percentScenesPlayed, 50.0, accuracy: 0.01)
    }
    
    func testPercentScenesPlayed_ReturnsZero_WhenNoScenes() throws {
        let stats = try createTestStats(scene_count: 0, scenes_played: 0)
        
        XCTAssertEqual(stats.percentScenesPlayed, 0)
    }
    
    // MARK: - Helpers
    
    private func createTestStats(
        scene_count: Int = 100,
        scenes_size: Int64 = 1000000000,
        scenes_duration: Double = 36000,
        scenes_played: Int = 50
    ) throws -> Stats {
        let json = """
        {
            "scene_count": \(scene_count),
            "scenes_size": \(scenes_size),
            "scenes_duration": \(scenes_duration),
            "image_count": 0,
            "images_size": 0,
            "gallery_count": 0,
            "performer_count": 100,
            "studio_count": 50,
            "group_count": 5,
            "movie_count": 5,
            "tag_count": 200,
            "total_o_count": 100,
            "total_play_duration": 10000,
            "total_play_count": 200,
            "scenes_played": \(scenes_played)
        }
        """
        
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(Stats.self, from: data)
    }
}
