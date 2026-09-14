import SwiftUI

/// Displays metadata (Title, Date, Rating) for a scene card.
///
/// **Used by:** `SceneCard`
struct SceneCardInfo: View {
    let config: SceneCardConfiguration
    let forceTitleHeight: Bool
    let isCompact: Bool
    let actions: SceneCardActions
    let scrubTime: Double?
    @Binding var isPressed: Bool  // For bounce animation (controlled by parent)
    
    init(config: SceneCardConfiguration, forceTitleHeight: Bool, isCompact: Bool = false, actions: SceneCardActions = .none, scrubTime: Double? = nil, isPressed: Binding<Bool>) {
        self.config = config
        self.forceTitleHeight = forceTitleHeight
        self.isCompact = isCompact
        self.actions = actions
        self.scrubTime = scrubTime
        self._isPressed = isPressed
    }

    @EnvironmentObject var settings: SettingsStore
    @State private var isDescriptionExpanded = false
    @State private var accentColor: Color = .blue
    @State private var isPressingDescription = false
    

    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title - tapping navigates to scene
            Text(config.title)
                .font(.headline)
                .lineLimit(isCompact ? 1 : (isDescriptionExpanded ? nil : 2))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: (forceTitleHeight && !isDescriptionExpanded) ? (isCompact ? 22 : 45) : nil, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .contentShape(Rectangle())
            
            // Metadata row
            metadataRow
            
            // Description (Expandable) & Tags
            if config.showDescription, let description = config.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(isDescriptionExpanded ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentShape(Rectangle())
                        .scaleEffect(isPressingDescription ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressingDescription)
                        .onLongPressGesture(minimumDuration: 0.5, perform: {
                            withAnimation {
                                isDescriptionExpanded.toggle()
                                HapticManager.mediumImpact()
                            }
                        }, onPressingChanged: { pressing in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                isPressingDescription = pressing
                            }
                        })
                        .onTapGesture {
                            // Fallback to scene click if just tapped
                            actions.onSceneClick?(scrubTime)
                        }
                    
                    if isDescriptionExpanded && !config.tags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(config.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(accentColor.opacity(0.8))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
            }
            
            // Performers & Indicators
            if !config.performers.isEmpty || config.isMonitored != nil || config.addedDate != nil || !config.indicators.isEmpty {
                 if isDescriptionExpanded {
                     // Expanded: Show full Performer Grid
                     expandedPerformersSection
                 } else {
                     // Collapsed: Show text list
                     performersSection
                 }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onPress(isPressed: $isPressed) {
             actions.onSceneClick?(scrubTime)
        }
        .task {
            if let url = config.imageUrl {
                if let extracted = await HeroAccentColor.extract(from: url) {
                    withAnimation {
                        self.accentColor = extracted
                    }
                }
            }
        }
    }
    
    // MARK: - Metadata Row
    
    @ViewBuilder
    private var metadataRow: some View {
        HStack {
            // Studio - tappable if action provided
            if let studio = config.studio {
                Text(studio)
                    .font(.subheadline)
                    .foregroundColor(actions.onStudioClick != nil ? .blue : .white)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticManager.lightImpact()
                        if let onStudio = actions.onStudioClick {
                            onStudio()
                        } else {
                            // Fallback to scene click if no studio action
                            actions.onSceneClick?(scrubTime)
                        }
                    }
            }
            
            // Date - tapping navigates to scene
            if let date = config.date {
                if config.studio != nil {
                    Text("•")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                Text(DateFormatters.formatDateString(date))
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .contentShape(Rectangle())
                    .contentShape(Rectangle())
            }
            

        }
    }
    
    @ViewBuilder
    private var performersSection: some View {
        HStack(spacing: 8) {
            // Performers - tappable if they have local IDs
            ForEach(config.performers.prefix(3)) { performer in
                if let localId = performer.localId {
                    Text(performer.name)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticManager.lightImpact()
                            actions.onPerformerClick?(localId, performer.name)
                        }
                } else {
                    Text(performer.name)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Indicators - tapping navigates to scene
            HStack(spacing: 8) {
                ForEach(config.indicators) { indicator in
                    if let customIcon = indicator.customIcon {
                        HStack(spacing: 6) {
                            Image(customIcon)
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)
                            Text(indicator.text)
                        }
                        .font(.subheadline)
                        .foregroundColor(indicator.color)
                    } else if let icon = indicator.icon {
                        Label(indicator.text, systemImage: icon)
                            .font(.subheadline)
                            .labelStyle(.titleAndIcon)
                            .foregroundColor(indicator.color)
                    } else {
                        Text(indicator.text)
                            .font(.subheadline)
                            .foregroundColor(indicator.color)
                    }
                }
            }
            .contentShape(Rectangle())
            .contentShape(Rectangle())
            
            // Monitored status (Whisparr cards)
            if let isMonitored = config.isMonitored {
                if let addedDate = config.addedDate {
                    Text(addedDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: isMonitored ? "bookmark.fill" : "bookmark")
                    .foregroundColor(isMonitored ? .blue : .secondary)
            }
        }
    }
    
    @ViewBuilder
    private var expandedPerformersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Check if we have any performers to show
            if !config.performers.isEmpty {
                Text("Performers")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 140), spacing: 12)], spacing: 12) {
                    ForEach(config.performers) { performer in
                        VStack(spacing: 4) {
                            // Image
                            if let url = performer.imageUrl {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .frame(width: 120, height: 120, alignment: .top)
                                .blur(radius: settings.blurNsfw ? 20 : 0)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            } else {
                                // Placeholder for no image
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white.opacity(0.5))
                                    )
                            }
                            
                            // Name
                            Text(performer.name)
                                .font(.system(size: 10))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(width: 120)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                             HapticManager.lightImpact()
                             if let localId = performer.localId {
                                 actions.onPerformerClick?(localId, performer.name)
                             }
                         }
                    }
                }
            }
            
            // Show indicators/monitored status below grid if they exist
            if !config.indicators.isEmpty || config.isMonitored != nil {
                 HStack(spacing: 12) {
                     // Indicators
                     ForEach(config.indicators) { indicator in
                         if let customIcon = indicator.customIcon {
                             HStack(spacing: 6) {
                                 Image(customIcon)
                                     .renderingMode(.template)
                                     .resizable()
                                     .aspectRatio(contentMode: .fit)
                                     .frame(width: 14, height: 14)
                                 Text(indicator.text)
                             }
                             .font(.subheadline)
                             .foregroundColor(indicator.color)
                         } else if let icon = indicator.icon {
                             Label(indicator.text, systemImage: icon)
                                 .font(.subheadline)
                                 .labelStyle(.titleAndIcon)
                                 .foregroundColor(indicator.color)
                         } else {
                             Text(indicator.text)
                                 .font(.subheadline)
                                 .foregroundColor(indicator.color)
                         }
                     }
                     
                     Spacer()
                     
                     // Monitored
                     if let isMonitored = config.isMonitored {
                         Image(systemName: isMonitored ? "bookmark.fill" : "bookmark")
                             .foregroundColor(isMonitored ? .blue : .secondary)
                     }
                 }
                 .padding(.top, 4)
            }
        }
        .padding(.top, 4)
    }
}
