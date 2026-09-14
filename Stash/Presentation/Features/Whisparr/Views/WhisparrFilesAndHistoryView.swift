import SwiftUI
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrFilesAndHistoryView")

/// Displays files and grab history for a Whisparr item.
///
/// **Navigated from:** `WhisparrSceneDetailView`
struct WhisparrFilesAndHistoryView: View {
    let movie: WhisparrScene
    @State private var viewModel: WhisparrFilesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showDeleteConfirmation = false
    
    init(movie: WhisparrScene, viewModel: WhisparrFilesViewModel) {
        self.movie = movie
        _viewModel = State(wrappedValue: viewModel)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // File Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("File Details")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if let file = movie.sceneFile {
                        WhisparrFileCard(file: file) {
                            showDeleteConfirmation = true
                        }
                        .padding(.horizontal)
                    } else {
                        HStack {
                            Image(systemName: "film")
                                .foregroundColor(.secondary)
                            Text("No file available")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.stashCardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                
                // History Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("History")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    switch viewModel.historyState {
                    case .loading:
                        ProgressView()
                            .padding()
                            .frame(maxWidth: .infinity)
                    case .error(let error):
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .padding()
                    case .empty:
                        Text("No history events")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.stashCardBackground)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    case .loaded(let events):
                        LazyVStack(spacing: 12) {
                            ForEach(events) { event in
                                WhisparrHistoryRow(event: event)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.stashBackground)
        .navigationTitle("Files & History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchHistory()
        }
        .refreshable {
            await viewModel.fetchHistory()
        }
        .alert("Delete File", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.deleteFile() {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this file? This cannot be undone.")
        }
        .overlay(
            Group {
                if let error = viewModel.deleteError {
                    Text(error)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(8)
                        .padding()
                        // Easy way to dismiss error overlay
                        .onTapGesture { viewModel.deleteError = nil }
                }
            },
            alignment: .bottom
        )
    }
}
