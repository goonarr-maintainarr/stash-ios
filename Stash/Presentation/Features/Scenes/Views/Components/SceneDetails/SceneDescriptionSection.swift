import SwiftUI

/// A reusable expandable description section for scene detail views.
/// Shows a "Description" headline with expandable text content in a card style.
/// Expandable description text View.
///
/// **Used by:** `SceneDetailView`
struct SceneDescriptionSection: View {
    let text: String?
    @State private var isExpanded = false
    
    var body: some View {
        if let text = text, !text.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Description")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(text)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 4)
                        .animation(.easeInOut, value: isExpanded)
                    
                    if !isExpanded {
                        Text("Read more")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .padding(.top, 4)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.stashCardBackground)
                .cornerRadius(12)
            }
            .onTapGesture {
                withAnimation {
                    isExpanded.toggle()
                }
            }
        }
    }
}
