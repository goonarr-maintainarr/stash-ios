import SwiftUI

/// Displays external Stash IDs (StashDB, etc).
///
/// **Used by:** `SceneDetailView`
struct SceneStashIDsView: View {
    let stashIds: [Scene.StashID]
    
    var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("External IDs")
                    .font(.headline)
                
                VStack(spacing: 0) {
                    ForEach(Array(stashIds.enumerated()), id: \.element.stash_id) { index, id in
                        HStack {
                            Text(formatEndpoint(id.endpoint))
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .leading)
                            
                            Text(id.stash_id)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                        }
                        .padding()
                        
                        if index < stashIds.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color.stashCardBackground)
                .cornerRadius(12)
            }
        }
        
        private func formatEndpoint(_ endpoint: String) -> String {
            if endpoint.contains("stashdb.org") {
                return "StashDB"
            } else if endpoint.contains("theporndb.net") || endpoint.contains("metadataapi.net") {
                return "ThePornDB"
            }
            
            // Fallback to domain name if possible
            if let url = URL(string: endpoint), let host = url.host {
                return host
            }
            
            return "Unknown"
        }
    }
