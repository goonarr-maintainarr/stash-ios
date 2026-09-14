import SwiftUI

/// Loading skeleton for a category row.
///
/// **Used by:** `HomeView`
struct CategoryRowSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title - matches CategoryRow header
            HStack {
                SkeletonView(height: 24)
                    .frame(width: 150)
                Spacer()
                SkeletonView(height: 16)
                    .frame(width: 60)
            }
            .padding(.horizontal)
            
            // Horizontal Scroll - uses SceneCardSkeleton with same width as CategoryRow
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) { // Same spacing as CategoryRow
                    ForEach(0..<3, id: \.self) { _ in
                        SceneCardSkeleton()
                            .frame(width: UIScreen.main.bounds.width - 28) // Same width as CategoryRow
                    }
                }
                .padding(.horizontal, 8) // Same padding as CategoryRow
            }
        }
    }
}
