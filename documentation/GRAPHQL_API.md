# Stash GraphQL API Documentation

This document provides GraphQL queries and examples for integrating with the Stash API in the iOS app.

## Table of Contents

- [Pagination](#pagination)
- [Scene Streaming & Transcoding](#scene-streaming--transcoding)
- [Stats](#stats)
- [Performers](#performers)
- [Tags](#tags)

---

## Pagination

### Get All Scenes with Pagination

```graphql
query FindScenes($page: Int!, $perPage: Int!) {
  findScenes(
    filter: {
      page: $page
      per_page: $perPage
      sort: "created_at"
      direction: DESC
    }
  ) {
    count
    scenes {
      id
      title
      code
      details
      date
      rating100
      o_counter
      play_count
      organized
      created_at
      updated_at
      
      files {
        id
        path
        size
        duration
        width
        height
        video_codec
        audio_codec
        frame_rate
        bit_rate
      }
      
      paths {
        screenshot
        preview
        stream
        sprite
      }
      
      studio {
        id
        name
        image_path
      }
      
      performers {
        id
        name
        image_path
      }
      
      tags {
        id
        name
      }
      
      stash_ids {
        endpoint
        stash_id
      }
    }
  }
}
```

**Variables:**

```json
{
  "page": 1,
  "perPage": 25
}
```

### Sort Options

Available `sort` values:
- `"created_at"`
- `"updated_at"`
- `"title"`
- `"date"` (scene date)
- `"rating100"`
- `"o_counter"`
- `"play_count"`
- `"filesize"`
- `"duration"`
- `"random"` (for random ordering)

### Direction Options

- `ASC` (ascending)
- `DESC` (descending)

### Advanced Filtering

```graphql
query FindScenes(
  $page: Int!
  $perPage: Int!
  $sort: String
  $direction: SortDirectionEnum
  $query: String
) {
  findScenes(
    filter: {
      page: $page
      per_page: $perPage
      sort: $sort
      direction: $direction
      q: $query
    }
    scene_filter: {
      organized: true
      rating100: { value: 80, modifier: GREATER_THAN }
    }
  ) {
    count
    scenes {
      id
      title
      rating100
      paths {
        screenshot
        stream
      }
    }
  }
}
```

---

## Scene Streaming & Transcoding

### Get Scene Stream Endpoints

Use the `sceneStreams` field to get all available streaming options with transcoding:

```graphql
query GetSceneStreams($id: ID!) {
  findScene(id: $id) {
    id
    title
    sceneStreams {
      url
      mime_type
      label
    }
  }
}
```

Or standalone:

```graphql
query GetSceneStreams($sceneId: ID!) {
  sceneStreams(id: $sceneId) {
    url
    mime_type
    label
  }
}
```

### Available Stream Types

The API returns multiple streaming options:

1. **Direct Stream** - Original file (if audio codec is supported)
2. **MP4** - Transcoded to MP4 (various resolutions)
3. **WEBM** - Transcoded to WebM (various resolutions)
4. **HLS** - HTTP Live Streaming (Apple standard, best for iOS)
5. **DASH** - Dynamic Adaptive Streaming
6. **MKV** - Matroska (only if source is MKV)

### Resolutions Available

- **Original** - No transcoding
- **4K** (2160p)
- **Full HD** (1080p)
- **HD** (720p)
- **Standard** (480p)
- **Low** (240p)

### Example Response

```json
{
  "data": {
    "sceneStreams": [
      {
        "url": "http://localhost:9999/scene/123/stream",
        "mime_type": "video/mp4",
        "label": "Direct stream"
      },
      {
        "url": "http://localhost:9999/scene/123/stream.mp4?resolution=ORIGINAL",
        "mime_type": "video/mp4",
        "label": "MP4"
      },
      {
        "url": "http://localhost:9999/scene/123/stream.mp4?resolution=FULL_HD",
        "mime_type": "video/mp4",
        "label": "MP4 Full HD (1080p)"
      },
      {
        "url": "http://localhost:9999/scene/123/stream.m3u8?resolution=FULL_HD",
        "mime_type": "application/vnd.apple.mpegurl",
        "label": "HLS Full HD (1080p)"
      }
    ]
  }
}
```

### iOS Implementation

**Recommended: Use HLS streams** (`.m3u8`) as they're natively supported by AVPlayer:

```swift
// Filter for HLS streams
let hlsStreams = sceneStreams.filter { $0.mime_type == "application/vnd.apple.mpegurl" }

// Pick the resolution you want
let stream = hlsStreams.first { $0.label?.contains("1080p") } ?? hlsStreams.first

// Use with AVPlayer
if let streamURL = URL(string: stream.url) {
    let player = AVPlayer(url: streamURL)
}
```

### Add to GraphQLQueries.swift

```swift
static let sceneStreams = """
query GetSceneStreams($sceneId: ID!) {
    sceneStreams(id: $sceneId) {
        url
        mime_type
        label
    }
}
"""
```

### Model

```swift
struct SceneStreamsResult: Decodable {
    let sceneStreams: [SceneStreamEndpoint]
}

struct SceneStreamEndpoint: Decodable {
    let url: String
    let mime_type: String?
    let label: String?
}
```

---

## Stats

### Get System Stats

```graphql
query GetStats {
  stats {
    scene_count
    scenes_size
    scenes_duration
    image_count
    images_size
    gallery_count
    performer_count
    studio_count
    group_count
    tag_count
    total_o_count
    total_play_duration
    total_play_count
    scenes_played
  }
}
```

### Model

```swift
struct StatsResult: Decodable {
    let stats: Stats
}

struct Stats: Decodable {
    let scene_count: Int
    let scenes_size: Double
    let scenes_duration: Double
    let image_count: Int
    let images_size: Double
    let gallery_count: Int
    let performer_count: Int
    let studio_count: Int
    let group_count: Int
    let tag_count: Int
    let total_o_count: Int
    let total_play_duration: Double
    let total_play_count: Int
    let scenes_played: Int
}
```

### Add to GraphQLClient

```swift
func fetchStats(url: URL, apiKey: String) async throws -> Stats {
    let result: StatsResult = try await fetch(
        query: GraphQLQueries.stats, 
        variables: nil, 
        url: url, 
        apiKey: apiKey
    )
    return result.stats
}
```

---

## Performers

### Get All Performers

```graphql
query FindPerformers($filter: FindFilterType, $performer_filter: PerformerFilterType) {
  findPerformers(filter: $filter, performer_filter: $performer_filter) {
    count
    performers {
      id
      name
      disambiguation
      urls
      gender
      birthdate
      ethnicity
      country
      eye_color
      height_cm
      measurements
      fake_tits
      penis_length
      circumcised
      career_length
      tattoos
      piercings
      alias_list
      favorite
      tags {
        id
        name
      }
      image_path
      scene_count
      image_count
      gallery_count
      group_count
      rating100
      details
      death_date
      hair_color
      weight
      created_at
      updated_at
      custom_fields
      stash_ids {
        endpoint
        stash_id
      }
    }
  }
}
```

**Variables for pagination:**

```json
{
  "filter": {
    "page": 1,
    "per_page": 25,
    "sort": "name",
    "direction": "ASC"
  }
}
```

### Get Single Performer

```graphql
query GetPerformer($id: ID!) {
  findPerformer(id: $id) {
    id
    name
    disambiguation
    urls
    gender
    birthdate
    ethnicity
    country
    eye_color
    height_cm
    measurements
    favorite
    image_path
    scene_count
    rating100
    details
    created_at
    updated_at
    tags {
      id
      name
    }
    stash_ids {
      endpoint
      stash_id
    }
  }
}
```

### Update Performer Image

```graphql
mutation UpdatePerformerImage($performerId: ID!, $imageData: String!) {
  performerUpdate(input: {
    id: $performerId
    image: $imageData
  }) {
    id
    name
    image_path
  }
}
```

The `image` field accepts:
- A URL (e.g., `"https://example.com/image.jpg"`)
- A base64 encoded data URL (e.g., `"data:image/jpeg;base64,/9j/4AAQ..."`)

---

## Tags

### Icon

The tag icon used throughout Stash is FontAwesome's `faTag`:
- **SF Symbols equivalent**: `tag.fill`
- **SVG available at**: https://fontawesome.com/icons/tag?f=classic&s=solid

---

## Complete Scene Query

For reference, here's the complete scene structure with all available fields:

```graphql
query GetCompleteScene($id: ID!) {
  findScene(id: $id) {
    # Basic Info
    id
    title
    code
    details
    director
    urls
    date
    rating100
    organized
    o_counter
    interactive
    interactive_speed
    
    # Captions
    captions {
      language_code
      caption_type
    }
    
    # Timestamps
    created_at
    updated_at
    last_played_at
    
    # Playback Info
    resume_time
    play_duration
    play_count
    play_history
    o_history
    
    # Files (new structure)
    files {
      id
      path
      basename
      size
      mod_time
      created_at
      updated_at
      
      # Video-specific fields
      format
      width
      height
      duration
      video_codec
      audio_codec
      frame_rate
      bit_rate
      
      # Fingerprints
      fingerprints {
        type
        value
      }
    }
    
    # Generated paths
    paths {
      screenshot
      preview
      stream
      webp
      vtt
      sprite
      funscript
      interactive_heatmap
      caption
    }
    
    # Scene markers
    scene_markers {
      id
      title
      seconds
      stream
      preview
      screenshot
      primary_tag {
        id
        name
      }
      tags {
        id
        name
      }
    }
    
    # Relationships
    studio {
      id
      name
      image_path
    }
    
    performers {
      id
      name
      image_path
    }
    
    tags {
      id
      name
    }
    
    galleries {
      id
      title
    }
    
    groups {
      group {
        id
        name
      }
      scene_index
    }
    
    # StashDB IDs
    stash_ids {
      endpoint
      stash_id
    }
    
    # Stream endpoints
    sceneStreams {
      url
      mime_type
      label
    }
  }
}
```

---

## Notes

- The `count` field in paginated queries returns the total number of items matching your filters
- All timestamps are in ISO 8601 format
- The API key should be passed in the `ApiKey` header (already handled by `GraphQLClient`)
- Resolution parameters for streaming should match the enum values: `ORIGINAL`, `FOUR_K`, `FULL_HD`, `STANDARD_HD`, `STANDARD`, `LOW`
