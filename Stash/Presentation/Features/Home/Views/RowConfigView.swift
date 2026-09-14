import SwiftUI

/// Configuration view for reordering Home page rows.
struct RowConfigView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var container: DependencyContainer
    @Bindable var viewModel: HomeViewModel
    @State private var orderedCategories: [RowItem] = []
    
    /// Simple wrapper for category data
    struct RowItem: Identifiable, Equatable {
        let id: String
        let title: String
        
        static func == (lhs: RowItem, rhs: RowItem) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    /// Get tag names from categories that have tagIds (tag-based categories)
    private var followedTagNames: [String] {
        viewModel.categories
            .filter { $0.tagIds != nil && !($0.tagIds?.isEmpty ?? true) }
            .map { $0.title }
    }
    
    var body: some View {
        List {
            Section {
                NavigationLink {
                    TagSelectionView(viewModel: container.makeTagSelectionViewModel())
                } label: {
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.blue)
                        Text("Manage Followed Tags")
                    }
                }
                .listRowBackground(Color.stashCardBackground)
                .moveDisabled(true)
                .deleteDisabled(true)
            } header: {
                Text("Tags")
            } footer: {
                Text("Followed tags appear as rows on the Home page.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Show currently followed tag names
            if !followedTagNames.isEmpty {
                Section {
                    ForEach(followedTagNames, id: \.self) { tagName in
                        HStack {
                            Image(systemName: "tag")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            Text(tagName)
                                .font(.body)
                        }
                        .listRowBackground(Color.stashCardBackground)
                    }
                    .moveDisabled(true)
                    .deleteDisabled(true)
                } header: {
                    Text("Followed Tags (\(followedTagNames.count))")
                }
            }
            
            //show toggles for row categories
            Section {
                CategoryToggle(
                    title: "Random",
                    isEnabled: settings.showRandomCategory,
                    onChange: { settings.showRandomCategory = $0; refreshCategories() }
                )
                CategoryToggle(
                    title: "Recently Added",
                    isEnabled: settings.showRecentlyAddedCategory,
                    onChange: { settings.showRecentlyAddedCategory = $0; refreshCategories() }
                )
                CategoryToggle(
                    title: "Recently Released",
                    isEnabled: settings.showRecentlyReleasedCategory,
                    onChange: { settings.showRecentlyReleasedCategory = $0; refreshCategories() }
                )
                CategoryToggle(
                    title: "Top Rated",
                    isEnabled: settings.showTopRatedCategory,
                    onChange: { settings.showTopRatedCategory = $0; refreshCategories() }
                )
                CategoryToggle(
                    title: "Most Viewed",
                    isEnabled: settings.showMostViewedCategory,
                    onChange: { settings.showMostViewedCategory = $0; refreshCategories() }
                )
            } header: {
                Text("Default Categories")
            } footer: {
                Text("Toggle categories to show or hide them on the Home page.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                CategoryToggle(
                    title: "StashDB Favorites",
                    isEnabled: settings.showStashDBFavorites,
                    onChange: { settings.showStashDBFavorites = $0; refreshCategories() }
                )
            } header: {
                Text("StashDB")
            } footer: {
                Text("Shows scenes from your StashDB favorite performers and studios.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                ForEach(orderedCategories) { item in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                        
                        Text(item.title)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.stashCardBackground)
                }
                .onMove(perform: moveRow)
            } header: {
                Text("Row Order")
            } footer: {
                Text("Drag rows to reorder. Changes are saved automatically.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        }
        .scrollContentBackground(.hidden)
        .background(Color.stashBackground)
        .navigationTitle("Configure Rows")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCategories()
        }
    }
    
    // MARK: - Actions
    
    private func loadCategories() {
        // Get current categories from viewModel
        let categories = viewModel.categories
        
        // If we have a saved order, use it to sort
        let savedOrder = settings.categoryOrder
        
        if savedOrder.isEmpty {
            // No saved order - use current order from viewModel
            orderedCategories = categories.map { RowItem(id: $0.id, title: $0.title) }
        } else {
            // Sort by saved order
            var sorted: [RowItem] = []
            
            // Add items in saved order
            for id in savedOrder {
                if let cat = categories.first(where: { $0.id == id }) {
                    sorted.append(RowItem(id: cat.id, title: cat.title))
                }
            }
            
            // Add any new categories not in saved order
            for cat in categories {
                if !savedOrder.contains(cat.id) {
                    sorted.append(RowItem(id: cat.id, title: cat.title))
                }
            }
            
            orderedCategories = sorted
        }
    }
    
    private func moveRow(from source: IndexSet, to destination: Int) {
        orderedCategories.move(fromOffsets: source, toOffset: destination)
        saveOrder()
    }
    
    private func saveOrder() {
        settings.categoryOrder = orderedCategories.map { $0.id }
        NotificationCenter.default.post(name: .categoryOrderChanged, object: nil)
    }
    
    private func refreshCategories() {
        // Reload home categories and update the row list
        Task {
            await viewModel.loadCategories()
            loadCategories()
        }
    }
}

/// Toggle view with local state to avoid @Bindable crash
struct CategoryToggle: View {
    let title: String
    let isEnabled: Bool
    let onChange: (Bool) -> Void
    
    @State private var localEnabled: Bool = false
    
    var body: some View {
        Toggle(title, isOn: $localEnabled)
            .listRowBackground(Color.stashCardBackground)
            .onAppear {
                localEnabled = isEnabled
            }
            .onChange(of: localEnabled) { _, newValue in
                if newValue != isEnabled {
                    onChange(newValue)
                }
            }
    }
}
