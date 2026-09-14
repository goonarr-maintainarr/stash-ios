import XCTest
@testable import Stash

final class VTTParserTests: XCTestCase {
    
    func testParse_validVTT_createsSpriteFrames() {
        let vtt = """
        WEBVTT
        
        00:00:00.000 --> 00:00:05.000
        /scene/123_sprite.jpg#xywh=0,0,160,90
        
        00:00:05.000 --> 00:00:10.000
        /scene/123_sprite.jpg#xywh=160,0,160,90
        """
        
        let frames = VTTParser.parse(vtt)
        XCTAssertEqual(frames.count, 2)
        
        let first = frames[0]
        XCTAssertEqual(first.startTime, 0.0)
        XCTAssertEqual(first.endTime, 5.0)
        XCTAssertEqual(first.x, 0.0)
        XCTAssertEqual(first.y, 0.0)
        XCTAssertEqual(first.width, 160.0)
        XCTAssertEqual(first.height, 90.0)
        
        let second = frames[1]
        XCTAssertEqual(second.startTime, 5.0)
        XCTAssertEqual(second.endTime, 10.0)
        XCTAssertEqual(second.x, 160.0)
        XCTAssertEqual(second.y, 0.0)
        XCTAssertEqual(second.width, 160.0)
        XCTAssertEqual(second.height, 90.0)
    }
    
    func testParse_twoComponentTimestamp() {
        let vtt = """
        WEBVTT
        
        01:30.500 --> 02:00.000
        /scene/sprite.jpg#xywh=320,180,160,90
        """
        
        let frames = VTTParser.parse(vtt)
        XCTAssertEqual(frames.count, 1)
        
        let frame = frames[0]
        XCTAssertEqual(frame.startTime, 90.5) // 1 min + 30.5s
        XCTAssertEqual(frame.endTime, 120.0)  // 2 min
        XCTAssertEqual(frame.x, 320.0)
        XCTAssertEqual(frame.y, 180.0)
    }
    
    func testParse_emptyContent_returnsEmptyArray() {
        let frames = VTTParser.parse("")
        XCTAssertTrue(frames.isEmpty)
    }
    
    func testParse_headerOnly_returnsEmptyArray() {
        let vtt = """
        WEBVTT
        
        """
        let frames = VTTParser.parse(vtt)
        XCTAssertTrue(frames.isEmpty)
    }
    
    func testParse_malformedCoordinates_skipsFrame() {
        let vtt = """
        WEBVTT
        
        00:00:00.000 --> 00:00:05.000
        /scene/sprite.jpg#xywh=0,0,160
        """
        let frames = VTTParser.parse(vtt)
        XCTAssertTrue(frames.isEmpty)
    }
}
