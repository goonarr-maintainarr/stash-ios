import SwiftUI

/// A manual search/selection sheet for releases.
///
/// **Presented by:** `WhisparrSceneDetailView` (Interactive Search)
struct WhisparrReleaseSheet: View {
    let release: WhisparrRelease
    let runtime: Double?
    let onDownload: (Bool) -> Void // Bool for forced
    
    @Environment(\.dismiss) private var dismiss
    @State private var showForceConfirm = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(release.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack {
                            Badge(text: release.qualityName, color: .blue)
                            Badge(text: release.sizeLabel, color: .secondary)
                            Badge(text: "\(release.age) days old", color: .secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.top, 24)
                .padding(.bottom, 8)
                
                // Rejections
                if let rejections = release.rejections, !rejections.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Release Rejected")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.orange)
                        
                        ForEach(rejections, id: \.self) { reason in
                            Text("• \(reason)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Actions
                HStack(spacing: 12) {
                    Button(action: {
                        if release.rejected == true {
                            showForceConfirm = true
                        } else {
                            onDownload(false)
                            dismiss()
                        }
                    }) {
                        Text(release.rejected == true ? "Force Download" : "Download")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(release.rejected == true ? Color.orange : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    if let urlStr = release.infoUrl, let url = URL(string: urlStr) {
                        Link(destination: url) {
                            Text("Website")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.secondary.opacity(0.15))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                
                // Details Grid
                VStack(alignment: .leading, spacing: 16) {
                    Text("Details")
                        .font(.headline)
                    
                    GridRow(label: "Indexer", value: release.indexer ?? "Unknown")
                    GridRow(label: "Protocol", value: release.protocol?.uppercased() ?? "-")
                    if let seeders = release.seeders {
                        GridRow(label: "Peers", value: "\(seeders) seeders / \(release.leechers ?? 0) leechers")
                    }
                    if let group = release.releaseGroup {
                        GridRow(label: "Group", value: group)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .background(GeometryReader { geometry in
                Color.clear.preference(key: ViewHeightKey.self, value: geometry.size.height)
            })
        }
        .background(Color.stashBackground.ignoresSafeArea()) // Opaque background
        .alert("Force Download?", isPresented: $showForceConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Download", role: .destructive) {
                onDownload(true)
                dismiss()
            }
        } message: {
            Text("This release was rejected. Downloading it may result in issues or manual intervention.")
        }
    }
}

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue()) // Use max to ensure we get full height
    }
}

fileprivate struct GridRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

fileprivate struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color == .secondary ? .primary : color)
            .cornerRadius(6)
    }
}
