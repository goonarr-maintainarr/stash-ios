import SwiftUI

/// A list row representing a potential release download.
///
/// **Used by:** `WhisparrReleaseSheet`
struct WhisparrReleaseRow: View {
    let release: WhisparrRelease
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top Line: Title
            Text(release.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            
            // Middle Line: Quality • Size • Age
            HStack(spacing: 8) {
                Text(release.qualityName)
                    .fontWeight(.medium)
                
                Text("•")
                
                Text(release.sizeLabel)
                
                Text("•")
                
                Text("\(release.age)d")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            // Bottom Line: Protocol • Indexer • Flags
            HStack(spacing: 8) {
                // Protocol Badge
                Text(release.protocol?.uppercased() ?? "UNKNOWN")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
                
                // Indexer
                if let indexer = release.indexer {
                    Text("•")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(indexer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Peers (if torrent)
                if let seeders = release.seeders, let leechers = release.leechers, (release.protocol == "torrent" || seeders > 0) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                        Text("\(seeders)")
                        Text("/")
                        Image(systemName: "arrow.down")
                        Text("\(leechers)")
                    }
                    .font(.caption)
                    .foregroundColor(peerColor(seeders: seeders))
                }
                
                Spacer()
                

                
                // Flags
                if release.isProper {
                    Text("PROPER")
                        .font(.caption)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
                
                if let rejected = release.rejected, rejected {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // Make full row tappable
    }
    
    private func peerColor(seeders: Int) -> Color {
        if seeders >= 50 { return .green }
        if seeders >= 10 { return .blue }
        return .orange
    }
}
