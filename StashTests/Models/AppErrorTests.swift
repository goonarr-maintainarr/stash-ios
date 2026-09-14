import XCTest
@testable import Stash

final class AppErrorTests: XCTestCase {
    
    // MARK: - Network Error Tests
    
    func testNetworkError_userMessages() {
        XCTAssertEqual(NetworkError.noConnection.userMessage, "No internet connection")
        XCTAssertEqual(NetworkError.timeout.userMessage, "Request timed out")
        XCTAssertEqual(NetworkError.invalidURL("bad").userMessage, "Invalid server URL")
        XCTAssertEqual(NetworkError.httpError(statusCode: 500, response: nil).userMessage, "Server error (500)")
        XCTAssertEqual(NetworkError.cancelled.userMessage, "Request was cancelled")
    }
    
    func testNetworkError_isRetryable() {
        XCTAssertTrue(NetworkError.noConnection.isRetryable)
        XCTAssertTrue(NetworkError.timeout.isRetryable)
        XCTAssertTrue(NetworkError.httpError(statusCode: 503, response: nil).isRetryable)
        XCTAssertFalse(NetworkError.httpError(statusCode: 401, response: nil).isRetryable)
        XCTAssertFalse(NetworkError.cancelled.isRetryable)
        XCTAssertFalse(NetworkError.invalidURL("bad").isRetryable)
    }
    
    // MARK: - Database Error Tests
    
    func testDatabaseError_userMessages() {
        XCTAssertEqual(DatabaseError.notInitialized.userMessage, "Database not ready")
        XCTAssertEqual(DatabaseError.diskFull.userMessage, "Device storage is full")
        XCTAssertEqual(DatabaseError.corruptedData("file").userMessage, "Local data is corrupted")
    }
    
    // MARK: - Repository Error Tests
    
    func testRepositoryError_userMessages() {
        XCTAssertEqual(RepositoryError.invalidConfiguration.userMessage, "App configuration is invalid")
        XCTAssertEqual(RepositoryError.notFound.userMessage, "Item not found")
        XCTAssertEqual(RepositoryError.alreadyExists.userMessage, "Item already exists")
    }
    
    // MARK: - Validation Error Tests
    
    func testValidationError_userMessages() {
        let empty = ValidationError.emptyField("Name")
        XCTAssertEqual(empty.userMessage, "Name cannot be empty")
        
        let range = ValidationError.outOfRange("Rating", min: 0, max: 100)
        XCTAssertEqual(range.userMessage, "Rating must be between 0 and 100")
        
        let custom = ValidationError.custom("Custom validation message")
        XCTAssertEqual(custom.userMessage, "Custom validation message")
    }
    
    // MARK: - API Error Tests
    
    func testStashAPIError_userMessages() {
        XCTAssertEqual(StashAPIError.unauthorizedAPIKey.userMessage, "Invalid API key")
        XCTAssertEqual(StashAPIError.invalidResponse.userMessage, "Invalid server response")
        XCTAssertEqual(StashAPIError.graphQLErrors(["GraphQL failure"]).userMessage, "GraphQL failure")
    }
    
    func testWhisparrAPIError_userMessages() {
        XCTAssertEqual(WhisparrAPIError.notFound.userMessage, "Not found in Whisparr")
        XCTAssertEqual(WhisparrAPIError.unauthorizedAPIKey.userMessage, "Invalid Whisparr API key")
    }
    
    func testStashDBError_userMessages() {
        XCTAssertEqual(StashDBError.rateLimited.userMessage, "StashDB rate limit exceeded")
        XCTAssertEqual(StashDBError.unauthorizedAPIKey.userMessage, "Invalid StashDB API key")
    }
    
    // MARK: - Root AppError Delegation Tests
    
    func testAppError_descriptionDelegatesCorrectly() {
        let netErr = AppError.network(.noConnection)
        XCTAssertEqual(netErr.errorDescription, "No internet connection")
        
        let notFoundErr = AppError.notFound("Scene")
        XCTAssertEqual(notFoundErr.errorDescription, "Scene not found")
    }
    
    func testAppError_isRetryableDelegatesCorrectly() {
        XCTAssertTrue(AppError.network(.noConnection).isRetryable)
        XCTAssertTrue(AppError.network(.timeout).isRetryable)
        XCTAssertFalse(AppError.database(.notInitialized).isRetryable)
        XCTAssertFalse(AppError.repository(.invalidConfiguration).isRetryable)
        XCTAssertFalse(AppError.notFound("Scene").isRetryable)
    }
    
    func testAppError_shouldLog() {
        XCTAssertFalse(AppError.notFound("Scene").shouldLog)
        XCTAssertFalse(AppError.validation(.emptyField("Title")).shouldLog)
        XCTAssertTrue(AppError.network(.timeout).shouldLog)
        XCTAssertTrue(AppError.database(.diskFull).shouldLog)
    }
    
    // MARK: - Error Conversion Extensions
    
    func testURLError_toNetworkError() {
        let timedOut = URLError(.timedOut)
        if case .timeout = timedOut.toNetworkError() {
            // Success
        } else {
            XCTFail("Expected .timeout")
        }
        
        let noConn = URLError(.notConnectedToInternet)
        if case .noConnection = noConn.toNetworkError() {
            // Success
        } else {
            XCTFail("Expected .noConnection")
        }
    }
    
    func testError_toAppError() {
        let existing = AppError.repository(.notFound)
        let converted = (existing as Error).toAppError()
        if case .repository(.notFound) = converted {
            // Success
        } else {
            XCTFail("Expected .repository(.notFound)")
        }
        
        let urlErr = URLError(.timedOut)
        let convertedUrl = (urlErr as Error).toAppError()
        if case .network(.timeout) = convertedUrl {
            // Success
        } else {
            XCTFail("Expected .network(.timeout)")
        }
    }
}
