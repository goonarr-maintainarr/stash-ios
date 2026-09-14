import SwiftUI
import NukeUI

/// A form for editing performer details (name, stats, image, etc.).
///
/// **Navigated from:** `PerformerDetailView` (Edit Button)
struct EditPerformerView: View {
    @State var viewModel: EditPerformerViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        NavigationView {
            Form {
                // Image Swiper Section (moved to top)
                Section {
                    VStack(spacing: 8) {
                        TabView(selection: $viewModel.selectedImageIndex) {
                            // Current Image (Index 0)
                            if let imagePath = viewModel.currentImagePath,
                               let url = settings.createImageUrl(path: imagePath) {
                                LazyImage(url: url) { state in
                                    if let image = state.image {
                                        image.resizable()
                                            .aspectRatio(contentMode: .fit)
                                    } else if state.isLoading {
                                        ProgressView()
                                    } else {
                                        Color.gray.opacity(0.3)
                                    }
                                }
                                .tag(0)
                            } else {
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .padding(40)
                                    .foregroundColor(.gray)
                                    .background(Color.gray.opacity(0.1))
                                    .tag(0)
                            }
                            
                            // Fetched Images (Index 1+)
                            ForEach(Array(viewModel.stashBoxImages.enumerated()), id: \.offset) { index, image in
                                if let url = URL(string: image.url) {
                                    LazyImage(url: url) { state in
                                        if let img = state.image {
                                            img.resizable()
                                                .aspectRatio(contentMode: .fit)
                                        } else if state.isLoading {
                                            ProgressView()
                                        } else {
                                            Color.gray.opacity(0.3)
                                        }
                                    }
                                    .tag(index + 1)
                                }
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                        .frame(height: 400)
                        .background(Color.stashCardBackground) // Theme color instead of black bars
                        .cornerRadius(12)
                        
                        if case .loadingImages = viewModel.state {
                            HStack {
                                ProgressView()
                                Text("Searching StashDB...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if !viewModel.stashBoxImages.isEmpty {
                            Text(viewModel.selectedImageIndex == 0 ? "Current Image" : "StashDB Image \(viewModel.selectedImageIndex)/\(viewModel.stashBoxImages.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                             Text("No images found on StashDB")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .listRowInsets(EdgeInsets()) // Edge-to-edge for swiper
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section(header: Text("Basic Info")) {
                    TextField("Name", text: $viewModel.name)
                    TextField("Disambiguation", text: $viewModel.disambiguation)
                    Picker("Gender", selection: $viewModel.gender) {
                        Text("Not Set").tag("")
                        Text("Male").tag("MALE")
                        Text("Female").tag("FEMALE")
                        Text("Transgender Male").tag("TRANSGENDER_MALE")
                        Text("Transgender Female").tag("TRANSGENDER_FEMALE")
                        Text("Intersex").tag("INTERSEX")
                        Text("Non-Binary").tag("NON_BINARY")
                    }
                    TextField("Country", text: $viewModel.country)
                    TextField("Ethnicity", text: $viewModel.ethnicity)
                    TextField("Birthdate (YYYY-MM-DD)", text: $viewModel.birthdate)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Death Date (YYYY-MM-DD)", text: $viewModel.deathDate)
                        .keyboardType(.numbersAndPunctuation)
                    Toggle("Favorite", isOn: $viewModel.favorite)
                }
                .listRowBackground(Color.stashCardBackground)
                
                Section(header: Text("Physical")) {
                    TextField("Height (cm)", text: $viewModel.heightCm)
                        .keyboardType(.numberPad)
                    TextField("Weight (kg)", text: $viewModel.weight)
                        .keyboardType(.numberPad)
                    TextField("Measurements", text: $viewModel.measurements)
                    TextField("Eye Color", text: $viewModel.eyeColor)
                    TextField("Hair Color", text: $viewModel.hairColor)
                    
                    // Show breast-related field for non-male
                    if viewModel.gender != "MALE" {
                        TextField("Fake Tits", text: $viewModel.fakeTits)
                    }
                    
                    // Show male-specific fields only for male/trans-male
                    if viewModel.gender == "MALE" || viewModel.gender == "TRANSGENDER_MALE" {
                        TextField("Penis Length (cm)", text: $viewModel.penisLength)
                            .keyboardType(.decimalPad)
                        Picker("Circumcised", selection: $viewModel.circumcised) {
                            Text("Not Set").tag("")
                            Text("Cut").tag("CUT")
                            Text("Uncut").tag("UNCUT")
                        }
                    }
                }
                .listRowBackground(Color.stashCardBackground)
                
                Section(header: Text("Career")) {
                    TextField("Career Length", text: $viewModel.careerLength)
                    TextField("Aliases (comma separated)", text: $viewModel.aliases)
                    
                    VStack(alignment: .leading) {
                        Text("URLs (one per line)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $viewModel.urlsString)
                            .frame(height: 80)
                    }
                }
                .listRowBackground(Color.stashCardBackground)
                
                Section(header: Text("Body Modifications")) {
                    VStack(alignment: .leading) {
                        Text("Tattoos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $viewModel.tattoos)
                            .frame(height: 60)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Piercings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $viewModel.piercings)
                            .frame(height: 60)
                    }
                }
                .listRowBackground(Color.stashCardBackground)
                
                Section(header: Text("Biography")) {
                    VStack(alignment: .leading) {
                        Text("Details")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $viewModel.details)
                            .frame(height: 100)
                    }
                    
                    HStack {
                        Text("Rating")
                        Spacer()
                        Stepper(
                            value: Binding(
                                get: { viewModel.rating100 ?? 0 },
                                set: { viewModel.rating100 = $0 == 0 ? nil : $0 }
                            ),
                            in: 0...100,
                            step: 10
                        ) {
                            Text("\(viewModel.rating100 ?? 0)")
                                .frame(width: 40)
                        }
                    }
                }
                .listRowBackground(Color.stashCardBackground)
                
                if case .error(let message) = viewModel.state {
                    Section {
                        Text(message)
                            .foregroundColor(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.stashBackground)
            .navigationTitle("Edit Performer")
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
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.state == .saving)
                }
            }
            .disabled(viewModel.state == .saving)
            .overlay {
                if case .saving = viewModel.state {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
                }
            }
        }
    }
}
