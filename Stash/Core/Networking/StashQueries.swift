import Foundation

/// Centralized GraphQL queries and fragments for the Stash server.
/// All queries target the local Stash instance's GraphQL API.
struct StashQueries {
    
    // MARK: - Common Fragments
    
    static let sceneFields = """
        id
        title
        date
        details
        created_at
        updated_at
        rating100
        o_counter
        o_history
        play_history
        resume_time
        studio {
            id
            name
            image_path
        }
        stash_ids {
            stash_id
            endpoint
        }
        director
        code
        url
        urls
        tags {
            id
            name
        }
    """
    
    static let scenePathsFields = """
        paths {
            screenshot
            preview
            stream
            sprite
            vtt
        }
    """
    
    static let sceneFilesFields = """
        files {
            path
            size
            duration
            video_codec
            audio_codec
            width
            height
        }
    """
    
    static let performerFields = """
        id
        name
        created_at
        updated_at
        image_path
        birthdate
        death_date
        country
        scene_count
        o_counter
    """
    
    static let performerDetailFields = """
        id
        name
        disambiguation
        urls
        gender
        birthdate
        ethnicity
        country
        eye_color
        height_cm
        measurements
        fake_tits
        penis_length
        circumcised
        career_length
        tattoos
        piercings
        alias_list
        favorite
        tags {
            id
            name
        }
        image_path
        scene_count
        image_count
        gallery_count
        group_count
        o_counter
        rating100
        details
        death_date
        hair_color
        weight
        created_at
        updated_at
        stash_ids {
            stash_id
            endpoint
        }
    """
    
    static let tagFields = """
        id
        name
        scene_count
        description
    """
    
    static let sceneMarkerFields = """
        id
        title
        seconds
        stream
        preview
    """
    
    // MARK: - Scene Queries
    
    static func findScenes(searchText: String, page: Int, perPage: Int = 20, sort: String, direction: String = "DESC", randomize: Bool = false) -> String {
        let operationName = randomize ? "FindScenes_\(Int(Date().timeIntervalSince1970))" : "FindScenes"
        
        return """
        query \(operationName) {
            findScenes(filter: { q: "\(searchText)", per_page: \(perPage), page: \(page), sort: "\(sort)", direction: \(direction) }) {
                scenes {
                    \(sceneFields)
                    \(scenePathsFields)
                    \(sceneFilesFields)
                    performers {
                        \(performerFields)
                    }
                    tags {
                        \(tagFields)
                    }
                    scene_markers {
                        \(sceneMarkerFields)
                    }
                }
                count
            }
        }
        """
    }

    static func sceneStreams(id: String) -> String {
        return """
        query SceneStreams {
            sceneStreams(id: "\(id)") {
                url
                label
                mime_type
            }
        }
        """
    }

    /// Find scenes with minimal data for list display and fast sync.
    static func findScenesListCore(searchText: String = "", page: Int, perPage: Int, sort: String = "created_at", direction: String = "DESC") -> String {
        return """
        query FindScenesListCore {
            findScenes(filter: { q: "\(searchText)", per_page: \(perPage), page: \(page), sort: "\(sort)", direction: \(direction) }) {
                scenes {
                    \(sceneFields)
                    \(scenePathsFields)
                    \(sceneFilesFields)
                    performers {
                        \(performerFields)
                    }
                    scene_markers {
                        id
                        title
                        seconds
                    }
                }
                count
            }
        }
        """
    }
    
    static func findScenesUpdatedSince(timestamp: String, page: Int = 1, perPage: Int = 100) -> String {
        return """
        query FindScenesUpdatedSince {
            findScenes(
                filter: { per_page: \(perPage), page: \(page), sort: "updated_at", direction: DESC }
                scene_filter: { updated_at: { modifier: GREATER_THAN, value: "\(timestamp)" } }
            ) {
                scenes {
                    \(sceneFields)
                    \(scenePathsFields)
                    \(sceneFilesFields)
                    performers {
                        \(performerFields)
                    }
                    tags {
                        \(tagFields)
                    }
                    scene_markers {
                        \(sceneMarkerFields)
                    }
                }
                count
            }
        }
        """
    }
    
    static func findSceneTimestamps(page: Int, perPage: Int) -> String {
        return """
        query FindScenes($page: Int!, $perPage: Int!) {
            findScenes(
                scene_filter: {}
                filter: { page: $page, per_page: $perPage }
            ) {
                count
                scenes {
                    id
                    updated_at
                }
            }
        }
        """
    }
    
    static func findScene(id: String) -> String {
        return """
        query FindScene {
            findScene(id: "\(id)") {
                \(sceneFields)
                \(sceneFields)
                \(scenePathsFields)
                \(scenePathsFields)
                \(sceneFilesFields)
                performers {
                    \(performerFields)
                }
                tags {
                    \(tagFields)
                }
                scene_markers {
                    \(sceneMarkerFields)
                }
            }
        }
        """
    }
    
    static func findScenesBatch(ids: [String]) -> String {
        let sceneDetailFields = """
            \(sceneFields)
            details
            \(scenePathsFields)
            \(sceneFilesFields)
            performers {
                \(performerFields)
            }
            tags {
                \(tagFields)
            }
            scene_markers {
                \(sceneMarkerFields)
            }
        """
        
        let queries = ids.enumerated().map { index, id in
            "scene\(index): findScene(id: \"\(id)\") { \(sceneDetailFields) }"
        }.joined(separator: "\n            ")
        
        return """
        query BatchFindScenes {
            \(queries)
        }
        """
    }
    
    static func findPerformerScenes(performerId: String, page: Int, perPage: Int = 100) -> String {
        return """
        query FindPerformerScenes {
            findScenes(scene_filter: { performers: { value: ["\(performerId)"], modifier: INCLUDES_ALL } }, filter: { per_page: \(perPage), page: \(page), sort: "date", direction: DESC }) {
                scenes {
                    \(sceneFields)
                    \(scenePathsFields)
                    \(sceneFilesFields)
                    performers {
                        \(performerFields)
                    }
                    tags {
                        \(tagFields)
                    }
                    scene_markers {
                        \(sceneMarkerFields)
                    }
                }
                count
            }
        }
        """
    }
    
    static func findStudioScenes(studioId: String, page: Int, perPage: Int = 40) -> String {
        return """
        query FindStudioScenes {
            findScenes(scene_filter: { studios: { value: ["\(studioId)"], modifier: INCLUDES_ALL } }, filter: { per_page: \(perPage), page: \(page), sort: "date", direction: DESC }) {
                scenes {
                    \(sceneFields)
                    \(sceneFields)
                    \(scenePathsFields)
                    \(scenePathsFields)
                    \(sceneFilesFields)
                    performers {
                        \(performerFields)
                    }
                    tags {
                        \(tagFields)
                    }
                    scene_markers {
                        \(sceneMarkerFields)
                    }
                }
                count
            }
        }
        """
    }
    
    static func findStudioScenePerformerIDs(studioId: String) -> String {
        return """
        query FindStudioScenePerformerIDs {
            findScenes(
                scene_filter: { studios: { value: ["\(studioId)"], modifier: INCLUDES_ALL } },
                filter: { per_page: -1 }
            ) {
                scenes {
                    performers {
                        id
                    }
                }
            }
        }
        """
    }
    
    static func findPerformersByIds(ids: [String], page: Int, perPage: Int = 40, sort: String = "name", direction: String = "ASC") -> String {
        let idsString = ids.map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        query FindPerformersByIds {
            findPerformers(
                ids: [\(idsString)],
                filter: { per_page: \(perPage), page: \(page), sort: "\(sort)", direction: \(direction) }
            ) {
                performers {
                    \(performerFields)
                    scene_count
                }
                count
            }
        }
        """
    }
    
    // Kept for reference or direct usage if needed
    static func findStudioPerformers(studioId: String, page: Int, perPage: Int = 40) -> String {
        return """
        query FindStudioPerformers {
            findPerformers(performer_filter: { studios: { value: ["\(studioId)"], modifier: INCLUDES_ALL } }, filter: { per_page: \(perPage), page: \(page), sort: "name", direction: ASC }) {
                performers {
                    \(performerFields)
                    scene_count
                }
                count
            }
        }
        """
    }
    
    static func findScenesByTag(tagIds: [String], page: Int, perPage: Int = 20, sort: String, direction: String = "DESC") -> String {
        let tagIdsString = tagIds.map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        query FindScenesByTag {
            findScenes(scene_filter: { tags: { value: [\(tagIdsString)], modifier: INCLUDES_ALL } }, filter: { per_page: \(perPage), page: \(page), sort: "\(sort)", direction: \(direction) }) {
                scenes {
                    \(sceneFields)
                    \(scenePathsFields)
                    \(sceneFilesFields)
                    performers {
                        \(performerFields)
                    }
                    tags {
                        \(tagFields)
                    }
                    scene_markers {
                        \(sceneMarkerFields)
                    }
                }
                count
            }
        }
        """
    }
    
    static func findPerformers(searchText: String, page: Int, perPage: Int = 20, sort: String, direction: String = "DESC") -> String {
        return """
        query FindPerformers {
            findPerformers(filter: { q: "\(searchText)", per_page: \(perPage), page: \(page), sort: "\(sort)", direction: \(direction) }) {
                performers {
                    \(performerFields)
                    scene_count
                    o_counter
                }
                count
            }
        }
        """
    }
    
    static func findPerformersUpdatedSince(timestamp: String, page: Int = 1, perPage: Int = 100) -> String {
        return """
        query FindPerformersUpdatedSince {
            findPerformers(
                filter: { per_page: \(perPage), page: \(page), sort: "updated_at", direction: DESC }
                performer_filter: { updated_at: { modifier: GREATER_THAN, value: "\(timestamp)" } }
            ) {
                performers {
                    \(performerDetailFields)
                }
                count
            }
        }
        """
    }
    
    static func findPerformerTimestamps(page: Int, perPage: Int) -> String {
        return """
        query FindPerformers($page: Int!, $perPage: Int!) {
            findPerformers(
                performer_filter: {}
                filter: { page: $page, per_page: $perPage }
            ) {
                count
                performers {
                    id
                    updated_at
                }
            }
        }
        """
    }
    
    static func findPerformer(id: String) -> String {
        return """
        query FindPerformer {
            findPerformer(id: "\(id)") {
                \(performerDetailFields)
            }
        }
        """
    }
    
    static func findPerformersBatch(ids: [String]) -> String {
        let queries = ids.enumerated().map { index, id in
            "performer\(index): findPerformer(id: \"\(id)\") { \(performerDetailFields) }"
        }.joined(separator: "\n            ")
        
        return """
        query BatchFindPerformers {
            \(queries)
        }
        """
    }
    
    // MARK: - Tag Queries
    
    static func findTags(searchText: String, page: Int = 1, perPage: Int = 100) -> String {
        return """
        query FindTags {
            findTags(filter: { q: "\(searchText)", per_page: \(perPage), page: \(page) }) {
                tags {
                    \(tagFields)
                }
                count
            }
        }
        """
    }
    
    static func findTag(id: String) -> String {
        return """
        query FindTag {
            findTag(id: "\(id)") {
                \(tagFields)
            }
        }
        """
    }
    
    // MARK: - Job Queue
    
    static let jobQueue = """
        query JobQueue {
            jobQueue {
                id
                addTime
                description
                status
                progress
                startTime
                endTime
            }
        }
        """
    
    static let logs = """
        query Logs {
            logs {
                time
                level
                message
            }
        }
        """
    
    static let testConnection = """
        query TestConnection {
            findScenes(filter: { per_page: 1 }) {
                scenes {
                    id
                }
                count
            }
        }
        """
    
    static let me = """
        query Me {
            me {
                id
                name
            }
        }
        """
    
    // MARK: - Mutations
    
    static func sceneIncrementO(id: String) -> String {
        return """
        mutation SceneIncrementO {
            sceneIncrementO(id: "\(id)")
        }
        """
    }
    
    static func sceneUpdate(id: String, rating100: Int?) -> String {
        let ratingValue = rating100.map { String($0) } ?? "null"
        return """
        mutation SceneUpdate {
            sceneUpdate(input: { id: "\(id)", rating100: \(ratingValue) }) {
                id
                rating100
            }
        }
        """
    }
    
    static func sceneUpdateTitle(id: String, title: String) -> String {
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
        return """
        mutation SceneUpdateTitle {
            sceneUpdate(input: { id: "\(id)", title: "\(escapedTitle)" }) {
                id
                title
            }
        }
        """
    }
    
    static func sceneUpdateDetails(
        id: String,
        title: String?,
        details: String?,
        performerIds: [String]?,
        tagIds: [String]?,
        coverImage: String?,
        director: String? = nil,
        code: String? = nil,
        url: String? = nil,
        studioId: String? = nil,
        organized: Bool? = nil
    ) -> String {
        var inputs: [String] = []
        inputs.append("id: \"\(id)\"")
        
        if let title = title {
            let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
            inputs.append("title: \"\(escapedTitle)\"")
        }
        
        if let details = details {
            // Escape quotes and newlines in details
            let escapedDetails = details.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
            inputs.append("details: \"\(escapedDetails)\"")
        }
        
        if let performerIds = performerIds {
            let idsString = performerIds.map { "\"\($0)\"" }.joined(separator: ", ")
            inputs.append("performer_ids: [\(idsString)]")
        }
        
        if let tagIds = tagIds {
            let idsString = tagIds.map { "\"\($0)\"" }.joined(separator: ", ")
            inputs.append("tag_ids: [\(idsString)]")
        }
        
        if let coverImage = coverImage {
            inputs.append("cover_image: \"\(coverImage)\"")
        }

        if let director = director {
            let escaped = director.replacingOccurrences(of: "\"", with: "\\\"")
            inputs.append("director: \"\(escaped)\"")
        }
        
        if let code = code {
            let escaped = code.replacingOccurrences(of: "\"", with: "\\\"")
            inputs.append("code: \"\(escaped)\"")
        }
        
        if let url = url {
            let escaped = url.replacingOccurrences(of: "\"", with: "\\\"")
            inputs.append("url: \"\(escaped)\"")
        }
        
        if let studioId = studioId {
            inputs.append("studio_id: \"\(studioId)\"")
        }
        
        if let organized = organized {
            inputs.append("organized: \(organized)")
        }
        
        return """
        mutation SceneUpdateDetails {
            sceneUpdate(input: { \(inputs.joined(separator: ", ")) }) {
                \(sceneFields)
                details
                \(scenePathsFields)
                \(sceneFilesFields)
                performers {
                    \(performerFields)
                }
                tags {
                    \(tagFields)
                }
                scene_markers {
                    \(sceneMarkerFields)
                }
                o_history
                play_history
            }
        }
        """
    }
    
    static func sceneDeleteO(sceneId: String, times: [String]) -> String {
        let timesString = times.map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        mutation SceneDeleteO {
            sceneDeleteO(id: "\(sceneId)", times: [\(timesString)]) {
                count
                history
            }
        }
        """
    }
    
    static func sceneDeletePlay(sceneId: String, times: [String]) -> String {
        let timesString = times.map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        mutation SceneDeletePlay {
            sceneDeletePlay(id: "\(sceneId)", times: [\(timesString)]) {
                count
                history
            }
        }
        """
    }
    
    static func sceneDestroy(id: String, deleteFile: Bool, deleteGenerated: Bool) -> String {
        return """
        mutation SceneDestroy {
            sceneDestroy(input: { id: "\(id)", delete_file: \(deleteFile), delete_generated: \(deleteGenerated) })
        }
        """
    }
    
    static func sceneSaveActivity(id: String, resumeTime: Double?, playDuration: Double?) -> String {
        var args: [String] = []
        args.append("id: \"\(id)\"")
        
        if let resumeTime = resumeTime {
            args.append("resume_time: \(resumeTime)")
        }
        
        if let playDuration = playDuration {
            args.append("playDuration: \(playDuration)")
        }
        
        return """
        mutation SaveSceneActivity {
            sceneSaveActivity(\(args.joined(separator: ", ")))
        }
        """
    }
    
    static func sceneIncrementPlayCount(id: String) -> String {
        return """
        mutation IncrementPlayCount {
            sceneIncrementPlayCount(id: "\(id)")
        }
        """
    }
    
    static let performerUpdate = """
    mutation PerformerUpdate($input: PerformerUpdateInput!) {
        performerUpdate(input: $input) {
            \(performerFields)
            scene_count
            image_path
            o_counter
        }
    }
    """
    
    
    static func performerDestroy(id: String) -> String {
        return """
        mutation PerformerDestroy {
            performerDestroy(input: { id: "\(id)" })
        }
        """
    }
    
    static func tagDestroy(id: String) -> String {
        return """
        mutation TagDestroy {
            tagDestroy(input: { id: "\(id)" })
        }
        """
    }
    
    static func tagsDestroy(ids: [String]) -> String {
        let idsString = ids.map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        mutation TagsDestroy {
            tagsDestroy(ids: [\(idsString)])
        }
        """
    }
    
    static func metadataGenerate(options: GenerationOptions) -> String {
        return """
        mutation MetadataGenerate {
            metadataGenerate(input: {
                covers: \(options.covers)
                sprites: \(options.sprites)
                previews: \(options.previews)
                imagePreviews: \(options.imagePreviews)
                markers: \(options.markers)
                markerImagePreviews: \(options.markerImagePreviews)
                markerScreenshots: \(options.markerScreenshots)
                transcodes: \(options.transcodes)
                forceTranscodes: \(options.forceTranscodes)
                phashes: \(options.phashes)
                interactiveHeatmapsSpeeds: \(options.interactiveHeatmapsSpeeds)
                imageThumbnails: \(options.imageThumbnails)
                clipPreviews: \(options.clipPreviews)
                overwrite: \(options.overwrite)
            })
        }
        """
    }
    
    static func metadataScan(options: ScanOptions) -> String {
        return """
        mutation StartScan {
            metadataScan(input: {
                paths: \(options.pathsArray)
                rescan: \(options.rescan)
                scanGenerateCovers: \(options.scanGenerateCovers)
                scanGeneratePreviews: \(options.scanGeneratePreviews)
                scanGenerateImagePreviews: \(options.scanGenerateImagePreviews)
                scanGenerateSprites: \(options.scanGenerateSprites)
                scanGeneratePhashes: \(options.scanGeneratePhashes)
                scanGenerateThumbnails: \(options.scanGenerateThumbnails)
                scanGenerateClipPreviews: \(options.scanGenerateClipPreviews)
            })
        }
        """
    }
    // MARK: - Configuration & Scraping
    
    static let configuration = """
        query Configuration {
            configuration {
                general {
                    stashBoxes {
                        name
                        endpoint
                        api_key
                    }
                }
            }
        }
        """

    static let taggerConfig = """
        query TaggerConfig {
            configuration {
                ui
            }
        }
        """

    static let configureTaggerConfig = """
        mutation ConfigureTaggerConfig($config: Any!) {
            configureUISetting(key: "taggerConfig", value: $config)
        }
        """

    
    static func searchPerformer(term: String) -> String {
        let escapedTerm = term.replacingOccurrences(of: "\"", with: "\\\"")
        return """
        query SearchPerformer {
            searchPerformer(term: "\(escapedTerm)") {
                images {
                    id
                    url
                    width
                    height
                }
                career_start_year
                name
                age
                birth_date
                ethnicity
                country
                eye_color
                hair_color
                height
                measurements {
                    cup_size
                    band_size
                    waist
                    hip
                }
                cup_size
                band_size
                waist_size
                hip_size
                breast_type
                career_end_year
                tattoos {
                    location
                    description
                }
                piercings {
                    location
                    description
                }
                scene_count
            }
        }
        """
    }
    
    static func tagCreate(name: String) -> String {
        let escapedName = name.replacingOccurrences(of: "\"", with: "\\\"")
        return """
        mutation TagCreate {
            tagCreate(input: { name: "\(escapedName)" }) {
                id
                name
            }
        }
        """
    }
    
    static func performerCreate(
        name: String,
        image: String? = nil,
        details: String? = nil,
        gender: String? = nil,
        birth_date: String? = nil,
        ethnicity: String? = nil,
        country: String? = nil,
        eye_color: String? = nil,
        hair_color: String? = nil,
        height: Int? = nil,
        measurements: String? = nil,
        fake_tits: String? = nil,
        career_length: String? = nil,
        tattoos: String? = nil,
        piercings: String? = nil
    ) -> String {
        var inputs: [String] = []
        inputs.append("name: \"\(name)\"")
        
        if let image = image {
            inputs.append("image: \"\(image)\"")
        }
        
        if let details = details {
             let escapedDetails = details.replacingOccurrences(of: "\"", with: "\\\"")
             inputs.append("details: \"\(escapedDetails)\"")
        }
        
        if let gender = gender, !gender.isEmpty {
             // Basic sanitation for Enum: Uppercase and replace spaces with underscores
             let sanitized = gender.uppercased().replacingOccurrences(of: " ", with: "_").trimmingCharacters(in: .whitespacesAndNewlines)
             // If result is empty or invalid chars, maybe omit? 
             // Stash Enums: MALE, FEMALE, TRANSGENDER_MALE, TRANSGENDER_FEMALE, INTERSEX, NON_BINARY
             // If sanitized matches known enums, append. Else, risky.
             // We'll trust the sanitized string is close enough or use it.
             // But if it contains "<" or ">", ignore it.
             if !sanitized.contains("<") && !sanitized.contains(">") {
                 inputs.append("gender: \(sanitized)")
             }
        }

        if let birth_date = birth_date { inputs.append("birthdate: \"\(birth_date)\"") } 
        if let ethnicity = ethnicity { inputs.append("ethnicity: \"\(ethnicity)\"") } 
        if let country = country { inputs.append("country: \"\(country)\"") } 
        if let eye_color = eye_color { inputs.append("eye_color: \"\(eye_color)\"") } 
        if let hair_color = hair_color { inputs.append("hair_color: \"\(hair_color)\"") } 
        if let height = height { inputs.append("height_cm: \(height)") } 
        if let measurements = measurements { inputs.append("measurements: \"\(measurements)\"") }
        
        if let fake_tits = fake_tits, !fake_tits.isEmpty { 
            let escapedFakeTits = fake_tits.replacingOccurrences(of: "\"", with: "\\\"")
            inputs.append("fake_tits: \"\(escapedFakeTits)\"") 
        }
        if let career_length = career_length, !career_length.isEmpty {
            let escapedCareer = career_length.replacingOccurrences(of: "\"", with: "\\\"")
            inputs.append("career_length: \"\(escapedCareer)\"")
        }
        if let tattoos = tattoos { inputs.append("tattoos: \"\(tattoos)\"") }
        if let piercings = piercings { inputs.append("piercings: \"\(piercings)\"") }
        let inputString = inputs.joined(separator: ", ")
        
        return """
        mutation PerformerCreate {
            performerCreate(input: { \(inputString) }) {
                id
                name
            }
        }
        """
    }
    
    static func performerUpdate(
        id: String,
        name: String? = nil,
        url: String? = nil,
        details: String? = nil,
        gender: String? = nil,
        birth_date: String? = nil,
        ethnicity: String? = nil,
        country: String? = nil,
        eye_color: String? = nil,
        hair_color: String? = nil,
        height: Int? = nil,
        measurements: String? = nil,
        breast_type: String? = nil,
        tattoos: String? = nil,
        piercings: String? = nil,
        twitter: String? = nil,
        instagram: String? = nil
    ) -> String {
        var inputs: [String] = []
        inputs.append("id: \"\(id)\"")
        
        if let name = name { 
            let escaped = name.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
            inputs.append("name: \"\(escaped)\"") 
        }
        if let url = url { inputs.append("image: \"\(url)\"") }
        if let details = details { 
            let escaped = details.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
            inputs.append("details: \"\(escaped)\"") 
        }
        if let gender = gender { inputs.append("gender: \(gender)") }
        if let birth_date = birth_date { inputs.append("birthdate: \"\(birth_date)\"") }
        if let ethnicity = ethnicity { 
            let escaped = ethnicity.replacingOccurrences(of: "\"", with: "\\\"")
            inputs.append("ethnicity: \"\(escaped)\"") 
        }
        if let country = country { 
            let escaped = country.replacingOccurrences(of: "\"", with: "\\\"")
            inputs.append("country: \"\(escaped)\"") 
        }
        if let eye_color = eye_color { 
            let escaped = eye_color.replacingOccurrences(of: "\"", with: "\\\"")
            inputs.append("eye_color: \"\(escaped)\"") 
        }
        if let height = height { inputs.append("height_cm: \(height)") }
        if let measurements = measurements { 
            let escaped = measurements.replacingOccurrences(of: "\"", with: "\\\"")
            inputs.append("measurements: \"\(escaped)\"") 
        }
        if let tattoos = tattoos { 
            let escaped = tattoos.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
            inputs.append("tattoos: \"\(escaped)\"") 
        }
        if let piercings = piercings { 
            let escaped = piercings.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
            inputs.append("piercings: \"\(escaped)\"") 
        }
        if let twitter = twitter { inputs.append("twitter: \"\(twitter)\"") }
        if let instagram = instagram { inputs.append("instagram: \"\(instagram)\"") }

        let inputString = inputs.joined(separator: ", ")
        
        return """
        mutation PerformerUpdate {
            performerUpdate(input: { \(inputString) }) {
                id
                name
                image_path
            }
        }
        """
    }
    
    static let scrapeSingleScene = """
        query ScrapeSingleScene($source: ScraperSourceInput!, $input: ScrapeSingleSceneInput!) {
            scrapeSingleScene(source: $source, input: $input) {
                title
                details
                date
                image
                director
                code
                url
                urls
                studio {
                    name
                }
                performers {
                    name
                    gender
                    images
                }
                tags {
                    name
                }
                remote_site_id
            }
        }
    """
    
    // MARK: - Stats Query
    
    static let stats = """
        query Stats {
            stats {
                scene_count
                scenes_size
                scenes_duration
                image_count
                images_size
                gallery_count
                performer_count
                studio_count
                group_count
                movie_count
                tag_count
                total_o_count
                total_play_duration
                total_play_count
                scenes_played
            }
        }
        """
    static func stopJob(jobId: String) -> String {
        return """
        mutation StopJob {
            stopJob(job_id: "\(jobId)")
        }
        """
    }
    static func stopAllJobs() -> String {
        return """
        mutation StopAllJobs {
            stopAllJobs
        }
        """
    }
}

struct SceneStreamResult: Decodable {
    let sceneStreams: [SceneStreamEndpoint]
}
