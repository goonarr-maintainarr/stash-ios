import SwiftUI

struct WhisparrHistoryRow: View {
    let event: WhisparrHistoryEvent
    @State private var showDetails = false
    
    var iconName: String {
        switch event.eventType {
        case .grabbed: return "arrow.down.circle.fill"
        case .downloadFolderImported: return "folder.fill"
        case .downloadFailed: return "exclamationmark.triangle.fill"
        case .deleted: return "trash.fill"
        case .renamed: return "pencil"
        case .ignored: return "eye.slash.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch event.eventType {
        case .grabbed: return .blue
        case .downloadFolderImported: return .green
        case .downloadFailed: return .red
        case .deleted: return .orange
        case .renamed: return .purple
        case .ignored: return .gray
        case .unknown: return .secondary
        }
    }
    
    var title: String {
        switch event.eventType {
        case .grabbed: return "Grabbed"
        case .downloadFolderImported: return "Imported"
        case .downloadFailed: return "Download Failed"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .ignored: return "Ignored"
        case .unknown: return "Unknown Event"
        }
    }
    
    var body: some View {
        Button(action: {
            showDetails = true
        }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title Row
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(formatDate(event.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Source Title (File Name usually)
                    if let source = event.sourceTitle {
                        Text(source)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Quality • Indexer
                    if let quality = event.quality {
                        HStack {
                            Text(quality.quality.name)
                                .fontWeight(.medium)
                            
                            if let indexer = event.data?["indexer"]?.flatMap({ $0 }) {
                                Text("•")
                                Text(indexer)
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.stashCardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetails) {
             WhisparrHistoryDetailSheet(event: event)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct WhisparrHistoryDetailSheet: View {
    let event: WhisparrHistoryEvent
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if event.eventType == .downloadFolderImported {
                importedEventView
            } else if event.eventType == .grabbed {
                grabbedEventView
            } else {
                genericEventView
            }
        }
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.stashBackground.opacity(0.5))
    }
    
    private var detents: Set<PresentationDetent> {
        if event.eventType == .downloadFolderImported {
            return [.fraction(0.35)]
        } else if event.eventType == .grabbed {
            return [.fraction(0.7)]
        } else {
            return [.fraction(0.45)]
        }
    }
    
    // MARK: - Imported View
    private var importedEventView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Folder Imported")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(event.date.formatted(date: .long, time: .shortened))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                
                Text(importedDescription)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var importedDescription: String {
        let client = event.data?["downloadClient"]?.flatMap { $0 } ?? 
                     event.data?["downloadClientName"]?.flatMap { $0 } ?? 
                     "Download Client"
        return "Scene downloaded successfully and imported from \(client)"
    }
    
    // MARK: - Grabbed View
    private var grabbedEventView: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Large Header (Matches Imported View)
                VStack(spacing: 8) {
                    Text("Release Grabbed")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(event.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Description (Moved closer to header with padding)
                Text(grabbedDescription)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 16)
                    .padding(.horizontal)
                
                Divider()
                
                // Details (Compact)
                VStack(spacing: 12) {
                    // Custom Formats Score
                    if let score = event.data?["customFormatScore"]?.flatMap({ $0 }), score != "0" {
                         HStack {
                             Text("Score")
                                 .font(.subheadline)
                                 .foregroundColor(.secondary)
                             Spacer()
                             Text(score)
                                 .font(.subheadline)
                                 .fontWeight(.bold)
                                 .padding(.horizontal, 6)
                                 .padding(.vertical, 2)
                                 .background(Color.blue.opacity(0.2))
                                 .foregroundColor(.blue)
                                 .cornerRadius(4)
                         }
                         Divider()
                    }
                    
                    // Dynamic Details with Dividers
                    if let indexer = event.data?["indexer"]?.flatMap({ $0 }) {
                        compactDetailRow("Indexer", indexer)
                    }
                    
                    if let flags = event.data?["indexerFlags"]?.flatMap({ $0 }), flags != "0" {
                        compactDetailRow("Flags", flags)
                    }
                    
                    if let source = event.data?["releaseSource"]?.flatMap({ $0 }) {
                        compactDetailRow("Source", source)
                    }
                    
                    if let matchType = event.data?["movieMatchType"]?.flatMap({ $0 }) {
                        compactDetailRow("Match Type", matchType)
                    }
                    
                    if let releaseType = event.data?["releaseType"]?.flatMap({ $0 }) {
                         compactDetailRow("Release Type", releaseType)
                    }
                    
                    if let group = event.data?["releaseGroup"]?.flatMap({ $0 }) {
                        compactDetailRow("Release Group", group)
                    }
                    
                    if let age = event.data?["age"]?.flatMap({ $0 }) {
                        compactDetailRow("Age", "\(age) days")
                    } else if let ageHours = event.data?["ageHours"]?.flatMap({ $0 }), let hours = Double(ageHours) {
                        compactDetailRow("Age", String(format: "%.1f hours", hours))
                    }
                    
                    if let sizeStr = event.data?["size"]?.flatMap({ $0 }), let size = Int64(sizeStr) {
                         compactDetailRow("File Size", ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    }
                    
                    if let published = event.data?["publishedDate"]?.flatMap({ $0 }), let date = ISO8601DateFormatter().date(from: published) {
                        compactDetailRow("Published", date.formatted(date: .abbreviated, time: .shortened))
                    }
                    
                    if let link = grabbedLink, let url = URL(string: link) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Link")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Link(destination: url) {
                                    Image(systemName: "link")
                                }
                            }
                            Divider()
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding()
            }
            .background(Color.clear)
            .navigationBarHidden(true)
        }
    }
    
    private func compactDetailRow(_ label: String, _ value: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.trailing)
            }
            Divider()
        }
    }
    
    private var grabbedDescription: String {
        let indexer = event.data?["indexer"]?.flatMap { $0 } ?? "Unknown Indexer"
        let client = event.data?["downloadClient"]?.flatMap { $0 } ?? 
                     event.data?["downloadClientName"]?.flatMap { $0 } ?? 
                     "Download Client"
        return "Movie grabbed from \(indexer) and sent to \(client)."
    }
    
    private var grabbedLink: String? {
        return event.data?["nzbInfoUrl"]?.flatMap({ $0 }) ?? 
               event.data?["infoUrl"]?.flatMap({ $0 }) ??
               event.data?["downloadUrl"]?.flatMap({ $0 })
    }

    // MARK: - Generic View
    private var genericEventView: some View {
        NavigationView {
            List {
                Section("Event Details") {
                    EventDetailRow(label: "Type", value: event.eventType.rawValue.capitalized)
                    EventDetailRow(label: "Date", value: event.date.formatted(date: .long, time: .standard))
                    if let source = event.sourceTitle {
                        EventDetailRow(label: "Source Title", value: source)
                    }
                }
                
                if let quality = event.quality {
                    Section("Quality") {
                         EventDetailRow(label: "Quality", value: quality.quality.name)
                    }
                }
                
                if let data = event.data, !data.isEmpty {
                    Section("Data") {
                        ForEach(Array(data.keys.sorted()), id: \.self) { key in
                            if let value = data[key] {
                                EventDetailRow(label: key, value: value ?? "null")
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("History Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct EventDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
        .padding(.vertical, 2)
    }
}
