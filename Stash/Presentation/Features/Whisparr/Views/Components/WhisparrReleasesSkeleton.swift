import SwiftUI

/// Skeleton placeholder for a release row during loading.
struct WhisparrReleaseRowSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title placeholder - 2 rows to match typical release titles
            VStack(alignment: .leading, spacing: 4) {
                Color.secondary.opacity(0.2)
                    .frame(height: 16)
                    .cornerRadius(4)
                    .shimmering()
                
                Color.secondary.opacity(0.2)
                    .frame(width: 200, height: 16)
                    .cornerRadius(4)
                    .shimmering()
            }
            
            // Quality • Size • Age placeholder
            HStack(spacing: 8) {
                Color.secondary.opacity(0.2)
                    .frame(width: 60, height: 14)
                    .cornerRadius(4)
                    .shimmering()
                
                Text("•")
                    .foregroundColor(.secondary.opacity(0.3))
                
                Color.secondary.opacity(0.2)
                    .frame(width: 50, height: 14)
                    .cornerRadius(4)
                    .shimmering()
                
                Text("•")
                    .foregroundColor(.secondary.opacity(0.3))
                
                Color.secondary.opacity(0.2)
                    .frame(width: 30, height: 14)
                    .cornerRadius(4)
                    .shimmering()
            }
            
            // Protocol • Indexer placeholder
            HStack(spacing: 8) {
                Color.secondary.opacity(0.2)
                    .frame(width: 50, height: 20)
                    .cornerRadius(4)
                    .shimmering()
                
                Text("•")
                    .foregroundColor(.secondary.opacity(0.3))
                
                Color.secondary.opacity(0.2)
                    .frame(width: 80, height: 14)
                    .cornerRadius(4)
                    .shimmering()
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

/// Skeleton list for multiple release rows.
struct WhisparrReleasesSkeleton: View {
    var body: some View {
        List {
            ForEach(0..<8, id: \.self) { _ in
                WhisparrReleaseRowSkeleton()
                    .listRowBackground(Color.stashBackground)
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }
}
