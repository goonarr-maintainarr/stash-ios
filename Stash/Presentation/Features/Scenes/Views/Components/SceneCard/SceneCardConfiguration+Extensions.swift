import SwiftUI

extension SceneCardConfiguration {
    
    // MARK: - Scene Init
    init(scene: Scene, settings: SettingsStoreProtocol, showDescription: Bool = true) {
        
        // Map Performers
        let cardPerformers = scene.performers?.map { p in
            SceneCardConfiguration.SceneCardPerformer(
                id: p.id,
                name: p.name ?? "Unknown",
                localId: p.id,
                imageUrl: settings.createImageUrl(path: p.image_path)
            )
        } ?? []
        
        // Map Indicators
        var indicators: [SceneCardConfiguration.SceneCardIndicator] = []
        if let oCount = scene.o_counter, oCount > 0 {
            indicators.append(.init(customIcon: "SweatDrops", text: "\(oCount)", color: .white))
        }
        if let markers = scene.scene_markers, !markers.isEmpty {
            indicators.append(.init(customIcon: "MapMarker", text: "\(markers.count)", color: .white))
        }
        
        if let rating = scene.rating100 {
            let value = Double(rating) / 20.0
            indicators.append(.init(icon: "star.fill", text: String(format: "%g", value), color: .yellow))
        }
        
        // Map Runtime
        var runtimeString: String?
        if let file = scene.files?.first, let duration = file.duration {
            let minutes = Int(duration / 60)
            runtimeString = "\(minutes)m"
        }
        
     self.init(
            title: scene.title ?? "No Title",
            imageUrl: settings.createImageUrl(path: scene.paths?.screenshot),
            videoPreviewUrl: settings.createImageUrl(path: scene.paths?.preview),
            spriteUrl: settings.createImageUrl(path: scene.paths?.sprite),
            vttUrl: settings.createImageUrl(path: scene.paths?.vtt),
            date: scene.date,
            studio: scene.studio?.name,
            runtime: runtimeString,
            performers: cardPerformers,
            statusColor: nil,
            statusText: nil,
            indicators: indicators,
            isMonitored: nil,
            addedDate: nil,
            resumeTime: scene.resume_time,

            duration: scene.files?.first?.duration,
            description: scene.details,
            tags: scene.tags?.compactMap { $0.name } ?? [],
            showDescription: showDescription
        )
    }
    
    // MARK: - Whisparr Init
    init(whisparrScene: WhisparrScene, isInQueue: Bool, qualityProfileName: String? = nil, showDescription: Bool = true) {
        // Status Color Logic
        let statusColor: Color
        if whisparrScene.hasFile {
            statusColor = .green
        } else if isInQueue {
            statusColor = .purple
        } else {
            statusColor = .red
        }
        
        // Map Performers (Female/Non-Male only for Whisparr usually)
        let femalePerformers = whisparrScene.credits
            .filter { $0.performer.gender?.uppercased() != "MALE" }
            .prefix(3)
            .map { credit in
                // TODO: Link to local performer if we can match IDs? For now textual.
                let imageUrlString = credit.performer.images?.first?.remoteUrl ?? credit.performer.images?.first?.url
                
                return SceneCardConfiguration.SceneCardPerformer(
                    id: credit.performer.foreignId,
                    name: credit.performer.name ?? "Unknown",
                    localId: credit.performer.foreignId,
                    imageUrl: URL(string: imageUrlString ?? "")
                )
            }
        
        // Map Runtime
        var runtimeString = "\(whisparrScene.runtime)m"
        if whisparrScene.sizeOnDisk > 0 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useAll]
            formatter.countStyle = .file
            let size = formatter.string(fromByteCount: whisparrScene.sizeOnDisk)
            runtimeString += " • \(size)"
        }
        
        let releaseDate: String
        if let date = whisparrScene.releaseDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: date)
            releaseDate = DateFormatters.formatDateString(dateString)
        } else {
            releaseDate = "\(whisparrScene.year)"
        }
        
        // Map Indicators
        let indicators: [SceneCardConfiguration.SceneCardIndicator] = []
        
        self.init(
            title: whisparrScene.title,
            imageUrl: URL(string: whisparrScene.imageUrl ?? ""),
            videoPreviewUrl: nil,
            spriteUrl: nil,
            vttUrl: nil,
            date: releaseDate,
            studio: whisparrScene.studioTitle,
            runtime: runtimeString,
            performers: Array(femalePerformers),
            statusColor: statusColor,
            statusText: qualityProfileName,
            indicators: indicators,
            isMonitored: whisparrScene.monitored,
            addedDate: whisparrScene.added.formatted(date: .numeric, time: .omitted),
            resumeTime: nil,

            duration: Double(whisparrScene.runtime * 60),
            description: whisparrScene.overview,
            tags: [], // Whisparr scene might not have simple tag list in this model, verifying later if needed
            showDescription: showDescription
        )
    }
    
    // MARK: - StashDB Init
    init(stashDBScene: StashDBScene, showDescription: Bool = true) {
        // Map Performers (Female/Non-Male only)
        let femalePerformers = (stashDBScene.performers ?? [])
            .filter { $0.performer.gender?.uppercased() != "MALE" }
            .prefix(3)
            .map { appearance in
                SceneCardConfiguration.SceneCardPerformer(
                    id: appearance.performer.id,
                    name: appearance.performer.name,
                    localId: appearance.performer.id,
                    imageUrl: nil // StashDBPerformerBasic does not have image data
                )
            }
        
        // Map Runtime
        var runtimeString: String?
        if let duration = stashDBScene.duration {
            let minutes = Int(duration / 60)
            runtimeString = "\(minutes)m"
        }
        
        self.init(
            title: stashDBScene.title ?? "No Title",
            imageUrl: URL(string: stashDBScene.images?.first?.url ?? ""),
            videoPreviewUrl: nil,
            spriteUrl: nil,
            vttUrl: nil,
            date: stashDBScene.date,
            studio: stashDBScene.studio?.name,
            runtime: runtimeString,
            performers: Array(femalePerformers),
            statusColor: nil,
            statusText: nil,
            indicators: [],
            isMonitored: nil,
            addedDate: nil,
            resumeTime: nil,

            duration: stashDBScene.duration.map { Double($0) },
            description: stashDBScene.details,
            tags: stashDBScene.tags?.compactMap { $0.name } ?? [],
            showDescription: showDescription
        )
    }
}
