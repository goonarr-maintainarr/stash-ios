import Foundation
@testable import Stash

class MockSettingsStore: SettingsStoreProtocol {
    var apiKey: String = "test-api-key"
    var serverUrl: String = "https://test.example.com"
    var url: URL? = URL(string: "https://test.example.com")
    var followedTagIds: [String] = []
    var isValid: Bool = true
    
    var whisparrUrl: String = ""
    var whisparrApiKey: String = ""
    var whisparrQualityProfileId: Int = 1
    var whisparrRootFolderPath: String = ""
    
    var stashDBUrl: String = ""
    var stashDBApiKey: String = ""
    var excludeVRFromStashDB: Bool = false
    var excludeCompilationsFromStashDB: Bool = false
    
    var prefetchOnScroll: Bool = true
    var prefetchHomeSceneDetails: Bool = true
    var showScenePreviews: Bool = false
    var muteScenePreviews: Bool = true
    var showMarkerPreviews: Bool = false
    var blurNsfw: Bool = false
    
    var isGeneratingContent: Bool = false
    var generationMessage: String?
    var isScanning: Bool = false
    var scanMessage: String?
    
    var generationOptions: GenerationOptions = GenerationOptions()
    var scanOptions: ScanOptions = ScanOptions()
    
    func addFollowedTag(id: String) {
        if !followedTagIds.contains(id) {
            followedTagIds.append(id)
        }
    }
    
    func removeFollowedTag(id: String) {
        if let index = followedTagIds.firstIndex(of: id) {
            followedTagIds.remove(at: index)
        }
    }
    
    func createImageUrl(path: String?) -> URL? {
        guard let path = path else { return nil }
        return URL(string: "https://test.example.com/\(path)")
    }
    
    func triggerGeneration() async {}
    func triggerScan() async {}
}
