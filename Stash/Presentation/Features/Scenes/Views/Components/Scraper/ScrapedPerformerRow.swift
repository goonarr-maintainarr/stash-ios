import SwiftUI
import NukeUI

struct ScrapedPerformerRow: View {
    let performer: ScrapedPerformer
    @Binding var missingPerformers: Set<String>
    var viewModel: SceneDetailViewModel
    
    @State private var isExpanded = false
    @State private var createName: String = ""
    @State private var isCreating = false
    @Namespace private var animation
    
    // Image Cycling State
    @State private var fetchedImages: [String] = []
    @State private var currentImageIndex = 0
    @State private var isLoadingImages = false
    
    // Performer Details State
    @State private var birthDate: String = ""
    @State private var ethnicity: String = ""
    @State private var country: String = ""
    @State private var eyeColor: String = ""
    @State private var hairColor: String = ""
    @State private var height: String = "" // String for text field, convert to Int
    @State private var measurements: String = ""
    @State private var breastType: String = ""
    @State private var careerStart: String = ""
    @State private var careerEnd: String = ""
    @State private var tattoos: String = ""
    @State private var piercings: String = ""
    
    var currentDisplayImage: String? {
        if !fetchedImages.isEmpty {
            if fetchedImages.indices.contains(currentImageIndex) {
                 return fetchedImages[currentImageIndex]
            }
            return fetchedImages.first
        }
        return performer.images?.first
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if isExpanded {
                VStack(spacing: 12) {
                    // Expanded Header (Name + Arrow)
                    HStack {
                         Text(performer.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .matchedGeometryEffect(id: "name", in: animation)
                        Spacer()
                        Image(systemName: "chevron.up")
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .matchedGeometryEffect(id: "arrow", in: animation)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation { isExpanded = false }
                    }
                    
                    // Expanded Image Carousel
                    TabView(selection: $currentImageIndex) {
                        // Original Scraped Image
                        if let imageString = performer.images?.first,
                           let url = URL(string: imageString) {
                            LazyImage(url: url) { state in
                                if let image = state.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } else if state.isLoading {
                                    ProgressView()
                                } else {
                                    Color.gray.opacity(0.3)
                                }
                            }
                            .tag(0)
                        }
                        
                        // Fetched Images
                        ForEach(Array(fetchedImages.enumerated()), id: \.offset) { index, imageString in
                            if let url = URL(string: imageString) {
                                LazyImage(url: url) { state in
                                    if let image = state.image {
                                        image
                                            .resizable()
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
                    .frame(height: 350)
                    .background(Color.stashCardBackground)
                    .cornerRadius(8)
                    .matchedGeometryEffect(id: "image", in: animation)
                    
                    Group { // Wrap the conditional views in a Group to apply modifiers
                        if isLoadingImages {
                             ProgressView()
                                .scaleEffect(0.8)
                                .padding(.vertical, 4)
                        } else if fetchedImages.isEmpty {
                            Text("No additional images found")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    Text("Create Performer Details")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 8) {
                        TextField("Name", text: $createName)
                            .padding(8)
                            .background(Color.stashSecondaryBackground)
                            .cornerRadius(6)
                            .font(.caption)
                        
                        Group {
                            HStack {
                                TextField("Birth Date (YYYY-MM-DD)", text: $birthDate)
                                    .padding(8)
                                    .background(Color.stashSecondaryBackground)
                                    .cornerRadius(6)
                                TextField("Ethnicity", text: $ethnicity)
                                    .padding(8)
                                    .background(Color.stashSecondaryBackground)
                                    .cornerRadius(6)
                            }
                            HStack {
                                TextField("Country", text: $country)
                                    .padding(8)
                                    .background(Color.stashSecondaryBackground)
                                    .cornerRadius(6)
                                TextField("Height (cm)", text: $height)
                                    .keyboardType(.numberPad)
                                    .padding(8)
                                    .background(Color.stashSecondaryBackground)
                                    .cornerRadius(6)
                            }
                            HStack {
                                TextField("Eye Color", text: $eyeColor)
                                    .padding(8)
                                    .background(Color.stashSecondaryBackground)
                                    .cornerRadius(6)
                                TextField("Hair Color", text: $hairColor)
                                    .padding(8)
                                    .background(Color.stashSecondaryBackground)
                                    .cornerRadius(6)
                            }
                            HStack {
                                TextField("Measurements", text: $measurements)
                                    .padding(8)
                                    .background(Color.stashSecondaryBackground)
                                    .cornerRadius(6)
                                TextField("Breast Type", text: $breastType)
                                    .padding(8)
                                    .background(Color.stashSecondaryBackground)
                                    .cornerRadius(6)
                            }
                             HStack {
                                TextField("Career Start", text: $careerStart)
                                    .keyboardType(.numberPad)
                                    .padding(8)
                                    .background(Color.stashSecondaryBackground)
                                    .cornerRadius(6)
                                TextField("Career End", text: $careerEnd)
                                    .keyboardType(.numberPad)
                                    .padding(8)
                                    .background(Color(red: 0.15, green: 0.18, blue: 0.25))
                                    .cornerRadius(6)
                            }
                            TextField("Tattoos", text: $tattoos)
                                .padding(8)
                                .background(Color(red: 0.15, green: 0.18, blue: 0.25))
                                .cornerRadius(6)
                            TextField("Piercings", text: $piercings)
                                .padding(8)
                                .background(Color(red: 0.15, green: 0.18, blue: 0.25))
                                .cornerRadius(6)
                        }
                        .font(.caption)
                    }
                    
                    Button {
                        Task {
                            isCreating = true
                            
                            // Parse Integers
                            let heightInt = Int(height)
                            let startInt = Int(careerStart)
                            let endInt = Int(careerEnd)
                            
                            // Treat empty strings as nil
                            let bDate = birthDate.isEmpty ? nil : birthDate
                            let ethn = ethnicity.isEmpty ? nil : ethnicity
                            let cntry = country.isEmpty ? nil : country
                            let eyes = eyeColor.isEmpty ? nil : eyeColor
                            let hair = hairColor.isEmpty ? nil : hairColor
                            let meas = measurements.isEmpty ? nil : measurements
                            let breast = breastType.isEmpty ? nil : breastType
                            let tats = tattoos.isEmpty ? nil : tattoos
                            let pierc = piercings.isEmpty ? nil : piercings

                            let success = await viewModel.createPerformer(
                                name: createName,
                                image: currentDisplayImage,
                                details: nil,
                                gender: performer.gender,
                                birth_date: bDate,
                                ethnicity: ethn,
                                country: cntry,
                                eye_color: eyes,
                                hair_color: hair,
                                height: heightInt,
                                measurements: meas,
                                breast_type: breast,
                                career_start_year: startInt,
                                career_end_year: endInt,
                                tattoos: tats,
                                piercings: pierc
                            )
                            isCreating = false
                            if success {
                                missingPerformers.remove(performer.name)
                                withAnimation {
                                    isExpanded = false
                                }
                            }
                        }
                    } label: {
                        if isCreating {
                            ProgressView()
                            .scaleEffect(0.8)
                        } else {
                            Text("Create")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(createName.isEmpty || isCreating)
                }
                .task {
                    isLoadingImages = true
                    // fetchPerformerImages now returns StashDBPerformer
                    if let result = await viewModel.fetchPerformerImages(name: performer.name) {
                        // Get image URLs
                        fetchedImages = result.images?.map { $0.url } ?? []
                        
                        // Populate Fields (StashDBPerformer uses camelCase)
                        if let date = result.birthDate { birthDate = date }
                        if let eth = result.ethnicity { ethnicity = eth }
                        if let cntry = result.country { country = cntry }
                        if let eye = result.eyeColor { eyeColor = eye }
                        if let hair = result.hairColor { hairColor = hair }
                        if let h = result.height { height = String(h) }
                        
                        // Measurements from nested struct
                        var meas = ""
                        if let m = result.measurements {
                            if let cup = m.cup_size { meas += cup }
                            if let band = m.band_size { meas += "\(band)" }
                        }
                        measurements = meas
                        
                        if let bt = result.breastType { breastType = bt }
                        if let start = result.careerStartYear { careerStart = String(start) }
                        if let end = result.careerEndYear { careerEnd = String(end) }
                        
                        // Tattoos/Piercings are arrays of StashDBBodyMod objects
                        if let tats = result.tattoos {
                            tattoos = tats.compactMap { "\($0.location ?? "") \($0.description ?? "")" }.joined(separator: ", ").trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        if let pierc = result.piercings {
                            piercings = pierc.compactMap { "\($0.location ?? "") \($0.description ?? "")" }.joined(separator: ", ").trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    isLoadingImages = false
                }
            } else {
                // Collapsed View
                HStack(spacing: 12) {
                    if let imageString = performer.images?.first,
                       let url = URL(string: imageString) {
                        LazyImage(url: url) { state in
                            if let image = state.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color.gray
                            }
                        }
                        .frame(width: 120, height: 120, alignment: .top)
                        .clipped()
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: "image", in: animation)
                    } else {
                        Image(systemName: "person.fill")
                            .resizable()
                            .padding(24)
                            .frame(width: 120, height: 120)
                            .background(Color.gray.opacity(0.3))
                            .foregroundColor(.gray)
                            .cornerRadius(8)
                            .matchedGeometryEffect(id: "image", in: animation)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(performer.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .matchedGeometryEffect(id: "name", in: animation)
                        
                        if missingPerformers.contains(performer.name) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                Text("Needs creation")
                                    .font(.caption)
                            }
                            .foregroundColor(.yellow)
                        }
                    }
                    
                    Spacer()
                    
                    if missingPerformers.contains(performer.name) {
                        Image(systemName: "chevron.left") // Point inward
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .matchedGeometryEffect(id: "arrow", in: animation)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if missingPerformers.contains(performer.name) {
                        withAnimation {
                            isExpanded = true
                            createName = performer.name
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
