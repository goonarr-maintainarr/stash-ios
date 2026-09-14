import SwiftUI

struct SkeletonView: View {
    @State private var isAnimating = false
    var height: CGFloat? = nil
    var width: CGFloat? = nil
    var cornerRadius: CGFloat = 4
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.15),
                        Color.gray.opacity(0.25),
                        Color.gray.opacity(0.15)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
            .overlay(
                GeometryReader { geometry in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.08),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.4)
                        .offset(x: isAnimating ? geometry.size.width : -geometry.size.width * 0.4)
                }
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.2)
                        .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

struct SceneCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail shimmer
            SkeletonView(cornerRadius: 0)
                .aspectRatio(16/9, contentMode: .fit)
            
            // Info section
            VStack(alignment: .leading, spacing: 8) {
                // Title
                SkeletonView(height: 18)
                    .frame(maxWidth: .infinity)
                
                // Metadata row
                SkeletonView(height: 14)
                    .frame(width: 150)
                
                // Description shimmer
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonView(height: 12)
                        .frame(maxWidth: .infinity)
                    SkeletonView(height: 12)
                        .frame(maxWidth: .infinity)
                    SkeletonView(height: 12)
                        .frame(width: 200)
                }
                .padding(.vertical, 4)
                
                // Performers row
                HStack(spacing: 8) {
                    SkeletonView(height: 14)
                        .frame(width: 70)
                    SkeletonView(height: 14)
                        .frame(width: 50)
                }
            }
            .padding(12)
        }
        .background(Color.stashCardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct SceneGridSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            SkeletonView(cornerRadius: 0)
                .aspectRatio(16/9, contentMode: .fit)
            
            VStack(alignment: .leading, spacing: 8) {
                // Title
                SkeletonView(height: 18)
                    .frame(maxWidth: .infinity)
                
                // Metadata row (Date • Rating)
                HStack(spacing: 8) {
                    SkeletonView(height: 12)
                        .frame(width: 80)
                    
                    Spacer()
                    
                    SkeletonView(height: 12)
                        .frame(width: 30)
                }
            }
            .padding(8)
            .background(Color.stashCardBackground)
        }
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct SceneCompactSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail
            SkeletonView(cornerRadius: 8)
                .frame(width: 140, height: 79)
            
            VStack(alignment: .leading, spacing: 8) {
                // Title
                SkeletonView(height: 18)
                    .frame(maxWidth: .infinity)
                
                // Metadata
                SkeletonView(height: 12)
                    .frame(width: 120)
                
                // Performers/Tags
                SkeletonView(height: 12)
                    .frame(width: 100)
            }
            .padding(.vertical, 4)
        }
        .padding(8)
        .background(Color.stashCardBackground)
        .cornerRadius(8)
    }
}

struct PerformerCardSkeleton: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Image placeholder
            SkeletonView(cornerRadius: 12)
            
            // Info section
            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(height: 18)
                    .frame(width: 100)
                SkeletonView(height: 14)
                    .frame(width: 60)
            }
            .padding(12)
        }
        .aspectRatio(3/4, contentMode: .fit)
        .cornerRadius(12)
    }
}

