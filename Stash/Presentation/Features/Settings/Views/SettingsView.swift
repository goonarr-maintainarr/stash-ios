import os
import SwiftUI


private let logger = Logger(subsystem: "com.stash.app", category: "SettingsView")

/// The main settings configuration screen.
///
/// **Part of:** `MainTabView` (Fifth Tab)
struct SettingsView: View {
    @EnvironmentObject var store: SettingsStore
    @EnvironmentObject var container: DependencyContainer
    let viewModel: SettingsViewModel
    let coordinator: SettingsCoordinator
    
    @State private var showFullSyncConfirmation = false
    
    init(viewModel: SettingsViewModel, coordinator: SettingsCoordinator) {
        self.viewModel = viewModel
        self.coordinator = coordinator
    }
    
    var body: some View {
        let _ = logger.debug("🔄 SettingsView.body evaluated")
        NavigationStack {
            List {
                serverAndTasksSection
                    .id("serverTasks")  // Stable identity
                WhisparrLogsSection()
                    .id("whisparrLogs")
                whisparrSection
                    .id("whisparr")
                stashDBAndSettingsSection
                    .id("stashDB")
            }
        .scrollContentBackground(.hidden)
        .background(Color.stashBackground)
        .listRowBackground(Color.stashCardBackground)
        .navigationTitle("Settings")
        .task {
            // Load Whisparr config
            if !store.whisparrUrl.isEmpty && !store.whisparrApiKey.isEmpty {
                await viewModel.fetchWhisparrConfig()
            }
            
            // Safety check: ensure Stash subscription is connected
            let subscriptionService = StashSubscriptionService.shared
            if !subscriptionService.isConnected && store.isValid, let url = store.url {
                 logger.debug("⚠️ Global subscription not connected, connecting from Settings...")
                 subscriptionService.connect(url: url, apiKey: store.apiKey)
            }
            
            // Connect to Whisparr SignalR if configured
            if !store.whisparrUrl.isEmpty && !store.whisparrApiKey.isEmpty {
                let whisparrService = WhisparrSignalRService.shared
                if !whisparrService.isConnected {
                    whisparrService.connect(url: store.whisparrUrl, apiKey: store.whisparrApiKey)
                }
            }
        }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .scanOptions:
                    ScanOptionsSheet()
                        .environmentObject(store)
                case .generationOptions:
                    SceneGenerationSheet()
                        .environmentObject(store)
                }
            }
        }
        .alert("Full Sync", isPresented: $showFullSyncConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sync") {
                Task {
                    await coordinator.performFullSync()
                }
            }
        } message: {
            Text("This will fetch all data from your Stash server and remove any items that have been deleted. This may take a few minutes for large libraries.")
        }
    }
    
    // MARK: - Extracted Sections
    
    @ViewBuilder
    private var serverAndTasksSection: some View {
        Group {
            // Tasks Section - self-contained, observes JobsState directly
            if store.isValid {
                JobQueueSection()
            }
            
            if store.isValid {
                Section(header: Text("Library")) {
                    Button(action: {
                        HapticManager.lightImpact()
                        viewModel.triggerScan()
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Scan")
                        }
                    }
                    
                    NavigationLink(value: SettingsRoute.scanOptions) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("Scan Options")
                        }
                    }
                }
                
                Section(header: Text("Content Generation")) {
                    Button(action: {
                        HapticManager.lightImpact()
                        viewModel.triggerGeneration()
                    }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Generate Content")
                        }
                    }
                    
                    NavigationLink(value: SettingsRoute.generationOptions) {
                        HStack {
                            Image(systemName: "gearshape")
                            Text("Generation Options")
                        }
                    }
                }
            }
            
            Section(header: Text("Server Connection"), footer: Text("Enter the full URL to your Stash GraphQL endpoint, e.g., http://stash.local:9999/graphql or https://stash.example.com/graphql")) {
                HStack {
                    TextField("Server URL", text: $store.serverUrl)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    
                    if store.isValid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                SecureField("API Key", text: $store.apiKey)
                
                Button(action: {
                    Task { await viewModel.testStashConnection() }
                }) {
                    HStack {
                        Text("Test Connection")
                        Spacer()
                        if viewModel.isTestingStash {
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.isTestingStash || !store.isValid)
                
                if let message = viewModel.testMessage {
                    Text(message)
                        .foregroundColor(viewModel.testSuccess ? .green : .red)
                        .font(.caption)
                }
            }
        }
        .listRowBackground(Color.stashCardBackground)
    }
    
    @ViewBuilder
    private var whisparrSection: some View {
        Group {
            Section(header: Text("Whisparr Integration"), footer: Text("Enter your Whisparr server URL (e.g., http://whisparr.local:8787) and API key. Root folders and quality profiles will be fetched automatically. The Whisparr tab will appear when both are configured.")) {
                HStack {
                    TextField("Whisparr URL", text: $store.whisparrUrl)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    
                    if URL(string: store.whisparrUrl) != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                SecureField("Whisparr API Key", text: $store.whisparrApiKey)
                    .onChange(of: store.whisparrApiKey) { _, _ in
                        Task { await viewModel.fetchWhisparrConfig() }
                    }
                
                // Root folder and quality profile pickers
                if !store.whisparrUrl.isEmpty && !store.whisparrApiKey.isEmpty {
                    Picker("Root Folder", selection: $store.whisparrRootFolderPath) {
                        if viewModel.availableRootFolders.isEmpty {
                            Text("None found").tag("")
                        } else {
                            ForEach(viewModel.availableRootFolders) { folder in
                                Text(folder.path).tag(folder.path)
                            }
                        }
                    }
                    .disabled(viewModel.availableRootFolders.isEmpty)
                    
                    Picker("Quality Profile", selection: $store.whisparrQualityProfileId) {
                        if viewModel.availableQualityProfiles.isEmpty {
                            Text("None found").tag(0)
                        } else {
                            ForEach(viewModel.availableQualityProfiles) { profile in
                                Text(profile.name).tag(profile.id)
                            }
                        }
                    }
                    .disabled(viewModel.availableQualityProfiles.isEmpty)
                    
                    Button(action: {
                        Task { await viewModel.fetchWhisparrConfig() }
                    }) {
                        HStack {
                            Text("Load Configuration")
                            Spacer()
                            if viewModel.isLoadingWhisparrConfig {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isLoadingWhisparrConfig)
                    
                    if let error = viewModel.whisparrConfigError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }

        }
        .listRowBackground(Color.stashCardBackground)
    }
    
    @ViewBuilder
    private var stashDBAndSettingsSection: some View {
        Group {
            Section(header: Text("StashDB Integration")) {
                SecureField("StashDB API Key", text: $store.stashDBApiKey)
                
                Text("Endpoint: \(store.stashDBUrl)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Toggle("Exclude VR Videos", isOn: $store.excludeVRFromStashDB)
                Toggle("Exclude Compilations", isOn: $store.excludeCompilationsFromStashDB)
                Toggle("Exclude Owned Scenes", isOn: $store.excludeOwnedScenesFromStashDB)
            }
            
            Section(footer: Text("Enter your StashDB API key to enable StashDB integration. Enable filters to exclude VR videos and/or compilation scenes when viewing performer scenes on StashDB.")) {
                if !store.stashDBApiKey.isEmpty {
                    Label("StashDB API Key Set", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            Section {
                Button(action: {
                    HapticManager.lightImpact()
                    Task {
                        await viewModel.testStashDBConnection()
                    }
                }) {
                    HStack {
                        Text("Test StashDB Connection")
                        Spacer()
                        if viewModel.isTestingStashDB {
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.isTestingStashDB || store.stashDBApiKey.isEmpty)
                
                if let message = viewModel.testStashDBMessage {
                    Text(message)
                        .foregroundColor(viewModel.testStashDBSuccess ? .green : .red)
                        .font(.caption)
                }
            }
            
            Section {
                Toggle("Prefetch on Scroll", isOn: $store.prefetchOnScroll)
                Toggle("Show Scene Previews", isOn: $store.showScenePreviews)
                Toggle("Mute Scene Previews", isOn: $store.muteScenePreviews)
                    .disabled(!store.showScenePreviews)
                Toggle("Show Marker Previews", isOn: $store.showMarkerPreviews)
            } header: {
                Text("Performance")
            } footer: {
                Text("'Prefetch on Scroll' prefetches scene details and images as you scroll. 'Show Scene Previews' enables video previews on long press (streams ~12s videos on-demand). 'Mute Scene Previews' disables audio for preview videos. 'Show Marker Previews' enables video previews for scene markers. Disable any to reduce server load if you experience performance issues.")
            }
            
            
            DataManagementSection(
                coordinator: coordinator,
                isServerValid: store.isValid,
                showFullSyncConfirmation: $showFullSyncConfirmation
            )
        }
        .listRowBackground(Color.stashCardBackground)
    }
}
