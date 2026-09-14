import XCTest
import SwiftUI
@testable import Stash

class PerformerMetadataRowTests: XCTestCase {
    
    // MARK: - shouldShowCountry Computation Tests
    
    func testShouldShowCountry_Grid3x_HidesCountry() {
        // Given
        let row = PerformerMetadataRow(
            name: "Test Performer",
            age: 25,
            sceneCount: 10,
            oCount: 5,
            country: "USA",
            style: .card,
            layoutType: .grid3x
        )
        
        // Then
        XCTAssertFalse(row.shouldShowCountry, "Grid3x should hide country")
    }
    
    func testShouldShowCountry_Grid2x_HidesCountry() {
        // Given
        let row = PerformerMetadataRow(
            name: "Test Performer",
            age: 25,
            sceneCount: 10,
            oCount: 5,
            country: "USA",
            style: .card,
            layoutType: .grid2x
        )
        
        // Then
        XCTAssertFalse(row.shouldShowCountry, "Grid2x should hide country")
    }
    
    func testShouldShowCountry_List_ShowsCountry() {
        // Given
        let row = PerformerMetadataRow(
            name: "Test Performer",
            age: 25,
            sceneCount: 10,
            oCount: 5,
            country: "USA",
            style: .card,
            layoutType: .list
        )
        
        // Then
        XCTAssertTrue(row.shouldShowCountry, "List layout should show country")
    }
    
    func testShouldShowCountry_StyleOverrides() {
        // Given - Style says no country
        let style = PerformerMetadataStyle(
            nameFont: .title,
            nameLineLimit: nil,
            iconFont: .caption,
            statFont: .subheadline,
            showCountry: false
        )
        
        let row = PerformerMetadataRow(
            name: "Test Performer",
            age: 25,
            sceneCount: 10,
            oCount: 5,
            country: "USA",
            style: style,
            layoutType: .list  // Even though list normally shows country
        )
        
        // Then
        XCTAssertFalse(row.shouldShowCountry, "Style.showCountry should override layout")
    }
    
    func testShouldShowCountry_NoLayoutType_UsesStyleDefault() {
        // Given
        let row = PerformerMetadataRow(
            name: "Test Performer",
            age: 25,
            sceneCount: 10,
            oCount: 5,
            country: "USA",
            style: .card,  // card style has showCountry: true
            layoutType: nil
        )
        
        // Then
        XCTAssertTrue(row.shouldShowCountry, "No layout type should use style default")
    }
    
    // MARK: - Performer Initializer Tests
    
    func testPerformerInitializer_ComputesShouldShowCountry() {
        // Given
        let performer = Performer(
            id: "1",
            name: "Test Performer",
            disambiguation: nil,
            urls: [],
            gender: "Female",
            birthdate: "2000-01-01",
            death_date: nil,
            ethnicity: nil,
            country: "USA",
            eye_color: nil,
            hair_color: nil,
            height_cm: nil,
            weight: nil,
            measurements: nil,
            fake_tits: nil,
            penis_length: nil,
            circumcised: nil,
            career_length: nil,
            tattoos: nil,
            piercings: nil,
            alias_list: [],
            favorite: false,
            image_path: nil,
            details: nil,
            scene_count: 10,
            image_count: 0,
            gallery_count: 0,
            group_count: 0,
            o_counter: 5,
            rating100: nil,
            created_at: "2023-01-01",
            updated_at: "2023-01-01",
            stash_ids: [],
            tags: []
        )
        
        // When
        let row = PerformerMetadataRow(
            performer: performer,
            style: .card,
            layoutType: .grid3x
        )
        
        // Then
        XCTAssertEqual(row.name, "Test Performer")
        XCTAssertEqual(row.sceneCount, 10)
        XCTAssertEqual(row.oCount, 5)
        XCTAssertEqual(row.country, "USA")
        XCTAssertFalse(row.shouldShowCountry, "Grid3x should hide country")
    }
    
    // MARK: - Property Storage Tests
    
    func testProperties_StoredCorrectly() {
        // Given/When
        let row = PerformerMetadataRow(
            name: "Jane Doe",
            age: 30,
            sceneCount: 50,
            oCount: 15,
            country: "Canada",
            style: .list,
            layoutType: .list
        )
        
        // Then
        XCTAssertEqual(row.name, "Jane Doe")
        XCTAssertEqual(row.age, 30)
        XCTAssertEqual(row.sceneCount, 50)
        XCTAssertEqual(row.oCount, 15)
        XCTAssertEqual(row.country, "Canada")
        XCTAssertEqual(row.layoutType, .list)
    }
    
    func testNilProperties_HandledCorrectly() {
        // Given/When
        let row = PerformerMetadataRow(
            name: "Test",
            age: nil,
            sceneCount: nil,
            oCount: nil,
            country: nil,
            style: .card,
            layoutType: .grid2x
        )
        
        // Then
        XCTAssertNil(row.age)
        XCTAssertNil(row.sceneCount)
        XCTAssertNil(row.oCount)
        XCTAssertNil(row.country)
    }
    
    // MARK: - Style Tests
    
    func testCardStyle_HasCorrectDefaults() {
        // Given
        let style = PerformerMetadataStyle.card
        
        // Then
        XCTAssertEqual(style.nameLineLimit, 2)
        XCTAssertTrue(style.showCountry)
    }
    
    func testListStyle_HasCorrectDefaults() {
        // Given
        let style = PerformerMetadataStyle.list
        
        // Then
        XCTAssertNil(style.nameLineLimit)
        XCTAssertFalse(style.showCountry)
    }
    
    // MARK: - Layout Integration Tests
    
    func testAllLayoutTypes_ProduceConsistentResults() {
        // Given
        let layouts: [PerformerLayoutType] = [.grid3x, .grid2x, .list]
        
        for layout in layouts {
            // When
            let row = PerformerMetadataRow(
                name: "Test",
                age: 25,
                sceneCount: 10,
                oCount: 5,
                country: "USA",
                style: .card,
                layoutType: layout
            )
            
            // Then
            XCTAssertEqual(row.layoutType, layout)
            
            // Verify shouldShowCountry logic
            switch layout {
            case .grid3x, .grid2x:
                XCTAssertFalse(row.shouldShowCountry, "\(layout) should hide country")
            case .list:
                XCTAssertTrue(row.shouldShowCountry, "\(layout) should show country")
            }
        }
    }
}
