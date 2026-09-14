import SwiftUI

/// Loading state for Scene Details.
///
/// **Used by:** `SceneDetailView`
struct SceneDetailSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Video Player Placeholder (matches SceneVideoPlayerView)
                SkeletonView(cornerRadius: 0)
                    .frame(height: 300)
                
                // Header (Title, Date, Rating)
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    SkeletonView(height: 28)
                        .frame(maxWidth: 300)
                    
                    // Date & Studio & Rating
                    HStack(spacing: 8) {
                         SkeletonView(height: 16)
                            .frame(width: 80)
                         
                         SkeletonView(height: 16)
                            .frame(width: 100)
                        
                         Spacer()
                        
                         SkeletonView(height: 16)
                            .frame(width: 80)
                    }
                    
                    // Details/Description lines
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(0..<3) { _ in
                             SkeletonView(height: 14)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)
                
                // Tags Section (Matches TagsSection)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        SkeletonView(height: 18)
                           .frame(width: 60)
                        SkeletonView(height: 14)
                           .frame(width: 40)
                    }
                    .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0..<4) { _ in
                                SkeletonView(cornerRadius: 16)
                                   .frame(width: 80, height: 32)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Markers Section (Matches SceneMarkersSection horizontal carousel)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        SkeletonView(height: 18)
                           .frame(width: 90)
                        SkeletonView(height: 14)
                           .frame(width: 40)
                    }
                    .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0..<3) { _ in
                                VStack(alignment: .leading, spacing: 8) {
                                    SkeletonView(cornerRadius: 8)
                                       .frame(width: 320, height: 180)
                                    
                                    SkeletonView(height: 14)
                                       .frame(width: 200)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Performers Section (Matches PerformersSection vertical hero list)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        SkeletonView(height: 18)
                           .frame(width: 100)
                        SkeletonView(height: 14)
                           .frame(width: 40)
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        ForEach(0..<2) { _ in
                            SkeletonView(cornerRadius: 16)
                                .frame(maxWidth: .infinity)
                                .frame(height: 400)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.stashBackground)
    }
}

#Preview {
    SceneDetailSkeletonView()
}
