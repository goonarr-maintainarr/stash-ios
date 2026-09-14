import SwiftUI

/// A custom layout that arranges subviews in a flow (left-to-right, then next line).
/// Equivalent to a CSS flex-wrap container.
///
/// **Used by:**
/// - `SceneDetailView` (Tags list)
/// - `PerformerDetailView` (Tags/Aliases)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // If the proposal width is infinite or nil, we can't really "wrap", so we just measure the max width if we were to lay it all out linearly or just return zero.
        // However, for FlowLayout to work inside a ScrollView or list, it usually receives a finite width proposal.
        let containerWidth = proposal.width ?? .infinity
        
        var height: CGFloat = 0
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentRowWidth + size.width > containerWidth && currentRowWidth > 0 {
                // Wrap to next line
                height += currentRowHeight + spacing
                currentRowWidth = 0
                currentRowHeight = 0
            }
            
            currentRowWidth += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
        
        height += currentRowHeight
        
        // IMPORTANT: We must return the proposed width, otherwise the parent might collapse us if we return a smaller width (tight-fitting).
        // Returning proposal.width ensures we fill the horizontal space available, similar to a block element.
        return CGSize(width: proposal.width ?? currentRowWidth, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var currentRowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            // Check if we need to break to the next line
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += currentRowHeight + spacing
                currentRowHeight = 0
            }
            
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            
            x += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}
