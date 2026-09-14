import SwiftUI

struct SelectionRow<Content: View>: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    let content: () -> Content
    
    init(title: String, isSelected: Bool, action: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
        self.content = content
    }
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .fontWeight(.bold)
                    
                    content()
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
