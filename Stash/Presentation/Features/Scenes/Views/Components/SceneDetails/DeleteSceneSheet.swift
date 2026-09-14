import SwiftUI

struct DeleteSceneSheet: View {
    @Binding var deleteFile: Bool
    @Binding var deleteGenerated: Bool
    @Binding var isDeleting: Bool
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Are you sure you want to delete this scene?")
                        .font(.headline)
                    
                    Toggle("Delete File from Disk", isOn: $deleteFile)
                        .tint(.red)
                    
                    Toggle("Delete Generated Content", isOn: $deleteGenerated)
                        .tint(.red)
                    
                    Text("Generated content includes thumbnails, previews, and other cached data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        onConfirm()
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "trash.fill")
                                Text("Delete")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isDeleting)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Delete Scene")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.clear)
        }
    }
}
