import XCTest
import AVKit
@testable import Stash

@MainActor
final class FloatingVideoPlayerServiceTests: XCTestCase {
    
    private var service: FloatingVideoPlayerService!
    
    override func setUp() {
        super.setUp()
        service = FloatingVideoPlayerService.shared
        service.stopPlaying()
    }
    
    override func tearDown() {
        service.stopPlaying()
        super.tearDown()
    }
    
    func testInitialState_afterStopPlaying() {
        service.stopPlaying()
        XCTAssertFalse(service.isPlaying)
        XCTAssertNil(service.currentScene)
        XCTAssertNil(service.currentPlayer)
    }
    
    func testStartPlaying_updatesActiveState() {
        let player = AVPlayer()
        let scene = Scene.testScene(id: "float-1", title: "Floating Test Scene")
        
        service.startPlaying(player: player, scene: scene)
        
        XCTAssertTrue(service.isPlaying)
        XCTAssertEqual(service.currentScene?.id, "float-1")
        XCTAssertNotNil(service.currentPlayer)
    }
    
    func testStopPlaying_cleansUpState() {
        let player = AVPlayer()
        let scene = Scene.testScene(id: "float-2", title: "Floating Scene 2")
        
        service.startPlaying(player: player, scene: scene)
        XCTAssertTrue(service.isPlaying)
        
        service.stopPlaying()
        XCTAssertFalse(service.isPlaying)
        XCTAssertNil(service.currentScene)
        XCTAssertNil(service.currentPlayer)
    }
    
    func testMinimize_setsIsPlayingTrue() {
        service.stopPlaying()
        XCTAssertFalse(service.isPlaying)
        
        service.minimize()
        XCTAssertTrue(service.isPlaying)
    }
}
