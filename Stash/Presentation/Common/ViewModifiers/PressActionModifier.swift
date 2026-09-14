import SwiftUI

/// A modifier that handles a tap action while providing a press state for animations.
/// This separates the action (tap) from the press state (long press), preventing immediate
/// action triggering on touch down, which allows other gestures (like scrolling or long-press preview) to work.
struct PressActionModifier: ViewModifier {
    @Binding var isPressed: Bool
    let action: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if let action = action {
                    HapticManager.lightImpact()
                    action()
                }
            }
            .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    isPressed = pressing
                }
            }, perform: {
                // Intentionally empty.
                // This gesture is primarily for the "pressing" state.
                // Actual long-press actions (like preview) should be handled by a separate modifier/gesture
                // that runs simultaneously or with higher priority if needed.
            })
    }
}

extension View {
    /// Adds a tap action with a press animation state.
    /// - Parameters:
    ///   - isPressed: Binding to control the pressed state (e.g., for scaling).
    ///   - perform: The action to perform on tap.
    func onPress(isPressed: Binding<Bool>, perform action: (() -> Void)?) -> some View {
        modifier(PressActionModifier(isPressed: isPressed, action: action))
    }
}
