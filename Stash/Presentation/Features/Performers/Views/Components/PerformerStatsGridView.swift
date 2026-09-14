import SwiftUI

/// Displays career stats (Years active, Scene count).
///
/// **Used by:** `PerformerDetailContentView`
struct PerformerStatsGridView: View {
    let performer: PerformerDetailDisplay
    
    private var statCards: [(icon: String, title: String, value: String)] {
        var cards: [(String, String, String)] = []
        
        if let birthdate = performer.birthdate {
            cards.append(("calendar", "Born", birthdate))
        }
        
        if let deathDate = performer.deathDate {
            cards.append(("heart.slash", "Died", deathDate))
        }
        
        if let career = performer.careerLength {
            cards.append(("briefcase", "Career", career))
        }
        
        if let rating = performer.rating100, rating > 0 {
            cards.append(("star.fill", "Rating", "\(rating / 20)/5"))
        }
        
        return cards
    }
    
    var body: some View {
        Group {
            if statCards.count <= 2 {
                // Center 1 or 2 items using HStack
                HStack(spacing: 8) {
                    ForEach(statCards.indices, id: \.self) { index in
                        StatCard(icon: statCards[index].icon, title: statCards[index].title, value: statCards[index].value)
                    }
                }
            } else {
                // Use grid for 3+ items
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(statCards.indices, id: \.self) { index in
                        StatCard(icon: statCards[index].icon, title: statCards[index].title, value: statCards[index].value)
                    }
                }
            }
        }
        .padding(.top, 12)
    }
}

private struct StatCard: View {
    let icon: String?
    let customIcon: String?
    let title: String
    let value: String
    var valueColor: Color = .primary
    
    init(icon: String? = nil, customIcon: String? = nil, title: String, value: String, valueColor: Color = .primary) {
        self.icon = icon
        self.customIcon = customIcon
        self.title = title
        self.value = value
        self.valueColor = valueColor
    }
    
    var body: some View {
        VStack(spacing: 2) {
            if let customIcon = customIcon {
                Image(customIcon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundColor(.blue)
            } else if let icon = icon {
                Image(systemName: icon)
                    .font(.footnote)
                    .foregroundColor(.blue)
            }
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .accentedCardBackground(opacity: 0.8)
        .cornerRadius(10)
    }
}
