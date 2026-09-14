import SwiftUI

/// Displays tags associated with the performer.
///
/// **Used by:** `PerformerDetailContentView`
struct PerformerTagsView: View {
    let tags: [Performer.PerformerTag]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            FlowLayout(spacing: 6) {
                ForEach(tags) { tag in
                    Text(tag.name)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .accentedCardBackground(opacity: 0.6)
        .cornerRadius(12)
        .padding(.top, 8)
    }
}


