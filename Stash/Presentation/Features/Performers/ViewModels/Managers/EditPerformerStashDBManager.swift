import Observation
import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "EditPerformerStashDBManager")

/// Manages StashDB image fetching and metadata auto-fill.
@MainActor
@Observable
class EditPerformerStashDBManager {
    
    // MARK: - Observable Properties
    
    var stashBoxImages: [StashBoxImage] = []
    var selectedImageUrl: String?
    var isLoadingImages = false
    
    // MARK: - Dependencies
    
    private let stashDBRepository: StashDBRepositoryProtocol
    private let performerRepository: any PerformerRepositoryProtocol
    private let settings: SettingsStoreProtocol
    
    // MARK: - Initialization
    
    init(
        stashDBRepository: StashDBRepositoryProtocol,
        performerRepository: any PerformerRepositoryProtocol,
        settings: SettingsStoreProtocol
    ) {
        self.stashDBRepository = stashDBRepository
        self.performerRepository = performerRepository
        self.settings = settings
        logger.debug("🔧 EditPerformerStashDBManager initialized")
    }
    
    // MARK: - Image Fetching
    
    func fetchStashDBImages(performerName: String) async throws {
        guard !performerName.isEmpty else {
            logger.info("⚠️ Skipping StashDB search - empty name")
            return
        }
        
        logger.info("🔍 Fetching StashDB images for: \(performerName)")
        isLoadingImages = true
        
        do {
            // 1. Fetch Configuration to get StashBoxes
            var stashBoxes: [StashBoxConfiguration.StashBoxEndpoint] = []
            do {
                let config = try await performerRepository.fetchStashBoxConfiguration()
                stashBoxes = config.general?.stashBoxes ?? []
            } catch {
                logger.error("⚠️ Failed to fetch configuration: \(error.localizedDescription)")
            }
            
            // Fallback: Check settings
            if stashBoxes.isEmpty && settings.stashDBApiKey != "" {
                stashBoxes.append(StashBoxConfiguration.StashBoxEndpoint(
                    endpoint: settings.stashDBUrl,
                    api_key: settings.stashDBApiKey,
                    name: "StashDB (Settings)"
                ))
            }
            
            // 2. Search all stashboxes concurrently
            var foundPerformers: [(StashBoxConfiguration.StashBoxEndpoint, [StashDBPerformer])] = []
            
            await withTaskGroup(of: (StashBoxConfiguration.StashBoxEndpoint, [StashDBPerformer]).self) { group in
                for box in stashBoxes {
                    group.addTask {
                        let performers = await self.searchPerformers(in: box, term: performerName)
                        return (box, performers)
                    }
                }
                
                for await result in group {
                    foundPerformers.append(result)
                }
            }
            
            // 3. Process Results
            var allImages: [StashBoxImage] = []
            let searchName = performerName.lowercased().trimmingCharacters(in: .whitespaces)
            
            for (box, performers) in foundPerformers {
                for performer in performers {
                    let performerName = performer.name.lowercased().trimmingCharacters(in: .whitespaces)
                    
                    // Only include exact name matches
                    guard performerName == searchName else { continue }
                    
                    // Collect images
                    if let images = performer.images {
                        let boxImages = images.map { img in
                            StashBoxImage(
                                id: img.id,
                                url: img.url,
                                endpoint: box.endpoint,
                                name: performer.name,
                                birthdate: performer.birthDate,
                                country: performer.country
                            )
                        }
                        allImages.append(contentsOf: boxImages)
                    }
                }
            }
            
            // Deduplicate images by URL
            let uniqueImages = Array(Set(allImages.map { $0.url })).compactMap { url in
                allImages.first(where: { $0.url == url })
            }
            
            stashBoxImages = uniqueImages
            logger.info("📸 Loaded \(uniqueImages.count) unique images")
            isLoadingImages = false
        }
    }
    
    
    private func searchPerformers(in box: StashBoxConfiguration.StashBoxEndpoint, term: String) async -> [StashDBPerformer] {
        do {
            return try await stashDBRepository.searchPerformers(term: term, endpoint: box.endpoint, apiKey: box.api_key)
        } catch {
            logger.error("❌ Failed to search \(box.name ?? "StashBox"): \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Metadata Auto-Fill
    
    /// Auto-fills metadata from StashDB if exact match found.
    func autoFillMetadata(performerName: String) async -> PerformerAutoFillData? {
        guard !performerName.isEmpty else {
            logger.info("⚠️ Skipping auto-fill - empty name")
            return nil
        }
        
        logger.info("🔍 Auto-filling metadata for: \(performerName)")
        
        // Fetch configuration
        var stashBoxes: [StashBoxConfiguration.StashBoxEndpoint] = []
        do {
            let config = try await performerRepository.fetchStashBoxConfiguration()
            stashBoxes = config.general?.stashBoxes ?? []
        } catch {
            logger.error("⚠️ Failed to fetch configuration: \(error.localizedDescription)")
        }
        
        if stashBoxes.isEmpty && settings.stashDBApiKey != "" {
            stashBoxes.append(StashBoxConfiguration.StashBoxEndpoint(
                endpoint: settings.stashDBUrl,
                api_key: settings.stashDBApiKey,
                name: "StashDB (Settings)"
            ))
        }
        
        for box in stashBoxes {
            do {
                let performers = try await stashDBRepository.searchPerformers(
                    term: performerName,
                    endpoint: box.endpoint,
                    apiKey: box.api_key
                )
                
                if let match = performers.first(where: { $0.name.lowercased() == performerName.lowercased() }) {
                    logger.info("✅ Found exact match in \(box.name ?? "StashBox"), auto-filling")
                    return PerformerAutoFillData(from: match)
                }
            } catch {
                logger.error("❌ Auto-fill search failed for \(box.name ?? "StashBox"): \(error.localizedDescription)")
            }
        }
        
        logger.info("ℹ️ No exact match found for auto-fill")
        return nil
    }
}

// MARK: - Helper Models

/// A structure representing an image available from StashBox.
struct StashBoxImage: Identifiable, Equatable {
    let id: String
    let url: String
    let endpoint: String
    let name: String?
    let birthdate: String?
    let country: String?
}

struct PerformerAutoFillData {
    let birthdate: String?
    let country: String?
    let ethnicity: String?
    let heightCm: Int?
    let measurements: String?
    let fakeTits: String?
    let careerLength: String?
    let tattoos: String?
    let piercings: String?
    let gender: String?
    let eyeColor: String?
    let hairColor: String?
    
    init(from performer: StashDBPerformer) {
        self.birthdate = performer.birthDate
        self.country = performer.country
        self.ethnicity = performer.ethnicity
        self.heightCm = performer.height
        
        // Build measurements string
        var meas = ""
        if let m = performer.measurements {
            if let cup = m.cup_size { meas += cup }
            if let band = m.band_size { meas += "\(band)" }
        }
        self.measurements = meas.isEmpty ? nil : meas
        
        self.fakeTits = performer.breastType
        
        // Build career length from start/end years
        if let start = performer.careerStartYear, let end = performer.careerEndYear {
            self.careerLength = "\(start)-\(end)"
        } else if let start = performer.careerStartYear {
            self.careerLength = "\(start)-Present"
        } else {
            self.careerLength = nil
        }
        
        // Build tattoos string
        if let tats = performer.tattoos, !tats.isEmpty {
            let tattooStr = tats.compactMap { "\($0.location ?? "") \($0.description ?? "")" }
                .joined(separator: ", ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            self.tattoos = tattooStr.isEmpty ? nil : tattooStr
        } else {
            self.tattoos = nil
        }
        
        // Build piercings string
        if let pierc = performer.piercings, !pierc.isEmpty {
            let piercingStr = pierc.compactMap { "\($0.location ?? "") \($0.description ?? "")" }
                .joined(separator: ", ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            self.piercings = piercingStr.isEmpty ? nil : piercingStr
        } else {
            self.piercings = nil
        }
        
        self.gender = performer.gender
        self.eyeColor = performer.eyeColor
        self.hairColor = performer.hairColor
    }
}
