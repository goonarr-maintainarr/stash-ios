import SwiftUI

/// A reusable "Add to Whisparr" button with consistent styling across the app.
/// A split-button for adding a scene to Whisparr (or viewing it if already added).
///
/// **Used by:** `SceneDetailView`
struct AddToWhisparrButton: View {
    let isLoading: Bool
    let isDisabled: Bool
    let action: () async -> Bool
    
    @Environment(\.dismiss) private var dismiss
    
    private let whisparrPink = Color(red: 0.91, green: 0.33, blue: 0.65)
    
    var body: some View {
        Button {
            HapticManager.lightImpact()
            Task {
                if await action() {
                    await MainActor.run { dismiss() }
                }
            }
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                }
                Text("Add to Whisparr")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(whisparrPink)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isLoading || isDisabled)
        .padding(.horizontal)
        .shadow(color: whisparrPink.opacity(0.4), radius: 8, x: 0, y: 4)
    }
}
