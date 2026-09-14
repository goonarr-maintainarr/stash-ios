import SwiftUI
import os

/// Configuration sheet for triggering metadata generation (Covers, Sprites, etc.).
///
/// **Presented by:** `SettingsView`
struct SceneGenerationSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        Form {
            Section(header: Text("Generation Options")) {
                // Checkboxes for each option
                DescriptionToggleRow(
                    title: "Covers",
                    description: "Generate cover images (screenshots) for scenes",
                    isOn: $settings.generationOptions.covers
                )
                DescriptionToggleRow(
                    title: "Sprites",
                    description: "Generate sprite sheets for timeline scrubbing",
                    isOn: $settings.generationOptions.sprites
                )
                DescriptionToggleRow(
                    title: "Previews",
                    description: "Generate preview videos (short clips from the scene)",
                    isOn: $settings.generationOptions.previews
                )
                DescriptionToggleRow(
                    title: "Image Previews",
                    description: "Generate animated image previews (webp/gif)",
                    isOn: $settings.generationOptions.imagePreviews
                )
                DescriptionToggleRow(
                    title: "Markers",
                    description: "Generate default screenshots for markers",
                    isOn: $settings.generationOptions.markers
                )
                DescriptionToggleRow(
                    title: "Marker Image Previews",
                    description: "Generate animated previews for markers",
                    isOn: $settings.generationOptions.markerImagePreviews
                )
                DescriptionToggleRow(
                    title: "Marker Screenshots",
                    description: "Generate screenshots for markers",
                    isOn: $settings.generationOptions.markerScreenshots
                )
                DescriptionToggleRow(
                    title: "Transcodes",
                    description: "Generate transcoded versions of videos",
                    isOn: $settings.generationOptions.transcodes
                )
                DescriptionToggleRow(
                    title: "Force Transcodes",
                    description: "Generate transcodes even if not required",
                    isOn: $settings.generationOptions.forceTranscodes
                )
                DescriptionToggleRow(
                    title: "Phashes",
                    description: "Generate perceptual hashes for duplicate detection",
                    isOn: $settings.generationOptions.phashes
                )
                DescriptionToggleRow(
                    title: "Interactive Heatmaps & Speeds",
                    description: "Generate interactive heatmaps for funscript files",
                    isOn: $settings.generationOptions.interactiveHeatmapsSpeeds
                )
                DescriptionToggleRow(
                    title: "Image Thumbnails",
                    description: "Generate thumbnails for images",
                    isOn: $settings.generationOptions.imageThumbnails
                )
                DescriptionToggleRow(
                    title: "Clip Previews",
                    description: "Generate preview clips",
                    isOn: $settings.generationOptions.clipPreviews
                )
            }
            .listRowBackground(Color.stashCardBackground)
            
            Section {
                Toggle("Overwrite Existing Files", isOn: $settings.generationOptions.overwrite)
                    .tint(.red)
            } header: {
                Text("Danger Zone")
            }
            .listRowBackground(Color.stashCardBackground)
        }
        .scrollContentBackground(.hidden)
        .background(Color.stashBackground)
        .navigationTitle("Generation Options")
    }
}
