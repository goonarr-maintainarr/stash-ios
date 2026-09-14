import Foundation

extension Scene {
    var year: Int? {
        guard let dateString = date else { return nil }
        
        // Handle YYYY-MM-DD
        let components = dateString.split(separator: "-")
        if let first = components.first, let year = Int(first) {
            return year
        }
        
        return nil
    }
}

extension Scene {
    static var preview: Scene {
        Scene(
            id: "1",
            title: "Preview Scene",
            details: "This is a preview scene details",
            date: "2023-01-01",
            rating100: 85,
            o_counter: 5,
            paths: ScenePaths(screenshot: nil, preview: nil, stream: nil, sprite: nil, vtt: nil),
            performers: [Performer(id: "1", name: "Performer Name", image_path: nil)],
            studio: Studio(id: "1", name: "Studio Name", image_path: nil)
        )
    }
}
