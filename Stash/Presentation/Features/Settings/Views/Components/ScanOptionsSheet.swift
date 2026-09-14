import SwiftUI

/// Configuration sheet for triggering a Library Scan on the server.
///
/// **Presented by:** `SettingsView` (via "Full Scan" or "Selected Scan")
struct ScanOptionsSheet: View {
    @EnvironmentObject var store: SettingsStore
    
    var body: some View {
        List {
            Section(header: Text("Scan Behavior")) {
                Toggle("Rescan All Files", isOn: $store.scanOptions.rescan)
            }
            .listRowBackground(Color.stashCardBackground)
            
            Section(header: Text("Generation Options")) {
                DescriptionToggleRow(
                    title: "Generate Covers",
                    description: "Generate cover images (screenshots) for scenes",
                    isOn: $store.scanOptions.scanGenerateCovers
                )
                DescriptionToggleRow(
                    title: "Generate Previews",
                    description: "Generate preview videos (short clips from the scene)",
                    isOn: $store.scanOptions.scanGeneratePreviews
                )
                DescriptionToggleRow(
                    title: "Generate Image Previews",
                    description: "Generate animated image previews (webp/gif)",
                    isOn: $store.scanOptions.scanGenerateImagePreviews
                )
                DescriptionToggleRow(
                    title: "Generate Sprites",
                    description: "Generate sprite sheets for timeline scrubbing",
                    isOn: $store.scanOptions.scanGenerateSprites
                )
                DescriptionToggleRow(
                    title: "Generate Perceptual Hashes",
                    description: "Generate perceptual hashes for duplicate detection",
                    isOn: $store.scanOptions.scanGeneratePhashes
                )
                DescriptionToggleRow(
                    title: "Generate Thumbnails",
                    description: "Generate thumbnails for images",
                    isOn: $store.scanOptions.scanGenerateThumbnails
                )
                DescriptionToggleRow(
                    title: "Generate Clip Previews",
                    description: "Generate preview clips",
                    isOn: $store.scanOptions.scanGenerateClipPreviews
                )
            }
            .listRowBackground(Color.stashCardBackground)
        }
        .scrollContentBackground(.hidden)
        .background(Color.stashBackground)
        .navigationTitle("Scan Options")
        .navigationBarTitleDisplayMode(.inline)
    }
}

