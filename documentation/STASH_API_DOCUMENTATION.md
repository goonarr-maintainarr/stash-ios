# Stash GraphQL API Documentation

**Stash** is a self-hosted webapp written in Go which organizes and serves your media collection. It uses a **GraphQL API** for all data operations.

Base URL: `http://localhost:9999/graphql` (default)

## API Type

Stash uses **GraphQL** instead of REST. This means:
- Single endpoint for all operations
- Client specifies exactly what data to return
- Queries for reading data
- Mutations for creating/updating/deleting data
- Subscriptions for real-time updates

## Authentication

Stash supports API key authentication:
- Add `ApiKey` header with your API key
- API keys can be generated in Settings → Security

Example header:
```
ApiKey: your-api-key-here
```

---

## Core Data Types

### Scene
Videos in your collection. Contains metadata like title, date, performers, studio, tags, etc.

### Image
Individual images in your collection.

### Gallery
Collections of images grouped together.

### Performer
Actors/performers appearing in scenes and images.

### Studio
Production studios that create content.

### Tag
Categorization tags for organizing content.

### Group (formerly Movie)
Groups of related scenes (e.g., series, collections).

### Scene Marker
Timestamped markers within scenes for specific moments or tags.

### File
Represents files on disk with metadata like size, format, duration, etc.

---

## 1. QUERY OPERATIONS

### Scene Queries

#### `findScene`
Find a single scene by ID or checksum.

**Parameters:**
- `id` (ID, optional): Scene ID
- `checksum` (String, optional): File checksum

**Returns:** Scene object

**Example:**
```graphql
query {
  findScene(id: "123") {
    id
    title
    date
    rating100
    organized
    o_counter
    url
    performers {
      id
      name
    }
    studio {
      id
      name
    }
    tags {
      id
      name
    }
    files {
      path
      size
      duration
      video_codec
      width
      height
    }
  }
}
```

#### `findScenes`
Query multiple scenes with filtering, sorting, and pagination.

**Parameters:**
- `scene_filter` (SceneFilterType): Filter criteria
- `filter` (FindFilterType): Pagination and sorting
- `ids` (ID[]): Specific scene IDs

**Returns:** FindScenesResultType with scenes array and count

**Example:**
```graphql
query {
  findScenes(
    filter: { per_page: 20, page: 1, sort: "created_at", direction: DESC }
    scene_filter: { is_organized: false }
  ) {
    count
    scenes {
      id
      title
      date
      rating100
    }
  }
}
```

#### `findSceneByHash`
Find scene by file hash.

**Parameters:**
- `input` (SceneHashInput): Hash input with oshash, checksum, or phash

**Returns:** Scene object

#### `findDuplicateScenes`
Find perceptual duplicate scenes based on similarity.

**Parameters:**
- `distance` (Int): Perceptual hash distance threshold
- `duration_diff` (Float): Max duration difference in seconds

**Returns:** Array of scene groups (duplicates)

#### `sceneStreams`
Get valid stream paths for a scene.

**Parameters:**
- `id` (ID): Scene ID

**Returns:** Array of SceneStreamEndpoint objects

#### `sceneWall`
Get random scenes for wall display.

**Parameters:**
- `q` (String, optional): Search query

**Returns:** Array of Scene objects

#### `parseSceneFilenames`
Parse scene filenames to extract metadata.

**Parameters:**
- `filter` (FindFilterType): Scene selection filter
- `config` (SceneParserInput): Parser configuration

**Returns:** SceneParserResultType with parsed results

---

### Image Queries

#### `findImage`
Find a single image by ID or checksum.

**Parameters:**
- `id` (ID, optional): Image ID
- `checksum` (String, optional): File checksum

**Returns:** Image object

#### `findImages`
Query multiple images with filtering and pagination.

**Parameters:**
- `image_filter` (ImageFilterType): Filter criteria
- `filter` (FindFilterType): Pagination and sorting
- `ids` (ID[]): Specific image IDs

**Returns:** FindImagesResultType

**Example:**
```graphql
query {
  findImages(filter: { per_page: 50, page: 1 }) {
    count
    images {
      id
      title
      rating100
      organized
      o_counter
      files {
        path
        size
        width
        height
      }
      galleries {
        id
        title
      }
      performers {
        id
        name
      }
    }
  }
}
```

---

### Gallery Queries

#### `findGallery`
Find a single gallery by ID.

**Parameters:**
- `id` (ID): Gallery ID

**Returns:** Gallery object

#### `findGalleries`
Query multiple galleries with filtering and pagination.

**Parameters:**
- `gallery_filter` (GalleryFilterType): Filter criteria
- `filter` (FindFilterType): Pagination and sorting
- `ids` (ID[]): Specific gallery IDs

**Returns:** FindGalleriesResultType

**Example:**
```graphql
query {
  findGalleries(filter: { per_page: 25, page: 1 }) {
    count
    galleries {
      id
      title
      date
      url
      rating100
      organized
      image_count
      cover {
        id
        path
      }
      studio {
        id
        name
      }
      performers {
        id
        name
      }
      tags {
        id
        name
      }
    }
  }
}
```

---

### Performer Queries

#### `findPerformer`
Find a single performer by ID.

**Parameters:**
- `id` (ID): Performer ID

**Returns:** Performer object

#### `findPerformers`
Query multiple performers with filtering and pagination.

**Parameters:**
- `performer_filter` (PerformerFilterType): Filter criteria
- `filter` (FindFilterType): Pagination and sorting
- `ids` (ID[]): Specific performer IDs

**Returns:** FindPerformersResultType

**Example:**
```graphql
query {
  findPerformers(filter: { per_page: 25, page: 1, sort: "name" }) {
    count
    performers {
      id
      name
      disambiguation
      gender
      birthdate
      death_date
      country
      eye_color
      hair_color
      height_cm
      weight
      measurements
      career_length
      tattoos
      piercings
      url
      twitter
      instagram
      favorite
      rating100
      scene_count
      image_count
      gallery_count
      stash_ids {
        endpoint
        stash_id
      }
    }
  }
}
```

---

### Studio Queries

#### `findStudio`
Find a single studio by ID.

**Parameters:**
- `id` (ID): Studio ID

**Returns:** Studio object

#### `findStudios`
Query multiple studios with filtering and pagination.

**Parameters:**
- `studio_filter` (StudioFilterType): Filter criteria
- `filter` (FindFilterType): Pagination and sorting
- `ids` (ID[]): Specific studio IDs

**Returns:** FindStudiosResultType

**Example:**
```graphql
query {
  findStudios(filter: { per_page: 50, page: 1 }) {
    count
    studios {
      id
      name
      url
      details
      favorite
      rating100
      scene_count
      image_count
      gallery_count
      parent_studio {
        id
        name
      }
      child_studios {
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

---

### Tag Queries

#### `findTag`
Find a single tag by ID.

**Parameters:**
- `id` (ID): Tag ID

**Returns:** Tag object

#### `findTags`
Query multiple tags with filtering and pagination.

**Parameters:**
- `tag_filter` (TagFilterType): Filter criteria
- `filter` (FindFilterType): Pagination and sorting
- `ids` (ID[]): Specific tag IDs

**Returns:** FindTagsResultType

**Example:**
```graphql
query {
  findTags(filter: { per_page: 100, page: 1 }) {
    count
    tags {
      id
      name
      description
      aliases
      favorite
      scene_count
      scene_marker_count
      image_count
      gallery_count
      performer_count
      parents {
        id
        name
      }
      children {
        id
        name
      }
    }
  }
}
```

---

### Group Queries

#### `findGroup`
Find a single group by ID.

**Parameters:**
- `id` (ID): Group ID

**Returns:** Group object

#### `findGroups`
Query multiple groups with filtering and pagination.

**Parameters:**
- `group_filter` (GroupFilterType): Filter criteria
- `filter` (FindFilterType): Pagination and sorting
- `ids` (ID[]): Specific group IDs

**Returns:** FindGroupsResultType

**Example:**
```graphql
query {
  findGroups(filter: { per_page: 25, page: 1 }) {
    count
    groups {
      id
      name
      aliases
      date
      rating100
      duration
      director
      synopsis
      url
      studio {
        id
        name
      }
      scenes {
        id
        title
      }
      scene_count
    }
  }
}
```

---

### Scene Marker Queries

#### `findSceneMarkers`
Query scene markers with filtering and pagination.

**Parameters:**
- `scene_marker_filter` (SceneMarkerFilterType): Filter criteria
- `filter` (FindFilterType): Pagination and sorting
- `ids` (ID[]): Specific marker IDs

**Returns:** FindSceneMarkersResultType

**Example:**
```graphql
query {
  findSceneMarkers(filter: { per_page: 50, page: 1 }) {
    count
    scene_markers {
      id
      title
      seconds
      primary_tag {
        id
        name
      }
      tags {
        id
        name
      }
      scene {
        id
        title
      }
    }
  }
}
```

#### `markerWall`
Get random scene markers for wall display.

**Parameters:**
- `q` (String, optional): Search query

**Returns:** Array of SceneMarker objects

#### `sceneMarkerTags`
Organize scene markers by tag for a given scene.

**Parameters:**
- `scene_id` (ID): Scene ID

**Returns:** Array of SceneMarkerTag objects

---

### File & Folder Queries

#### `findFile`
Find a file by ID or path.

**Parameters:**
- `id` (ID, optional): File ID
- `path` (String, optional): File path

**Returns:** BaseFile object

#### `findFiles`
Query files with filtering and pagination.

**Parameters:**
- `file_filter` (FileFilterType): Filter criteria
- `filter` (FindFilterType): Pagination and sorting
- `ids` (ID[]): Specific file IDs

**Returns:** FindFilesResultType

#### `findFolder`
Find a folder by ID or path.

**Parameters:**
- `id` (ID, optional): Folder ID
- `path` (String, optional): Folder path

**Returns:** Folder object

#### `findFolders`
Query folders with filtering and pagination.

**Parameters:**
- `folder_filter` (FolderFilterType): Filter criteria
- `filter` (FindFilterType): Pagination and sorting
- `ids` (ID[]): Specific folder IDs

**Returns:** FindFoldersResultType

---

### Scraper Queries

#### `listScrapers`
List available scrapers.

**Parameters:**
- `types` (ScrapeContentType[]): Content types to filter

**Returns:** Array of Scraper objects

**Example:**
```graphql
query {
  listScrapers(types: [SCENE, PERFORMER, GALLERY]) {
    id
    name
    scene {
      supported_scrapes
    }
    performer {
      supported_scrapes
    }
  }
}
```

#### `scrapeSingleScene`
Scrape metadata for a single scene.

**Parameters:**
- `source` (ScraperSourceInput): Scraper source
- `input` (ScrapeSingleSceneInput): Scene input

**Returns:** Array of ScrapedScene objects

#### `scrapeMultiScenes`
Scrape metadata for multiple scenes.

**Parameters:**
- `source` (ScraperSourceInput): Scraper source
- `input` (ScrapeMultiScenesInput): Scenes input

**Returns:** Array of ScrapedScene arrays

#### `scrapeSinglePerformer`
Scrape metadata for a single performer.

**Parameters:**
- `source` (ScraperSourceInput): Scraper source
- `input` (ScrapeSinglePerformerInput): Performer input

**Returns:** Array of ScrapedPerformer objects

#### `scrapeMultiPerformers`
Scrape metadata for multiple performers.

**Parameters:**
- `source` (ScraperSourceInput): Scraper source
- `input` (ScrapeMultiPerformersInput): Performers input

**Returns:** Array of ScrapedPerformer arrays

#### `scrapeSingleStudio`
Scrape metadata for a single studio.

**Parameters:**
- `source` (ScraperSourceInput): Scraper source
- `input` (ScrapeSingleStudioInput): Studio input

**Returns:** Array of ScrapedStudio objects

#### `scrapeSingleGallery`
Scrape metadata for a single gallery.

**Parameters:**
- `source` (ScraperSourceInput): Scraper source
- `input` (ScrapeSingleGalleryInput): Gallery input

**Returns:** Array of ScrapedGallery objects

#### `scrapeSingleGroup`
Scrape metadata for a single group.

**Parameters:**
- `source` (ScraperSourceInput): Scraper source
- `input` (ScrapeSingleGroupInput): Group input

**Returns:** Array of ScrapedGroup objects

#### `scrapeURL`
Scrape content based on a URL.

**Parameters:**
- `url` (String): URL to scrape
- `ty` (ScrapeContentType): Content type

**Returns:** ScrapedContent object

#### `scrapeSceneURL`
Scrape a complete scene record from URL.

**Parameters:**
- `url` (String): Scene URL

**Returns:** ScrapedScene object

#### `scrapePerformerURL`
Scrape a complete performer record from URL.

**Parameters:**
- `url` (String): Performer URL

**Returns:** ScrapedPerformer object

#### `scrapeGalleryURL`
Scrape a complete gallery record from URL.

**Parameters:**
- `url` (String): Gallery URL

**Returns:** ScrapedGallery object

#### `scrapeGroupURL`
Scrape a complete group record from URL.

**Parameters:**
- `url` (String): Group URL

**Returns:** ScrapedGroup object

---

### System & Configuration Queries

#### `configuration`
Get current complete configuration.

**Returns:** ConfigResult object

**Example:**
```graphql
query {
  configuration {
    general {
      database_path
      generated_path
      cache_path
      stashes {
        path
      }
    }
    interface {
      menu_items
      sound_on_preview
      wall_show_title
      maximum_loop_duration
      language
    }
    dlna {
      enabled
      server_name
    }
  }
}
```

#### `directory`
List directory contents.

**Parameters:**
- `path` (String, optional): Directory path
- `locale` (String, default: "en"): Collation locale

**Returns:** Directory object with path and directories/files arrays

#### `systemStatus`
Get system status information.

**Returns:** SystemStatus object with app version, database info, OS, working directory, etc.

**Example:**
```graphql
query {
  systemStatus {
    appVersion
    databasePath
    databaseSchema
    configPath
    os
    workingDir
    homeDir
    ffmpegPath
    ffprobePath
  }
}
```

#### `version`
Get current Stash version info.

**Returns:** Version object

#### `latestversion`
Get latest available version info.

**Returns:** LatestVersion object with update information

#### `stats`
Get statistics about your collection.

**Returns:** StatsResultType

**Example:**
```graphql
query {
  stats {
    scene_count
    scenes_size
    scenes_duration
    image_count
    images_size
    gallery_count
    performer_count
    studio_count
    movie_count
    tag_count
    total_o_count
    total_play_duration
    total_play_count
  }
}
```

---

### Job & Plugin Queries

#### `jobQueue`
Get current job queue.

**Returns:** Array of Job objects

**Example:**
```graphql
query {
  jobQueue {
    id
    status
    subTasks
    description
    progress
    startTime
    endTime
    addTime
  }
}
```

#### `findJob`
Find a specific job.

**Parameters:**
- `input` (FindJobInput): Job search criteria

**Returns:** Job object

#### `plugins`
List loaded plugins.

**Returns:** Array of Plugin objects

#### `pluginTasks`
List available plugin operations.

**Returns:** Array of PluginTask objects

---

### Saved Filter Queries

#### `findSavedFilter`
Find a saved filter by ID.

**Parameters:**
- `id` (ID): Filter ID

**Returns:** SavedFilter object

#### `findSavedFilters`
Find all saved filters for a mode.

**Parameters:**
- `mode` (FilterMode, optional): Filter mode

**Returns:** Array of SavedFilter objects

---

### Package Queries

#### `installedPackages`
List installed packages (scrapers, plugins, etc.).

**Parameters:**
- `type` (PackageType): Package type

**Returns:** Array of Package objects

#### `availablePackages`
List available packages from a source.

**Parameters:**
- `type` (PackageType): Package type
- `source` (String): Package source URL

**Returns:** Array of Package objects

---

### Utility Queries

#### `logs`
Get application logs.

**Returns:** Array of LogEntry objects

#### `markerStrings`
Get marker string suggestions.

**Parameters:**
- `q` (String, optional): Search query
- `sort` (String, optional): Sort order

**Returns:** Array of MarkerStringsResultType

#### `dlnaStatus`
Get DLNA server status.

**Returns:** DLNAStatus object

#### `validateStashBoxCredentials`
Validate StashBox credentials.

**Parameters:**
- `input` (StashBoxInput): StashBox connection details

**Returns:** StashBoxValidationResult

---

## 2. MUTATION OPERATIONS

### Scene Mutations

#### `sceneCreate`
Create a new scene.

**Parameters:**
- `input` (SceneCreateInput): Scene data

**Returns:** Created Scene object

**Example:**
```graphql
mutation {
  sceneCreate(input: {
    title: "My Scene"
    date: "2024-01-15"
    details: "Scene description"
    url: "https://example.com/scene"
    rating100: 85
    performer_ids: ["1", "2"]
    studio_id: "5"
    tag_ids: ["10", "15", "20"]
  }) {
    id
    title
    date
  }
}
```

#### `sceneUpdate`
Update an existing scene.

**Parameters:**
- `input` (SceneUpdateInput): Updated scene data including ID

**Returns:** Updated Scene object

#### `sceneMerge`
Merge multiple scenes into one.

**Parameters:**
- `input` (SceneMergeInput): Source and destination scene IDs

**Returns:** Merged Scene object

#### `bulkSceneUpdate`
Update multiple scenes at once.

**Parameters:**
- `input` (BulkSceneUpdateInput): Bulk update criteria

**Returns:** Array of updated Scene objects

#### `scenesUpdate`
Update multiple specific scenes.

**Parameters:**
- `input` (SceneUpdateInput[]): Array of scene updates

**Returns:** Array of updated Scene objects

#### `sceneDestroy`
Delete a scene.

**Parameters:**
- `input` (SceneDestroyInput): Scene ID and deletion options

**Returns:** Boolean success

#### `scenesDestroy`
Delete multiple scenes.

**Parameters:**
- `input` (ScenesDestroyInput): Scene IDs and deletion options

**Returns:** Boolean success

#### `sceneAddO`
Increment scene O-counter.

**Parameters:**
- `id` (ID): Scene ID
- `times` (Timestamp[], optional): Specific timestamps

**Returns:** HistoryMutationResult

#### `sceneDeleteO`
Decrement scene O-counter.

**Parameters:**
- `id` (ID): Scene ID
- `times` (Timestamp[], optional): Specific timestamps to remove

**Returns:** HistoryMutationResult

#### `sceneResetO`
Reset scene O-counter to 0.

**Parameters:**
- `id` (ID): Scene ID

**Returns:** New count (Int)

#### `sceneAddPlay`
Increment scene play count.

**Parameters:**
- `id` (ID): Scene ID
- `times` (Timestamp[], optional): Specific timestamps

**Returns:** HistoryMutationResult

#### `sceneDeletePlay`
Decrement scene play count.

**Parameters:**
- `id` (ID): Scene ID
- `times` (Timestamp[], optional): Specific timestamps to remove

**Returns:** HistoryMutationResult

#### `sceneResetPlayCount`
Reset scene play count to 0.

**Parameters:**
- `id` (ID): Scene ID

**Returns:** New count (Int)

#### `sceneSaveActivity`
Save scene playback activity (resume point and duration).

**Parameters:**
- `id` (ID): Scene ID
- `resume_time` (Float, optional): Resume time in seconds
- `playDuration` (Float, optional): Play duration to add

**Returns:** Boolean success

#### `sceneResetActivity`
Reset scene playback activity.

**Parameters:**
- `id` (ID): Scene ID
- `reset_resume` (Boolean): Reset resume point
- `reset_duration` (Boolean): Reset play duration

**Returns:** Boolean success

#### `sceneGenerateScreenshot`
Generate screenshot for scene.

**Parameters:**
- `id` (ID): Scene ID
- `at` (Float, optional): Time in seconds for screenshot

**Returns:** Screenshot path (String)

#### `sceneAssignFile`
Assign a file to a scene.

**Parameters:**
- `input` (AssignSceneFileInput): Scene and file IDs

**Returns:** Boolean success

---

### Scene Marker Mutations

#### `sceneMarkerCreate`
Create a scene marker.

**Parameters:**
- `input` (SceneMarkerCreateInput): Marker data

**Returns:** Created SceneMarker object

**Example:**
```graphql
mutation {
  sceneMarkerCreate(input: {
    scene_id: "123"
    title: "Marker Title"
    seconds: 125.5
    primary_tag_id: "10"
    tag_ids: ["11", "12"]
  }) {
    id
    title
    seconds
  }
}
```

#### `sceneMarkerUpdate`
Update a scene marker.

**Parameters:**
- `input` (SceneMarkerUpdateInput): Updated marker data

**Returns:** Updated SceneMarker object

#### `bulkSceneMarkerUpdate`
Update multiple scene markers.

**Parameters:**
- `input` (BulkSceneMarkerUpdateInput): Bulk update criteria

**Returns:** Array of updated SceneMarker objects

#### `sceneMarkerDestroy`
Delete a scene marker.

**Parameters:**
- `id` (ID): Marker ID

**Returns:** Boolean success

#### `sceneMarkersDestroy`
Delete multiple scene markers.

**Parameters:**
- `ids` (ID[]): Marker IDs

**Returns:** Boolean success

---

### Image Mutations

#### `imageUpdate`
Update an image.

**Parameters:**
- `input` (ImageUpdateInput): Updated image data

**Returns:** Updated Image object

**Example:**
```graphql
mutation {
  imageUpdate(input: {
    id: "456"
    title: "Image Title"
    rating100: 90
    organized: true
    performer_ids: ["1", "2"]
    tag_ids: ["5", "6"]
  }) {
    id
    title
    rating100
  }
}
```

#### `bulkImageUpdate`
Update multiple images.

**Parameters:**
- `input` (BulkImageUpdateInput): Bulk update criteria

**Returns:** Array of updated Image objects

#### `imagesUpdate`
Update multiple specific images.

**Parameters:**
- `input` (ImageUpdateInput[]): Array of image updates

**Returns:** Array of updated Image objects

#### `imageDestroy`
Delete an image.

**Parameters:**
- `input` (ImageDestroyInput): Image ID and deletion options

**Returns:** Boolean success

#### `imagesDestroy`
Delete multiple images.

**Parameters:**
- `input` (ImagesDestroyInput): Image IDs and deletion options

**Returns:** Boolean success

#### `imageIncrementO`
Increment image O-counter.

**Parameters:**
- `id` (ID): Image ID

**Returns:** New count (Int)

#### `imageDecrementO`
Decrement image O-counter.

**Parameters:**
- `id` (ID): Image ID

**Returns:** New count (Int)

#### `imageResetO`
Reset image O-counter.

**Parameters:**
- `id` (ID): Image ID

**Returns:** New count (Int)

---

### Gallery Mutations

#### `galleryCreate`
Create a new gallery.

**Parameters:**
- `input` (GalleryCreateInput): Gallery data

**Returns:** Created Gallery object

**Example:**
```graphql
mutation {
  galleryCreate(input: {
    title: "My Gallery"
    date: "2024-01-15"
    url: "https://example.com/gallery"
    rating100: 88
    performer_ids: ["1", "2"]
    studio_id: "5"
    tag_ids: ["10", "15"]
  }) {
    id
    title
    date
  }
}
```

#### `galleryUpdate`
Update a gallery.

**Parameters:**
- `input` (GalleryUpdateInput): Updated gallery data

**Returns:** Updated Gallery object

#### `bulkGalleryUpdate`
Update multiple galleries.

**Parameters:**
- `input` (BulkGalleryUpdateInput): Bulk update criteria

**Returns:** Array of updated Gallery objects

#### `galleriesUpdate`
Update multiple specific galleries.

**Parameters:**
- `input` (GalleryUpdateInput[]): Array of gallery updates

**Returns:** Array of updated Gallery objects

#### `galleryDestroy`
Delete a gallery.

**Parameters:**
- `input` (GalleryDestroyInput): Gallery ID and deletion options

**Returns:** Boolean success

#### `addGalleryImages`
Add images to a gallery.

**Parameters:**
- `input` (GalleryAddInput): Gallery ID and image IDs

**Returns:** Boolean success

#### `removeGalleryImages`
Remove images from a gallery.

**Parameters:**
- `input` (GalleryRemoveInput): Gallery ID and image IDs

**Returns:** Boolean success

#### `setGalleryCover`
Set gallery cover image.

**Parameters:**
- `input` (GallerySetCoverInput): Gallery ID and cover file ID

**Returns:** Boolean success

#### `resetGalleryCover`
Reset gallery cover to default.

**Parameters:**
- `input` (GalleryResetCoverInput): Gallery ID

**Returns:** Boolean success

#### `galleryChapterCreate`
Create a gallery chapter.

**Parameters:**
- `input` (GalleryChapterCreateInput): Chapter data

**Returns:** GalleryChapter object

#### `galleryChapterUpdate`
Update a gallery chapter.

**Parameters:**
- `input` (GalleryChapterUpdateInput): Updated chapter data

**Returns:** GalleryChapter object

#### `galleryChapterDestroy`
Delete a gallery chapter.

**Parameters:**
- `id` (ID): Chapter ID

**Returns:** Boolean success

---

### Performer Mutations

#### `performerCreate`
Create a new performer.

**Parameters:**
- `input` (PerformerCreateInput): Performer data

**Returns:** Created Performer object

**Example:**
```graphql
mutation {
  performerCreate(input: {
    name: "Performer Name"
    disambiguation: "Performer 1"
    gender: FEMALE
    birthdate: "1990-05-15"
    country: "USA"
    eye_color: "Blue"
    hair_color: "Blonde"
    height_cm: 165
    url: "https://example.com/performer"
    twitter: "@performer"
    instagram: "performer"
    favorite: true
    rating100: 95
  }) {
    id
    name
  }
}
```

#### `performerUpdate`
Update a performer.

**Parameters:**
- `input` (PerformerUpdateInput): Updated performer data

**Returns:** Updated Performer object

#### `bulkPerformerUpdate`
Update multiple performers.

**Parameters:**
- `input` (BulkPerformerUpdateInput): Bulk update criteria

**Returns:** Array of updated Performer objects

#### `performerDestroy`
Delete a performer.

**Parameters:**
- `input` (PerformerDestroyInput): Performer ID

**Returns:** Boolean success

#### `performersDestroy`
Delete multiple performers.

**Parameters:**
- `ids` (ID[]): Performer IDs

**Returns:** Boolean success

---

### Studio Mutations

#### `studioCreate`
Create a new studio.

**Parameters:**
- `input` (StudioCreateInput): Studio data

**Returns:** Created Studio object

**Example:**
```graphql
mutation {
  studioCreate(input: {
    name: "Studio Name"
    url: "https://studio.com"
    details: "Studio description"
    parent_id: "10"
    rating100: 85
    favorite: true
  }) {
    id
    name
  }
}
```

#### `studioUpdate`
Update a studio.

**Parameters:**
- `input` (StudioUpdateInput): Updated studio data

**Returns:** Updated Studio object

#### `bulkStudioUpdate`
Update multiple studios.

**Parameters:**
- `input` (BulkStudioUpdateInput): Bulk update criteria

**Returns:** Array of updated Studio objects

#### `studioDestroy`
Delete a studio.

**Parameters:**
- `input` (StudioDestroyInput): Studio ID

**Returns:** Boolean success

#### `studiosDestroy`
Delete multiple studios.

**Parameters:**
- `ids` (ID[]): Studio IDs

**Returns:** Boolean success

---

### Tag Mutations

#### `tagCreate`
Create a new tag.

**Parameters:**
- `input` (TagCreateInput): Tag data

**Returns:** Created Tag object

**Example:**
```graphql
mutation {
  tagCreate(input: {
    name: "Tag Name"
    description: "Tag description"
    aliases: ["alias1", "alias2"]
    parent_ids: ["5"]
    favorite: true
  }) {
    id
    name
  }
}
```

#### `tagUpdate`
Update a tag.

**Parameters:**
- `input` (TagUpdateInput): Updated tag data

**Returns:** Updated Tag object

#### `bulkTagUpdate`
Update multiple tags.

**Parameters:**
- `input` (BulkTagUpdateInput): Bulk update criteria

**Returns:** Array of updated Tag objects

#### `tagDestroy`
Delete a tag.

**Parameters:**
- `input` (TagDestroyInput): Tag ID

**Returns:** Boolean success

#### `tagsDestroy`
Delete multiple tags.

**Parameters:**
- `ids` (ID[]): Tag IDs

**Returns:** Boolean success

#### `tagsMerge`
Merge multiple tags into one.

**Parameters:**
- `input` (TagsMergeInput): Source and destination tag IDs

**Returns:** Merged Tag object

---

### Group Mutations

#### `groupCreate`
Create a new group.

**Parameters:**
- `input` (GroupCreateInput): Group data

**Returns:** Created Group object

**Example:**
```graphql
mutation {
  groupCreate(input: {
    name: "Series Name"
    aliases: "Alternative Name"
    date: "2024-01-01"
    rating100: 90
    duration: 7200
    director: "Director Name"
    synopsis: "Series description"
    url: "https://example.com/series"
    studio_id: "5"
  }) {
    id
    name
  }
}
```

#### `groupUpdate`
Update a group.

**Parameters:**
- `input` (GroupUpdateInput): Updated group data

**Returns:** Updated Group object

#### `bulkGroupUpdate`
Update multiple groups.

**Parameters:**
- `input` (BulkGroupUpdateInput): Bulk update criteria

**Returns:** Array of updated Group objects

#### `groupDestroy`
Delete a group.

**Parameters:**
- `input` (GroupDestroyInput): Group ID

**Returns:** Boolean success

#### `groupsDestroy`
Delete multiple groups.

**Parameters:**
- `ids` (ID[]): Group IDs

**Returns:** Boolean success

#### `addGroupSubGroups`
Add sub-groups to a group.

**Parameters:**
- `input` (GroupSubGroupAddInput): Parent group ID and sub-group IDs

**Returns:** Boolean success

#### `removeGroupSubGroups`
Remove sub-groups from a group.

**Parameters:**
- `input` (GroupSubGroupRemoveInput): Parent group ID and sub-group IDs

**Returns:** Boolean success

#### `reorderSubGroups`
Reorder sub-groups within a group.

**Parameters:**
- `input` (ReorderSubGroupsInput): Group ID and new order

**Returns:** Boolean success

---

### System & Configuration Mutations

#### `setup`
Initial system setup.

**Parameters:**
- `input` (SetupInput): Setup configuration

**Returns:** Boolean success

#### `migrate`
Migrate database schema. Returns job ID.

**Parameters:**
- `input` (MigrateInput): Migration configuration

**Returns:** Job ID (String)

#### `downloadFFMpeg`
Download and install FFmpeg binaries. Returns job ID.

**Returns:** Job ID (String)

#### `configureGeneral`
Update general configuration.

**Parameters:**
- `input` (ConfigGeneralInput): General config

**Returns:** ConfigGeneralResult

#### `configureInterface`
Update interface configuration.

**Parameters:**
- `input` (ConfigInterfaceInput): Interface config

**Returns:** ConfigInterfaceResult

#### `configureDLNA`
Update DLNA configuration.

**Parameters:**
- `input` (ConfigDLNAInput): DLNA config

**Returns:** ConfigDLNAResult

#### `configureScraping`
Update scraping configuration.

**Parameters:**
- `input` (ConfigScrapingInput): Scraping config

**Returns:** ConfigScrapingResult

#### `configureDefaults`
Update default settings.

**Parameters:**
- `input` (ConfigDefaultSettingsInput): Default settings

**Returns:** ConfigDefaultSettingsResult

#### `configureUI`
Update UI configuration.

**Parameters:**
- `input` (ConfigUIInput): UI config as JSON

**Returns:** JSON string

#### `generateAPIKey`
Generate a new API key.

**Parameters:**
- `input` (GenerateAPIKeyInput): API key options

**Returns:** API key (String)

---

### Saved Filter Mutations

#### `saveFilter`
Save or update a filter.

**Parameters:**
- `input` (SaveFilterInput): Filter data

**Returns:** SavedFilter object

#### `destroySavedFilter`
Delete a saved filter.

**Parameters:**
- `input` (DestroyFilterInput): Filter ID

**Returns:** Boolean success

#### `setDefaultFilter`
Set default filter for a mode.

**Parameters:**
- `input` (SetDefaultFilterInput): Filter ID and mode

**Returns:** Boolean success

---

### Task & Job Mutations

#### `metadataScan`
Start metadata scan. Returns job ID.

**Parameters:**
- `input` (ScanMetadataInput): Scan options

**Returns:** Job ID (String)

#### `metadataGenerate`
Start metadata generation. Returns job ID.

**Parameters:**
- `input` (GenerateMetadataInput): Generation options

**Returns:** Job ID (String)

#### `metadataAutoTag`
Start auto-tagging. Returns job ID.

**Parameters:**
- `input` (AutoTagMetadataInput): Auto-tag options

**Returns:** Job ID (String)

#### `metadataClean`
Clean metadata. Returns job ID.

**Parameters:**
- `input` (CleanMetadataInput): Clean options

**Returns:** Job ID (String)

#### `metadataExport`
Export metadata. Returns job ID.

**Returns:** Job ID (String)

#### `metadataImport`
Import metadata. Returns job ID.

**Returns:** Job ID (String)

#### `exportObjects`
Export database objects. Returns job ID.

**Parameters:**
- `input` (ExportObjectsInput): Export options

**Returns:** Job ID (String)

#### `importObjects`
Import database objects. Returns job ID.

**Parameters:**
- `input` (ImportObjectsInput): Import options

**Returns:** Job ID (String)

#### `backupDatabase`
Backup database. Returns job ID.

**Parameters:**
- `input` (BackupDatabaseInput): Backup options

**Returns:** Job ID (String)

#### `anonymiseDatabase`
Anonymize database. Returns job ID.

**Parameters:**
- `input` (AnonymiseDatabaseInput): Anonymize options

**Returns:** Job ID (String)

#### `optimiseDatabase`
Optimize database.

**Returns:** Boolean success

#### `stopJob`
Stop a running job.

**Parameters:**
- `job_id` (ID): Job ID

**Returns:** Boolean success

#### `stopAllJobs`
Stop all running jobs.

**Returns:** Boolean success

---

### Plugin Mutations

#### `runPluginTask`
Run a plugin task.

**Parameters:**
- `plugin_id` (ID): Plugin ID
- `task_name` (String): Task name
- `args` (JSON, optional): Task arguments

**Returns:** Job ID (String)

#### `reloadPlugins`
Reload all plugins.

**Returns:** Boolean success

---

### Package Mutations

#### `installPackages`
Install packages.

**Parameters:**
- `type` (PackageType): Package type
- `packages` (PackageSpecInput[]): Packages to install

**Returns:** Job ID (String)

#### `updatePackages`
Update installed packages.

**Parameters:**
- `type` (PackageType): Package type
- `packages` (PackageSpecInput[]): Packages to update

**Returns:** Job ID (String)

#### `uninstallPackages`
Uninstall packages.

**Parameters:**
- `type` (PackageType): Package type
- `packages` (PackageSpecInput[]): Packages to uninstall

**Returns:** Job ID (String)

---

## 3. SUBSCRIPTION OPERATIONS

Stash supports GraphQL subscriptions for real-time updates.

### `jobsSubscribe`
Subscribe to job status updates.

**Returns:** Job updates stream

**Example:**
```graphql
subscription {
  jobsSubscribe {
    id
    status
    progress
    description
  }
}
```

### `loggingSubscribe`
Subscribe to log entries.

**Returns:** LogEntry stream

**Example:**
```graphql
subscription {
  loggingSubscribe {
    time
    level
    message
  }
}
```

### `scanCompleteSubscribe`
Subscribe to scan completion events.

**Returns:** Boolean stream

---

## Common Input Types

### FindFilterType
Pagination and sorting options.

**Fields:**
- `page` (Int): Page number (1-indexed)
- `per_page` (Int): Items per page
- `sort` (String): Field to sort by
- `direction` (SortDirectionEnum): ASC or DESC
- `q` (String): Search query

### SceneFilterType
Filter criteria for scenes.

**Common Fields:**
- `is_organized` (Boolean): Organized status
- `is_missing` (String): Missing data field
- `rating100` (IntCriterionInput): Rating filter
- `o_counter` (IntCriterionInput): O-counter filter
- `organized` (Boolean): Organized status
- `resolution` (ResolutionEnum): Video resolution
- `duration` (IntCriterionInput): Duration filter
- `has_markers` (String): Has markers filter
- `performers` (MultiCriterionInput): Performer filter
- `studios` (HierarchicalMultiCriterionInput): Studio filter
- `tags` (HierarchicalMultiCriterionInput): Tag filter
- `date` (DateCriterionInput): Date filter
- `created_at` (TimestampCriterionInput): Created date filter
- `updated_at` (TimestampCriterionInput): Updated date filter

### Criterion Input Types
Used for filtering numeric, date, and multi-value fields:
- `IntCriterionInput`: For integer comparisons
- `FloatCriterionInput`: For float comparisons
- `DateCriterionInput`: For date comparisons
- `TimestampCriterionInput`: For timestamp comparisons
- `StringCriterionInput`: For string comparisons
- `MultiCriterionInput`: For multi-value fields (IDs)
- `HierarchicalMultiCriterionInput`: For hierarchical multi-value fields

---

## Example Workflows

### Complete Scene Query
```graphql
query {
  findScene(id: "123") {
    id
    title
    date
    details
    url
    rating100
    organized
    o_counter
    play_count
    play_duration
    resume_time
    created_at
    updated_at
    files {
      id
      path
      size
      duration
      video_codec
      audio_codec
      width
      height
      frame_rate
      bitrate
    }
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
    scene_markers {
      id
      title
      seconds
      primary_tag {
        id
        name
      }
      tags {
        id
        name
      }
    }
    galleries {
      id
      title
    }
    studio {
      id
      name
      image_path
    }
    groups {
      id
      name
    }
    performers {
      id
      name
      disambiguation
      gender
      favorite
      image_path
    }
    tags {
      id
      name
      description
    }
    stash_ids {
      endpoint
      stash_id
    }
  }
}
```

### Create and Update Scene
```graphql
# Create
mutation {
  sceneCreate(input: {
    title: "New Scene"
    date: "2024-01-15"
    details: "Description"
    url: "https://example.com/scene"
    rating100: 85
    performer_ids: ["1", "2"]
    studio_id: "5"
    tag_ids: ["10", "15"]
  }) {
    id
  }
}

# Update
mutation {
  sceneUpdate(input: {
    id: "123"
    title: "Updated Title"
    rating100: 90
    organized: true
  }) {
    id
    title
  }
}
```

### Search with Filters
```graphql
query {
  findScenes(
    filter: {
      per_page: 25
      page: 1
      sort: "date"
      direction: DESC
      q: "keyword"
    }
    scene_filter: {
      rating100: { value: 80, modifier: GREATER_THAN }
      performers: { value: ["1", "2"], modifier: INCLUDES_ALL }
      tags: { value: ["10"], modifier: INCLUDES }
      organized: true
      duration: { value: 600, modifier: GREATER_THAN }
    }
  ) {
    count
    scenes {
      id
      title
      date
      rating100
    }
  }
}
```

---

## Notes

- All timestamps are in ISO 8601 format
- IDs are strings in GraphQL (ID type)
- Ratings use `rating100` field (0-100 scale)
- File paths are absolute on the server
- Image paths can be accessed via the server's image endpoint
- The API supports batching multiple operations in a single request
- Use GraphQL introspection to explore the full schema

For more information, visit:
- Official docs: https://docs.stashapp.cc
- API Documentation: https://github.com/stashapp/stash/blob/develop/graphql/schema/
- Community: https://discord.gg/2TsNFKt
