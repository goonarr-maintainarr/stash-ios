import SwiftUI

struct WhisparrSearchButtons: View {
    let scene: WhisparrScene
    let isSearching: Bool
    let onAutomaticSearch: () async -> Bool
    let onInteractiveSearch: () -> Void
    
    private let whisparrPink = Color(red: 0.91, green: 0.33, blue: 0.65)
    
    var body: some View {
        HStack(spacing: 12) {
            automaticSearchButton
            interactiveSearchButton
        }
        .padding(.horizontal)
    }
    
    private var automaticSearchButton: some View {
        Button(action: {
            Task {
                if await onAutomaticSearch() {
                    HapticManager.success()
                } else {
                    HapticManager.error()
                }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                Text("Automatic Search")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(whisparrPink)
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: whisparrPink.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .allowsHitTesting(!isSearching)
    }
    
    private var interactiveSearchButton: some View {
        Button(action: {
            onInteractiveSearch()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                    .font(.body)
                Text("Interactive Search")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(whisparrPink)
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: whisparrPink.opacity(0.4), radius: 8, x: 0, y: 4)
        }

        .allowsHitTesting(!isSearching)
        .scaleEffect(isSearching ? 1.05 : 1.0)
        .animation(isSearching ? Algorithm.searchBounceAnimation : .default, value: isSearching)
    }
    
    private struct Algorithm {
        static let searchBounceAnimation = Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)
    }
}
