import SwiftUI

/// A horizontal scrolling row (carousel) for performers on the home page.
struct PerformerCategoryRow: View {
    let title: String
    let performers: [Performer]
    let onPerformerClick: ((Performer) -> Void)?
    let onSeeAllClick: (() -> Void)?
    
    private let cardWidth: CGFloat = 200
    private let cardHeight: CGFloat = 267 // 3:4 aspect ratio
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(title)
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let onSeeAll = onSeeAllClick {
                    Button(action: {
                        HapticManager.lightImpact()
                        onSeeAll()
                    }) {
                        Text("View All")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal)
            
            // Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if performers.isEmpty {
                        // Skeleton loading
                        ForEach(0..<5, id: \.self) { _ in
                            PerformerCardSkeleton()
                                .frame(width: cardWidth, height: cardHeight)
                        }
                    } else {
                        ForEach(performers) { performer in
                            PerformerCard(
                                performer: performer,
                                style: .grid,
                                layoutType: .grid3x,
                                actions: PerformerCardActions(
                                    onPerformerClick: {
                                        onPerformerClick?(performer)
                                    }
                                )
                            )
                            .frame(width: cardWidth, height: cardHeight)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }
}



