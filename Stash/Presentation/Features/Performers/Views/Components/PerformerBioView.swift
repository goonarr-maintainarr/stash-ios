import SwiftUI

/// Displays expandable bio text.
///
/// **Used by:** `PerformerDetailContentView`
struct PerformerBioView: View {
    let details: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("About")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Text(details)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .accentedCardBackground(opacity: 0.6)
        .cornerRadius(12)
        .padding(.top, 8)
    }
}
