import SwiftUI

/// Displays extra metadata like Organizer URL and O-Counter.
///
/// **Used by:** `SceneDetailView`
struct SceneAdditionalMetadataView: View {
    let director: String?
    let code: String?
    let url: String?
    let urls: [String]?
    let createdAt: String?
    let updatedAt: String?
    
    // Pre-compute which fields are non-empty for O(1) divider checks
    private var hasDirector: Bool { !(director?.isEmpty ?? true) }
    private var hasCode: Bool { !(code?.isEmpty ?? true) }
    
    private var displayUrls: [String] {
        if let urls = urls, !urls.isEmpty { return urls }
        if let url = url, !url.isEmpty { return [url] }
        return []
    }
    
    private var hasUrls: Bool { !displayUrls.isEmpty }
    private var hasCreatedAt: Bool { !(createdAt?.isEmpty ?? true) }
    private var hasUpdatedAt: Bool { !(updatedAt?.isEmpty ?? true) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.headline)
            
            VStack(spacing: 0) {
                if hasDirector, let director = director {
                    row(label: "Director", value: director)
                    if hasCode || hasUrls || hasCreatedAt || hasUpdatedAt {
                        divider
                    }
                }
                
                if hasCode, let code = code {
                    row(label: "Code", value: code, isMonospace: true)
                    if hasUrls || hasCreatedAt || hasUpdatedAt {
                        divider
                    }
                }
                
                if hasUrls {
                    if displayUrls.count > 1 {
                        CollapsibleLinksView(urls: displayUrls, title: "URLs", showBackground: false)
                            .padding(.horizontal, 4)
                        
                        if hasCreatedAt || hasUpdatedAt {
                            divider
                        }
                    } else if let urlString = displayUrls.first {
                        urlRow(label: "URL", urlString: urlString)
                        if hasCreatedAt || hasUpdatedAt {
                            divider
                        }
                    }
                }
                
                if hasCreatedAt, let created = createdAt {
                     row(label: "Created", value: DateFormatters.formatTimestamp(created))
                     if hasUpdatedAt {
                         divider
                     }
                }
                
                if hasUpdatedAt, let updated = updatedAt {
                    row(label: "Updated", value: DateFormatters.formatTimestamp(updated))
                }
            }
            .background(Color.stashCardBackground)
            .cornerRadius(12)
        }
    }
    
    private func row(label: String, value: String, isMonospace: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(isMonospace ? .system(.body, design: .monospaced) : .body)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
        }
        .padding()
    }
    
    private func urlRow(label: String, urlString: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            if let url = URL(string: urlString) {
                Link(destination: url) {
                    Text(urlString)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.blue)
                }
            } else {
                Text(urlString)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var divider: some View {
        Divider()
            .padding(.leading, 16)
    }
    
}
