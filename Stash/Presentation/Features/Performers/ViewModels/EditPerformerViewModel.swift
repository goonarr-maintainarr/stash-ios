import Observation
import SwiftUI
import Nuke
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "EditPerformerViewModel")

/// A structure representing the result of a performer update mutation.
struct EditPerformerUpdateResult: Decodable {
    let performerUpdate: Performer?
}

/// A ViewModel responsible for managing the state and logic for editing a `Performer`.
///
/// Coordinates form management, StashDB operations, and save operations using composition pattern.
@MainActor
@Observable
class EditPerformerViewModel {
    
    // MARK: - ViewState
    
    enum ViewState: Equatable {
        case idle
        case loading
        case saving
        case loadingImages
        case success(String)
        case error(String)
    }
    
    /// The current state of the view.
    var state: ViewState = .idle
    
    // MARK: - Managers
    
    private let formManager: EditPerformerFormManager
    private let stashDBManager: EditPerformerStashDBManager
    private let saveManager: EditPerformerSaveManager
    
    // MARK: - Helper Accessors
    
    var aliases: String {
        get { formManager.aliasString }
        set { formManager.aliasString = newValue }
    }
    
    var currentImagePath: String? { performer.image_path }
    
    // Forward form properties
    var name: String {
        get { formManager.name }
        set { formManager.name = newValue }
    }
    var disambiguation: String {
        get { formManager.disambiguation }
        set { formManager.disambiguation = newValue }
    }
    var birthdate: String {
        get { formManager.birthdate }
        set { formManager.birthdate = newValue }
    }
    var deathDate: String {
        get { formManager.deathDate }
        set { formManager.deathDate = newValue }
    }
    var country: String {
        get { formManager.country }
        set { formManager.country = newValue }
    }
    var ethnicity: String {
        get { formManager.ethnicity }
        set { formManager.ethnicity = newValue }
    }
    var heightCm: String {
        get { formManager.heightCm }
        set { formManager.heightCm = newValue }
    }
    var weight: String {
        get { formManager.weight }
        set { formManager.weight = newValue }
    }
    var measurements: String {
        get { formManager.measurements }
        set { formManager.measurements = newValue }
    }
    var fakeTits: String {
        get { formManager.fakeTits }
        set { formManager.fakeTits = newValue }
    }
    var penisLength: String {
        get { formManager.penisLength }
        set { formManager.penisLength = newValue }
    }
    var circumcised: String {
        get { formManager.circumcised }
        set { formManager.circumcised = newValue }
    }
    var careerLength: String {
        get { formManager.careerLength }
        set { formManager.careerLength = newValue }
    }
    var tattoos: String {
        get { formManager.tattoos }
        set { formManager.tattoos = newValue }
    }
    var piercings: String {
        get { formManager.piercings }
        set { formManager.piercings = newValue }
    }
    var aliasString: String {
        get { formManager.aliasString }
        set { formManager.aliasString = newValue }
    }
    var urlsString: String {
        get { formManager.urlsString }
        set { formManager.urlsString = newValue }
    }
    var gender: String {
        get { formManager.gender }
        set { formManager.gender = newValue }
    }
    var eyeColor: String {
        get { formManager.eyeColor }
        set { formManager.eyeColor = newValue }
    }
    var hairColor: String {
        get { formManager.hairColor }
        set { formManager.hairColor = newValue }
    }
    var favorite: Bool {
        get { formManager.favorite }
        set { formManager.favorite = newValue }
    }
    var details: String {
        get { formManager.details }
        set { formManager.details = newValue }
    }
    var rating100: Int? {
        get { formManager.rating100 }
        set { formManager.rating100 = newValue }
    }
    
    // Forward StashDB properties
    var stashBoxImages: [StashBoxImage] {
        get { stashDBManager.stashBoxImages }
        set { stashDBManager.stashBoxImages = newValue }
    }
    var selectedImageUrl: String? {
        get { stashDBManager.selectedImageUrl }
        set { stashDBManager.selectedImageUrl = newValue }
    }
    var isLoadingImages: Bool {
        stashDBManager.isLoadingImages
    }
    
    // IMAGE selection index (0 = current, 1+ = StashDB images)
    var selectedImageIndex: Int = 0
    
    // MARK: - Private Properties
    
    private let performer: Performer
    
    /// Initializes the `EditPerformerViewModel`.
    ///
    /// - Parameters:
    ///   - performer: The performer to edit.
    ///   - performerRepository: The Performer repository.
    ///   - stashDBRepository: The StashDB repository.
    ///   - settings: The user settings store.
    ///   - database: The local database.
    init(
        performer: Performer,
        performerRepository: any PerformerRepositoryProtocol,
        stashDBRepository: StashDBRepositoryProtocol,
        settings: SettingsStoreProtocol,
        database: StashDatabase
    ) {
        self.performer = performer
        
        // Initialize managers
        self.formManager = EditPerformerFormManager(performer: performer)
        self.stashDBManager = EditPerformerStashDBManager(
            stashDBRepository: stashDBRepository,
            performerRepository: performerRepository,
            settings: settings
        )
        self.saveManager = EditPerformerSaveManager(performerRepository: performerRepository)
        
        logger.debug("🔧 EditPerformerViewModel initialized")
        
        // Auto-fetch images if name isn't empty
        if !formManager.name.isEmpty {
            Task {
                await fetchStashDBImages()
            }
        }
    }
    
    /// Fetches potential performer images from configured StashBoxes.
    func fetchStashDBImages() async {
        logger.info("🔍 Fetching StashDB images")
        state = .loadingImages
        
        do {
            try await stashDBManager.fetchStashDBImages(performerName: formManager.name)
            
            // Auto-fill metadata if available
            if let autoFillData = await stashDBManager.autoFillMetadata(performerName: formManager.name) {
                applyAutoFillData(autoFillData)
            }
            
            state = .idle
            logger.info("✅ StashDB images fetched")
        } catch {
            state = .error("Failed to load images: \(error.localizedDescription)")
            logger.error("❌ Failed to fetch images: \(error.localizedDescription)")
        }
    }
    
    private func applyAutoFillData(_ data: PerformerAutoFillData) {
        logger.info("📝 Applying auto-fill data")
        
        if formManager.birthdate.isEmpty, let val = data.birthdate { formManager.birthdate = val }
        if formManager.country.isEmpty, let val = data.country { formManager.country = val }
        if formManager.ethnicity.isEmpty, let val = data.ethnicity { formManager.ethnicity = val }
        if formManager.heightCm.isEmpty, let val = data.heightCm { formManager.heightCm = String(val) }
        if formManager.measurements.isEmpty, let val = data.measurements { formManager.measurements = val }
        if formManager.fakeTits.isEmpty, let val = data.fakeTits { formManager.fakeTits = val }
        if formManager.careerLength.isEmpty, let val = data.careerLength { formManager.careerLength = val }
        if formManager.tattoos.isEmpty, let val = data.tattoos { formManager.tattoos = val }
        if formManager.piercings.isEmpty, let val = data.piercings { formManager.piercings = val }
        if formManager.gender.isEmpty, let val = data.gender { formManager.gender = val }
        if formManager.eyeColor.isEmpty, let val = data.eyeColor { formManager.eyeColor = val }
        if formManager.hairColor.isEmpty, let val = data.hairColor { formManager.hairColor = val }
    }
    
    /// Saves the performer updates to the server.
    @discardableResult
    func save() async -> Bool {
        logger.info("💾 Saving performer")
        state = .saving
        
        do {
            // Determine selected image URL from index
            let imageUrl: String?
            if selectedImageIndex > 0 && (selectedImageIndex - 1) < stashBoxImages.count {
                imageUrl = stashBoxImages[selectedImageIndex - 1].url
            } else {
                imageUrl = nil // Keep current image
            }
            
            let input = formManager.buildUpdateInput(
                performerId: performer.id,
                selectedImageUrl: imageUrl
            )
            
            try await saveManager.savePerformer(input: input)
            
            state = .success("Saved!")
            logger.info("✅ Performer saved")
            return true
            
        } catch {
            state = .error("Failed to save: \(error.localizedDescription)")
            logger.error("❌ Save failed: \(error.localizedDescription)")
            return false
        }
    }
}

extension Notification.Name {
    /// Notification posted when a performer is successfully updated.
    static let performerUpdated = Notification.Name("performerUpdated")
}
