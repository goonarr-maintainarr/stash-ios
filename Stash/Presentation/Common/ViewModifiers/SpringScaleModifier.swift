import SwiftUI

/// A view modifier that adds a spring-based scale animation on tap.
/// The view scales down slightly when pressed, then bounces back.
struct SpringScaleModifier: ViewModifier {
    let action: () -> Void
    let scale: CGFloat
    let response: Double
    let dampingFraction: Double
    
    @State private var isPressed = false
    
    init(
        scale: CGFloat = 0.96,
        response: Double = 0.3,
        dampingFraction: Double = 0.6,
        action: @escaping () -> Void
    ) {
        self.scale = scale
        self.response = response
        self.dampingFraction = dampingFraction
        self.action = action
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.spring(response: response, dampingFraction: dampingFraction), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            HapticManager.lightImpact()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        action()
                    }
            )
    }
}

extension View {
    /// Adds a spring-based scale animation that triggers an action on tap.
    /// - Parameters:
    ///   - scale: The scale factor when pressed (default: 0.96)
    ///   - response: Spring response time (default: 0.3)
    ///   - dampingFraction: Spring damping (default: 0.6)
    ///   - action: The action to perform on tap
    func springScale(
        scale: CGFloat = 0.96,
        response: Double = 0.3,
        dampingFraction: Double = 0.6,
        action: @escaping () -> Void
    ) -> some View {
        modifier(SpringScaleModifier(
            scale: scale,
            response: response,
            dampingFraction: dampingFraction,
            action: action
        ))
    }
}
