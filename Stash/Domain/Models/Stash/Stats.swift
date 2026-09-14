import Foundation

/// Response wrapper for the stats GraphQL query
struct StatsQueryResponse: Decodable {
    let data: StatsData
    
    struct StatsData: Decodable {
        let stats: Stats
    }
}

/// Model representing library statistics from Stash
struct Stats: Decodable, Equatable {
    let scene_count: Int
    let scenes_size: Int64
    let scenes_duration: Double
    let image_count: Int
    let images_size: Int64
    let gallery_count: Int
    let performer_count: Int
    let studio_count: Int
    let group_count: Int
    let movie_count: Int
    let tag_count: Int
    let total_o_count: Int
    let total_play_duration: Double
    let total_play_count: Int
    let scenes_played: Int
    
    // MARK: - Formatted Properties
    
    /// Scenes size formatted as human-readable string (e.g., "21.9 TB")
    var formattedScenesSize: String {
        ByteCountFormatter.string(fromByteCount: scenes_size, countStyle: .file)
    }
    
    /// Images size formatted as human-readable string
    var formattedImagesSize: String {
        ByteCountFormatter.string(fromByteCount: images_size, countStyle: .file)
    }
    
    /// Scenes duration formatted as days/hours/minutes
    var formattedScenesDuration: String {
        formatDuration(scenes_duration)
    }
    
    /// Total play duration formatted as days/hours/minutes
    var formattedPlayDuration: String {
        formatDuration(total_play_duration)
    }
    
    /// Average scene duration
    var averageSceneDuration: String {
        guard scene_count > 0 else { return "0m" }
        let avgSeconds = scenes_duration / Double(scene_count)
        return formatDuration(avgSeconds)
    }
    
    /// Percentage of scenes played
    var percentScenesPlayed: Double {
        guard scene_count > 0 else { return 0 }
        return Double(scenes_played) / Double(scene_count) * 100
    }
    
    // MARK: - Private Helpers
    
    private func formatDuration(_ seconds: Double) -> String {
        let totalMinutes = Int(seconds / 60)
        let totalHours = totalMinutes / 60
        let totalDays = totalHours / 24
        
        if totalDays > 0 {
            let remainingHours = totalHours % 24
            return "\(totalDays)d \(remainingHours)h"
        } else if totalHours > 0 {
            let remainingMinutes = totalMinutes % 60
            return "\(totalHours)h \(remainingMinutes)m"
        } else {
            return "\(totalMinutes)m"
        }
    }
}
