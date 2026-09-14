import XCTest
import Combine
@testable import Stash

@MainActor
class StashSubscriptionServiceTests: XCTestCase {
    
    var service: StashSubscriptionService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        cancellables = Set<AnyCancellable>()
        service = StashSubscriptionService.shared
        // Clear any existing jobs
        service.jobsState.jobs.removeAll()
        service.jobsState.hasIdentifyJob = false
    }
    
    override func tearDown() async throws {
        service.disconnect()
        service.jobsState.jobs.removeAll()
        service.jobsState.hasIdentifyJob = false
        cancellables = nil
        try await super.tearDown()
    }
    
    // MARK: - Job Update Tests
    
    func testUpdateJob_NewJob_AddsToJobsList() async throws {
        // Given
        let job = Job(
            id: "test-job-1",
            addTime: nil,
            description: "Test Job",
            status: .running,
            progress: 0.5,
            startTime: "2024-01-01T12:00:00Z",
            endTime: nil,
            error: nil,
            subTasks: nil
        )
        
        // When
        await service.updateJob(job)
        
        // Then
        XCTAssertEqual(service.jobsState.jobs.count, 1)
        XCTAssertEqual(service.jobsState.jobs.first?.id, "test-job-1")
        XCTAssertEqual(service.jobsState.jobs.first?.status, .running)
    }
    
    func testUpdateJob_ExistingJob_UpdatesInPlace() async throws {
        // Given
        let initialJob = Job(
            id: "test-job-1",
            addTime: nil,
            description: "Test Job",
            status: .running,
            progress: 0.3,
            startTime: "2024-01-01T12:00:00Z",
            endTime: nil,
            error: nil,
            subTasks: nil
        )
        await service.updateJob(initialJob)
        
        // When
        let updatedJob = Job(
            id: "test-job-1",
            addTime: nil,
            description: "Test Job",
            status: .running,
            progress: 0.8,
            startTime: "2024-01-01T12:00:00Z",
            endTime: nil,
            error: nil,
            subTasks: nil
        )
        await service.updateJob(updatedJob)
        
        // Then
        XCTAssertEqual(service.jobsState.jobs.count, 1)
        XCTAssertEqual(service.jobsState.jobs.first?.progress, 0.8)
    }
    
    func testUpdateJob_MultipleJobs_MaintainsOrder() async throws {
        // Given
        let job1 = Job(id: "job-1", addTime: nil, description: "Job 1", status: .running, progress: nil, startTime: "2024-01-01T12:00:00Z", endTime: nil, error: nil, subTasks: nil)
        let job2 = Job(id: "job-2", addTime: nil, description: "Job 2", status: .running, progress: nil, startTime: "2024-01-01T12:01:00Z", endTime: nil, error: nil, subTasks: nil)
        let job3 = Job(id: "job-3", addTime: nil, description: "Job 3", status: .running, progress: nil, startTime: "2024-01-01T12:02:00Z", endTime: nil, error: nil, subTasks: nil)
        
        // When
        await service.updateJob(job1)
        await service.updateJob(job2)
        await service.updateJob(job3)
        
        // Then
        XCTAssertEqual(service.jobsState.jobs.count, 3)
        XCTAssertEqual(service.jobsState.jobs[0].id, "job-3") // Most recent first
        XCTAssertEqual(service.jobsState.jobs[1].id, "job-2")
        XCTAssertEqual(service.jobsState.jobs[2].id, "job-1")
    }
    
    // MARK: - Job Completion Tests
    
    func testUpdateJob_JobCompletes_PostsNotification() async throws {
        // Given
        let expectation = expectation(forNotification: .stashJobCompleted, object: nil)
        
        let job = Job(
            id: "test-job-1",
            addTime: nil,
            description: "Test Job",
            status: .finished,
            progress: 1.0,
            startTime: "2024-01-01T12:00:00Z",
            endTime: "2024-01-01T12:05:00Z",
            error: nil,
            subTasks: nil
        )
        
        // When
        await service.updateJob(job)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testUpdateJob_JobAlreadyCompleted_DoesNotRepostNotification() async throws {
        // Given
        let completedJob = Job(
            id: "test-job-1",
            addTime: nil,
            description: "Test Job",
            status: .finished,
            progress: 1.0,
            startTime: "2024-01-01T12:00:00Z",
            endTime: "2024-01-01T12:05:00Z",
            error: nil,
            subTasks: nil
        )
        await service.updateJob(completedJob)
        
        // Clear notification center
        var notificationCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .stashJobCompleted,
            object: nil,
            queue: nil
        ) { _ in
            notificationCount += 1
        }
        
        // When - update the same job again
        await service.updateJob(completedJob)
        
        // Wait a bit to ensure no notification is posted
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(notificationCount, 0)
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testUpdateJob_JobCompletes_RemovesAfterDelay() async throws {
        // Given
        let job = Job(
            id: "test-job-1",
            addTime: nil,
            description: "Test Job",
            status: .finished,
            progress: 1.0,
            startTime: "2024-01-01T12:00:00Z",
            endTime: "2024-01-01T12:05:00Z",
            error: nil,
            subTasks: nil
        )
        
        // When
        await service.updateJob(job)
        XCTAssertEqual(service.jobsState.jobs.count, 1)
        
        // Wait for removal (5 second delay + buffer)
        try await Task.sleep(nanoseconds: 5_500_000_000) // 5.5 seconds
        
        // Then
        XCTAssertEqual(service.jobsState.jobs.count, 0)
    }
    
    // MARK: - Identify Job Tracking Tests
    
    func testUpdateJob_IdentifyJob_SetsFlag() async throws {
        // Given
        let identifyJob = Job(
            id: "identify-job",
            addTime: nil,
            description: "Identifying scenes...",
            status: .running,
            progress: 0.5,
            startTime: "2024-01-01T12:00:00Z",
            endTime: nil,
            error: nil,
            subTasks: nil
        )
        
        // When
        await service.updateJob(identifyJob)
        
        // Then
        XCTAssertTrue(service.jobsState.hasIdentifyJob)
    }
    
    func testUpdateJob_NonIdentifyJob_DoesNotSetFlag() async throws {
        // Given
        let regularJob = Job(
            id: "scan-job",
            addTime: nil,
            description: "Scanning files...",
            status: .running,
            progress: 0.5,
            startTime: "2024-01-01T12:00:00Z",
            endTime: nil,
            error: nil,
            subTasks: nil
        )
        
        // When
        await service.updateJob(regularJob)
        
        // Then
        XCTAssertFalse(service.jobsState.hasIdentifyJob)
    }
    
    func testUpdateJob_AllJobsComplete_PostsAllJobsCompletedNotification() async throws {
        // Given
        let expectation = expectation(forNotification: .stashAllJobsCompleted, object: nil)
        
        let job = Job(
            id: "test-job-1",
            addTime: nil,
            description: "Test Job",
            status: .finished,
            progress: 1.0,
            startTime: "2024-01-01T12:00:00Z",
            endTime: "2024-01-01T12:05:00Z",
            error: nil,
            subTasks: nil
        )
        
        // When
        await service.updateJob(job)
        
        // Wait for removal and notification
        try await Task.sleep(nanoseconds: 5_500_000_000) // 5.5 seconds
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testUpdateJob_AllJobsCompleteWithIdentify_IncludesIdentifyFlagInNotification() async throws {
        // Given
        let expectation = expectation(forNotification: .stashAllJobsCompleted, object: nil) { notification in
            guard let userInfo = notification.userInfo,
                  let hasIdentify = userInfo["hasIdentify"] as? Bool else {
                return false
            }
            return hasIdentify == true
        }
        
        let identifyJob = Job(
            id: "identify-job",
            addTime: nil,
            description: "Identify scenes",
            status: .finished,
            progress: 1.0,
            startTime: "2024-01-01T12:00:00Z",
            endTime: "2024-01-01T12:05:00Z",
            error: nil,
            subTasks: nil
        )
        
        // When
        await service.updateJob(identifyJob)
        
        // Wait for removal and notification
        try await Task.sleep(nanoseconds: 5_500_000_000) // 5.5 seconds
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(service.jobsState.hasIdentifyJob) // Should be reset after notification
    }
    
    // MARK: - Convenience Accessor Tests
    
    func testJobsAccessor_ReturnsJobsStateJobs() async throws {
        // Given
        let job = Job(id: "job-1", addTime: nil, description: "Job 1", status: .running, progress: nil, startTime: "2024-01-01T12:00:00Z", endTime: nil, error: nil, subTasks: nil)
        await service.updateJob(job)
        
        // When
        let jobs = service.jobs
        
        // Then
        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs.first?.id, "job-1")
    }
    
    // MARK: - Connection State Tests
    
    func testIsConnected_InitiallyFalse() {
        // Then
        XCTAssertFalse(service.isConnected)
    }
}
