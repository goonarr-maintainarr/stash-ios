import SwiftUI
import NukeUI

/// A reusable generic view for displaying performer details (Local or StashDB).
/// This ensures a unified UI across the app for any performer profile.
struct PerformerDetailContentView<ScenesContent: View>: View {
    let performer: PerformerDetailDisplay
    
    // Actions - These allow the parent view to handle specific logic (like editing/deleting)
    // while this view handles purely the display.
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onFilter: (() -> Void)? = nil
    var onSort: (() -> Void)? = nil
    var onLookupStashDB: (() -> Void)? = nil
    
    // Generic Scene content
    @ViewBuilder let scenesView: ScenesContent
    
    @State private var heroColor: Color?
    @EnvironmentObject var settings: SettingsStore
    
    init(
        performer: PerformerDetailDisplay,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onFilter: (() -> Void)? = nil,
        onSort: (() -> Void)? = nil,
        onLookupStashDB: (() -> Void)? = nil,
        @ViewBuilder scenesView: () -> ScenesContent
    ) {
        self.performer = performer
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onFilter = onFilter
        self.onSort = onSort
        self.onLookupStashDB = onLookupStashDB
        self.scenesView = scenesView()
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Hero Section
                heroSection
                
                // Stats Grid
                PerformerStatsGridView(performer: performer)
                
                // Physical Info
                PerformerPhysicalInfoView(performer: performer)
                
                // Alias List
                if !performer.aliases.isEmpty {
                    PerformerAliasesView(aliases: performer.aliases)
                }
                
                // Body Mods (Tattoos/Piercings)
                if performer.tattoos != nil || performer.piercings != nil {
                    PerformerBodyModificationsView(performer: performer)
                }
                
                // Links
                if !performer.urls.isEmpty {
                    PerformerLinksView(urls: performer.urls)
                }
                
                // Stash IDs
                if !performer.stashIDs.isEmpty {
                    PerformerStashIDsView(stashIds: performer.stashIDs)
                }
                
                // Tags (Local only usually)
                if !performer.tags.isEmpty {
                    PerformerTagsView(tags: performer.tags.map { Performer.PerformerTag(id: $0, name: $0) })
                }
                
                // Scenes List (Injected)
                scenesView
            }
            .withHeroAccentColor(heroColor)
            .padding(.horizontal, 8)
        }
        .background(
            PerformerProfileBackground(imageURL: performer.imageURL)
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Only show menu if we have actions (usually local performer)
                if let onEdit = onEdit, let onDelete = onDelete {
                    Menu {
                        if let onLookupStashDB = onLookupStashDB {
                            Button(action: onLookupStashDB) {
                                Label("View Scenes on StashDB", systemImage: "globe")
                            }
                            
                            Divider()
                        }
                        
                        Button(action: onEdit) {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = performer.imageURL {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 500, alignment: .top)
                .clipped()
                .blur(radius: settings.blurNsfw ? 20 : 0)
                .task {
                    // Extract dominant color asynchronously
                    if let color = await HeroAccentColor.extract(from: url) {
                        heroColor = color
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .frame(height: 600)
            }
            
            // Gradient overlay
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 600)
            
            // Performer name overlay
            VStack(alignment: .leading, spacing: 4) {
                Text(performer.name)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 12) {
                    // Age
                    if let age = performer.age {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption)
                            Text("\(age)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    // Country (after age, matching card layout)
                    if let country = performer.country {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text(country)
                                .font(.subheadline)
                        }
                    }
                    
                    // Scene Count
                    if performer.sceneCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "film")
                                .font(.caption)
                            Text("\(performer.sceneCount)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    // O Count
                    if let oCount = performer.oCount, oCount > 0 {
                        HStack(spacing: 4) {
                            Image("SweatDrops")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)
                            Text("\(oCount)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 16)
            .padding(.bottom, 16)
            
            // StashDB Indicator Badge
            if !performer.isLocal {
                Text("StashDB")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .cornerRadius(16)
        .shadow(color: (heroColor ?? .black).opacity(heroColor != nil ? 0.5 : 0.3), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(heroColor?.opacity(0.3) ?? Color.clear, lineWidth: 1)
        )
    }
}
