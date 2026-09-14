import Foundation

/// Represents a single frame in a sprite sheet with timing and coordinates.
struct SpriteFrame {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

/// Parses WebVTT files for sprite sheet thumbnails.
///
/// Stash generates VTT files that map timestamps to coordinates in a sprite sheet image.
/// Format example:
/// ```
/// WEBVTT
///
/// 00:00:00.000 --> 00:00:10.000
/// /scene/123_sprite.jpg#xywh=0,0,160,90
/// ```
enum VTTParser {
    
    /// Parse VTT content into sprite frames.
    /// - Parameter vttContent: The raw VTT file content
    /// - Returns: Array of SpriteFrame with timing and coordinate data
    static func parse(_ vttContent: String) -> [SpriteFrame] {
        var frames: [SpriteFrame] = []
        frames.reserveCapacity(100) // Pre-allocate for typical sprite sheet
        
        var currentStartTime: TimeInterval?
        var currentEndTime: TimeInterval?
        
        // Use lazy iteration to avoid allocating full line array
        vttContent.enumerateLines { line, _ in
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and WEBVTT header
            guard !trimmedLine.isEmpty && !trimmedLine.hasPrefix("WEBVTT") else {
                return
            }
            
            // Parse timestamp line: "00:00:10.000 --> 00:00:20.000"
            if trimmedLine.contains("-->") {
                let times = trimmedLine.components(separatedBy: " --> ")
                if times.count == 2 {
                    currentStartTime = parseTimestamp(times[0])
                    currentEndTime = parseTimestamp(times[1])
                }
            }
            // Parse coordinate line: "/scene/123_sprite.jpg#xywh=160,0,160,90"
            else if trimmedLine.contains("#xywh="),
                    let start = currentStartTime,
                    let end = currentEndTime {
                if let coords = parseCoordinates(trimmedLine) {
                    frames.append(SpriteFrame(
                        startTime: start,
                        endTime: end,
                        x: coords.x,
                        y: coords.y,
                        width: coords.width,
                        height: coords.height
                    ))
                }
                currentStartTime = nil
                currentEndTime = nil
            }
        }
        
        return frames
    }
    
    /// Parse timestamp string to TimeInterval.
    /// - Parameter timestamp: Format "00:00:10.000" or "00:10.000"
    private static func parseTimestamp(_ timestamp: String) -> TimeInterval? {
        let cleaned = timestamp.trimmingCharacters(in: .whitespaces)
        let components = cleaned.components(separatedBy: ":")
        
        guard components.count >= 2 else { return nil }
        
        if components.count == 3 {
            // HH:MM:SS.mmm format
            let hours = Double(components[0]) ?? 0
            let minutes = Double(components[1]) ?? 0
            let seconds = Double(components[2]) ?? 0
            return hours * 3600 + minutes * 60 + seconds
        } else {
            // MM:SS.mmm format
            let minutes = Double(components[0]) ?? 0
            let seconds = Double(components[1]) ?? 0
            return minutes * 60 + seconds
        }
    }
    
    /// Parse xywh coordinate string.
    /// - Parameter line: Line containing "#xywh=x,y,w,h"
    private static func parseCoordinates(_ line: String) -> (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)? {
        guard let xywh = line.components(separatedBy: "#xywh=").last else { return nil }
        let values = xywh.components(separatedBy: ",").compactMap { CGFloat(Double($0) ?? 0) }
        
        guard values.count == 4 else { return nil }
        return (x: values[0], y: values[1], width: values[2], height: values[3])
    }
}
