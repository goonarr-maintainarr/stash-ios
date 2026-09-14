import os
import SwiftUI


private let logger = Logger(subsystem: "com.stash.app", category: "StarRatingView")

/// A custom star rating control for displaying and editing 1-5 star ratings.
///
/// **Used by:**
/// - `SceneDetailView` (Rating input)
/// - `SceneCard` (Read-only display)
struct StarRatingView: View {
    let rating: Int? // 0-100
    let onRatingChanged: ((Int) -> Void)?
    let interactive: Bool
    
    @State private var hoverRating: Int? = nil
    
    init(rating: Int?, interactive: Bool = false, onRatingChanged: ((Int) -> Void)? = nil) {
        self.rating = rating
        self.interactive = interactive
        self.onRatingChanged = onRatingChanged
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: starIcon(for: index))
                    .foregroundColor(starColor(for: index))
                    .font(.system(size: interactive ? 24 : 16))
                    .onTapGesture {
                        if interactive {
                            let newRating = index * 20 // Convert 1-5 to 0-100 scale
                            
                            // If tapping the current rating, clear it
                            if let currentRating = rating, abs(currentRating - newRating) <= 10 {
                                onRatingChanged?(0) // Clear rating
                            } else {
                                onRatingChanged?(newRating)
                            }
                        }
                    }
            }
            
            if let rating = rating, !interactive {
                Text(String(format: "%.1f", Double(rating) / 20.0))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
    }
    
    private func starIcon(for position: Int) -> String {
        guard let rating = hoverRating ?? rating else {
            return "star"
        }
        
        let stars = Double(rating) / 20.0 // Convert 0-100 to 0-5
        
        if Double(position) <= stars {
            return "star.fill"
        } else if Double(position) - 0.5 <= stars {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
    
    private func starColor(for position: Int) -> Color {
        guard let rating = hoverRating ?? rating else {
            return .gray
        }
        
        let stars = Double(rating) / 20.0
        return Double(position) <= stars + 0.5 ? .yellow : .gray
    }
}

// Preview
#Preview {
    VStack(spacing: 20) {
        StarRatingView(rating: 85, interactive: false)
        StarRatingView(rating: 60, interactive: false)
        StarRatingView(rating: 40, interactive: false)
        StarRatingView(rating: nil, interactive: false)
        
        Divider()
        
        StarRatingView(rating: 80, interactive: true) { newRating in
            // Preview callback - print is acceptable here
            logger.debug("New rating: \(newRating)")
        }
    }
    .padding()
}
