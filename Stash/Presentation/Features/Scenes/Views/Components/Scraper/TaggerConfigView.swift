import SwiftUI

/// View provided by Stash for configuring the tagger.
///
/// **Used by:** `SceneScrapeView` (Webview context)
struct TaggerConfigView: View {
    @State var viewModel: TaggerConfigViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Search Query")) {
                    Picker("Parse Mode", selection: $viewModel.config.mode) {
                        ForEach(ParseMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    
                    NavigationLink(destination: BlacklistSettingsView(blacklist: $viewModel.config.blacklist)) {
                        HStack {
                            Text("Blacklist")
                            Spacer()
                            Text("\(viewModel.config.blacklist.count) patterns")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.stashCardBackground)
                
                Section(header: Text("Tagger Settings")) {
                    Toggle("Set Tags", isOn: $viewModel.config.setTags)
                    if viewModel.config.setTags {
                        Picker("Tag Operation", selection: $viewModel.config.tagOperation) {
                            ForEach(TagOperation.allCases, id: \.self) { op in
                                Text(op.displayName).tag(op)
                            }
                        }
                    }
                    
                    Toggle("Set Cover Image", isOn: $viewModel.config.setCoverImage)
                    Toggle("Mark Scene as Organized", isOn: $viewModel.config.markSceneAsOrganizedOnSave)
                    Toggle("Create Parent Studios", isOn: $viewModel.config.createParentStudios)
                }
                .listRowBackground(Color.stashCardBackground)
                
                Section(header: Text("Performer Filters")) {
                    NavigationLink(destination: GenderFilterView(selectedGenders: Binding(
                        get: { viewModel.config.performerGenders ?? [] },
                        set: { viewModel.config.performerGenders = $0.isEmpty ? nil : $0 }
                    ))) {
                        HStack {
                            Text("Genders")
                            Spacer()
                            if let genders = viewModel.config.performerGenders {
                                Text("\(genders.count) selected")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("All")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    NavigationLink(destination: FieldSelectionView(
                        title: "Excluded Performer Fields",
                        allFields: TaggerConfig.allPerformerFields,
                        selectedFields: $viewModel.config.excludedPerformerFields
                    )) {
                        HStack {
                            Text("Excluded Fields")
                            Spacer()
                            Text("\(viewModel.config.excludedPerformerFields.count) excluded")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.stashCardBackground)
                
                Section(header: Text("Studio Filters")) {
                    NavigationLink(destination: FieldSelectionView(
                        title: "Excluded Studio Fields",
                        allFields: TaggerConfig.allStudioFields,
                        selectedFields: $viewModel.config.excludedStudioFields
                    )) {
                        HStack {
                            Text("Excluded Fields")
                            Spacer()
                            Text("\(viewModel.config.excludedStudioFields.count) excluded")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.stashCardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(Color.stashBackground)
            .navigationTitle("Tagger Config")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.save()
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.2).ignoresSafeArea()
                        ProgressView()
                            .padding()
                            .background(Color.secondary.opacity(0.8))
                            .cornerRadius(10)
                    }
                }
            }
            .alert("Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct BlacklistSettingsView: View {
    @Binding var blacklist: [String]
    @State private var newPattern: String = ""
    
    var body: some View {
        List {
            Section(header: Text("Add Pattern")) {
                HStack {
                    TextField("Regex pattern...", text: $newPattern)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    
                    Button(action: {
                        if !newPattern.isEmpty {
                            blacklist.append(newPattern)
                            newPattern = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .listRowBackground(Color.stashCardBackground)
            
            Section(header: Text("Patterns")) {
                if blacklist.isEmpty {
                    Text("No patterns defined")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(blacklist, id: \.self) { pattern in
                        Text(pattern)
                    }
                    .onDelete { indexSet in
                        blacklist.remove(atOffsets: indexSet)
                    }
                }
            }
            .listRowBackground(Color.stashCardBackground)
        }
        .scrollContentBackground(.hidden)
        .background(Color.stashBackground)
        .navigationTitle("Blacklist")
    }
}

struct GenderFilterView: View {
    @Binding var selectedGenders: [GenderEnum]
    
    var body: some View {
        List {
            ForEach(GenderEnum.allCases, id: \.self) { gender in
                Button(action: {
                    if selectedGenders.contains(gender) {
                        selectedGenders.removeAll { $0 == gender }
                    } else {
                        selectedGenders.append(gender)
                    }
                }) {
                    HStack {
                        Text(gender.displayName)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedGenders.contains(gender) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .listRowBackground(Color.stashCardBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.stashBackground)
        .navigationTitle("Gender Filter")
    }
}

struct FieldSelectionView: View {
    let title: String
    let allFields: [String]
    @Binding var selectedFields: [String]
    
    var body: some View {
        List {
            ForEach(allFields, id: \.self) { field in
                Button(action: {
                    if selectedFields.contains(field) {
                        selectedFields.removeAll { $0 == field }
                    } else {
                        selectedFields.append(field)
                    }
                }) {
                    HStack {
                        Text(field)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedFields.contains(field) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .listRowBackground(Color.stashCardBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.stashBackground)
        .navigationTitle(title)
    }
}
