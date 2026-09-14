import SwiftUI

/// A reusable toast overlay that slides up from the bottom of the screen.
/// Used for success messages, confirmations, etc.
///
/// **Used by:**
/// - `MainTabView` (via `ToastManager`)
struct ToastOverlay: View {
    let isShowing: Bool
    let message: String
    var icon: String = "checkmark.circle.fill"
    var iconColor: Color = .green
    
    var body: some View {
        Group {
            if isShowing {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .foregroundColor(iconColor)
                            .font(.title2)
                        Text(message)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.stashCardBackground)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    )
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isShowing)
            }
        }
    }
}

// MARK: - View Modifier

extension View {
    /// Overlays a toast message on the view.
    func toast(
        isShowing: Bool,
        message: String,
        icon: String = "checkmark.circle.fill",
        iconColor: Color = .green
    ) -> some View {
        self.overlay(
            ToastOverlay(
                isShowing: isShowing,
                message: message,
                icon: icon,
                iconColor: iconColor
            )
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.stashBackground
        ToastOverlay(isShowing: true, message: "Added to Whisparr")
    }
}
