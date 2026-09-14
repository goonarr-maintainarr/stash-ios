import Observation
import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "EditPerformerFormManager")

/// Manages form state for editing a performer.
@MainActor
@Observable
class EditPerformerFormManager {
    
    // MARK: - Observable Form Fields
    
    var name: String = ""
    var disambiguation: String = ""
    var birthdate: String = ""
    var deathDate: String = ""
    var country: String = ""
    var ethnicity: String = ""
    var heightCm: String = ""
    var weight: String = ""
    var measurements: String = ""
    var fakeTits: String = ""
    var penisLength: String = ""
    var circumcised: String = ""
    var careerLength: String = ""
    var tattoos: String = ""
    var piercings: String = ""
    var aliasString: String = ""
    var urlsString: String = ""
    var gender: String = ""
    var eyeColor: String = ""
    var hairColor: String = ""
    var favorite: Bool = false
    var details: String = ""
    var rating100: Int? = nil
    
    // MARK: - Initialization
    
    init(performer: Performer) {
        logger.debug("🔧 EditPerformerFormManager initialized")
        populateFields(from: performer)
    }
    
    // MARK: - Population
    
    private func populateFields(from performer: Performer) {
        logger.info("📝 Populating form fields from performer")
        
        name = performer.name ?? ""
        disambiguation = performer.disambiguation ?? ""
        birthdate = performer.birthdate ?? ""
        deathDate = performer.death_date ?? ""
        country = performer.country ?? ""
        ethnicity = performer.ethnicity ?? ""
        
        if let h = performer.height_cm, h > 0 {
            heightCm = String(h)
        }
        if let w = performer.weight, w > 0 {
            weight = String(w)
        }
        
        measurements = performer.measurements ?? ""
        fakeTits = performer.fake_tits ?? ""
        
        if let pl = performer.penis_length, pl > 0 {
            penisLength = String(format: "%.1f", pl)
        }
        
        circumcised = performer.circumcised ?? ""
        careerLength = performer.career_length ?? ""
        tattoos = performer.tattoos ?? ""
        piercings = performer.piercings ?? ""
        
        if let aliasList = performer.alias_list {
            aliasString = aliasList.joined(separator: ", ")
        }
        
        if let urls = performer.urls {
            urlsString = urls.joined(separator: "\n")
        }
        
        gender = performer.gender ?? ""
        eyeColor = performer.eye_color ?? ""
        hairColor = performer.hair_color ?? ""
        favorite = performer.favorite ?? false
        details = performer.details ?? ""
        rating100 = performer.rating100
        
        logger.info("✅ Form fields populated")
    }
    
    // MARK: - Input Building
    
    /// Builds PerformerUpdateInput from form fields.
    func buildUpdateInput(performerId: String, selectedImageUrl: String?) -> PerformerUpdateInput {
        logger.info("🔨 Building update input")
        
        let heightInt = Int(heightCm)
        let weightInt = Int(weight)
        let penisLengthDouble = Double(penisLength)
        
        let aliasList = aliasString.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let urlsList = urlsString.split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return PerformerUpdateInput(
            id: performerId,
            name: name,
            disambiguation: disambiguation.isEmpty ? nil : disambiguation,
            image: selectedImageUrl,
            details: details.isEmpty ? nil : details,
            gender: gender.isEmpty ? nil : gender,
            birthDate: birthdate.isEmpty ? nil : birthdate,
            deathDate: deathDate.isEmpty ? nil : deathDate,
            ethnicity: ethnicity.isEmpty ? nil : ethnicity,
            country: country.isEmpty ? nil : country,
            eyeColor: eyeColor.isEmpty ? nil : eyeColor,
            hairColor: hairColor.isEmpty ? nil : hairColor,
            height: heightInt,
            weight: weightInt,
            measurements: measurements.isEmpty ? nil : measurements,
            breastType: fakeTits.isEmpty ? nil : fakeTits,
            careerLength: careerLength.isEmpty ? nil : careerLength,
            careerStartYear: nil,
            careerEndYear: nil,
            tattoos: tattoos.isEmpty ? nil : tattoos,
            piercings: piercings.isEmpty ? nil : piercings,
            aliasList: aliasList,
            urls: urlsList,
            rating100: rating100,
            favorite: favorite,
            penisLength: penisLengthDouble,
            circumcised: circumcised.isEmpty ? nil : circumcised
        )
    }
}
