import SwiftUI
import NukeUI

/// A form for editing scene details (Title, Date, Rating, etc.).
///
/// **Navigated from:** `SceneDetailView` (Edit Button)
struct EditSceneView: View {
    @State private var viewModel: EditSceneViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: SettingsStore
    var onSave: () -> Void
    
    init(viewModel: EditSceneViewModel, onSave: @escaping () -> Void) {
        _viewModel = State(wrappedValue: viewModel)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Title", text: $viewModel.title, axis: .vertical)
                    TextField("Director", text: $viewModel.director)
                    TextField("Code", text: $viewModel.code)
                    TextField("URL", text: $viewModel.url)
                }
                .listRowBackground(Color.stashCardBackground)
                
                Section(header: Text("Description")) {
                    TextField("Description", text: $viewModel.details, axis: .vertical)
                        .lineLimit(3...)
                }
                .listRowBackground(Color.stashCardBackground)
                
                Section(header: Text("Performers")) {
                    // List current performers
                    ForEach(viewModel.performerManager.currentPerformers) { performer in
                        HStack(spacing: 12) {
                            PerformerThumbnail(
                                imagePath: performer.image_path,
                                name: performer.name ?? "Unknown",
                                settings: settings,
                                size: 120
                            )
                            
                            Text(performer.name ?? "Unknown")
                                .font(.body)
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                withAnimation {
                                    viewModel.removePerformer(id: performer.id)
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.vertical, 8)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    }
                    
                    // Search field
                    TextField("Add Performer...", text: Binding(
                        get: { viewModel.performerManager.searchText },
                        set: { viewModel.performerManager.searchText = $0 }
                    ))
                        .autocorrectionDisabled()
                    
                    if case .searching = viewModel.state {
                        ProgressView()
                    }
                    
                    // Search results
                    if !viewModel.performerManager.searchResults.isEmpty {
                        ForEach(viewModel.performerManager.searchResults) { performer in
                            Button {
                                withAnimation {
                                    viewModel.addPerformer(performer)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    PerformerThumbnail(
                                        imagePath: performer.image_path,
                                        name: performer.name ?? "Unknown",
                                        settings: settings,
                                        size: 120
                                    )
                                    
                                    Text(performer.name ?? "Unknown")
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.blue)
                                }
                                .padding(.vertical, 8)
                            }
                            .foregroundColor(.primary)
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        }
                    }
                }
                .listRowBackground(Color.stashCardBackground)
                
                Section(header: Text("Tags")) {
                    // List current tags
                    ForEach(viewModel.tagManager.currentTags) { tag in
                        HStack {
                            Text(tag.name)
                                .font(.body)
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                withAnimation {
                                    viewModel.removeTag(id: tag.id)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    
                    // Search field
                    TextField("Add Tag...", text: Binding(
                        get: { viewModel.tagManager.searchText },
                        set: { viewModel.tagManager.searchText = $0 }
                    ))
                        .autocorrectionDisabled()
                    
                    if case .searchingTags = viewModel.state {
                        ProgressView()
                    }
                    
                    // Search results
                    if !viewModel.tagManager.searchResults.isEmpty {
                        ForEach(viewModel.tagManager.searchResults) { tag in
                            Button {
                                withAnimation {
                                    viewModel.addTag(tag)
                                }
                            } label: {
                                HStack {
                                    Text(tag.name)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                .listRowBackground(Color.stashCardBackground)
                
                Section(header: Text("O History")) {
                    ForEach(viewModel.historyManager.oHistory, id: \.self) { timestamp in
                        HStack {
                            Text(formatHistoryDate(timestamp))
                                .font(.body)
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                withAnimation {
                                    viewModel.removeOHistory(at: timestamp)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    
                    if viewModel.historyManager.oHistory.isEmpty {
                        Text("No O history")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .listRowBackground(Color.stashCardBackground)
                
                Section(header: Text("Play History")) {
                    ForEach(viewModel.historyManager.playHistory, id: \.self) { timestamp in
                        HStack {
                            Text(formatHistoryDate(timestamp))
                                .font(.body)
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                withAnimation {
                                    viewModel.removePlayHistory(at: timestamp)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    
                    if viewModel.historyManager.playHistory.isEmpty {
                        Text("No play history")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .listRowBackground(Color.stashCardBackground)
            }
            .navigationTitle("Edit Scene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                onSave()
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.state == .saving)
                }
            }
            .overlay {
                if case .saving = viewModel.state {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
                }
            }
            .alert("Error", isPresented: .constant({ if case .error = viewModel.state { return true } else { return false } }())) {
                Button("OK", role: .cancel) { viewModel.clearError() }
            } message: {
                if case .error(let msg) = viewModel.state {
                    Text(msg)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.stashBackground)
            .listRowBackground(Color.stashCardBackground)
        }
    }
    
    private func formatHistoryDate(_ timestamp: String) -> String {
        // Parse ISO8601 timestamp and format for display
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: timestamp) {
            return formatDate(date)
        }
        
        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: timestamp) {
            return formatDate(date)
        }
        
        // Fallback to raw timestamp if parsing fails
        return timestamp
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let suffix = daySuffix(for: day)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d'\(suffix)', yyyy 'at' h:mma"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        return formatter.string(from: date)
    }
    
    private func daySuffix(for day: Int) -> String {
        switch day {
        case 1, 21, 31: return "st"
        case 2, 22: return "nd"
        case 3, 23: return "rd"
        default: return "th"
        }
    }
}
