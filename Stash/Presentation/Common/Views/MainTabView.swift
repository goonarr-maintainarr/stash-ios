import SwiftUI
import Combine

/// The root view of the application, managing the main tab navigation.
///
/// **Contains:**
/// - `HomeView`
/// - `SceneListView`
/// - `PerformerListView`
/// - `WhisparrDashboard` (Hub)
/// - `SettingsView`
struct MainTabView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var container: DependencyContainer
    var floatingPlayerManager: FloatingVideoPlayerService
    @State private var queueManager = WhisparrQueueService.shared
    @State private var selectedTab = 0
    
    // Toast State
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastView.ToastType = .info
    
    // ViewModel Factory to ensure single initialization
    @MainActor
    class ViewModelFactory: ObservableObject {
        let container: DependencyContainer
        
        lazy var homeViewModel: HomeViewModel = {
            return container.makeHomeViewModel()
        }()
        
        lazy var sceneListViewModel: SceneListViewModel = {
            return container.makeSceneListViewModel()
        }()
        
        lazy var performerListViewModel: PerformerListViewModel = {
            return container.makePerformerListViewModel()
        }()
        
        lazy var settingsViewModel: SettingsViewModel = {
            return container.makeSettingsViewModel()
        }()
        
        lazy var settingsCoordinator: SettingsCoordinator = {
            return container.makeSettingsCoordinator()
        }()
        
        lazy var whisparrSceneListViewModel: WhisparrSceneListViewModel = {
            return container.makeWhisparrSceneListViewModel()
        }()
        
        init(container: DependencyContainer) {
            self.container = container
        }
    }
    
    @StateObject private var viewModelFactory: ViewModelFactory
    
    init(container: DependencyContainer, floatingPlayerManager: FloatingVideoPlayerService) {
        self.floatingPlayerManager = floatingPlayerManager
        _viewModelFactory = StateObject(wrappedValue: ViewModelFactory(container: container))
    }
    
    var body: some View {
        ZStack {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: viewModelFactory.homeViewModel)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            SceneListView(viewModel: viewModelFactory.sceneListViewModel)
                .tabItem {
                    Label("Scenes", systemImage: "film")
                }
                .tag(1)

            PerformerListView(viewModel: viewModelFactory.performerListViewModel)
                .tabItem {
                    Label("Performers", systemImage: "person.2")
                }
                .tag(2)
            
            if !settingsStore.whisparrUrl.isEmpty && !settingsStore.whisparrApiKey.isEmpty {
                WhisparrSceneListView(viewModel: viewModelFactory.whisparrSceneListViewModel)
                .tabItem {
                    Label("Whisparr", systemImage: "video.fill")
                }
                .badge(queueManager.items.isEmpty ? 0 : queueManager.items.count)
                .tag(3)
            }

            SettingsView(
                viewModel: viewModelFactory.settingsViewModel,
                coordinator: viewModelFactory.settingsCoordinator
            )
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .onChange(of: selectedTab) { _ in
            HapticManager.mediumImpact()
        }
        .preferredColorScheme(.dark)
        .task {
            // Start global job subscription
            let service = container.stashSubscriptionService
            if settingsStore.isValid, let url = settingsStore.url {
                 service.connect(url: url, apiKey: settingsStore.apiKey)
            }
        }
        
        // Floating video player overlay
        FloatingVideoPlayerView(manager: floatingPlayerManager)
        
        // Toast Overlay
        if showToast {
            VStack {
                Spacer()
                ToastView(message: toastMessage, type: toastType)
                    .onTapGesture {
                        withAnimation { showToast = false }
                    }
            }
            .padding(.bottom, 60) // Position above tab bar
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(100)
        }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stashAllJobsCompleted)) { notification in
            // Only show toast if an Identify job was part of the batch
            guard let hasIdentify = notification.userInfo?["hasIdentify"] as? Bool, hasIdentify else {
                return
            }
            
            toastMessage = "New scenes added"
            toastType = .success
            
            withAnimation {
                showToast = true
            }
            
            // Haptic feedback
            HapticManager.success()
            
            // Auto hide after 4 seconds
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                withAnimation {
                    showToast = false
                }
            }
        }
    }
}
