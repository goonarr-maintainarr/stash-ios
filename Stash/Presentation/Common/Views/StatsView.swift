import SwiftUI

/// Displays library statistics (Total Scenes, Performers, etc.).
///
/// **Used by:**
/// - `HomeView` (via Toolbar Menu "Statistics")
struct StatsView: View {
    @State private var viewModel: StatsViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: StatsViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    loadingView
                case .loaded(let stats):
                    statsContent(stats)
                case .error(let message):
                    errorView(message)
                }
            }
            .navigationTitle("Library Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationBackground(Color.stashBackground.opacity(0.95))
        .task {
            await viewModel.loadStats()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading stats...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.stashBackground)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Failed to load stats")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.loadStats() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.stashBackground)
    }
    
    // MARK: - Stats Content
    
    private func statsContent(_ stats: Stats) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Library Overview
                sectionHeader("Library", icon: "square.stack.3d.up.fill")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    LibraryStatCard(title: "Scenes", value: formatNumber(stats.scene_count), icon: "film.fill", color: .blue)
                    LibraryStatCard(title: "Performers", value: formatNumber(stats.performer_count), icon: "person.2.fill", color: .pink)
                    LibraryStatCard(title: "Studios", value: formatNumber(stats.studio_count), icon: "building.2.fill", color: .purple)
                    LibraryStatCard(title: "Tags", value: formatNumber(stats.tag_count), icon: "tag.fill", color: .orange)
                }
                
                // Storage
                sectionHeader("Storage", icon: "externaldrive.fill")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    LibraryStatCard(title: "Total Size", value: stats.formattedScenesSize, icon: "internaldrive.fill", color: .green)
                    LibraryStatCard(title: "Duration", value: stats.formattedScenesDuration, icon: "clock.fill", color: .cyan)
                    LibraryStatCard(title: "Avg Length", value: stats.averageSceneDuration, icon: "timer", color: .teal)
                    LibraryStatCard(title: "Groups", value: formatNumber(stats.group_count), icon: "folder.fill", color: .indigo)
                }
                
                // Activity
                sectionHeader("Activity", icon: "chart.bar.fill")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    LibraryStatCard(title: "O-Counter", value: formatNumber(stats.total_o_count), icon: "heart.fill", color: .red)
                    LibraryStatCard(title: "Total Plays", value: formatNumber(stats.total_play_count), icon: "play.fill", color: .green)
                    LibraryStatCard(title: "Scenes Played", value: formatNumber(stats.scenes_played), icon: "checkmark.circle.fill", color: .blue)
                    LibraryStatCard(title: "Play Time", value: stats.formattedPlayDuration, icon: "hourglass", color: .orange)
                }
                
                // Progress Card
                VStack(spacing: 8) {
                    HStack {
                        Text("Scenes Watched")
                            .font(.headline)
                        Spacer()
                        Text("\(String(format: "%.1f", stats.percentScenesPlayed))%")
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }
                    ProgressView(value: stats.percentScenesPlayed / 100)
                        .tint(.blue)
                    HStack {
                        Text("\(formatNumber(stats.scenes_played)) of \(formatNumber(stats.scene_count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .padding()
                .background(Color.stashCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .background(Color.stashBackground)
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(title)
                .font(.title3.bold())
            Spacer()
        }
        .padding(.top, 8)
    }
    
    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Library Stat Card Component

private struct LibraryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.stashCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    StatsView(viewModel: DependencyContainer.preview.makeStatsViewModel())
}
