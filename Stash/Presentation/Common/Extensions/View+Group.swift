
import SwiftUI

extension View {
    /// Applies a transformation to the view.
    /// Useful for conditional modifiers or grouping logic.
    @ViewBuilder
    func group<Content: View>(@ViewBuilder transform: (Self) -> Content) -> some View {
        transform(self)
    }
}
