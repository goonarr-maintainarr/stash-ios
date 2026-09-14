import XCTest
@testable import Stash

final class SceneExtensionsTests: XCTestCase {
    
    func testYear_validDate_returnsYear() {
        let scene = Scene.testScene(date: "2024-05-12")
        XCTAssertEqual(scene.year, 2024)
    }
    
    func testYear_yearOnly_returnsYear() {
        let scene = Scene.testScene(date: "1999")
        XCTAssertEqual(scene.year, 1999)
    }
    
    func testYear_nilDate_returnsNil() {
        let scene = Scene.testScene(date: nil)
        XCTAssertNil(scene.year)
    }
    
    func testYear_invalidDate_returnsNil() {
        let scene = Scene.testScene(date: "unknown-date")
        XCTAssertNil(scene.year)
    }
    
    func testPreview_returnsValidScene() {
        let preview = Scene.preview
        XCTAssertEqual(preview.id, "1")
        XCTAssertEqual(preview.title, "Preview Scene")
        XCTAssertEqual(preview.year, 2023)
    }
}
