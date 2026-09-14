import SwiftUI

/// Displays physical stats (Height, Weight, Measurements).
///
/// **Used by:** `PerformerDetailContentView`
struct PerformerPhysicalInfoView: View {
    let performer: PerformerDetailDisplay
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Physical")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                if let gender = performer.gender, !gender.isEmpty {
                    AttributeRow(icon: "person.fill", label: "Gender", value: gender.capitalized)
                }
                if let ethnicity = performer.ethnicity, !ethnicity.isEmpty {
                    AttributeRow(icon: "globe", label: "Ethnicity", value: ethnicity)
                }
                if let height = performer.heightCm {
                    let feet = Double(height) / 30.48
                    let feetInt = Int(feet)
                    let inches = Int((feet - Double(feetInt)) * 12)
                    AttributeRow(icon: "ruler", label: "Height", value: "\(feetInt)'\(inches)\" (\(height)cm)")
                }
                if let weight = performer.weightKg {
                    let lbs = Int(Double(weight) * 2.205)
                    AttributeRow(icon: "scalemass", label: "Weight", value: "\(lbs) lbs (\(weight)kg)")
                }
                if let measurements = performer.measurements, !measurements.isEmpty {
                    AttributeRow(icon: "aspectratio", label: "Measurements", value: measurements)
                }
                if let eyeColor = performer.eyeColor, !eyeColor.isEmpty {
                    AttributeRow(icon: "eye.fill", label: "Eyes", value: eyeColor.capitalized)
                }
                if let hairColor = performer.hairColor, !hairColor.isEmpty {
                    AttributeRow(icon: "comb.fill", label: "Hair", value: hairColor.capitalized)
                }
                if let fakeTits = performer.fakeTits, !fakeTits.isEmpty {
                    AttributeRow(icon: "heart.fill", label: "Augmented", value: fakeTits)
                }
            }
        }
        .padding(12)
        .accentedCardBackground(opacity: 0.6)
        .cornerRadius(12)
        .padding(.top, 8)
    }
}

private struct AttributeRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.stashCardBackground)
        .cornerRadius(8)
    }
}
