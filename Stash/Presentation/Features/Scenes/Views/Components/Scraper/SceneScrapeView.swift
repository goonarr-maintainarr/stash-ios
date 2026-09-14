import SwiftUI
import NukeUI

/// Dialog for searching and selecting a scraper source.
///
/// **Presented by:** `SceneDetailView`
struct SceneScrapeView: View {
    var viewModel: SceneDetailViewModel
    @Binding var isPresented: Bool
    
    // Removed sheetDetent as it's full page now
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedStashBox: StashBox?
    @State private var searchText: String = ""
    @State private var showConfigSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Input Section
                VStack(alignment: .leading, spacing: 24) {
                    // Section: Select Scraper
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Scraper")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        if viewModel.stashBoxes.isEmpty {
                            Text("No StashBoxes configured")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(viewModel.stashBoxes) { box in
                                Button {
                                    selectedStashBox = box
                                } label: {
                                    HStack {
                                        Circle()
                                            .strokeBorder(Color.gray, lineWidth: 2)
                                            .background(Circle().fill(selectedStashBox == box ? Color.blue : Color.clear))
                                            .frame(width: 20, height: 20)
                                            .padding(.trailing, 8)
                                        
                                        VStack(alignment: .leading) {
                                            Text(box.name)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            Text(box.endpoint)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.stashCardBackground)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedStashBox == box ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Section: Search Query
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Search Query")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        TextField("Enter title or query...", text: $searchText)
                            .padding(12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    
                    // Section: Actions
                    VStack(spacing: 12) {
                        Button {
                            guard let box = selectedStashBox else { return }
                            Task {
                                await viewModel.scrapeScene(using: box, query: searchText)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Search")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedStashBox == nil ? Color.gray.opacity(0.3) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(selectedStashBox == nil)
                        .padding(.horizontal)
                        
                        Button {
                            guard let box = selectedStashBox else { return }
                            Task {
                                await viewModel.scrapeSceneByFragment(using: box)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "puzzlepiece.extension")
                                Text("Scrape by Fragment")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedStashBox == nil ? Color.gray.opacity(0.3) : Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(selectedStashBox == nil)
                        .padding(.horizontal)
                    }
                }
                .padding(.top)

                // Results Section
                if viewModel.scrapingState.isScraping {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Scraping Scene...")
                            .font(.headline)
                    }
                    .padding(.top, 20)
                } else if !viewModel.scrapedResults.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Divider()
                        
                        Text("Results (\(viewModel.scrapedResults.count))")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        ForEach(viewModel.scrapedResults) { result in
                            NavigationLink(destination: ScrapeResultReviewView(
                                result: result, 
                                currentScene: viewModel.scene!, 
                                viewModel: viewModel,
                                sheetDetent: .constant(.large), // Dummy binding as it's no longer used for detents
                                onComplete: { isPresented = false }
                            )) {
                                ScrapeResultCard(result: result)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .navigationTitle("Scrape Scene")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.stashBackground)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showConfigSheet = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showConfigSheet, onDismiss: {
            // Re-generate query if it was based on config rules
            if searchText.isEmpty || searchText == viewModel.generateSearchQuery() {
                 searchText = viewModel.generateSearchQuery()
            }
        }) {
            TaggerConfigView(viewModel: TaggerConfigViewModel(
                repository: viewModel.sceneRepository,
                initialConfig: viewModel.taggerConfig
            ))
        }
        .onAppear {
            if searchText.isEmpty {
                searchText = viewModel.generateSearchQuery()
            }
            if selectedStashBox == nil {
                selectedStashBox = viewModel.stashBoxes.first
            }
        }
    }
    
    private func formatDateWithOrdinal(_ input: String) -> String {
        let candidates: [String] = [
            "yyyy-MM-dd", "yyyy/MM/dd", "MM-dd-yy", "MM/dd/yy", "MM-dd-yyyy", "MM/dd/yyyy"
        ]
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        
        var date: Date?
        if let d = isoFormatter.date(from: input) {
            date = d
        } else {
            for pattern in candidates {
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US_POSIX")
                df.dateFormat = pattern
                if let d = df.date(from: input) { date = d; break }
            }
        }
        
        guard let validDate = date else { return input }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let monthDay = formatter.string(from: validDate)
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let year = yearFormatter.string(from: validDate)
        
        let day = Calendar.current.component(.day, from: validDate)
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        return "\(monthDay)\(suffix), \(year)"
    }
}

struct ScrapeResultCard: View {
    let result: ScrapedScene
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            GeometryReader { geometry in
                if let imageString = result.image {
                    if imageString.hasPrefix("http"), let url = URL(string: imageString) {
                        LazyImage(url: url) { state in
                            if let image = state.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                                     .frame(width: geometry.size.width, height: geometry.size.height)
                                     .clipped()
                            } else {
                                Rectangle().fill(Color.gray.opacity(0.3))
                            }
                        }
                    } else {
                         // Try Base64
                         let base64String = imageString.components(separatedBy: ",").last ?? imageString
                         if let data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters),
                            let uiImage = UIImage(data: data) {
                             Image(uiImage: uiImage)
                                 .resizable()
                                 .aspectRatio(contentMode: .fill)
                                 .frame(width: geometry.size.width, height: geometry.size.height)
                                 .clipped()
                         } else {
                             Rectangle().fill(Color.gray.opacity(0.3))
                         }
                    }
                } else {
                     Rectangle().fill(Color.gray.opacity(0.3))
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            
            // Info Section
            VStack(alignment: .leading, spacing: 4) {
                 Text(result.title ?? "Unknown Title")
                     .font(.headline)
                     .lineLimit(2)
                     .foregroundColor(.primary)
                
                HStack {
                    if let studio = result.studio?.name {
                         Text(studio)
                             .font(.subheadline)
                             .foregroundColor(.blue) // Match SceneCard studio color (could be white in SceneCard but usually blue for links)
                             .lineLimit(1)
                    }
                    
                    if let date = result.date {
                        if result.studio != nil {
                            Text("•")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Text(formatDateWithOrdinal(date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let remoteId = result.remote_site_id {
                    Text("ID: \(remoteId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                        .textSelection(.enabled)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.stashCardBackground)
        .cornerRadius(12)
    }
    
    private func formatDateWithOrdinal(_ input: String) -> String {
        let candidates: [String] = [
            "yyyy-MM-dd", "yyyy/MM/dd", "MM-dd-yy", "MM/dd/yy", "MM-dd-yyyy", "MM/dd/yyyy"
        ]
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        
        var date: Date?
        if let d = isoFormatter.date(from: input) {
            date = d
        } else {
            for pattern in candidates {
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US_POSIX")
                df.dateFormat = pattern
                if let d = df.date(from: input) { date = d; break }
            }
        }
        
        guard let validDate = date else { return input }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let monthDay = formatter.string(from: validDate)
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let year = yearFormatter.string(from: validDate)
        
        let day = Calendar.current.component(.day, from: validDate)
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        return "\(monthDay)\(suffix), \(year)"
    }
}
