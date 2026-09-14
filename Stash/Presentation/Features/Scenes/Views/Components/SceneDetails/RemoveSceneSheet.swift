import SwiftUI

/// A confirmation sheet for deleting a scene (and optionally its file).
///
/// **Presented by:** `SceneDetailView`
struct RemoveSceneSheet: View {
    let onRemove: (Bool, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var deleteFiles = false
    @State private var addImportExclusion = false
    
    var body: some View {
        NavigationView {
             Form {
                 Section(footer: Text("If enabled, the actual video files will be permanently deleted from your storage.")) {
                     Toggle("Delete files", isOn: $deleteFiles)
                 }
                 
                 Section(footer: Text("If enabled, this scene will be added to the blocklist to prevent it from being re-imported in the future.")) {
                     Toggle("Add to exclusion list", isOn: $addImportExclusion)
                 }
             }
             .scrollContentBackground(.hidden)
             .background(Color.clear)
             .navigationTitle("Remove Scene")
             .navigationBarTitleDisplayMode(.inline)
             .toolbar {
                 ToolbarItem(placement: .cancellationAction) {
                     Button("Cancel") { dismiss() }
                 }
                 ToolbarItem(placement: .navigationBarTrailing) {
                     Button(role: .destructive) {
                         onRemove(deleteFiles, addImportExclusion)
                         dismiss()
                     } label: {
                         Image(systemName: "trash")
                             .foregroundColor(.red)
                     }
                 }
             }
        }
    }
}
