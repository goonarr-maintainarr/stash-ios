import SwiftUI

struct WhisparrFileInfoSection: View {
    let scene: WhisparrScene
    let onFilesHistoryTap: () -> Void
    
    var body: some View {
        let sizeFormatter: ByteCountFormatter = {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useAll]
            formatter.countStyle = .file
            return formatter
        }()
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("File Info")
                    .font(.headline)
                
                Spacer()
                
                Button(action: onFilesHistoryTap) {
                    HStack(spacing: 4) {
                        Text("Files & History")
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                if let sceneFile = scene.sceneFile {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "Quality", value: sceneFile.quality.quality.name)
                        
                        InfoRow(label: "Size", value: sizeFormatter.string(fromByteCount: sceneFile.size))
                        
                        Group {
                            if let mediaInfo = sceneFile.mediaInfo {
                                InfoRow(label: "Resolution", value: mediaInfo.resolution)
                                InfoRow(label: "Duration", value: mediaInfo.runTime)
                            }
                        }
                        
                        if let releaseDate = scene.releaseDate {
                            InfoRow(label: "Released", value: DateFormatters.formatDate(releaseDate))
                        }
                    }
                } else {
                    Text("No file downloaded")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.stashCardBackground)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}
