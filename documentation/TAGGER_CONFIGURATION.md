# Tagger Configuration - iOS

This document explains all tagger configuration settings, how they're stored in Stash, how they're used when querying and applying data, and how to implement them in iOS.

## Table of Contents

- [Overview](#overview)
- [Configuration Settings](#configuration-settings)
- [How Configs Are Used](#how-configs-are-used)
- [GraphQL API](#graphql-api)
- [Data Models](#data-models)
- [iOS Implementation](#ios-implementation)
- [Complete Flow Example](#complete-flow-example)

---

## Overview

The tagger configuration controls how scenes are matched, what data is applied, and what metadata fields are used. All settings are stored in Stash's UI configuration and persist across sessions.

### Storage Location
- **Key**: `taggerConfig`
- **Storage**: Stash server (not local storage)
- **Scope**: Per user account
- **Mutation**: `configureUISetting`

### How They Work
Configs are **client-side only** - they control UI behavior and data filtering, not server scraping. They act as filters and rules for what gets sent in update mutations.

---

## Configuration Settings

### Complete Settings List

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| **mode** | ParseMode | `"auto"` | How to generate search query |
| **blacklist** | [String] | `[]` | Regex patterns to filter from queries |
| **performerGenders** | [GenderEnum] | `undefined` | Only show performers with these genders |
| **setCoverImage** | Boolean | `true` | Apply cover image from scrape results |
| **setTags** | Boolean | `false` | Apply tags from scrape results |
| **tagOperation** | TagOperation | `"merge"` | How to handle tags (merge/overwrite) |
| **selectedEndpoint** | String | `undefined` | Default scraper source |
| **fingerprintQueue** | Object | `{}` | Internal fingerprint matching queue |
| **excludedPerformerFields** | [String] | See below | Performer fields to exclude |
| **excludedStudioFields** | [String] | See below | Studio fields to exclude |
| **markSceneAsOrganizedOnSave** | Boolean | `false` | Mark scene organized when saving |
| **createParentStudios** | Boolean | `true` | Auto-create parent studios |

---

### 1. Parse Mode

**Type:** `"auto" | "filename" | "dir" | "path" | "metadata"`

**Default:** `"auto"`

**Description:** Determines how the search query is generated from scene data.

**Options:**
- `auto` - Use metadata if available, else filename
- `filename` - Extract from filename only
- `dir` - Use parent directory name
- `path` - Use full path
- `metadata` - Use scene metadata (date, studio, performers, title)

See [TAGGER_QUERY_PREPOPULATION.md](TAGGER_QUERY_PREPOPULATION.md) for details.

---

### 2. Blacklist

**Type:** `String[]` (regex patterns)

**Default:** `[]`

**Description:** Regular expression patterns to remove from search queries.

**Common Patterns:**
```swift
[
    "1080p", "720p", "480p", "4K", "2160p",
    "x264", "x265", "HEVC", "h264",
    "\\[.*?\\]",   // Remove [bracketed]
    "\\(.*?\\)",   // Remove (parenthetical)
    "XXX", "RARBG", "YIFY"
]
```

**Example:**
```
Input:  "Scene.Title.2024.1080p.x264.mp4"
Output: "Scene Title 2024"
```

---

### 3. Performer Genders

**Type:** `GenderEnum[]`

**Default:** `undefined` (show all)

**Description:** Filter scraped performers to only show specified genders.

**Gender Options:**
```graphql
enum GenderEnum {
  MALE
  FEMALE
  TRANSGENDER_MALE
  TRANSGENDER_FEMALE
  INTERSEX
  NON_BINARY
}
```

**Example:**
If set to `[FEMALE, NON_BINARY]`, only female and non-binary performers from scrape results will be shown/applied.

---

### 4. Set Cover Image

**Type:** `Boolean`

**Default:** `true`

**Description:** Automatically apply cover image from scrape results to the scene.

**Behavior:**
- `true` - Cover image is applied when saving scraped data
- `false` - Cover image is ignored, manual selection required

---

### 5. Set Tags

**Type:** `Boolean`

**Default:** `false`

**Description:** Whether to apply tags from scrape results.

**Behavior:**
- `true` - Tags are applied based on `tagOperation` setting
- `false` - Tags are ignored

---

### 6. Tag Operation

**Type:** `"merge" | "overwrite"`

**Default:** `"merge"`

**Description:** How to handle tags when `setTags` is enabled.

**Options:**
- `merge` - Add new tags to existing ones (union)
- `overwrite` - Replace all existing tags with scraped tags

**Example:**

| Existing Tags | Scraped Tags | Merge Result | Overwrite Result |
|---------------|--------------|--------------|------------------|
| `[A, B, C]` | `[C, D, E]` | `[A, B, C, D, E]` | `[C, D, E]` |

---

### 7. Selected Endpoint

**Type:** `String` (optional)

**Default:** `undefined`

**Description:** Default scraper source to use.

**Format:**
- StashBox: `"stashbox:https://stashdb.org/graphql"`
- Scraper: `"scraper:builtin_stashdb"`

**Behavior:**
- If set, this source is pre-selected in the tagger
- User can still change source manually

---

### 8. Excluded Performer Fields

**Type:** `String[]`

**Default:** 
```typescript
[
  "image",
  "urls", 
  "details",
  "death_date",
  "hair_color",
  "weight",
  "penis_length",
  "circumcised"
]
```

**Description:** Performer fields to exclude when applying scraped data.

**Available Fields:**
```typescript
[
  "name", "image", "disambiguation", "aliases",
  "gender", "birthdate", "death_date", "country",
  "ethnicity", "hair_color", "eye_color", "height",
  "weight", "penis_length", "circumcised", "measurements",
  "fake_tits", "tattoos", "piercings", "career_length",
  "urls", "details"
]
```

**Example:**
If `excludedPerformerFields` includes `"image"`, performer images won't be updated even if available in scrape results.

---

### 9. Excluded Studio Fields

**Type:** `String[]`

**Default:**
```typescript
["image"]
```

**Description:** Studio fields to exclude when applying scraped data.

**Available Fields:**
```typescript
["name", "image", "url", "parent_studio"]
```

---

### 10. Mark Scene as Organized on Save

**Type:** `Boolean`

**Default:** `false`

**Description:** Automatically mark scene as organized when saving tagger changes.

**Behavior:**
- `true` - Scene's `organized` field set to `true` on save
- `false` - `organized` field unchanged

---

### 11. Create Parent Studios

**Type:** `Boolean`

**Default:** `true`

**Description:** Automatically create parent studios from scraped data.

**Behavior:**
- `true` - If scraped studio has parent, create it if it doesn't exist
- `false` - Only create/update the main studio, ignore parent

---

### 12. Fingerprint Queue

**Type:** `Record<string, string[]>` (Object)

**Default:** `{}`

**Description:** Internal queue for fingerprint-based matching. Managed automatically by the tagger.

**Format:**
```json
{
  "scene_id_1": ["fingerprint1", "fingerprint2"],
  "scene_id_2": ["fingerprint3"]
}
```

**Note:** This is managed internally and rarely needs manual modification.

---

## How Configs Are Used

Configs control how scraped data is applied to scenes. Here's how each setting is used:

### 1. Query Generation (Parse Mode + Blacklist)

Used when building the search query string:

```swift
// Build query based on mode
let query = prepareQueryString(
    scene: scene,
    mode: config.mode,
    blacklist: config.blacklist
)

// Then scrape with that query
let results = try await scraperService.scrapeScene(
    method: .query(query),
    source: source
)
```

**Example:**
```swift
// Scene filename: "Brazzers.Jane.Doe.2024.1080p.x264.mp4"
// config.mode = .filename
// config.blacklist = ["1080p", "x264"]

// Result query: "Brazzers Jane Doe 2024"
```

---

### 2. Filtering Results (Performer Genders)

After getting scrape results, filter performers by gender:

```swift
var scrapedScene = results[0]

// Filter performers based on config
if let allowedGenders = config.performerGenders {
    scrapedScene.performers = scrapedScene.performers?.filter { performer in
        if let gender = performer.gender,
           let genderEnum = GenderEnum(rawValue: gender) {
            return allowedGenders.contains(genderEnum)
        }
        return false
    }
}
```

**Example:**
```swift
// Raw scrape results
let performers = [
    ScrapedPerformer(name: "Jane", gender: "FEMALE"),
    ScrapedPerformer(name: "John", gender: "MALE"),
    ScrapedPerformer(name: "Alex", gender: "NON_BINARY")
]

// config.performerGenders = [.female, .nonBinary]

// Filtered result:
[
    ScrapedPerformer(name: "Jane", gender: "FEMALE"),
    ScrapedPerformer(name: "Alex", gender: "NON_BINARY")
]
```

---

### 3. Applying Data (Excluded Fields)

When building update mutations, exclude configured fields:

```swift
func buildPerformerUpdate(
    performerId: String,
    scraped: ScrapedPerformer,
    config: TaggerConfig
) -> PerformerUpdateInput {
    var input = PerformerUpdateInput(id: performerId)
    
    // Only include fields NOT in excludedPerformerFields
    if !config.excludedPerformerFields.contains("name") {
        input.name = scraped.name
    }
    if !config.excludedPerformerFields.contains("birthdate") {
        input.birthdate = scraped.birthdate
    }
    if !config.excludedPerformerFields.contains("image") {
        input.image = scraped.images?.first
    }
    if !config.excludedPerformerFields.contains("gender") {
        input.gender = scraped.gender
    }
    // ... etc for all fields
    
    return input
}
```

**Example:**
```swift
// config.excludedPerformerFields = ["image", "urls", "details"]

// Scraped performer has all fields, but mutation only includes:
performerUpdate(input: {
    id: "123",
    name: "Jane Doe",
    birthdate: "1990-01-01",
    gender: "FEMALE"
    // image, urls, details NOT included
})
```

---

### 4. Tag Handling (setTags + tagOperation)

Control how tags are applied based on config:

```swift
func buildTagIds(
    existingTags: [Tag],
    scrapedTags: [ScrapedTag],
    config: TaggerConfig
) async throws -> [String] {
    
    if !config.setTags {
        // Don't apply scraped tags, keep existing
        return existingTags.map { $0.id }
    }
    
    // Find or create scraped tags
    let scrapedTagIds = try await scrapedTags.asyncMap { scrapedTag in
        try await findOrCreateTag(scrapedTag)
    }
    
    if config.tagOperation == .merge {
        // Combine existing + scraped (remove duplicates)
        let existingIds = existingTags.map { $0.id }
        return Array(Set(existingIds + scrapedTagIds))
    } else {
        // Overwrite - replace with scraped only
        return scrapedTagIds
    }
}
```

**Example:**
```swift
// Existing scene tags: ["Brunette", "HD", "POV"]
// Scraped tags: ["POV", "Threesome", "Outdoor"]

// config.setTags = true, config.tagOperation = .merge
// Result: ["Brunette", "HD", "POV", "Threesome", "Outdoor"]

// config.setTags = true, config.tagOperation = .overwrite
// Result: ["POV", "Threesome", "Outdoor"]

// config.setTags = false
// Result: ["Brunette", "HD", "POV"] (unchanged)
```

---

### 5. Cover Image (setCoverImage)

Conditionally include cover image in scene update:

```swift
func buildSceneUpdate(
    sceneId: String,
    scraped: ScrapedScene,
    config: TaggerConfig
) -> SceneUpdateInput {
    var input = SceneUpdateInput(id: sceneId)
    
    input.title = scraped.title
    input.date = scraped.date
    input.details = scraped.details
    
    // Only set cover if config allows
    if config.setCoverImage, let image = scraped.image {
        input.coverImage = image
    }
    
    return input
}
```

**Example:**
```swift
// config.setCoverImage = true
sceneUpdate(input: {
    id: "123",
    title: "Scene Title",
    cover_image: "data:image/jpeg;base64,..." // ✅ Included
})

// config.setCoverImage = false
sceneUpdate(input: {
    id: "123",
    title: "Scene Title"
    // cover_image NOT included
})
```

---

### 6. Mark Organized (markSceneAsOrganizedOnSave)

Set organized flag when saving:

```swift
func buildSceneUpdate(
    sceneId: String,
    scraped: ScrapedScene,
    existingScene: Scene,
    config: TaggerConfig
) -> SceneUpdateInput {
    var input = SceneUpdateInput(id: sceneId)
    
    input.title = scraped.title
    // ... other fields
    
    // Set organized based on config
    if config.markSceneAsOrganizedOnSave {
        input.organized = true
    } else {
        input.organized = existingScene.organized // Keep existing
    }
    
    return input
}
```

---

### 7. Parent Studios (createParentStudios)

Handle parent studio creation:

```swift
func applyStudio(
    scraped: ScrapedStudio,
    config: TaggerConfig
) async throws -> String {
    
    // Handle parent studio first if config allows
    var parentStudioId: String?
    if config.createParentStudios, let parent = scraped.parent {
        parentStudioId = try await findOrCreateStudio(parent)
    }
    
    // Create/update main studio
    let studioId = try await findOrCreateStudio(scraped)
    
    // Link parent if created
    if let parentId = parentStudioId {
        try await updateStudio(
            id: studioId,
            parentId: parentId
        )
    }
    
    return studioId
}
```

**Example:**
```swift
// Scraped studio: "Brazzers" with parent "MindGeek"

// config.createParentStudios = true
// 1. Create/find "MindGeek" studio
// 2. Create/find "Brazzers" studio
// 3. Link Brazzers.parent_id = MindGeek.id

// config.createParentStudios = false
// 1. Create/find "Brazzers" studio
// 2. Skip parent
```

---

### 8. Studio Field Exclusion

```swift
func buildStudioUpdate(
    studioId: String,
    scraped: ScrapedStudio,
    config: TaggerConfig
) -> StudioUpdateInput {
    var input = StudioUpdateInput(id: studioId)
    
    if !config.excludedStudioFields.contains("name") {
        input.name = scraped.name
    }
    if !config.excludedStudioFields.contains("image") {
        input.image = scraped.image
    }
    if !config.excludedStudioFields.contains("url") {
        input.urls = scraped.urls
    }
    if !config.excludedStudioFields.contains("parent_studio"),
       config.createParentStudios,
       let parent = scraped.parent {
        input.parentId = try await findOrCreateStudio(parent)
    }
    
    return input
}
```

---

## GraphQL API

### Query Configuration

```graphql
query Configuration {
  configuration {
    ui {
      taggerConfig
    }
  }
}
```

**Response:**
```json
{
  "data": {
    "configuration": {
      "ui": {
        "taggerConfig": {
          "mode": "auto",
          "blacklist": ["1080p", "x264"],
          "performerGenders": ["FEMALE"],
          "setCoverImage": true,
          "setTags": false,
          "tagOperation": "merge",
          "selectedEndpoint": "stashbox:https://stashdb.org/graphql",
          "fingerprintQueue": {},
          "excludedPerformerFields": ["image", "urls"],
          "markSceneAsOrganizedOnSave": false,
          "excludedStudioFields": ["image"],
          "createParentStudios": true
        }
      }
    }
  }
}
```

---

### Save Configuration

```graphql
mutation SaveTaggerConfig($config: Any!) {
  configureUISetting(key: "taggerConfig", value: $config)
}
```

**Variables:**
```json
{
  "config": {
    "mode": "auto",
    "blacklist": ["1080p", "720p", "x264"],
    "performerGenders": ["FEMALE", "NON_BINARY"],
    "setCoverImage": true,
    "setTags": true,
    "tagOperation": "merge",
    "selectedEndpoint": "stashbox:https://stashdb.org/graphql",
    "fingerprintQueue": {},
    "excludedPerformerFields": ["image", "urls", "details"],
    "markSceneAsOrganizedOnSave": true,
    "excludedStudioFields": ["image"],
    "createParentStudios": true
  }
}
```

---

## Data Models

### Swift Models

```swift
import Foundation

// MARK: - Parse Mode

enum ParseMode: String, Codable, CaseIterable {
    case auto = "auto"
    case filename = "filename"
    case directory = "dir"
    case path = "path"
    case metadata = "metadata"
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .filename: return "Filename"
        case .directory: return "Directory"
        case .path: return "Path"
        case .metadata: return "Metadata"
        }
    }
}

// MARK: - Tag Operation

enum TagOperation: String, Codable, CaseIterable {
    case merge = "merge"
    case overwrite = "overwrite"
    
    var displayName: String {
        switch self {
        case .merge: return "Merge"
        case .overwrite: return "Overwrite"
        }
    }
}

// MARK: - Gender Enum

enum GenderEnum: String, Codable, CaseIterable {
    case male = "MALE"
    case female = "FEMALE"
    case transgenderMale = "TRANSGENDER_MALE"
    case transgenderFemale = "TRANSGENDER_FEMALE"
    case intersex = "INTERSEX"
    case nonBinary = "NON_BINARY"
    
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .transgenderMale: return "Transgender Male"
        case .transgenderFemale: return "Transgender Female"
        case .intersex: return "Intersex"
        case .nonBinary: return "Non-Binary"
        }
    }
}

// MARK: - Tagger Config

struct TaggerConfig: Codable {
    var mode: ParseMode
    var blacklist: [String]
    var performerGenders: [GenderEnum]?
    var setCoverImage: Bool
    var setTags: Bool
    var tagOperation: TagOperation
    var selectedEndpoint: String?
    var fingerprintQueue: [String: [String]]
    var excludedPerformerFields: [String]
    var markSceneAsOrganizedOnSave: Bool
    var excludedStudioFields: [String]
    var createParentStudios: Bool
    
    // Default configuration
    static var `default`: TaggerConfig {
        TaggerConfig(
            mode: .auto,
            blacklist: [],
            performerGenders: nil,
            setCoverImage: true,
            setTags: false,
            tagOperation: .merge,
            selectedEndpoint: nil,
            fingerprintQueue: [:],
            excludedPerformerFields: defaultExcludedPerformerFields,
            markSceneAsOrganizedOnSave: false,
            excludedStudioFields: defaultExcludedStudioFields,
            createParentStudios: true
        )
    }
    
    // Default excluded fields
    static let defaultExcludedPerformerFields = [
        "image", "urls", "details", "death_date",
        "hair_color", "weight", "penis_length", "circumcised"
    ]
    
    static let defaultExcludedStudioFields = ["image"]
    
    // All available fields
    static let allPerformerFields = [
        "name", "image", "disambiguation", "aliases",
        "gender", "birthdate", "death_date", "country",
        "ethnicity", "hair_color", "eye_color", "height",
        "weight", "penis_length", "circumcised", "measurements",
        "fake_tits", "tattoos", "piercings", "career_length",
        "urls", "details"
    ]
    
    static let allStudioFields = ["name", "image", "url", "parent_studio"]
}
```

---

## iOS Implementation

### Configuration Service

```swift
import Foundation

class TaggerConfigService {
    private let graphQLService: GraphQLService
    
    init(graphQLService: GraphQLService) {
        self.graphQLService = graphQLService
    }
    
    // MARK: - Load Configuration
    
    func loadConfig() async throws -> TaggerConfig {
        let query = """
        query Configuration {
          configuration {
            ui {
              taggerConfig
            }
          }
        }
        """
        
        struct ConfigResponse: Codable {
            let configuration: ConfigData
        }
        
        struct ConfigData: Codable {
            let ui: UIData
        }
        
        struct UIData: Codable {
            let taggerConfig: TaggerConfig?
        }
        
        let response: GraphQLResponse<ConfigResponse> = try await graphQLService.query(
            query: query,
            variables: nil
        )
        
        return response.data.configuration.ui.taggerConfig ?? .default
    }
    
    // MARK: - Save Configuration
    
    func saveConfig(_ config: TaggerConfig) async throws {
        let mutation = """
        mutation SaveTaggerConfig($config: Any!) {
          configureUISetting(key: "taggerConfig", value: $config)
        }
        """
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let configDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        let variables: [String: Any] = ["config": configDict ?? [:]]
        
        struct SaveResponse: Codable {
            // Response structure
        }
        
        let _: GraphQLResponse<SaveResponse> = try await graphQLService.mutate(
            mutation: mutation,
            variables: variables
        )
    }
}
```

---

### Applying Configuration During Scrape

```swift
class TaggerApplyService {
    private let config: TaggerConfig
    
    init(config: TaggerConfig) {
        self.config = config
    }
    
    // MARK: - Apply Scraped Data
    
    func applyScrapedData(
        scene: Scene,
        scrapedScene: ScrapedScene
    ) async throws {
        
        // 1. Filter performers by gender
        var filteredPerformers = scrapedScene.performers ?? []
        if let allowedGenders = config.performerGenders {
            filteredPerformers = filteredPerformers.filter { performer in
                guard let gender = performer.gender,
                      let genderEnum = GenderEnum(rawValue: gender) else {
                    return false
                }
                return allowedGenders.contains(genderEnum)
            }
        }
        
        // 2. Create/update performers
        let performerIds = try await filteredPerformers.asyncMap { performer in
            try await applyPerformer(performer)
        }
        
        // 3. Create/update studio
        var studioId: String?
        if let studio = scrapedScene.studio {
            studioId = try await applyStudio(studio)
        }
        
        // 4. Handle tags
        let tagIds = try await buildTagIds(
            existingTags: scene.tags,
            scrapedTags: scrapedScene.tags ?? []
        )
        
        // 5. Build scene update
        var input = SceneUpdateInput(id: scene.id)
        input.title = scrapedScene.title
        input.code = scrapedScene.code
        input.details = scrapedScene.details
        input.director = scrapedScene.director
        input.urls = scrapedScene.urls
        input.date = scrapedScene.date
        input.studioId = studioId
        input.performerIds = performerIds
        input.tagIds = tagIds
        
        // Apply cover image if config allows
        if config.setCoverImage {
            input.coverImage = scrapedScene.image
        }
        
        // Mark organized if config allows
        if config.markSceneAsOrganizedOnSave {
            input.organized = true
        }
        
        // 6. Update scene
        try await updateScene(input: input)
    }
    
    // MARK: - Apply Performer
    
    private func applyPerformer(_ scraped: ScrapedPerformer) async throws -> String {
        // Find or create performer
        let performerId = try await findOrCreatePerformer(scraped)
        
        // Build update input based on excluded fields
        var input = PerformerUpdateInput(id: performerId)
        
        if !config.excludedPerformerFields.contains("name") {
            input.name = scraped.name
        }
        if !config.excludedPerformerFields.contains("gender") {
            input.gender = scraped.gender
        }
        if !config.excludedPerformerFields.contains("birthdate") {
            input.birthdate = scraped.birthdate
        }
        if !config.excludedPerformerFields.contains("image") {
            input.image = scraped.images?.first
        }
        // ... etc for all fields
        
        try await updatePerformer(input: input)
        return performerId
    }
    
    // MARK: - Apply Studio
    
    private func applyStudio(_ scraped: ScrapedStudio) async throws -> String {
        // Handle parent first if config allows
        var parentId: String?
        if config.createParentStudios, let parent = scraped.parent {
            parentId = try await applyStudio(parent)
        }
        
        // Find or create main studio
        let studioId = try await findOrCreateStudio(scraped)
        
        // Build update input
        var input = StudioUpdateInput(id: studioId)
        
        if !config.excludedStudioFields.contains("name") {
            input.name = scraped.name
        }
        if !config.excludedStudioFields.contains("image") {
            input.image = scraped.image
        }
        if !config.excludedStudioFields.contains("url") {
            input.urls = scraped.urls
        }
        if !config.excludedStudioFields.contains("parent_studio") {
            input.parentId = parentId
        }
        
        try await updateStudio(input: input)
        return studioId
    }
    
    // MARK: - Build Tag IDs
    
    private func buildTagIds(
        existingTags: [Tag],
        scrapedTags: [ScrapedTag]
    ) async throws -> [String] {
        
        if !config.setTags {
            return existingTags.map { $0.id }
        }
        
        let scrapedTagIds = try await scrapedTags.asyncMap { tag in
            try await findOrCreateTag(tag)
        }
        
        if config.tagOperation == .merge {
            let existingIds = existingTags.map { $0.id }
            return Array(Set(existingIds + scrapedTagIds))
        } else {
            return scrapedTagIds
        }
    }
}
```

---

## Complete Flow Example

```swift
// 1. Load config
let configService = TaggerConfigService(graphQLService: graphQL)
let config = try await configService.loadConfig()

// 2. Generate query using config
let queryService = TaggerQueryService(config: config)
let query = queryService.prepareQueryString(for: scene)

// 3. Scrape with query
let scraperService = SceneScraperService(graphQLService: graphQL)
let results = try await scraperService.scrapeScene(
    method: .query(query),
    source: ScraperSource(stashBoxIndex: 0, stashBoxEndpoint: nil, scraperID: nil)
)

// 4. Apply first result using config
let applyService = TaggerApplyService(config: config)
try await applyService.applyScrapedData(
    scene: scene,
    scrapedScene: results[0]
)
```

---

## Key Points

✅ **Configs are client-side only** - They control UI behavior and data filtering, not server scraping

✅ **Query generation** uses `mode` and `blacklist` before scraping

✅ **Result filtering** uses `performerGenders` after scraping

✅ **Data application** uses excluded fields and boolean flags when building mutations

✅ **No special GraphQL needed** - Standard mutations, just with conditional data based on config

✅ **Configs act as filters and rules** for what gets sent in update mutations

---

## Related Documentation

- [TAGGER_QUERY_PREPOPULATION.md](TAGGER_QUERY_PREPOPULATION.md) - Query generation details
- [SCENE_SCRAPING.md](SCENE_SCRAPING.md) - Scene scraping implementation
- [GRAPHQL_API.md](GRAPHQL_API.md) - GraphQL queries and mutations
