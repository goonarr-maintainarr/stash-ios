import XCTest
@testable import Stash

final class PerformerModelTests: XCTestCase {
    
    // MARK: - JSON Decoding Tests
    
    func testDecode_MinimalPerformer_Succeeds() throws {
        let json = """
        {
            "id": "perf-123",
            "name": "Jane Doe",
            "disambiguation": null,
            "gender": "Female",
            "birthdate": "1990-01-15",
            "country": "USA",
            "ethnicity": null,
            "height_cm": 165,
            "weight": 55,
            "measurements": "34-24-36",
            "fake_tits": null,
            "penis_length": null,
            "circumcised": null,
            "tattoos": null,
            "piercings": null,
            "career_length": "2015-",
            "favorite": true,
            "image_path": "/performers/123/image.jpg",
            "details": "A talented performer",
            "scene_count": 50,
            "o_counter": 25,
            "performer_count": null,
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-02T00:00:00Z",
            "rating100": 90,
            "alias_list": ["Jane D", "JD"],
            "stash_ids": null,
            "tags": null,
            "urls": null,
            "eye_color": "Brown",
            "hair_color": "Blonde",
            "group_count": null
        }
        """
        
        let data = json.data(using: .utf8)!
        let performer = try JSONDecoder().decode(Performer.self, from: data)
        
        XCTAssertEqual(performer.id, "perf-123")
        XCTAssertEqual(performer.name, "Jane Doe")
        XCTAssertEqual(performer.gender, "Female")
        XCTAssertEqual(performer.birthdate, "1990-01-15")
        XCTAssertEqual(performer.height_cm, 165)
        XCTAssertEqual(performer.weight, 55)
        XCTAssertEqual(performer.scene_count, 50)
        XCTAssertEqual(performer.o_counter, 25)
        XCTAssertEqual(performer.rating100, 90)
        XCTAssertEqual(performer.alias_list, ["Jane D", "JD"])
    }
    
    func testDecode_WithStashIds_Succeeds() throws {
        let json = """
        {
            "id": "perf-456",
            "name": "Actor Name",
            "disambiguation": null,
            "gender": "Male",
            "birthdate": null,
            "country": null,
            "ethnicity": null,
            "height_cm": null,
            "weight": null,
            "measurements": null,
            "fake_tits": null,
            "penis_length": null,
            "circumcised": null,
            "tattoos": null,
            "piercings": null,
            "career_length": null,
            "favorite": false,
            "image_path": null,
            "details": null,
            "scene_count": null,
            "o_counter": null,
            "performer_count": null,
            "created_at": null,
            "updated_at": null,
            "rating100": null,
            "alias_list": null,
            "stash_ids": [
                {
                    "stash_id": "stash-perf-123",
                    "endpoint": "https://stashdb.org/graphql"
                }
            ],
            "tags": null,
            "urls": null,
            "eye_color": null,
            "hair_color": null,
            "group_count": null
        }
        """
        
        let data = json.data(using: .utf8)!
        let performer = try JSONDecoder().decode(Performer.self, from: data)
        
        XCTAssertEqual(performer.stash_ids?.count, 1)
        XCTAssertEqual(performer.stash_ids?.first?.stash_id, "stash-perf-123")
    }
    
    // MARK: - Test Helper Tests
    
    func testTestPerformer_CreatesValidPerformer() {
        let performer = Performer.testPerformer(id: "test-id", name: "Test Name")
        
        XCTAssertEqual(performer.id, "test-id")
        XCTAssertEqual(performer.name, "Test Name")
    }
    
    // MARK: - Age Calculation Tests
    
    func testAge_ReturnsCorrectAge() {
        // Create a performer with a birthdate 30 years ago
        let calendar = Calendar.current
        let thirtyYearsAgo = calendar.date(byAdding: .year, value: -30, to: Date())!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let birthdateString = dateFormatter.string(from: thirtyYearsAgo)
        
        let performer = Performer.testPerformer(id: "age-test", name: "Test", birthdate: birthdateString)
        
        XCTAssertEqual(performer.age, 30)
    }
    
    func testAge_ReturnsNil_WhenNoBirthdate() {
        let performer = Performer.testPerformer(id: "no-birthdate", name: "Test", birthdate: nil)
        
        XCTAssertNil(performer.age)
    }
    
    // MARK: - Equatable Tests
    
    func testEquality_SameId_AreEqual() {
        let performer1 = Performer.testPerformer(id: "same-id", name: "Name 1")
        let performer2 = Performer.testPerformer(id: "same-id", name: "Name 1")
        
        XCTAssertEqual(performer1, performer2)
    }
    
    func testEquality_DifferentId_AreNotEqual() {
        let performer1 = Performer.testPerformer(id: "id-1", name: "Same Name")
        let performer2 = Performer.testPerformer(id: "id-2", name: "Same Name")
        
        XCTAssertNotEqual(performer1, performer2)
    }
}
