import XCTest
@testable import Stash

final class URLWebSocketAndValidationTests: XCTestCase {
    
    // MARK: - URL WebSocket Conversion Tests
    
    func testWebSocketURL_httpConvertsToWS() {
        let httpURL = URL(string: "http://192.168.1.50:9999/graphql")!
        let wsURL = httpURL.webSocketURL
        XCTAssertEqual(wsURL.scheme, "ws")
        XCTAssertEqual(wsURL.host, "192.168.1.50")
        XCTAssertEqual(wsURL.port, 9999)
        XCTAssertEqual(wsURL.path, "/graphql")
    }
    
    func testWebSocketURL_httpsConvertsToWSS() {
        let httpsURL = URL(string: "https://stash.example.com/ws")!
        let wssURL = httpsURL.webSocketURL
        XCTAssertEqual(wssURL.scheme, "wss")
        XCTAssertEqual(wssURL.host, "stash.example.com")
        XCTAssertEqual(wssURL.path, "/ws")
    }
    
    func testWebSocketURL_preservesQueryParams() {
        let url = URL(string: "https://stash.example.com/ws?token=12345")!
        let wsURL = url.webSocketURL
        XCTAssertEqual(wsURL.scheme, "wss")
        XCTAssertEqual(wsURL.query, "token=12345")
    }
    
    // MARK: - SettingsStore Validation Tests
    
    func testValidateStashConfiguration_validURL_succeeds() throws {
        let store = MockSettingsStore()
        store.url = URL(string: "https://stash.example.com")
        
        let validatedURL = try store.validateStashConfiguration()
        XCTAssertEqual(validatedURL.absoluteString, "https://stash.example.com")
    }
    
    func testValidateStashConfiguration_nilURL_throwsAppError() {
        let store = MockSettingsStore()
        store.url = nil
        
        XCTAssertThrowsError(try store.validateStashConfiguration()) { error in
            guard case AppError.repository(.invalidConfiguration) = error else {
                XCTFail("Expected AppError.repository(.invalidConfiguration), got: \(error)")
                return
            }
        }
    }
    
    func testValidateWhisparrConfiguration_valid_succeeds() throws {
        let store = MockSettingsStore()
        store.whisparrUrl = "https://whisparr.example.com"
        store.whisparrApiKey = "secret-api-key"
        
        XCTAssertNoThrow(try store.validateWhisparrConfiguration())
    }
    
    func testValidateWhisparrConfiguration_emptyURL_throws() {
        let store = MockSettingsStore()
        store.whisparrUrl = ""
        store.whisparrApiKey = "secret-api-key"
        
        XCTAssertThrowsError(try store.validateWhisparrConfiguration())
    }
    
    func testValidateWhisparrConfiguration_emptyApiKey_throws() {
        let store = MockSettingsStore()
        store.whisparrUrl = "https://whisparr.example.com"
        store.whisparrApiKey = ""
        
        XCTAssertThrowsError(try store.validateWhisparrConfiguration())
    }
}
