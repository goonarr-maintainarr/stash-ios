import SwiftUI

/// Displays external Stash IDs for a performer.
///
/// **Used by:** `PerformerDetailContentView`
struct PerformerStashIDsView: View {
    let stashIds: [Performer.StashID]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("External IDs")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(spacing: 0) {
                ForEach(Array(stashIds.enumerated()), id: \.element.stash_id) { index, id in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatEndpoint(id.endpoint))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(id.stash_id)
                            .font(.system(.subheadline, design: .monospaced))
                            .lineLimit(3)
                            .textSelection(.enabled) // Allow copying
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    
                    if index < stashIds.count - 1 {
                        Divider()
                    }
                }
            }
            }

        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .accentedCardBackground(opacity: 0.6)
        .cornerRadius(12)
        .padding(.top, 8)
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
