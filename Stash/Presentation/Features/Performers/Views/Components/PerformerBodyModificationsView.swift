import SwiftUI

/// Displays tattoo/piercing info.
///
/// **Used by:** `PerformerDetailContentView`
struct PerformerBodyModificationsView: View {
    let performer: PerformerDetailDisplay
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Body Modifications")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            if let tattoos = performer.tattoos, !tattoos.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tattoos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(tattoos)
                        .font(.subheadline)
                }
            }
            
            if let piercings = performer.piercings, !piercings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Piercings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(piercings)
                        .font(.subheadline)
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
