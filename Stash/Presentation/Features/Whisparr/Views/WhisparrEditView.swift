import SwiftUI
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrEditView")

/// Edit form for a Whisparr-managed scene.
///
/// **Navigated from:** `WhisparrSceneListView`
struct WhisparrEditView: View {
    let movie: WhisparrScene
    @ObservedObject var metadata = WhisparrMetadataService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var monitored: Bool
    @State private var qualityProfileId: Int
    @State private var rootFolderPath: String
    
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showMoveConfirmation = false
    
    // Store original values to detect changes
    private let originalMonitored: Bool
    private let originalQualityProfileId: Int
    private let originalRootFolderPath: String
    
    init(movie: WhisparrScene) {
        self.movie = movie
        _monitored = State(initialValue: movie.monitored)
        _qualityProfileId = State(initialValue: movie.qualityProfileId ?? 0)
        _rootFolderPath = State(initialValue: movie.rootFolderPath ?? "")
        
        // Store originals
        self.originalMonitored = movie.monitored
        self.originalQualityProfileId = movie.qualityProfileId ?? 0
        self.originalRootFolderPath = movie.rootFolderPath ?? ""
    }
    
    // Helper to ensure current root folder is displayed even if not in fetched list
    // Only add it if it's not already in the list (no duplicates)
    private var displayedRootFolders: [WhisparrRootFolder] {
        var folders = metadata.rootFolders
        // Only add current root folder if it's not already in the list
        if !originalRootFolderPath.isEmpty && !folders.contains(where: { $0.path == originalRootFolderPath }) {
            let current = WhisparrRootFolder(id: -1, path: originalRootFolderPath, accessible: true, freeSpace: 0, unmappedFolders: nil)
            folders.append(current)
        }
        return folders
    }
    
    var body: some View {
        NavigationView {
            Form {
                if metadata.isLoading && metadata.qualityProfiles.isEmpty {
                    ProgressView()
                } else {
                    Section {
                        Toggle("Monitored", isOn: $monitored)
                            .tint(.blue)
                        
                        Picker("Quality Profile", selection: $qualityProfileId) {
                            ForEach(metadata.qualityProfiles) { profile in
                                Text(profile.name).tag(profile.id)
                            }
                        }
                        
                        if !displayedRootFolders.isEmpty {
                            Picker("Root Folder", selection: $rootFolderPath) {
                                ForEach(displayedRootFolders) { folder in
                                    Text(folder.path).tag(folder.path)
                                }
                            }
                        }
                    }
                }
                
                if let error = saveError ?? metadata.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit Movie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveChanges() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving || (metadata.isLoading && metadata.qualityProfiles.isEmpty))
                }
            }
            .task {
                await metadata.ensureLoaded()
                // Set default quality profile if unset and available
                if qualityProfileId == 0, let first = metadata.qualityProfiles.first {
                    qualityProfileId = first.id
                }
            }
            .background(Color.clear)
            .alert("Move Files?", isPresented: $showMoveConfirmation) {
                Button("Move Files", role: .none) {
                    Task { await performSave(moveFiles: true) }
                }
                Button("No", role: .destructive) {
                    Task { await performSave(moveFiles: false) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Do you want to move the files to the new root folder?")
            }
        }
    }
    
    private func hasRootFolderChanged() -> Bool {
        return rootFolderPath != originalRootFolderPath
    }
    
    private func saveChanges() async {
        logger.info("💾 WhisparrEditView - saveChanges() called")
        logger.info("📊 Current values - monitored: \(monitored), qualityProfileId: \(qualityProfileId), rootFolderPath: \(rootFolderPath)")
        logger.info("📊 Original values - monitored: \(originalMonitored), qualityProfileId: \(originalQualityProfileId), rootFolderPath: \(originalRootFolderPath)")
        
        // Check if root folder changed and movie has files
        if hasRootFolderChanged() && movie.hasFile {
            logger.info("📏 Root folder changed and movie has files - showing move confirmation")
            showMoveConfirmation = true
            return
        }
        
        // If no file or root folder didn't change, save without moving
        await performSave(moveFiles: nil)
    }
    
    private func performSave(moveFiles: Bool?) async {
        logger.info("💾 WhisparrEditView - performSave(moveFiles: \(moveFiles?.description ?? "nil")) called")
        
        isSaving = true
        saveError = nil
        
        do {
            let repository = WhisparrRepository()
            let updatedScene: WhisparrScene
            
            // Use editor endpoint if root folder changed, otherwise use regular update
            if hasRootFolderChanged() {
                logger.info("🌐 Calling repository.updateSceneUsingEditor() with moveFiles: \(moveFiles?.description ?? "nil")")
                updatedScene = try await repository.updateSceneUsingEditor(
                    scene: movie,
                    monitored: monitored,
                    qualityProfileId: qualityProfileId,
                    rootFolderPath: rootFolderPath,
                    moveFiles: moveFiles
                )
            } else {
                logger.info("🌐 Calling repository.updateScene()")
                updatedScene = try await repository.updateScene(
                    scene: movie,
                    monitored: monitored,
                    qualityProfileId: qualityProfileId,
                    rootFolderPath: rootFolderPath
                )
            }
            
            logger.info("✅ Update successful! Returned scene - monitored: \(updatedScene.monitored), qualityProfileId: \(updatedScene.qualityProfileId ?? -1), rootFolderPath: \(updatedScene.rootFolderPath ?? "nil")")
            
            HapticManager.success()
            dismiss()
        } catch {
            logger.error("❌ Update failed: \(error.localizedDescription)")
            saveError = "Failed to save: \(error.localizedDescription)"
            HapticManager.error()
        }
        
        isSaving = false
    }
}
