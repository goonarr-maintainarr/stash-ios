import XCTest
@testable import Stash

@MainActor
final class SettingsStoreTests: XCTestCase {
    var settings: SettingsStore!
    
    // Backup values to restore after tests
    var originalServerUrl: Any?
    var originalApiKey: Any?
    
    override func setUp() {
        super.setUp()
        // Capture existing values
        originalServerUrl = UserDefaults.standard.object(forKey: "serverUrl")
        originalApiKey = UserDefaults.standard.object(forKey: "apiKey")
        
        // Reset for test
        UserDefaults.standard.removeObject(forKey: "serverUrl")
        UserDefaults.standard.removeObject(forKey: "apiKey")
        UserDefaults.standard.removeObject(forKey: "followedTagIds")
        
        settings = SettingsStore()
    }
    
    override func tearDown() {
        settings = nil
        
        // Restore values
        if let url = originalServerUrl {
            UserDefaults.standard.set(url, forKey: "serverUrl")
        } else {
            UserDefaults.standard.removeObject(forKey: "serverUrl")
        }
        
        if let key = originalApiKey {
            UserDefaults.standard.set(key, forKey: "apiKey")
        } else {
            UserDefaults.standard.removeObject(forKey: "apiKey")
        }
        
        UserDefaults.standard.removeObject(forKey: "followedTagIds")
        super.tearDown()
    }
    
    // MARK: - Validation Tests
    
    func testIsValid_WithValidUrl() {
        settings.serverUrl = "http://localhost:9999/graphql"
        XCTAssertTrue(settings.isValid)
    }
    
    func testIsValid_WithInvalidUrl() {
        settings.serverUrl = "" // Empty string is not a valid URL for network requests usually, but URL(string: "") returns nil? No, returns non-nil relative URL.
        // URL(string: "") is actually not nil, it's relative.
        // Let's check the implementation: return URL(string: serverUrl) != nil
        // A truly invalid URL string in Swift is rare (e.g. containing spaces), let's try that
        settings.serverUrl = "http:// local host" // Spaces make it nil
        XCTAssertFalse(settings.isValid)
    }
    
    // MARK: - URL Generation Tests
    
    func testCreateImageUrl_AppendsApiKey() {
        // Given
        settings.serverUrl = "http://localhost:9999/graphql"
        settings.apiKey = "test-token"
        let path = "/image.jpg"
        
        // When
        let url = settings.createImageUrl(path: path)
        
        // Then
        XCTAssertNotNil(url)
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: true)
        let apiKeyItem = components?.queryItems?.first(where: { $0.name == "apikey" })
        XCTAssertEqual(apiKeyItem?.value, "test-token")
        XCTAssertEqual(components?.path, "/image.jpg")
    }
    
    func testCreateImageUrl_HandlesExistingUrl() {
        // Given
        settings.serverUrl = "http://localhost:9999/graphql"
        settings.apiKey = "test-token"
        let fullPath = "http://external.com/image.jpg"
        
        // When
        let url = settings.createImageUrl(path: fullPath)
        
        // Then
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "external.com")
        // Should still append API key if settings say so
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: true)
        let apiKeyItem = components?.queryItems?.first(where: { $0.name == "apikey" })
        XCTAssertEqual(apiKeyItem?.value, "test-token")
    }
    
    func testCreateImageUrl_RemovesGraphqlSuffix() {
        // Given
        settings.serverUrl = "http://localhost:9999/graphql"
        let path = "/image.jpg"
        
        // When
        let url = settings.createImageUrl(path: path)
        
        // Then
        // Should be http://localhost:9999/image.jpg not .../graphql/image.jpg
        let urlString = url?.absoluteString
        XCTAssertTrue(urlString?.hasPrefix("http://localhost:9999/image.jpg") ?? false)
    }
    
    func testCreateImageUrl_NoPath_ReturnsNil() {
        XCTAssertNil(settings.createImageUrl(path: nil))
    }
    
    // MARK: - Tag Management Tests
    
    func testFollowedTags_Add() {
        // Given
        XCTAssertTrue(settings.followedTagIds.isEmpty)
        
        // When
        settings.addFollowedTag(id: "tag1")
        
        // Then
        XCTAssertEqual(settings.followedTagIds.count, 1)
        XCTAssertTrue(settings.followedTagIds.contains("tag1"))
    }
    
    func testFollowedTags_AddDuplicate() {
        // Given
        settings.addFollowedTag(id: "tag1")
        
        // When
        settings.addFollowedTag(id: "tag1")
        
        // Then
        XCTAssertEqual(settings.followedTagIds.count, 1)
    }
    
    func testFollowedTags_Remove() {
        // Given
        settings.addFollowedTag(id: "tag1")
        settings.addFollowedTag(id: "tag2")
        
        // When
        settings.removeFollowedTag(id: "tag1")
        
        // Then
        XCTAssertEqual(settings.followedTagIds.count, 1)
        XCTAssertTrue(settings.followedTagIds.contains("tag2"))
        XCTAssertFalse(settings.followedTagIds.contains("tag1"))
    }
}
