import SwiftUI

/// Displays execution links (social media, official site) with favicons.
///
/// **Used by:** `PerformerDetailContentView`
struct PerformerLinksView: View {
    let urls: [String]
    
    var body: some View {
        CollapsibleLinksView(urls: urls, title: "Links")
    }
}
