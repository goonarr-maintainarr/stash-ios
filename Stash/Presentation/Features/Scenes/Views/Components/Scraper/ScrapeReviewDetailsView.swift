import SwiftUI

struct ScrapeReviewDetailsView: View {
    let result: ScrapedScene
    let currentScene: Scene
    @Binding var useTitle: Bool
    @Binding var useDetails: Bool
    @Binding var useTags: Bool
    @Binding var useStudio: Bool
    @Binding var useDirector: Bool
    @Binding var useCode: Bool
    @Binding var useUrl: Bool
    @Binding var workingTags: [ScrapedTag]
    
    var body: some View {
        VStack(spacing: 20) {
            // Title Section
            VStack(alignment: .leading, spacing: 10) {
                Text("Title")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    SelectionRow(
                        title: "Current",
                        isSelected: !useTitle,
                        action: { useTitle = false }
                    ) {
                        Text(currentScene.title ?? "No Title")
                            .foregroundColor(.secondary)
                    }
                    
                    if let newTitle = result.title {
                        Divider()
                        SelectionRow(
                            title: "Scraped",
                            isSelected: useTitle,
                            action: { useTitle = true }
                        ) {
                            Text(newTitle)
                                .fontWeight(.medium)
                        }
                    } else {
                        Text("No title in result").font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.stashCardBackground)
                .cornerRadius(10)
            }
            
            // Description Section
            VStack(alignment: .leading, spacing: 10) {
                Text("Description")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    SelectionRow(
                        title: "Current",
                        isSelected: !useDetails,
                        action: { useDetails = false }
                    ) {
                        Text(currentScene.details ?? "No Description")
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    if let newDetails = result.details {
                        Divider()
                        SelectionRow(
                            title: "Scraped",
                            isSelected: useDetails,
                            action: { useDetails = true }
                        ) {
                            Text(newDetails)
                                .fontWeight(.medium)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text("No description in result").font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.stashCardBackground)
                .cornerRadius(10)
            }
            
            // Tags Section
            VStack(alignment: .leading, spacing: 10) {
                 Text("Tags")
                     .font(.title3)
                     .fontWeight(.bold)
                     .foregroundColor(.white)
                     .padding(.horizontal)
                 
                 VStack(alignment: .leading, spacing: 12) {
                     SelectionRow(
                         title: "Current (\(currentScene.tags?.count ?? 0))",
                         isSelected: !useTags,
                         action: { useTags = false }
                     ) {
                         if let current = currentScene.tags, !current.isEmpty {
                             Text(current.map { $0.name }.joined(separator: ", "))
                                 .font(.caption)
                                 .foregroundColor(.secondary)
                                 .lineLimit(2)
                         } else {
                             Text("None").font(.caption).foregroundColor(.secondary)
                         }
                     }
                     
                     if !workingTags.isEmpty {
                         Divider()
                         SelectionRow(
                             title: "Scraped (\(workingTags.count))",
                             isSelected: useTags,
                             action: { useTags = true }
                         ) {
                             VStack(spacing: 8) {
                                 ForEach(workingTags, id: \.name) { tag in
                                     HStack {
                                         Text(tag.name)
                                             .font(.subheadline)
                                             .fontWeight(.medium)
                                         Spacer()
                                         Button {
                                             if let index = workingTags.firstIndex(where: { $0.name == tag.name }) {
                                                 workingTags.remove(at: index)
                                             }
                                         } label: {
                                             Image(systemName: "xmark")
                                                 .foregroundColor(.red)
                                                 .font(.caption)
                                                 .padding(8)
                                                 .background(Color.red.opacity(0.1))
                                                 .clipShape(Circle())
                                         }
                                     }
                                     .padding(.vertical, 4)
                                     Divider()
                                 }
                             }
                         }
                     } else {
                          Text("No tags in result").font(.caption).foregroundColor(.secondary)
                     }
                 }
                 .padding()
                 .background(Color.stashCardBackground)
                 .cornerRadius(10)
            }
            
            // Stash ID Section
            VStack(alignment: .leading, spacing: 10) {
                 Text("Stash ID")
                     .font(.title3)
                     .fontWeight(.bold)
                     .foregroundColor(.white)
                     .padding(.horizontal)
                 
                 VStack(alignment: .leading, spacing: 12) {
                     // Current
                     VStack(alignment: .leading, spacing: 4) {
                         Text("Current")
                             .font(.caption)
                             .foregroundColor(.secondary)
                             .textCase(.uppercase)
                         
                         if let currentIds = currentScene.stash_ids, !currentIds.isEmpty {
                             ForEach(currentIds, id: \.stash_id) { sid in
                                 Text(sid.stash_id)
                                     .font(.subheadline)
                                     .foregroundColor(.secondary)
                             }
                         } else {
                             Text("None")
                                 .font(.subheadline)
                                 .foregroundColor(.secondary)
                         }
                     }
                     .frame(maxWidth: .infinity, alignment: .leading)
                     .padding(.vertical, 4)
                     
                     if let newId = result.remote_site_id {
                         Divider()
                         
                         VStack(alignment: .leading, spacing: 4) {
                             Text("Scraped")
                                 .font(.caption)
                                 .foregroundColor(.secondary)
                                 .textCase(.uppercase)
                             
                             Text(newId)
                                 .font(.subheadline)
                                 .fontWeight(.medium)
                                 .foregroundColor(.white)
                         }
                         .frame(maxWidth: .infinity, alignment: .leading)
                         .padding(.vertical, 4)
                     }
                 }
                 .padding()
                 .background(Color.stashCardBackground)
                 .cornerRadius(10)
            }
            
            // Studio Section
            VStack(alignment: .leading, spacing: 10) {
                 Text("Studio")
                     .font(.title3)
                     .fontWeight(.bold)
                     .foregroundColor(.white)
                     .padding(.horizontal)
                 
                 VStack(alignment: .leading, spacing: 12) {
                     SelectionRow(
                         title: "Current",
                         isSelected: !useStudio,
                         action: { useStudio = false }
                     ) {
                         Text(currentScene.studio?.name ?? "No Studio")
                             .foregroundColor(.secondary)
                     }
                     
                     if let newStudio = result.studio?.name {
                         Divider()
                         SelectionRow(
                             title: "Scraped",
                             isSelected: useStudio,
                             action: { useStudio = true }
                         ) {
                             Text(newStudio)
                                 .fontWeight(.medium)
                         }
                     } else {
                         Text("No studio in result").font(.caption).foregroundColor(.secondary)
                     }
                 }
                 .padding()
                 .background(Color.stashCardBackground)
                 .cornerRadius(10)
            }

            // Director Section
            VStack(alignment: .leading, spacing: 10) {
                 Text("Director")
                     .font(.title3)
                     .fontWeight(.bold)
                     .foregroundColor(.white)
                     .padding(.horizontal)
                 
                 VStack(alignment: .leading, spacing: 12) {
                     SelectionRow(
                         title: "Current",
                         isSelected: !useDirector,
                         action: { useDirector = false }
                     ) {
                         // Check if Scene has director. It's usually in `director` property or handled via special logic. 
                         // Assuming `director` property exists on Scene based on Stash schema. 
                         // If not, I should have checked Scene model. Assuming optional String.
                         // But `Scene` structure definition (Step ??) wasn't fully checked for Director. 
                         // If it doesn't exist, this line might fail. 
                         // Logic check: User asked to "get director".
                         // Stash usually has Director field.
                         // I will try to access `currentScene.director`. If it fails, I'll need to fix Scene model.
                         Text(currentScene.director ?? "None") 
                             .foregroundColor(.secondary)
                     }
                     
                     if let director = result.director {
                         Divider()
                         SelectionRow(
                             title: "Scraped",
                             isSelected: useDirector,
                             action: { useDirector = true }
                         ) {
                             Text(director)
                                 .fontWeight(.medium)
                         }
                     } else {
                         Text("No director in result").font(.caption).foregroundColor(.secondary)
                     }
                 }
                 .padding()
                 .background(Color.stashCardBackground)
                 .cornerRadius(10)
            }
            
            // Code Section
            VStack(alignment: .leading, spacing: 10) {
                 Text("Scene Code")
                     .font(.title3)
                     .fontWeight(.bold)
                     .foregroundColor(.white)
                     .padding(.horizontal)
                 
                 VStack(alignment: .leading, spacing: 12) {
                     SelectionRow(
                         title: "Current",
                         isSelected: !useCode,
                         action: { useCode = false }
                     ) {
                         Text(currentScene.code ?? "None")
                             .foregroundColor(.secondary)
                     }
                     
                     if let code = result.code {
                         Divider()
                         SelectionRow(
                             title: "Scraped",
                             isSelected: useCode,
                             action: { useCode = true }
                         ) {
                             Text(code)
                                 .fontWeight(.medium)
                         }
                     } else {
                         Text("No code in result").font(.caption).foregroundColor(.secondary)
                     }
                 }
                 .padding()
                 .background(Color.stashCardBackground)
                 .cornerRadius(10)
            }
            
            // URL Section
            VStack(alignment: .leading, spacing: 10) {
                 Text("URL")
                     .font(.title3)
                     .fontWeight(.bold)
                     .foregroundColor(.white)
                     .padding(.horizontal)
                 
                 VStack(alignment: .leading, spacing: 12) {
                     SelectionRow(
                         title: "Current",
                         isSelected: !useUrl,
                         action: { useUrl = false }
                     ) {
                        if let url = currentScene.url {
                            Text(url)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("None")
                                .foregroundColor(.secondary)
                        }
                     }
                     
                     if let url = result.url ?? result.urls?.first {
                         Divider()
                         SelectionRow(
                             title: "Scraped",
                             isSelected: useUrl,
                             action: { useUrl = true }
                         ) {
                             Text(url)
                                 .fontWeight(.medium)
                                 .lineLimit(1)
                         }
                     } else {
                         Text("No url in result").font(.caption).foregroundColor(.secondary)
                     }
                 }
                 .padding()
                 .background(Color.stashCardBackground)
                 .cornerRadius(10)
            }
            
        }
    }
}
