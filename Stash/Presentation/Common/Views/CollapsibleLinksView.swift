import SwiftUI
import NukeUI

/// Displays execution links (social media, official site) with favicons.
///
/// **Used by:** `PerformerDetailContentView`, `SceneAdditionalMetadataView`
struct CollapsibleLinksView: View {
    let urls: [String]
    let title: String
    let showBackground: Bool
    @State private var isExpanded = false
    
    init(urls: [String], title: String = "Links", showBackground: Bool = true) {
        self.urls = urls
        self.title = title
        self.showBackground = showBackground
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation { isExpanded.toggle() }
            }) {
                HStack {
                    if !showBackground {
                        Text(title)
                            .font(.subheadline) // Regular font for metadata
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                    } else {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    
                    if let firstUrl = urls.first {
                        HStack(spacing: 6) {
                            faviconView(for: firstUrl, size: 16)
                            Text(labelForUrl(firstUrl))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .padding(.leading, showBackground ? 8 : 0) // No extra padding needed if title is fixed width 80 (standard HStack spacing applies)
                    }
                    
                    Spacer()
                    
                    if !isExpanded && urls.count > 1 {
                        HStack(spacing: -4) {
                            ForEach(Array(urls.dropFirst().prefix(4).enumerated()), id: \.element) { index, urlString in
                                faviconView(for: urlString, size: 20)
                                    .padding(2)
                                    .background(Color.white) // Optional: ring effect for overlap
                                    .clipShape(Circle())
                                    .zIndex(Double(5 - index)) // Stack order
                            }
                        }
                        .padding(.trailing, 8)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(urls.enumerated()), id: \.element) { index, urlString in
                        if let url = URL(string: urlString) {
                            Link(destination: url) {
                                HStack(spacing: 12) {
                                    faviconView(for: urlString, size: 20)
                                        .cornerRadius(4)
                                    
                                    Text(labelForUrl(urlString))
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            
                            if index < urls.count - 1 {
                                Divider()
                                    .padding(.leading, 44) // Indent past icon
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .accentedCardBackground(opacity: showBackground ? 0.6 : 0)
        .cornerRadius(12)
        .padding(.top, 8)
    }
    
    private func faviconView(for urlString: String, size: CGFloat) -> some View {
        LazyImage(url: getFaviconURL(for: urlString)) { state in
            if let image = state.image {
                image.resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "globe")
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
    
    private func getFaviconURL(for urlString: String) -> URL? {
        guard let host = URL(string: urlString)?.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64")
    }
    
    private func labelForUrl(_ url: String) -> String {
        let lowercased = url.lowercased()
        if lowercased.contains("twitter.com") || lowercased.contains("x.com") {
            return "Twitter/X"
        } else if lowercased.contains("instagram.com") {
            return "Instagram"
        } else if lowercased.contains("onlyfans.com") {
            return "OnlyFans"
        } else if lowercased.contains("pornhub.com") {
            return "Pornhub"
        } else if lowercased.contains("reddit.com") {
            return "Reddit"
        } else if lowercased.contains("tiktok.com") {
            return "TikTok"
        } else if let host = URL(string: url)?.host {
            return host.replacingOccurrences(of: "www.", with: "")
        } else {
            return url
        }
    }
}
