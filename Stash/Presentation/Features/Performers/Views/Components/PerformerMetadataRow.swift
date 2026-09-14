import SwiftUI

struct PerformerMetadataStyle {
    let nameFont: Font
    let nameLineLimit: Int?
    let iconFont: Font
    let statFont: Font
    let showCountry: Bool
    
    static let card = PerformerMetadataStyle(
        nameFont: .title2,
        nameLineLimit: 2,
        iconFont: .caption2,
        statFont: .subheadline,
        showCountry: true
    )
    
    static let list = PerformerMetadataStyle(
        nameFont: .title,
        nameLineLimit: nil,
        iconFont: .caption,
        statFont: .subheadline,
        showCountry: false
    )
}

/// A standard detail row (Label: Value).
///
/// **Used by:** `PerformerDetailContentView`
struct PerformerMetadataRow: View {
    let name: String
    let age: Int?
    let sceneCount: Int?
    let oCount: Int?
    let country: String?
    let style: PerformerMetadataStyle
    let layoutType: PerformerLayoutType?
    let shouldShowCountry: Bool
    
    init(performer: Performer, style: PerformerMetadataStyle, layoutType: PerformerLayoutType? = nil) {
        self.name = performer.name ?? "Unknown Name"
        self.age = performer.age
        self.sceneCount = performer.scene_count
        self.oCount = performer.o_counter
        self.country = performer.country
        self.style = style
        self.layoutType = layoutType
        
        // Compute once
        if !style.showCountry {
            self.shouldShowCountry = false
        } else if let layoutType = layoutType {
            self.shouldShowCountry = layoutType == .list
        } else {
            self.shouldShowCountry = true
        }
    }
    
    init(
        name: String,
        age: Int?,
        sceneCount: Int?,
        oCount: Int?,
        country: String? = nil,
        style: PerformerMetadataStyle,
        layoutType: PerformerLayoutType? = nil
    ) {
        self.name = name
        self.age = age
        self.sceneCount = sceneCount
        self.oCount = oCount
        self.country = country
        self.style = style
        self.layoutType = layoutType
        
        // Compute once
        if !style.showCountry {
            self.shouldShowCountry = false
        } else if let layoutType = layoutType {
            self.shouldShowCountry = layoutType == .list
        } else {
            self.shouldShowCountry = true
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(layoutType == .grid3x ? .caption.bold() : style.nameFont)
                .fontWeight(layoutType == .grid3x ? .regular : .bold)
                .foregroundColor(.white)
                .lineLimit(style.nameLineLimit)
            
            // Hide statistics in 3x grid
            if layoutType != .grid3x {
                HStack(spacing: 12) {
                    // Age
                    if let age = age {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(style.iconFont)
                            Text("\(age)")
                                .font(style.statFont)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    // Country
                    if shouldShowCountry, let country = country {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(style.iconFont)
                            Text(country)
                                .font(style.statFont)
                        }
                    }
                    
                    // Scene Count
                    if let sceneCount = sceneCount {
                        HStack(spacing: 4) {
                            Image(systemName: "film")
                                .font(style.iconFont)
                            Text("\(sceneCount)")
                                .font(style.statFont)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    // O-Counter
                    if let oCount = oCount, oCount > 0 {
                        HStack(spacing: 4) {
                            Image("SweatDrops")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)
                            Text("\(oCount)")
                                .font(style.statFont)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .foregroundColor(.white.opacity(0.9))
            }
        }
    }
}
