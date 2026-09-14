import SwiftUI

/// A wrapper around StashDBPerformersSection specifically for WhisparrScene credits.
struct WhisparrPerformersSection: View {
    let femalePerformers: [WhisparrCredit]
    let localPerformerIds: [String: String]
    let performerDetails: [String: StashDBPerformer]
    var localPerformerOCounts: [String: Int] = [:]
    var localPerformerSceneCounts: [String: Int] = [:]
    var localImagePaths: [String: String] = [:]
    var onPerformerClick: ((String, String) -> Void)?
    
    var body: some View {
        PerformersSection(
            credits: femalePerformers,
            localPerformerIds: localPerformerIds,
            performerDetails: performerDetails,
            localPerformerOCounts: localPerformerOCounts,
            localPerformerSceneCounts: localPerformerSceneCounts,
            localImagePaths: localImagePaths,
            onPerformerClick: onPerformerClick
        )
    }
}
