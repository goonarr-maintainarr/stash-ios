import SwiftUI

/// Displays alias list for a performer.
///
/// **Used by:** `PerformerDetailContentView`
struct PerformerAliasesView: View {
    let aliases: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Also Known As")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Text(aliases.joined(separator: ", "))
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .accentedCardBackground(opacity: 0.6)
        .cornerRadius(12)
        .padding(.top, 8)
    }
}
