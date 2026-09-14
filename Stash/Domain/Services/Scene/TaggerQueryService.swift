import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "TaggerQueryService")

/// Service responsible for generating search queries for the Scene Scraper
/// based on scene metadata and file paths.
struct TaggerQueryService {
    
    // MARK: - Main Method
    
    static func prepareQueryString(for scene: Scene, mode: ParseMode = .auto, blacklist: [String] = []) -> String {
        logger.debug("Generating query for scene \(scene.id, privacy: .public) with mode \(mode.rawValue, privacy: .public)")
        var query = ""
        
        // Determine query based on mode
        switch mode {
        case .auto:
            // Auto: Use metadata if available, else filename
            if scene.date != nil && scene.studio != nil && !(scene.studio?.name.isEmpty ?? true) {
                query = buildMetadataQuery(scene)
                logger.debug("Auto-selected mode: metadata")
            } else if let path = scene.files?.first?.path {
                query = buildFilenameQuery(path)
                logger.debug("Auto-selected mode: filename")
            }
            
            // If query is still empty (e.g. no metadata and no file path), try title
            if query.isEmpty, let title = scene.title {
                 query = buildMetadataQuery(scene) // Will use title
                 logger.debug("Auto-selected mode: title (fallback)")
            }
            
        case .metadata:
            query = buildMetadataQuery(scene)
            
        case .filename:
            if let path = scene.files?.first?.path {
                query = buildFilenameQuery(path)
            }
            
        case .path:
            if let path = scene.files?.first?.path {
                query = buildPathQuery(path)
            }
            
        case .directory:
            if let path = scene.files?.first?.path {
                query = buildDirectoryQuery(path)
            }
        }
        
        // Apply blacklist patterns
        var cleanQuery = query
        if !blacklist.isEmpty {
            logger.debug("Applying \(blacklist.count, privacy: .public) blacklist patterns")
            for pattern in blacklist {
                do {
                    let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                    let range = NSRange(cleanQuery.startIndex..<cleanQuery.endIndex, in: cleanQuery)
                    cleanQuery = regex.stringByReplacingMatches(in: cleanQuery, options: [], range: range, withTemplate: " ")
                } catch {
                    logger.warning("Invalid regex pattern in blacklist: \(pattern, privacy: .public)")
                    continue
                }
            }
        }
        
        let finalQuery = cleanQuery.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        logger.debug("Final generated query: '\(finalQuery, privacy: .public)'")
        return finalQuery
    }
    
    // MARK: - Build Methods
    
    private static func buildMetadataQuery(_ scene: Scene) -> String {
        var components: [String] = []
        
        // Date
        if let date = scene.date {
            components.append(date)
        }
        
        // Studio
        if let studioName = scene.studio?.name {
            components.append(studioName)
        }
        
        // Performers
        if let performers = scene.performers {
            let performerNames = performers.compactMap { $0.name }.joined(separator: " ")
            if !performerNames.isEmpty {
                components.append(performerNames)
            }
        }
        
        // Title (clean special characters)
        if let title = scene.title {
            let cleanTitle = title.replacingOccurrences(
                of: "[^a-zA-Z0-9 ]+",
                with: "",
                options: .regularExpression
            )
            if !cleanTitle.isEmpty {
                components.append(cleanTitle)
            }
        }
        
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }
    
    private static func buildFilenameQuery(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let filename = url.deletingPathExtension().lastPathComponent
        
        var query = filename.replacingOccurrences(of: ".", with: " ")
        query = query.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
        
        return query
    }
    
    private static func buildPathQuery(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        var components = url.pathComponents.filter { $0 != "/" }
        
        // Replace filename with version without extension
        if let lastIndex = components.indices.last {
            let filename = url.deletingPathExtension().lastPathComponent
            components[lastIndex] = filename
        }
        
        // Helper to check if component looks like a drive root (e.g. C:) or just empty/slash
        // Standard implementation in doc was simpler, sticking to doc.
        
        var query = components.joined(separator: " ")
        query = query.replacingOccurrences(of: ".", with: " ")
        query = query.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
        
        return query
    }
    
    private static func buildDirectoryQuery(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.deletingLastPathComponent().lastPathComponent
    }
}
