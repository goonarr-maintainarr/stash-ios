import SwiftUI

/// A section containing data management actions (Full Sync, Cache Clearing).
///
/// **Used by:** `SettingsView`
struct DataManagementSection: View {
    let coordinator: SettingsCoordinator
    let isServerValid: Bool
    @Binding var showFullSyncConfirmation: Bool
    
    var body: some View {
        Section {
            if case .syncing(let progress, let message) = coordinator.syncState {
                VStack(spacing: 8) {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if progress > 0 {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                }
                .padding(.bottom, 8)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }

            Button(action: {
                HapticManager.lightImpact()
                showFullSyncConfirmation = true
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Full Sync")
                    Spacer()
                }
            }
            .disabled(coordinator.isSyncing || !isServerValid)
        } header: {
            Text("Data Management")
        } footer: {
            Text("Sync all scenes, performers, and tags from your Stash server. This will add new items and remove any that have been deleted from your server.")
        }
    }
}
