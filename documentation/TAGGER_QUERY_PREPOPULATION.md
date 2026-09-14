# Tagger Query Prepopulation - iOS

This document explains how the Stash tagger prepopulates the search query field based on scene metadata and parse modes.

## Table of Contents

- [Overview](#overview)
- [Parse Modes](#parse-modes)
- [Query Building Logic](#query-building-logic)
- [Blacklist Processing](#blacklist-processing)
- [iOS Implementation](#ios-implementation)
- [Examples](#examples)

---

## Overview

When the tagger loads a scene, it automatically generates a search query string based on:

1. **Parse Mode** - How to extract the query (metadata, filename, path, etc.)
2. **Scene Metadata** - Existing scene information (date, studio, performers, title)
3. **File Path** - Directory and filename information
4. **Blacklist Patterns** - Regex patterns to filter out unwanted text

The prepopulated query appears in the search field and can be edited before searching.

---

## Parse Modes

### 1. Auto Mode (Default)

**Logic:**
- If scene has both `date` AND `studio`: Use **Metadata Mode**
- Otherwise: Use **Filename Mode**

**Best for:** Most users - automatically chooses the best method

---

### 2. Metadata Mode

**Uses existing scene metadata:**

```
[date] [studio name] [performer names] [title]
```

**Fields:**
- `scene.date` - Release date (YYYY-MM-DD)
- `scene.studio.name` - Studio name
- `scene.performers[].name` - All performer names (space-separated)
- `scene.title` - Scene title (special characters removed)

**Example:**
```
2024-01-15 Brazzers Jane Doe John Smith Hot Scene Title
```

**Best for:** Scenes with complete metadata already entered

---

### 3. Filename Mode

**Uses the filename without extension:**

```
Scene.Title.2024.1080p.mp4 → Scene Title 2024 1080p
```

**Processing:**
1. Remove file extension
2. Replace dots with spaces
3. Apply blacklist filters
4. Replace multiple spaces with single space

**Example:**
```
Brazzers.Jane.Doe.2024.1080p.x264.mp4 → Brazzers Jane Doe 2024 1080p x264
```

**Best for:** Well-named files with scene info in filename

---

### 4. Path Mode

**Uses full directory path + filename:**

```
/movies/studio/2024/Scene.Title.mp4 → movies studio 2024 Scene Title
```

**Example:**
```
/media/adult/Brazzers/2024/Hot.Scene.mp4 → media adult Brazzers 2024 Hot Scene
```

**Best for:** Organized library with studio/date in folder structure

---

### 5. Directory Mode

**Uses only the parent directory name:**

```
/movies/studio/2024/Scene.Title.mp4 → 2024
```

**Example:**
```
/media/Brazzers/Scene.Title.mp4 → Brazzers
```

**Best for:** Studio or collection folders

---

## Query Building Logic

### Decision Flow

```
if parseMode == .auto {
    if scene.date != nil && scene.studio != nil {
        // Use Metadata Mode
        query = buildMetadataQuery(scene)
    } else {
        // Use Filename Mode
        query = buildFilenameQuery(scene.files[0].path)
    }
} else if parseMode == .metadata {
    query = buildMetadataQuery(scene)
} else if parseMode == .filename {
    query = buildFilenameQuery(scene.files[0].path)
} else if parseMode == .path {
    query = buildPathQuery(scene.files[0].path)
} else if parseMode == .directory {
    query = buildDirectoryQuery(scene.files[0].path)
}

// Apply blacklist filters
query = applyBlacklist(query, patterns: blacklist)
```

---

### Metadata Query Building

```swift
func buildMetadataQuery(scene: Scene) -> String {
    var components: [String] = []
    
    // Add date
    if let date = scene.date {
        components.append(date)
    }
    
    // Add studio name
    if let studioName = scene.studio?.name {
        components.append(studioName)
    }
    
    // Add performer names
    let performerNames = scene.performers.map { $0.name }.joined(separator: " ")
    if !performerNames.isEmpty {
        components.append(performerNames)
    }
    
    // Add title (remove special characters)
    if let title = scene.title {
        let cleanTitle = title.replacingOccurrences(
            of: "[^a-zA-Z0-9 ]+",
            with: "",
            options: .regularExpression
        )
        if !cleanTitle.isEmpty {
            components.append(cleanTitle)
        }
    }
    
    return components.filter { !$0.isEmpty }.joined(separator: " ")
}
```

---

### Filename Query Building

```swift
func buildFilenameQuery(path: String) -> String {
    // Get filename without extension
    let url = URL(fileURLWithPath: path)
    let filename = url.deletingPathExtension().lastPathComponent
    
    // Replace dots with spaces
    var query = filename.replacingOccurrences(of: ".", with: " ")
    
    // Replace multiple spaces with single space
    query = query.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
    
    return query.trimmingCharacters(in: .whitespaces)
}
```

---

### Path Query Building

```swift
func buildPathQuery(path: String) -> String {
    let url = URL(fileURLWithPath: path)
    
    // Get all path components (directories + filename)
    var components = url.pathComponents
    
    // Remove root "/" and extension from filename
    components = components.filter { $0 != "/" }
    let filename = url.deletingPathExtension().lastPathComponent
    components[components.count - 1] = filename
    
    // Join and process
    var query = components.joined(separator: " ")
    query = query.replacingOccurrences(of: ".", with: " ")
    query = query.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
    
    return query.trimmingCharacters(in: .whitespaces)
}
```

---

### Directory Query Building

```swift
func buildDirectoryQuery(path: String) -> String {
    let url = URL(fileURLWithPath: path)
    
    // Get parent directory name
    let directory = url.deletingLastPathComponent().lastPathComponent
    
    return directory
}
```

---

## Blacklist Processing

Blacklist patterns are **regular expressions** that filter out unwanted text from the query string.

### Common Blacklist Patterns

```swift
let commonBlacklist = [
    "1080p",           // Remove resolution
    "720p",
    "480p",
    "4K",
    "x264",            // Remove codec
    "x265",
    "HEVC",
    "h264",
    "\\[.*?\\]",       // Remove [bracketed] text
    "\\(.*?\\)",       // Remove (parenthetical) text
    "XXX",
    "RARBG",           // Remove release group names
    "YIFY",
    "\\.com",          // Remove .com domains
    "www\\.",
]
```

### Applying Blacklist

```swift
func applyBlacklist(_ query: String, patterns: [String]) -> String {
    var result = query
    
    // Convert patterns to NSRegularExpression
    let regexPatterns = patterns.compactMap {
        try? NSRegularExpression(pattern: $0, options: .caseInsensitive)
    }
    
    // Apply each pattern
    for regex in regexPatterns {
        let range = NSRange(result.startIndex..., in: result)
        result = regex.stringByReplacingMatches(
            in: result,
            range: range,
            withTemplate: " "
        )
    }
    
    // Clean up multiple spaces
    result = result.replacingOccurrences(
        of: " +",
        with: " ",
        options: .regularExpression
    )
    
    return result.trimmingCharacters(in: .whitespaces)
}
```

---

## iOS Implementation

### Data Models

```swift
import Foundation

enum ParseMode: String, Codable, CaseIterable {
    case auto = "auto"
    case metadata = "metadata"
    case filename = "filename"
    case path = "path"
    case directory = "dir"
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .metadata: return "Metadata"
        case .filename: return "Filename"
        case .path: return "Path"
        case .directory: return "Directory"
        }
    }
}

struct TaggerConfig: Codable {
    var parseMode: ParseMode = .auto
    var blacklist: [String] = []
}
```

---

### Query Prepopulation Service

```swift
import Foundation

class TaggerQueryService {
    private let config: TaggerConfig
    
    init(config: TaggerConfig) {
        self.config = config
    }
    
    // MARK: - Main Method
    
    func prepareQueryString(for scene: Scene) -> String {
        let mode = config.parseMode
        let blacklist = config.blacklist
        
        var query = ""
        
        // Determine query based on mode
        if mode == .auto {
            // Auto: Use metadata if available, else filename
            if scene.date != nil && scene.studio != nil {
                query = buildMetadataQuery(scene)
            } else if let path = scene.files.first?.path {
                query = buildFilenameQuery(path)
            }
        } else if mode == .metadata {
            query = buildMetadataQuery(scene)
        } else if mode == .filename {
            if let path = scene.files.first?.path {
                query = buildFilenameQuery(path)
            }
        } else if mode == .path {
            if let path = scene.files.first?.path {
                query = buildPathQuery(path)
            }
        } else if mode == .directory {
            if let path = scene.files.first?.path {
                query = buildDirectoryQuery(path)
            }
        }
        
        // Apply blacklist
        query = applyBlacklist(query, patterns: blacklist)
        
        return query
    }
    
    // MARK: - Build Methods
    
    private func buildMetadataQuery(_ scene: Scene) -> String {
        var components: [String] = []
        
        // Date
        if let date = scene.date {
            components.append(date)
        }
        
        // Studio
        if let studioName = scene.studio?.name {
            components.append(studioName)
        }
        
        // Performers
        let performerNames = scene.performers.map { $0.name }.joined(separator: " ")
        if !performerNames.isEmpty {
            components.append(performerNames)
        }
        
        // Title (clean special characters)
        if let title = scene.title {
            let cleanTitle = title.replacingOccurrences(
                of: "[^a-zA-Z0-9 ]+",
                with: "",
                options: .regularExpression
            )
            if !cleanTitle.isEmpty {
                components.append(cleanTitle)
            }
        }
        
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }
    
    private func buildFilenameQuery(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let filename = url.deletingPathExtension().lastPathComponent
        
        var query = filename.replacingOccurrences(of: ".", with: " ")
        query = query.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
        
        return query.trimmingCharacters(in: .whitespaces)
    }
    
    private func buildPathQuery(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        var components = url.pathComponents.filter { $0 != "/" }
        
        // Replace filename with version without extension
        if let lastIndex = components.indices.last {
            let filename = url.deletingPathExtension().lastPathComponent
            components[lastIndex] = filename
        }
        
        var query = components.joined(separator: " ")
        query = query.replacingOccurrences(of: ".", with: " ")
        query = query.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
        
        return query.trimmingCharacters(in: .whitespaces)
    }
    
    private func buildDirectoryQuery(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.deletingLastPathComponent().lastPathComponent
    }
    
    // MARK: - Blacklist
    
    private func applyBlacklist(_ query: String, patterns: [String]) -> String {
        var result = query
        
        let regexPatterns = patterns.compactMap {
            try? NSRegularExpression(pattern: $0, options: .caseInsensitive)
        }
        
        for regex in regexPatterns {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: " "
            )
        }
        
        result = result.replacingOccurrences(
            of: " +",
            with: " ",
            options: .regularExpression
        )
        
        return result.trimmingCharacters(in: .whitespaces)
    }
}
```

---

### SwiftUI Integration

```swift
import SwiftUI

struct TaggerView: View {
    let scene: Scene
    @StateObject private var viewModel: TaggerViewModel
    
    init(scene: Scene, queryService: TaggerQueryService) {
        self.scene = scene
        _viewModel = StateObject(wrappedValue: TaggerViewModel(
            scene: scene,
            queryService: queryService
        ))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Parse mode picker
            Picker("Parse Mode", selection: $viewModel.parseMode) {
                ForEach(ParseMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.parseMode) { _ in
                viewModel.updateQuery()
            }
            
            // Query field
            HStack {
                Text("Query")
                    .foregroundColor(.secondary)
                TextField("Search query", text: $viewModel.queryString)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Search button
            Button(action: { Task { await viewModel.search() } }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear {
            viewModel.updateQuery()
        }
    }
}

@MainActor
class TaggerViewModel: ObservableObject {
    @Published var queryString: String = ""
    @Published var parseMode: ParseMode = .auto
    
    private let scene: Scene
    private let queryService: TaggerQueryService
    
    init(scene: Scene, queryService: TaggerQueryService) {
        self.scene = scene
        self.queryService = queryService
    }
    
    func updateQuery() {
        queryString = queryService.prepareQueryString(for: scene)
    }
    
    func search() async {
        // Perform search with queryString
    }
}
```

---

## Examples

### Example 1: Auto Mode with Complete Metadata

**Scene:**
- Date: `2024-01-15`
- Studio: `Brazzers`
- Performers: `Jane Doe`, `John Smith`
- Title: `Hot Scene!`
- Filename: `video123.mp4`

**Prepopulated Query:**
```
2024-01-15 Brazzers Jane Doe John Smith Hot Scene
```

**Explanation:** Auto mode detected both date and studio, so it used metadata mode.

---

### Example 2: Auto Mode without Metadata

**Scene:**
- Date: `nil`
- Studio: `nil`
- Filename: `Brazzers.Jane.Doe.Hot.Scene.2024.1080p.mp4`

**Prepopulated Query:**
```
Brazzers Jane Doe Hot Scene 2024 1080p
```

**Explanation:** Auto mode fell back to filename mode since metadata was missing.

---

### Example 3: Metadata Mode with Blacklist

**Scene:**
- Date: `2024-01-15`
- Studio: `Reality Kings`
- Title: `Amazing Scene [HD]`

**Blacklist:** `["\\[.*?\\]", "HD", "1080p"]`

**Without Blacklist:**
```
2024-01-15 Reality Kings Amazing Scene [HD]
```

**With Blacklist:**
```
2024-01-15 Reality Kings Amazing Scene
```

---

### Example 4: Filename Mode with Blacklist

**Filename:** `Brazzers.Scene.Title.2024.1080p.x264.XXX.mp4`

**Blacklist:** `["1080p", "x264", "XXX"]`

**Prepopulated Query:**
```
Brazzers Scene Title 2024
```

---

### Example 5: Path Mode

**Path:** `/media/adult/Reality Kings/2024/Hot.Scene.mp4`

**Prepopulated Query:**
```
media adult Reality Kings 2024 Hot Scene
```

---

### Example 6: Directory Mode

**Path:** `/media/adult/Brazzers/Scene.Title.mp4`

**Prepopulated Query:**
```
Brazzers
```

---

## Configuration

### Storing Config

```swift
class TaggerConfigManager {
    private let defaults = UserDefaults.standard
    private let configKey = "tagger_config"
    
    func saveConfig(_ config: TaggerConfig) {
        if let encoded = try? JSONEncoder().encode(config) {
            defaults.set(encoded, forKey: configKey)
        }
    }
    
    func loadConfig() -> TaggerConfig {
        guard let data = defaults.data(forKey: configKey),
              let config = try? JSONDecoder().decode(TaggerConfig.self, from: data) else {
            return TaggerConfig() // Return default config
        }
        return config
    }
}
```

### Default Blacklist Suggestions

```swift
extension TaggerConfig {
    static let defaultBlacklist = [
        "1080p", "720p", "480p", "4K", "2160p",
        "x264", "x265", "HEVC", "h264", "h265",
        "AAC", "MP3", "AC3", "DTS",
        "WEB-DL", "WEBRip", "BluRay", "BRRip", "DVDRip",
        "\\[.*?\\]",   // Remove [bracketed]
        "\\(.*?\\)",   // Remove (parenthetical)
        "XXX",
        "RARBG", "YIFY", "FGT", "ETRG",
        "\\.com", "www\\.",
    ]
}
```

---

## Best Practices

1. **Start with Auto Mode** - Works for most users
2. **Provide Mode Picker** - Let users switch modes easily
3. **Allow Query Editing** - Always let users manually edit the prepopulated query
4. **Save Last Mode** - Remember user's preferred parse mode
5. **Suggest Blacklist Patterns** - Provide common patterns as defaults
6. **Test with Real Files** - Test with actual scene filenames from your library
7. **Handle Missing Data** - Gracefully handle scenes without metadata or files

---

## UI Recommendations

### Query Field Features
- Show prepopulated query in text field
- Allow full editing before search
- Clear button to reset to default
- Search on Enter/Return key
- Real-time preview of query changes

### Parse Mode Selector
- Segmented control or dropdown
- Visual indicator of current mode
- Show example of what will be used
- Persist selection between sessions

### Blacklist Editor
- List of current patterns
- Add/remove patterns
- Test pattern against sample text
- Import default patterns
- Regex validation

---

## Testing

### Unit Tests

```swift
import XCTest

class TaggerQueryServiceTests: XCTestCase {
    var service: TaggerQueryService!
    
    override func setUp() {
        super.setUp()
        service = TaggerQueryService(config: TaggerConfig())
    }
    
    func testMetadataMode() {
        let scene = Scene(
            id: "1",
            title: "Test Scene!",
            date: "2024-01-15",
            studio: Studio(name: "Test Studio"),
            performers: [
                Performer(name: "Jane Doe"),
                Performer(name: "John Smith")
            ]
        )
        
        let query = service.prepareQueryString(for: scene)
        XCTAssertEqual(query, "2024-01-15 Test Studio Jane Doe John Smith Test Scene")
    }
    
    func testFilenameMode() {
        var config = TaggerConfig()
        config.parseMode = .filename
        service = TaggerQueryService(config: config)
        
        let scene = Scene(
            id: "1",
            files: [SceneFile(path: "/path/to/Test.Scene.2024.mp4")]
        )
        
        let query = service.prepareQueryString(for: scene)
        XCTAssertEqual(query, "Test Scene 2024")
    }
    
    func testBlacklist() {
        var config = TaggerConfig()
        config.parseMode = .filename
        config.blacklist = ["1080p", "x264"]
        service = TaggerQueryService(config: config)
        
        let scene = Scene(
            id: "1",
            files: [SceneFile(path: "/path/to/Scene.1080p.x264.mp4")]
        )
        
        let query = service.prepareQueryString(for: scene)
        XCTAssertEqual(query, "Scene")
    }
}
```

---

## Related Documentation

- [SCENE_SCRAPING.md](SCENE_SCRAPING.md) - Scene scraping implementation
- [GRAPHQL_API.md](GRAPHQL_API.md) - GraphQL queries
