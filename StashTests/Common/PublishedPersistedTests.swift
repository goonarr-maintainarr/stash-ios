import XCTest
import Combine
@testable import Stash

class PublishedPersistedTests: XCTestCase {
    
    var cancellables: Set<AnyCancellable>!
    var testDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        // Use a dedicated test suite to avoid conflicts
        testDefaults = UserDefaults(suiteName: "com.stash.tests")!
        testDefaults.removePersistentDomain(forName: "com.stash.tests")
    }
    
    override func tearDown() {
        cancellables = nil
        testDefaults.removePersistentDomain(forName: "com.stash.tests")
        testDefaults = nil
        super.tearDown()
    }
    
    // MARK: - Int RawValue Tests (New functionality)
    
    func testIntRawValue_SavesAndLoadsCorrectly() {
        // Given
        enum TestEnum: Int, CaseIterable {
            case first = 0
            case second = 1
            case third = 2
        }
        
        let wrapper = PublishedPersisted<TestEnum>(
            key: "testIntEnum",
            defaultValue: .first,
            storage: testDefaults
        )
        
        // When
        wrapper.wrappedValue = .third
        
        // Then
        let stored = testDefaults.integer(forKey: "testIntEnum")
        XCTAssertEqual(stored, 2, "Should store raw int value")
        
        // Create new wrapper to test loading
        let wrapper2 = PublishedPersisted<TestEnum>(
            key: "testIntEnum",
            defaultValue: .first,
            storage: testDefaults
        )
        XCTAssertEqual(wrapper2.wrappedValue, .third, "Should load stored value")
    }
    
    func testIntRawValue_UsesDefaultWhenNotSet() {
        // Given
        enum TestEnum: Int {
            case first = 0
            case second = 1
        }
        
        // When
        let wrapper = PublishedPersisted<TestEnum>(
            key: "notSetYet",
            defaultValue: .second,
            storage: testDefaults
        )
        
        // Then
        XCTAssertEqual(wrapper.wrappedValue, .second, "Should use default value")
    }
    
    func testIntRawValue_PublishesChanges() {
        // Given
        enum TestEnum: Int {
            case first = 0
            case second = 1
        }
        
        let wrapper = PublishedPersisted<TestEnum>(
            key: "testPublishing",
            defaultValue: .first,
            storage: testDefaults
        )
        
        var receivedValues: [TestEnum] = []
        let expectation = expectation(description: "Received published values")
        expectation.expectedFulfillmentCount = 2 // Initial + changed value
        
        // When
        wrapper.projectedValue
            .sink { value in
                receivedValues.append(value)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wrapper.wrappedValue = .second
        
        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedValues.count, 2)
        XCTAssertEqual(receivedValues[0], .first, "Should publish initial value")
        XCTAssertEqual(receivedValues[1], .second, "Should publish changed value")
    }
    
    // MARK: - String RawValue Tests (Existing functionality)
    
    func testStringRawValue_SavesAndLoadsCorrectly() {
        // Given
        enum Direction: String {
            case north, south, east, west
        }
        
        let wrapper = PublishedPersisted<Direction>(
            key: "testDirection",
            defaultValue: .north,
            storage: testDefaults
        )
        
        // When
        wrapper.wrappedValue = .west
        
        // Then
        let stored = testDefaults.string(forKey: "testDirection")
        XCTAssertEqual(stored, "west")
        
        // Reload
        let wrapper2 = PublishedPersisted<Direction>(
            key: "testDirection",
            defaultValue: .north,
            storage: testDefaults
        )
        XCTAssertEqual(wrapper2.wrappedValue, .west)
    }
    
    // MARK: - Plain String Tests
    
    func testPlainString_SavesAndLoadsCorrectly() {
        // Given
        let wrapper = PublishedPersisted<String>(
            key: "testString",
            defaultValue: "default",
            storage: testDefaults
        )
        
        // When
        wrapper.wrappedValue = "updated"
        
        // Then
        let stored = testDefaults.string(forKey: "testString")
        XCTAssertEqual(stored, "updated")
        
        // Reload
        let wrapper2 = PublishedPersisted<String>(
            key: "testString",
            defaultValue: "default",
            storage: testDefaults
        )
        XCTAssertEqual(wrapper2.wrappedValue, "updated")
    }
    
    // MARK: - Plain Int Tests
    
    func testPlainInt_SavesAndLoadsCorrectly() {
        // Given
        let wrapper = PublishedPersisted<Int>(
            key: "testInt",
            defaultValue: 42,
            storage: testDefaults
        )
        
        // When
        wrapper.wrappedValue = 100
        
        // Then
        let stored = testDefaults.integer(forKey: "testInt")
        XCTAssertEqual(stored, 100)
        
        // Reload
        let wrapper2 = PublishedPersisted<Int>(
            key: "testInt",
            defaultValue: 42,
            storage: testDefaults
        )
        XCTAssertEqual(wrapper2.wrappedValue, 100)
    }
    
    // MARK: - Bool Tests
    
    func testBool_SavesAndLoadsCorrectly() {
        // Given
        let wrapper = PublishedPersisted<Bool>(
            key: "testBool",
            defaultValue: false,
            storage: testDefaults
        )
        
        // When
        wrapper.wrappedValue = true
        
        // Then
        let stored = testDefaults.bool(forKey: "testBool")
        XCTAssertTrue(stored)
        
        // Reload
        let wrapper2 = PublishedPersisted<Bool>(
            key: "testBool",
            defaultValue: false,
            storage: testDefaults
        )
        XCTAssertTrue(wrapper2.wrappedValue)
    }
    
    // MARK: - PerformerLayoutType Integration Test
    
    func testPerformerLayoutType_WorksWithIntRawValue() {
        // Given - Test with actual app enum
        let wrapper = PublishedPersisted<PerformerLayoutType>(
            key: "testLayoutType",
            defaultValue: .grid2x,
            storage: testDefaults
        )
        
        // When
        wrapper.wrappedValue = .grid3x
        
        // Then
        XCTAssertEqual(wrapper.wrappedValue, .grid3x)
        
        // Reload and verify persistence
        let wrapper2 = PublishedPersisted<PerformerLayoutType>(
            key: "testLayoutType",
            defaultValue: .grid2x,
            storage: testDefaults
        )
        XCTAssertEqual(wrapper2.wrappedValue, .grid3x, "PerformerLayoutType should persist")
    }
}
