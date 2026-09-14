import XCTest
import AVFoundation
@testable import Stash

final class PlaybackTrackerTests: XCTestCase {
    var mockClient: MockStashClient!
    var player: AVPlayer!
    var tracker: PlaybackTracker!
    
    override func setUp() {
        super.setUp()
        mockClient = MockStashClient()
        player = AVPlayer()
        
        tracker = PlaybackTracker(
            sceneId: "123",
            player: player,
            minimumPlayPercent: 50, // 50% for testing
            graphQLClient: mockClient,
            url: URL(string: "http://localhost:9999")!,
            apiKey: "test-api-key"
        )
        
        // Setup Overrides
        tracker.isPlayingOverride = { true }
        tracker.currentTimeOverride = { 0 }
        tracker.durationOverride = { 100 }
    }
    
    override func tearDown() {
        tracker = nil
        player = nil
        mockClient = nil
        super.tearDown()
    }
    
    func testTrackPlayback_AccumulatesTime() {
        // When
        tracker.trackPlayback() // Simulate 1 second
        
        // Then
        // Cannot inspect private properties directly, but can inspect behavior.
        // It should NOT send anything yet (1s < 10s).
        XCTAssertEqual(mockClient.fetchCallCount, 0)
    }
    
    func testTrackPlayback_SendsUpdateAfter10Seconds() {
        // Given
        tracker.currentTimeOverride = { 10 } // Playing...
        
        // When: Simulate 10 ticks
        for _ in 1...10 {
            tracker.trackPlayback()
        }
        
        // Then: Should send "saveActivity"
        waitForMockData(callCount: 1)
        
        XCTAssertEqual(mockClient.fetchCallCount, 1)
        XCTAssertTrue(mockClient.lastQuery?.contains("sceneSaveActivity") ?? false)
        XCTAssertTrue(mockClient.lastQuery?.contains("resume_time: 10.0") ?? false)
    }
    
    func testTrackPlayback_IncrementsPlayCount_WhenThresholdReached() {
        // Given: Threshold is 50% (50s of 100s video)
        
        // When: Simulate 50 ticks (accumulated time = 50s)
        for i in 1...50 {
             tracker.currentTimeOverride = { Double(i) }
             tracker.trackPlayback()
        }
        
        // Then: Should send 5 saveActivities (at 10, 20, 30, 40, 50s)
        // AND 1 incrementPlayCount at 50s
        waitForMockData(callCount: 6)
        
        // Check for incrementPlayCount query
        let hasIncrement = mockClient.recordedQueries.contains { $0.contains("sceneIncrementPlayCount") }
        XCTAssertTrue(hasIncrement, "Should have called sceneIncrementPlayCount")
    }
    
    func testTrackPlayback_ResetsResumeTime_When98PercentComplete() {
         // Given
         tracker.currentTimeOverride = { 99 } // 99s of 100s (99%)
         
         // When: Trigger update (tick 10 times to hit sync interval)
         for _ in 1...10 {
             tracker.trackPlayback()
         }
         
         // Then
         waitForMockData(callCount: 1)
         
         XCTAssertTrue(mockClient.lastQuery?.contains("resume_time: 0.0") ?? false, "Should reset resume time to 0.0")
    }
    
    // MARK: - Helper
    
    private func waitForMockData(callCount: Int, timeout: TimeInterval = 1.0) {
        let predicate = NSPredicate { _, _ in
            self.mockClient.fetchCallCount >= callCount
        }
        let validation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        wait(for: [validation], timeout: timeout)
    }
}
