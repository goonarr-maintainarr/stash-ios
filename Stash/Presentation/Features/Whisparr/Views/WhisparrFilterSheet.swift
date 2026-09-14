import SwiftUI

/// Filter configuration for Whisparr lists.
///
/// **Presented by:** `WhisparrSceneListView`
struct WhisparrFilterSheet: View {
    @State var viewModel: WhisparrSceneListViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Sort By") {
                    ForEach(WhisparrSortType.allCases) { sortType in
                        Button {
                            viewModel.sortType = sortType
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack {
                                Label(sortType.displayName, systemImage: sortType.iconName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if viewModel.sortType == sortType {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }
                
                Section("Direction") {
                    Picker("Direction", selection: $viewModel.sortDirection) {
                        Label("Ascending", systemImage: "arrowtriangle.up").tag("ASC")
                        Label("Descending", systemImage: "arrowtriangle.down").tag("DESC")
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                
                Section("Filter") {
                    ForEach(WhisparrFilterType.allCases) { filterType in
                        Button {
                            viewModel.filterType = filterType
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            // Close sheet on filter selection? Maybe keep open for multiple changes?
                            // Usually applying sort closes it? "Make the whole menu pop up" implies quick action.
                            // But a sheet implies configuration. I'll add a "Done" button.
                        } label: {
                            HStack {
                                Label(filterType.displayName, systemImage: filterType.iconName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if viewModel.filterType == filterType {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sort & Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
