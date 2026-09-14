import Foundation
@testable import Stash



extension Performer {
    static func testPerformer(
        id: String = "test-performer-1",
        name: String = "Test Performer",
        details: String? = "Test performer details",
        scene_count: Int? = 10,
        o_counter: Int? = 5,
        birthdate: String? = "1990-01-01"
    ) -> Performer {
        return Performer(
            id: id,
            name: name,
            disambiguation: nil,
            urls: ["https://example.com"],
            gender: "Female",
            birthdate: birthdate,
            death_date: nil,
            ethnicity: "Caucasian",
            country: "USA",
            eye_color: "Brown",
            hair_color: nil,
            height_cm: 170,
            weight: nil,
            measurements: "34-24-34",
            fake_tits: "No",
            penis_length: nil,
            circumcised: nil,
            career_length: "2020-Present",
            tattoos: "None",
            piercings: "None",
            alias_list: ["Alias 1"],
            favorite: false,
            image_path: "/path/to/image.jpg",
            details: details,
            scene_count: scene_count,
            image_count: 10,
            gallery_count: 5,
            group_count: 2,
            o_counter: o_counter,
            rating100: 85,
            created_at: "2020-01-01",
            updated_at: "2020-01-01",
            stash_ids: [],
            tags: nil
        )
    }
}

extension Scene {
    static func testScene(
        id: String = "scene-1",
        title: String = "Test Scene",
        details: String? = "Test details",
        date: String? = "2024-01-01",
        created_at: String? = "2024-01-01T00:00:00Z",
        updated_at: String? = "2024-01-01T00:00:00Z",
        rating100: Int? = 85,
        o_counter: Int? = 3,
        performers: [Performer]? = [],
        tags: [Tag]? = []
    ) -> Scene {
        return Scene(
            id: id,
            title: title,
            details: details,
            date: date,
            created_at: created_at,
            updated_at: updated_at,
            rating100: rating100,
            o_counter: o_counter,
            resume_time: nil,
            paths: nil,
            files: nil,
            performers: performers,
            tags: tags,
            studio: nil,
            stash_ids: nil,
            scene_markers: nil,
            o_history: nil,
            play_history: nil,
            director: nil,
            code: nil,
            url: nil
        )
    }
}

extension Stats {
    static func testStats(
        scene_count: Int = 100,
        scenes_size: Int64 = 1000000000,
        scenes_duration: Double = 36000,
        scenes_played: Int = 50,
        performer_count: Int = 20,
        studio_count: Int = 10,
        tag_count: Int = 30
    ) -> Stats {
        let json = """
        {
            "scene_count": \(scene_count),
            "scenes_size": \(scenes_size),
            "scenes_duration": \(scenes_duration),
            "image_count": 0,
            "images_size": 0,
            "gallery_count": 0,
            "performer_count": \(performer_count),
            "studio_count": \(studio_count),
            "group_count": 0,
            "movie_count": 0,
            "tag_count": \(tag_count),
            "total_o_count": 10,
            "total_play_duration": 5000,
            "total_play_count": 50,
            "scenes_played": \(scenes_played)
        }
        """
        return try! JSONDecoder().decode(Stats.self, from: json.data(using: .utf8)!)
    }
}

