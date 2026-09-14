import SwiftUI
import NukeUI

/// A grid/list item representing a performer.
///
/// **Used by:**
/// - `PerformerListView`
/// - `StudioDetailView` (Performer grid)
struct PerformerCard: View {
    enum Style {
        case grid
        case hero
    }
    
    private enum PerformerData {
        case local(Performer)
        case stashDB(name: String, details: StashDBPerformer?, oCount: Int?, localImagePath: String?, localSceneCount: Int?)
        case whisparr(credit: WhisparrCredit, localId: String?, stash: StashDBPerformer?, oCount: Int?, localSceneCount: Int?, localImagePath: String?)
    }
    
    // Configuration
    private let data: PerformerData
    let style: Style
    let layoutType: PerformerLayoutType
    let actions: PerformerCardActions
    
    @State private var heroColor: Color?
    @State private var isPressed = false // For bounce animation
    @EnvironmentObject var settings: SettingsStore
    
    // Computed Properties
    var name: String {
        switch data {
        case .local(let p): return p.name ?? "Unknown"
        case .stashDB(let name, _, _, _, _): return name
        case .whisparr(let credit, _, _, _, _, _): return credit.performer.name ?? "Unknown"
        }
    }
    
    // ... (imageURL, age, etc. remain the same)
    var imageURL: URL? {
        switch data {
        case .local(let p):
            return settings.createImageUrl(path: p.image_path)
        case .stashDB(_, let details, _, let localImagePath, _):
            // Prioritize local image, then StashDB
            if let localPath = localImagePath, let url = settings.createImageUrl(path: localPath) {
                return url
            }
            if let urlString = details?.images?.first?.url {
                return URL(string: urlString)
            }
            return nil
        case .whisparr(let credit, _, let stash, _, _, let localImagePath):
            // Prioritize local image, then StashDB, then Whisparr
            if let localPath = localImagePath, let url = settings.createImageUrl(path: localPath) {
                return url
            }
            if let stashUrl = stash?.images?.first?.url, let url = URL(string: stashUrl) {
                return url
            } else if let whisparrUrl = credit.performer.images?.first?.url, let url = URL(string: whisparrUrl) {
                return url
            }
            return nil
        }
    }
    
    var age: Int? {
        switch data {
        case .local(let p): return p.age
        case .stashDB(_, let details, _, _, _): return details?.age
        case .whisparr(_, _, let stash, _, _, _): return stash?.age
        }
    }
    
    var sceneCount: Int? {
        switch data {
        case .local(let p): return p.scene_count
        case .stashDB(_, let details, _, _, let localSceneCount): 
            return localSceneCount ?? details?.sceneCount
        case .whisparr(_, _, _, _, let localSceneCount, _): return localSceneCount
        }
    }
    
    var oCount: Int? {
        switch data {
        case .local(let p): return p.o_counter
        case .stashDB(_, _, let count, _, _): return count
        case .whisparr(_, _, _, let count, _, _): return count
        }
    }
    
    var country: String? {
        switch data {
        case .local(let p): return p.country
        case .stashDB(_, let details, _, _, _): return details?.country
        case .whisparr(_, _, let stash, _, _, _): return stash?.country
        }
    }
    
    // MARK: - Helpers
    
    // MARK: - Initializers
    
    // 1. Standard Local Performer (Grid default)
    init(performer: Performer, style: Style = .grid, layoutType: PerformerLayoutType = .grid2x, actions: PerformerCardActions = .none) {
        self.data = .local(performer)
        self.style = style
        self.layoutType = layoutType
        self.actions = actions
    }
    
    // 2. StashDB Performer
    init(performerId: String, name: String, details: StashDBPerformer?, oCount: Int? = nil, localImagePath: String? = nil, localSceneCount: Int? = nil, style: Style = .grid, layoutType: PerformerLayoutType = .grid2x, actions: PerformerCardActions = .none) {
        self.data = .stashDB(name: name, details: details, oCount: oCount, localImagePath: localImagePath, localSceneCount: localSceneCount)
        self.style = style
        self.layoutType = layoutType
        self.actions = actions
    }
    
    // 3. Whisparr Credit (+ Optional StashDB data)
    init(credit: WhisparrCredit, localPerformerId: String?, stashPerformer: StashDBPerformer?, oCount: Int? = nil, localSceneCount: Int? = nil, localImagePath: String? = nil, style: Style = .grid, layoutType: PerformerLayoutType = .grid2x, actions: PerformerCardActions = .none) {
        self.data = .whisparr(credit: credit, localId: localPerformerId, stash: stashPerformer, oCount: oCount, localSceneCount: localSceneCount, localImagePath: localImagePath)
        self.style = style
        self.layoutType = layoutType
        self.actions = actions
    }

    var body: some View {
        Button {
            actions.onPerformerClick?()
        } label: {
            Group {
                switch style {
                case .grid:
                    gridContent
                case .hero:
                    heroContent
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Grid Content (Original PerformerCard style)
    private var gridContent: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Image layer
                if let url = imageURL {
                    LazyImage(url: url) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                                .clipped()
                                .blur(radius: settings.blurNsfw ? 20 : 0)
                        } else {
                            placeholderView(height: nil)
                        }
                    }
                } else {
                    placeholderView(height: nil)
                }
                
                // Gradient
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Info
                PerformerMetadataRow(
                    name: name,
                    age: age,
                    sceneCount: sceneCount,
                    oCount: oCount,
                    country: country,
                    style: .card,
                    layoutType: layoutType
                )
                .padding(layoutType == .grid3x ? 8 : 12)
            }
        }
        .aspectRatio(3/4, contentMode: .fit)
        .background(Color.stashCardBackground)
        .cornerRadius(12)
        .clipped()
        .shadow(color: (heroColor ?? .black).opacity(heroColor != nil ? 0.4 : 0.2), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(heroColor?.opacity(0.3) ?? Color.clear, lineWidth: 1)
        )
        .task {
            await extractHeroColor()
        }
    }
    
    // MARK: - Hero Content (With Glow & Fixed Height)
    private var heroContent: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = imageURL {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 400, alignment: .top)
                            .clipped()
                            .blur(radius: settings.blurNsfw ? 20 : 0)
                    } else {
                        placeholderView(height: 400)
                    }
                }
            } else {
                placeholderView(height: 400)
            }
            
            // Hero Gradient with Glow
            LinearGradient(
                gradient: Gradient(colors: [
                    (heroColor ?? .black).opacity(0.9),
                    (heroColor ?? .black).opacity(0.6),
                    .clear
                ]),
                startPoint: .bottom,
                endPoint: .center
            )
            .frame(height: 150)
            
            // Info
            PerformerMetadataRow(
                name: name,
                age: age,
                sceneCount: sceneCount,
                oCount: oCount,
                style: .card // Hero cards typically use card style metadata
            )
            .padding()
        }
        .cornerRadius(16)
        .shadow(color: (heroColor ?? .black).opacity(heroColor != nil ? 0.6 : 0.3), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(heroColor?.opacity(0.5) ?? Color.clear, lineWidth: 1)
        )
        .task {
            await extractHeroColor()
        }
    }
    
    private func placeholderView(height: CGFloat?) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(height: height) // If nil, expands in GeometryReader of grid
            .overlay(
                Text(String(name.prefix(1)))
                    .font(.system(size: 80))
                    .foregroundColor(.white)
            )
    }
    
    private func extractHeroColor() async {
        guard heroColor == nil, let url = imageURL else { return }
        
        if let color = await HeroAccentColor.extract(from: url) {
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.3)) {
                    self.heroColor = color
                }
            }
        }
    }
}
