import SwiftUI

/// A reusable toggle row with a description subtitle.
///
/// **Used by:** `SettingsView`
struct DescriptionToggleRow: View {
    let title: String
    let description: String?
    @Binding var isOn: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(title, isOn: $isOn)
            
            if let description = description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
