import SwiftUI

/// A unified protocol for performer data that can be displayed in scene detail views.
/// Both StashDB and Whisparr performer types can conform to this protocol.
protocol PerformerAppearanceDisplayable: Identifiable {
    var performerId: String { get }
    var performerName: String { get }
}

/// Wrapper for StashDB performer appearance
struct StashDBPerformerDisplay: PerformerAppearanceDisplayable {
    let appearance: StashDBPerformerAppearance
    
    var id: String { appearance.performer.id }
    var performerId: String { appearance.performer.id }
    var performerName: String { appearance.performer.name }
}

/// Wrapper for Whisparr credit
struct WhisparrPerformerDisplay: PerformerAppearanceDisplayable {
    let credit: WhisparrCredit
    
    var id: String { credit.performer.foreignId }
    var performerId: String { credit.performer.foreignId }
    var performerName: String { credit.performer.name ?? "Unknown" }
}

/// A reusable performers section for StashDB and Whisparr scene detail views.
/// Displays performer cards with navigation to either local or StashDB performer details.
///
/// **Used by:**
/// - `SceneDetailView`
/// - `WhisparrSceneDetailView`
struct PerformersSection<T: PerformerAppearanceDisplayable>: View {
    let performers: [T]
    let localPerformerIds: [String: String]
    let performerDetails: [String: StashDBPerformer]
    var localPerformerOCounts: [String: Int] = [:]
    var localPerformerSceneCounts: [String: Int] = [:]
    var localImagePaths: [String: String] = [:]

    var onPerformerClick: ((String, String) -> Void)?
    var zoomNamespace: Namespace.ID? // For iOS 18 zoom transition
    
    /// Closure to get the performer data for PerformerCard
    /// Parameters: (performer, localId, stashDetails, oCount, sceneCount, localImagePath, onPerformerClick)
    let performerCardBuilder: (T, String?, StashDBPerformer?, Int?, Int?, String?, @escaping () -> Void) -> AnyView
    
    var body: some View {
        if !performers.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(performers.count == 1 ? "Performer" : "Performers")
                        .font(.headline)
                    
                    if performers.count > 1 {
                        HStack(spacing: 6) {
                            Text("•")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Image(systemName: "person.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)
                                .foregroundColor(.white)
                            Text("\(performers.count)")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                VStack(spacing: 16) {
                    ForEach(Array(performers.enumerated()), id: \.element.id) { index, performer in
                        makeCard(for: performer)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    
    // MARK: - Helper Methods
    
    private func makeCard(for performer: T) -> some View {
        Group {
            if let localPerformerId = localPerformerIds[performer.performerId] {
                // Local Performer Match
                performerCardBuilder(
                    performer,
                    localPerformerId,
                    performerDetails[performer.performerId],
                    localPerformerOCounts[performer.performerId],
                    localPerformerSceneCounts[performer.performerId],
                    localImagePaths[performer.performerId],
                    {
                        HapticManager.lightImpact()
                        onPerformerClick?(localPerformerId, performer.performerName)
                    }
                )
            } else if let details = performerDetails[performer.performerId] {
                // StashDB Match
                performerCardBuilder(
                    performer,
                    nil,
                    details,
                    nil,
                    nil,
                    nil,
                    {
                        HapticManager.lightImpact()
                        // Use StashDB ID if no local ID match
                        onPerformerClick?(performer.performerId, performer.performerName)
                    }
                )
            } else {
                // No Match / Loading
                performerCardBuilder(
                    performer,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    {
                        HapticManager.lightImpact()
                        onPerformerClick?(performer.performerId, performer.performerName)
                    }
                )
            }
        }
    }
}

// MARK: - Convenience Extensions

extension PerformersSection where T == StashDBPerformerDisplay {
    /// Convenience initializer for StashDB scenes
    init(
        appearances: [StashDBPerformerAppearance],
        localPerformerIds: [String: String],
        performerDetails: [String: StashDBPerformer],
        localPerformerOCounts: [String: Int] = [:],
        localPerformerSceneCounts: [String: Int] = [:],
        localImagePaths: [String: String] = [:],

        onPerformerClick: ((String, String) -> Void)? = nil,
        zoomNamespace: Namespace.ID? = nil
    ) {
        self.performers = appearances.map { StashDBPerformerDisplay(appearance: $0) }
        self.localPerformerIds = localPerformerIds
        self.performerDetails = performerDetails
        self.localPerformerOCounts = localPerformerOCounts
        self.localPerformerSceneCounts = localPerformerSceneCounts
        self.localImagePaths = localImagePaths
        self.onPerformerClick = onPerformerClick
        self.zoomNamespace = zoomNamespace
        self.performerCardBuilder = { display, localId, details, oCount, sceneCount, imagePath, action in
            AnyView(PerformerCard(
                performerId: display.performerId,
                name: display.performerName,
                details: details,
                oCount: oCount,
                localImagePath: imagePath,
                localSceneCount: sceneCount,
                style: .hero,
                actions: PerformerCardActions(onPerformerClick: action)
            ))
        }
    }
}

extension PerformersSection where T == WhisparrPerformerDisplay {
    /// Convenience initializer for Whisparr scenes
    init(
        credits: [WhisparrCredit],
        localPerformerIds: [String: String],
        performerDetails: [String: StashDBPerformer],
        localPerformerOCounts: [String: Int] = [:],
        localPerformerSceneCounts: [String: Int] = [:],
        localImagePaths: [String: String] = [:],

        onPerformerClick: ((String, String) -> Void)? = nil,
        zoomNamespace: Namespace.ID? = nil
    ) {
        self.performers = credits.map { WhisparrPerformerDisplay(credit: $0) }
        self.localPerformerIds = localPerformerIds
        self.performerDetails = performerDetails
        self.localPerformerOCounts = localPerformerOCounts
        self.localPerformerSceneCounts = localPerformerSceneCounts
        self.localImagePaths = localImagePaths
        self.onPerformerClick = onPerformerClick
        self.zoomNamespace = zoomNamespace
        self.performerCardBuilder = { display, localId, details, oCount, sceneCount, imagePath, action in
            AnyView(PerformerCard(
                credit: display.credit,
                localPerformerId: localId,
                stashPerformer: details,
                oCount: oCount,
                localSceneCount: sceneCount,
                localImagePath: imagePath,
                style: .hero,
                actions: PerformerCardActions(onPerformerClick: action)
            ))
        }
    }
}

// MARK: - Local Performer Support

/// Wrapper for local Performer
struct LocalPerformerDisplay: PerformerAppearanceDisplayable {
    let performer: Performer
    
    var id: String { performer.id }
    var performerId: String { performer.id }
    var performerName: String { performer.name ?? "Unknown" }
}

extension PerformersSection where T == LocalPerformerDisplay {
    /// Convenience initializer for local scenes
    init(
        performers: [Performer],
        onPerformerClick: ((String, String) -> Void)? = nil,
        zoomNamespace: Namespace.ID? = nil
    ) {
        self.performers = performers.map { LocalPerformerDisplay(performer: $0) }
        // Map each performer ID to itself (they ARE local)
        self.localPerformerIds = Dictionary(uniqueKeysWithValues: performers.map { ($0.id, $0.id) })
        self.performerDetails = [:]
        self.localPerformerOCounts = [:]
        self.localPerformerSceneCounts = [:]
        self.localImagePaths = [:]
        self.onPerformerClick = onPerformerClick
        self.zoomNamespace = zoomNamespace
        self.performerCardBuilder = { display, localId, details, oCount, sceneCount, imagePath, action in
            AnyView(PerformerCard(performer: display.performer, style: .hero, actions: PerformerCardActions(onPerformerClick: action)))
        }
    }
}
