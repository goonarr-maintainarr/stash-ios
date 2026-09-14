import SwiftUI

/// Displays file information (Path, Checksum, Phash) for a scene.
///
/// **Used by:** `SceneDetailView`
struct FileInfoSection: View {
    let file: Scene.SceneFile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("File Info")
                .font(.headline)
            
            VStack(spacing: 0) {
                infoRow(label: "Path", value: file.path ?? "Unknown")
                Divider().padding(.leading, 16)
                
                if let width = file.width, let height = file.height {
                    infoRow(label: "Resolution", value: "\(width)x\(height)")
                    Divider().padding(.leading, 16)
                }
                
                if let duration = file.duration {
                    infoRow(label: "Duration", value: formatDuration(duration))
                    Divider().padding(.leading, 16)
                }
                
                if let size = file.size {
                    infoRow(label: "Size", value: formatSize(size))
                    Divider().padding(.leading, 16)
                }
                
                if let vCodec = file.video_codec {
                    infoRow(label: "Video Codec", value: vCodec, isLast: true)
                }
            }
            .background(Color.stashCardBackground)
            .cornerRadius(12)
        }
    }
    
    private func infoRow(label: String, value: String, isLast: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
            
            Spacer()
        }
        .padding()
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "\(seconds)s"
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
