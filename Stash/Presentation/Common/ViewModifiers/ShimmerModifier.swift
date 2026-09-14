import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    @State private var isVisible = false
    var duration: Double = 1.5
    var bounce: Bool = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.3), location: 0.3),
                            .init(color: .white.opacity(0.7), location: 0.5),
                            .init(color: .white.opacity(0.3), location: 0.7),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geometry.size.width * 2, height: geometry.size.height * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                isVisible = true
                startAnimation()
            }
            .onDisappear {
                isVisible = false
                phase = 0
            }
    }
    
    private func startAnimation() {
        guard isVisible else { return }
        withAnimation(Animation.linear(duration: duration).repeatForever(autoreverses: bounce)) {
            phase = 1
        }
    }
}

extension View {
    func shimmering(duration: Double = 1.5, bounce: Bool = false) -> some View {
        modifier(ShimmerModifier(duration: duration, bounce: bounce))
    }
}
