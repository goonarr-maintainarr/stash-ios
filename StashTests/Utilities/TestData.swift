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
