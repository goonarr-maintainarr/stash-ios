import SwiftUI

struct WhisparrFileCard: View {
    let file: WhisparrSceneFile
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "doc.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.relativePath)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(formatSize(file.size))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // File Specs
            VStack(spacing: 12) {
                if let mediaInfo = file.mediaInfo {
                    WhisparrInfoRow(label: "Resolution", value: mediaInfo.resolution)
                    WhisparrInfoRow(label: "Run Time", value: mediaInfo.runTime)
                    WhisparrInfoRow(label: "Scan Type", value: mediaInfo.scanType)
                    
                    Divider().padding(.vertical, 4)
                    
                    WhisparrInfoRow(label: "Video Codec", value: mediaInfo.videoCodec)
                    WhisparrInfoRow(label: "FPS", value: String(format: "%.3f", mediaInfo.videoFps))
                    WhisparrInfoRow(label: "Video Bitrate", value: formatBitrate(mediaInfo.videoBitrate))
                    WhisparrInfoRow(label: "Bit Depth", value: "\(mediaInfo.videoBitDepth)-bit")
                    
                    Divider().padding(.vertical, 4)
                    
                    WhisparrInfoRow(label: "Audio Codec", value: mediaInfo.audioCodec)
                    WhisparrInfoRow(label: "Channels", value: String(format: "%.1f", mediaInfo.audioChannels))
                    WhisparrInfoRow(label: "Audio Bitrate", value: formatBitrate(mediaInfo.audioBitrate))
                } else {
                    // Fallback if media info is missing (rare but possible)
                    WhisparrInfoRow(label: "Quality", value: file.quality.quality.name)
                }
                
                if let releaseGroup = file.releaseGroup {
                    Divider().padding(.vertical, 4)
                    WhisparrInfoRow(label: "Release Group", value: releaseGroup)
                }
                
                WhisparrInfoRow(label: "Date Added", value: formatDate(file.dateAdded))
            }
            
            Divider()
            
            // Delete Button
            Button(role: .destructive, action: onDelete) {
                HStack {
                    Spacer()
                    Image(systemName: "trash")
                    Text("Delete File")
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
        .background(Color.stashCardBackground)
        .cornerRadius(12)
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatBitrate(_ bitrate: Int) -> String {
        let mbps = Double(bitrate) / 1_000_000
        return String(format: "%.1f Mbps", mbps)
    }
}

struct WhisparrInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}
