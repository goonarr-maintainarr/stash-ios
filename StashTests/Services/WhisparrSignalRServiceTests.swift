import XCTest
@testable import Stash

@MainActor
class WhisparrSignalRServiceTests: XCTestCase {
    
    var service: WhisparrSignalRService!
    
    override func setUp() async throws {
        try await super.setUp()
        service = WhisparrSignalRService.shared
        service.activities.removeAll()
    }
    
    override func tearDown() async throws {
        service.disconnect()
        service.activities.removeAll()
        try await super.tearDown()
    }
    
    // MARK: - Activity Tests
    
    func testAddActivity_NewActivity_AddsToList() async throws {
        // Given
        let activity = WhisparrActivity(
            timestamp: Date(),
            eventType: .movie,
            title: "Test Movie",
            detail: "Updated",
            status: .updated
        )
        
        // When
        service.addActivity(activity)
        
        // Then
        XCTAssertEqual(service.activities.count, 1)
        XCTAssertEqual(service.activities.first?.title, "Test Movie")
    }
    
    func testAddActivity_MultipleActivities_MaintainsRecentFirst() async throws {
        // Given
        let activity1 = WhisparrActivity(
            timestamp: Date(),
            eventType: .command,
            title: "Command 1",
            detail: nil,
            status: .started
        )
        let activity2 = WhisparrActivity(
            timestamp: Date(),
            eventType: .movie,
            title: "Movie 1",
            detail: nil,
            status: .updated
        )
        
        // When
        service.addActivity(activity1)
        service.addActivity(activity2)
        
        // Then
        XCTAssertEqual(service.activities.count, 2)
        XCTAssertEqual(service.activities[0].title, "Movie 1") // Most recent first
        XCTAssertEqual(service.activities[1].title, "Command 1")
    }
    
    func testAddActivity_ExceedsMaxActivities_TrimsToMax() async throws {
        // Given - Add 60 activities (max is 50)
        for i in 0..<60 {
            let activity = WhisparrActivity(
                timestamp: Date(),
                eventType: .command,
                title: "Activity \(i)",
                detail: nil,
                status: .started
            )
            service.addActivity(activity)
        }
        
        // Then
        XCTAssertEqual(service.activities.count, 50)
        XCTAssertEqual(service.activities.first?.title, "Activity 59") // Most recent
        XCTAssertEqual(service.activities.last?.title, "Activity 10") // Oldest kept
    }
    
    func testClearActivities_RemovesAll() async throws {
        // Given
        for i in 0..<5 {
            let activity = WhisparrActivity(
                timestamp: Date(),
                eventType: .command,
                title: "Activity \(i)",
                detail: nil,
                status: .started
            )
            service.addActivity(activity)
        }
        
        // When
        service.clearActivities()
        
        // Then
        XCTAssertEqual(service.activities.count, 0)
    }
    
    // MARK: - Message Handling Tests
    
    func testHandleHubMessage_CommandEvent_CreatesCommandActivity() async throws {
        // Given
        let json = """
        {
            "arguments": [{
                "name": "command",
                "action": "updated",
                "body": {
                    "resource": {
                        "commandName": "Refresh Movie",
                        "message": "Updating info for Test Movie",
                        "status": "started"
                    }
                }
            }]
        }
        """
        
        // When
        service.handleHubMessage(json)
        
        // Then
        XCTAssertEqual(service.activities.count, 1)
        XCTAssertEqual(service.activities.first?.eventType, .command)
        XCTAssertEqual(service.activities.first?.title, "Refresh Movie")
        XCTAssertEqual(service.activities.first?.detail, "Updating info for Test Movie")
        XCTAssertEqual(service.activities.first?.status, .started)
    }
    
    func testHandleHubMessage_MovieEvent_CreatesMovieActivity() async throws {
        // Given
        let json = """
        {
            "arguments": [{
                "name": "movie",
                "action": "updated",
                "body": {
                    "resource": {
                        "title": "Test Movie Title"
                    }
                }
            }]
        }
        """
        
        // When
        service.handleHubMessage(json)
        
        // Then
        XCTAssertEqual(service.activities.count, 1)
        XCTAssertEqual(service.activities.first?.eventType, .movie)
        XCTAssertEqual(service.activities.first?.title, "Test Movie Title")
        XCTAssertEqual(service.activities.first?.detail, "updated")
        XCTAssertEqual(service.activities.first?.status, .updated)
    }
    
    func testHandleHubMessage_SystemEvent_CreatesSystemActivity() async throws {
        // Given
        let json = """
        {
            "arguments": [{
                "name": "system/task",
                "action": "sync",
                "body": {}
            }]
        }
        """
        
        // When
        service.handleHubMessage(json)
        
        // Then
        XCTAssertEqual(service.activities.count, 1)
        XCTAssertEqual(service.activities.first?.eventType, .system)
        XCTAssertEqual(service.activities.first?.title, "System Task")
        XCTAssertEqual(service.activities.first?.detail, "sync")
    }
    
    func testHandleHubMessage_InvalidJSON_DoesNotCrash() async throws {
        // Given
        let invalidJson = "not valid json"
        
        // When
        service.handleHubMessage(invalidJson)
        
        // Then - Should not crash
        XCTAssertEqual(service.activities.count, 0)
    }
    
    func testHandleHubMessage_MissingFields_DoesNotCrash() async throws {
        // Given
        let incompleteJson = """
        {
            "arguments": [{
                "name": "command"
            }]
        }
        """
        
        // When
        service.handleHubMessage(incompleteJson)
        
        // Then - Should not crash, no activity added
        XCTAssertEqual(service.activities.count, 0)
    }
    
    // MARK: - Command Status Tests
    
    func testHandleCommandEvent_CompletedStatus_SetsCompletedStatus() async throws {
        // Given
        let json = """
        {
            "arguments": [{
                "name": "command",
                "body": {
                    "resource": {
                        "commandName": "Test Command",
                        "message": "",
                        "status": "completed"
                    }
                }
            }]
        }
        """
        
        // When
        service.handleHubMessage(json)
        
        // Then
        XCTAssertEqual(service.activities.first?.status, .completed)
    }
    
    func testHandleCommandEvent_FailedStatus_SetsFailedStatus() async throws {
        // Given
        let json = """
        {
            "arguments": [{
                "name": "command",
                "body": {
                    "resource": {
                        "commandName": "Test Command",
                        "message": "",
                        "status": "failed"
                    }
                }
            }]
        }
        """
        
        // When
        service.handleHubMessage(json)
        
        // Then
        XCTAssertEqual(service.activities.first?.status, .failed)
    }
    
    func testHandleCommandEvent_UnknownStatus_SetsUpdatedStatus() async throws {
        // Given
        let json = """
        {
            "arguments": [{
                "name": "command",
                "body": {
                    "resource": {
                        "commandName": "Test Command",
                        "message": "",
                        "status": "queued"
                    }
                }
            }]
        }
        """
        
        // When
        service.handleHubMessage(json)
        
        // Then
        XCTAssertEqual(service.activities.first?.status, .updated)
    }
    
    // MARK: - Connection State Tests
    
    func testInitialConnectionState_Disconnected() {
        // Then
        XCTAssertFalse(service.isConnected)
        XCTAssertEqual(service.connectionState, "Disconnected")
    }
    
    func testConnect_InvalidURL_DoesNotConnect() {
        // When
        service.connect(url: "", apiKey: "test-key")
        
        // Then - Should not crash
        XCTAssertFalse(service.isConnected)
    }
    
    func testConnect_EmptyApiKey_DoesNotConnect() {
        // When
        service.connect(url: "http://test.com", apiKey: "")
        
        // Then - Should not crash
        XCTAssertFalse(service.isConnected)
    }
}

// MARK: - WhisparrActivity Tests

class WhisparrActivityTests: XCTestCase {
    
    func testEventType_Icons() {
        XCTAssertEqual(WhisparrActivity.EventType.command.icon, "gearshape")
        XCTAssertEqual(WhisparrActivity.EventType.movie.icon, "film")
        XCTAssertEqual(WhisparrActivity.EventType.system.icon, "arrow.triangle.2.circlepath")
        XCTAssertEqual(WhisparrActivity.EventType.unknown.icon, "questionmark")
    }
    
    func testActivity_Equatable() {
        let activity1 = WhisparrActivity(
            timestamp: Date(),
            eventType: .movie,
            title: "Test",
            detail: nil,
            status: .updated
        )
        
        let activity2 = WhisparrActivity(
            timestamp: Date(),
            eventType: .movie,
            title: "Test",
            detail: nil,
            status: .updated
        )
        
        // Activities with different UUIDs are not equal
        XCTAssertNotEqual(activity1, activity2)
        
        // Same activity is equal to itself
        XCTAssertEqual(activity1, activity1)
    }
}
