import SwiftUI

/// A horizontal scrolling row (carousel) for a home category.
///
/// **Used by:** `HomeView`
struct CategoryRow: View {
    let category: SceneCategory
    let onSceneClick: ((Scene, Double?) -> Void)?
    let onStashDBSceneClick: ((StashDBScene) -> Void)?
    let onStudioClick: ((Studio) -> Void)?
    let onPerformerClick: ((String, String) -> Void)?
    let onSeeAllClick: ((SceneCategory) -> Void)?
    var zoomTransition: Namespace.ID? = nil
    @EnvironmentObject var dependencyContainer: DependencyContainer
    
    init(
        category: SceneCategory,
        zoomTransition: Namespace.ID? = nil,
        onSceneClick: ((Scene, Double?) -> Void)? = nil,
        onStashDBSceneClick: ((StashDBScene) -> Void)? = nil,
        onStudioClick: ((Studio) -> Void)? = nil,
        onPerformerClick: ((String, String) -> Void)? = nil,
        onSeeAllClick: ((SceneCategory) -> Void)? = nil
    ) {
        self.category = category
        self.zoomTransition = zoomTransition
        self.onSceneClick = onSceneClick
        self.onStashDBSceneClick = onStashDBSceneClick
        self.onStudioClick = onStudioClick
        self.onPerformerClick = onPerformerClick
        self.onSeeAllClick = onSeeAllClick
    }
    
    /// Display title with count for tag-based categories
    private var categoryTitle: String {
        if let tagIds = category.tagIds, !tagIds.isEmpty, let count = category.count {
            return "\(category.title) · \(count.formatted())"
        }
        return category.title
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(categoryTitle)
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    HapticManager.lightImpact()
                    onSeeAllClick?(category)
                }) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if category.type == .localScenes {
                        ForEach(category.scenes) { scene in
                            SceneCard(
                                scene: scene,
                                forceTitleHeight: true,
                                showDescription: false,
                                isCompact: true,
                                actions: SceneCardActions(
                                    onSceneClick: { scrubTime in
                                        onSceneClick?(scene, scrubTime)
                                    },
                                    onStudioClick: {
                                        if let studio = scene.studio {
                                            onStudioClick?(Studio(id: studio.id, name: studio.name))
                                        }
                                    },
                                    onPerformerClick: { id, name in
                                        onPerformerClick?(id, name)
                                    }
                                )
                            )

                            .frame(width: UIScreen.main.bounds.width - 28)
                        }
                    } else {
                        // Show skeleton cards if loading (empty stashDBScenes)
                        if category.stashDBScenes.isEmpty {
                            ForEach(0..<3, id: \.self) { _ in
                                SceneCardSkeleton()
                                    .frame(width: UIScreen.main.bounds.width - 28)
                            }
                        } else {
                            ForEach(category.stashDBScenes.prefix(10)) { scene in
                                SceneCard(
                                    stashDBScene: scene,
                                    forceTitleHeight: true,
                                    showDescription: false,
                                    isCompact: true,
                                    actions: SceneCardActions(
                                        onSceneClick: { _ in
                                            onStashDBSceneClick?(scene)
                                        },
                                        onStudioClick: {
                                            if let studio = scene.studio {
                                                onStudioClick?(Studio(id: studio.id, name: studio.name))
                                            }
                                        },
                                        onPerformerClick: { id, name in
                                            onPerformerClick?(id, name)
                                        }
                                    )
                                )
                                .frame(width: UIScreen.main.bounds.width - 28)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }
}

extension View {
    @ViewBuilder
    func ifLet<Value, Content: View>(_ value: Value?, transform: (Self, Value) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}
