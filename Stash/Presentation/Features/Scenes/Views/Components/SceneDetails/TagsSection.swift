import SwiftUI

/// A tag cloud section.
///
/// **Used by:** `SceneDetailView`
struct TagsSection<T: TagDisplayable>: View {
    let tags: [T]
    var heroColor: Color?
    
    private var tagColor: Color {
        heroColor ?? .blue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Tags")
                    .font(.headline)
                if !tags.isEmpty {
                    HStack(spacing: 6) {
                        Text("•")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Image("TagIcon")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.white)
                            .frame(width: 14, height: 14)
                        Text("\(tags.count)")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(tags) { tag in
                        Text(tag.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(tagColor.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(tagColor.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
