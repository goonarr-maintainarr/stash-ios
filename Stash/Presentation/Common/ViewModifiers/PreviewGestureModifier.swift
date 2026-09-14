import SwiftUI

struct PreviewGestureModifier: ViewModifier {
    let enabled: Bool
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        if enabled {
                            HapticManager.mediumImpact()
                            action()
                        }
                    }
            )
    }
}

extension View {
    /// Adds a long-press gesture to trigger scene previews
    func onPreviewGesture(enabled: Bool = true, perform action: @escaping () -> Void) -> some View {
        modifier(PreviewGestureModifier(enabled: enabled, action: action))
    }
}
