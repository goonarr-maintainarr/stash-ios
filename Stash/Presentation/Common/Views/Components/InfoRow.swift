import SwiftUI

/// A reusable row for displaying labelled information.
///
/// **Used by:**
/// - `SceneDetailView` (File info, specs)
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}
