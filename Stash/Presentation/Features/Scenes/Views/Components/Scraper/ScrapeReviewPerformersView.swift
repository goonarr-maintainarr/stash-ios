import SwiftUI
import NukeUI

struct ScrapeReviewPerformersView: View {
    let result: ScrapedScene
    let currentScene: Scene
    @Binding var usePerformers: Bool
    @Binding var missingPerformers: Set<String>
    var viewModel: SceneDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Performers")
               .font(.title3)
               .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                SelectionRow(
                    title: "Current (\(currentScene.performers?.count ?? 0))",
                    isSelected: !usePerformers,
                    action: { usePerformers = false }
                ) {
                    if let current = currentScene.performers, !current.isEmpty {
                        Text(current.map { $0.name ?? "" }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    } else {
                        Text("None").font(.caption).foregroundColor(.secondary)
                    }
                }
                
                if let newPerformers = result.performers, !newPerformers.isEmpty {
                    Divider()
                    SelectionRow(
                        title: "Scraped (\(newPerformers.count))",
                        isSelected: usePerformers,
                        action: { usePerformers = true }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(newPerformers, id: \.name) { performer in
                                ScrapedPerformerRow(
                                    performer: performer,
                                    missingPerformers: $missingPerformers,
                                    viewModel: viewModel
                                )
                            }
                        }
                    }
                } else {
                    Text("No performers in result").font(.caption).foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.stashCardBackground)
            .cornerRadius(10)
        }
    }
}


