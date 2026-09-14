# Whisparr v3 API Documentation

**Whisparr** is a movie/scene collection manager for adult content. The v3 API provides comprehensive endpoints for managing movies, performers, files, downloads, and system configuration.

Base URL: `http://localhost:6969/api/v3` (default)

## Authentication

Whisparr uses API key authentication via the `X-Api-Key` header.

Example:
```
X-Api-Key: your-api-key-here
```

Get your API key from: Settings → General → Security → API Key

---

## Core Data Structures

### Movie
Represents a movie/scene in your collection with metadata, files, and monitoring status.

### MovieFile
Represents the physical file for a movie with quality, language, and media info.

### Performer
Represents a performer/actor with metadata and monitoring capabilities.

### History
Tracks all events related to movies (downloads, imports, deletions, etc.).

### Queue
Active and pending downloads from indexers/download clients.

---

## 1. MOVIE ENDPOINTS

### GET /api/v3/movie
Get all movies or filter by TMDB ID.

**Query Parameters:**
- `tmdbId` (int, optional): Filter by TMDB ID
- `excludeLocalCovers` (bool, optional): Exclude cover images from response

**Response:** Array of Movie objects

**Example Response:**
```json
[
  {
    "id": 1,
    "title": "Movie Title",
    "foreignId": "tmdb:12345",
    "tmdbId": 12345,
    "stashId": "stash-uuid",
    "year": 2024,
    "overview": "Movie description",
    "releaseDate": "2024-01-15T00:00:00Z",
    "images": [
      {
        "coverType": "poster",
        "url": "/MediaCover/1/poster.jpg"
      }
    ],
    "website": "https://example.com",
    "monitored": true,
    "isAvailable": true,
    "hasFile": true,
    "path": "/movies/Movie Title",
    "qualityProfileId": 1,
    "sizeOnDisk": 1073741824,
    "status": "released",
    "runtime": 120,
    "studioTitle": "Studio Name",
    "genres": ["Genre1", "Genre2"],
    "tags": [1, 2],
    "ratings": {
      "value": 8.5
    },
    "movieFile": {
      "id": 1,
      "movieId": 1,
      "relativePath": "Movie Title.mkv",
      "size": 1073741824,
      "quality": {
        "quality": {
          "id": 7,
          "name": "Bluray-1080p"
        }
      },
      "languages": [{"id": 1, "name": "English"}]
    }
  }
]
```

### GET /api/v3/movie/{id}
Get a specific movie by ID.

**Path Parameters:**
- `id` (int, required): Movie ID

**Response:** Movie object

### POST /api/v3/movie
Add a new movie to the collection.

**Request Body:**
```json
{
  "title": "Movie Title",
  "tmdbId": 12345,
  "qualityProfileId": 1,
  "path": "/movies/Movie Title",
  "monitored": true,
  "rootFolderPath": "/movies",
  "tags": [1],
  "addOptions": {
    "searchForMovie": true
  }
}
```

**Response:** Created movie object with ID

### PUT /api/v3/movie/{id}
Update an existing movie.

**Path Parameters:**
- `id` (int, required): Movie ID

**Query Parameters:**
- `moveFiles` (bool, optional): Move files to new path if changed

**Request Body:** Movie object with updated fields

**Response:** Updated movie object

**Special Case: Moving to a Different Root Folder**

When a user changes the `rootFolderPath`, the iOS app implements a user-confirmed workflow:

```
1. User edits movie and selects new root folder
   ↓
2. App detects: rootFolderPath has changed
   ↓
3. On Save, app shows confirmation alert:
   "Move the movie files to [new path]?"
   ├─ "Move Files" → PUT with moveFiles=true
   ├─ "No" → PUT with moveFiles=false
   └─ "Cancel" → Stay in edit form
   ↓
4. API call: PUT /api/v3/movie/{id}?moveFiles=true|false
   ↓
5. Response: Updated movie object with new path
```

**Workflow Implementation Details:**

- **Change Detection**: Compares current `rootFolderPath` against the value captured at form entry (with trailing slashes normalized)
- **Confirmation Dialog**: Only shown if:
  - Movie already exists (not a new add)
  - AND root folder path has actually changed
- **Three Options**:
  - **Move Files (destructive)**: Sets `moveFiles=true`, tells Whisparr to physically move files to new location
  - **No**: Sets `moveFiles=false`, updates only metadata and path without moving files
  - **Cancel**: Discards all changes, returns to form (with undo applied if needed)
- **State Management**:
  - Original movie state is captured at init time for comparison
  - If user dismisses without saving, `onDisappear` triggers automatic undo of all edits
  - If user cancels the move dialog, form remains open for further editing
- **Path Normalization**: Trailing slashes are stripped before comparison to avoid false change detection
- **Feedback**:
  - Progress indicator during API call
  - Success haptic feedback on iOS upon completion
  - Error alert if API fails (user can retry)

**Example Flow:**

1. User opens edit form for "Movie Title" currently at `/movies/old_location`
2. Original path is captured: `/movies/old_location`
3. User changes root folder to `/mnt/new_location`
4. User taps Save
5. App detects change and shows dialog
6. User taps "Move Files"
7. App calls: `PUT /api/v3/movie/1?moveFiles=true` with new path
8. Whisparr physically moves files from `/movies/old_location/Movie Title` → `/mnt/new_location/Movie Title`
9. Movie path is updated to `/mnt/new_location/Movie Title`
10. Form closes, success notification shown

### DELETE /api/v3/movie/{id}
Delete a movie.

**Path Parameters:**
- `id` (int, required): Movie ID

**Query Parameters:**
- `deleteFiles` (bool, optional): Delete movie files from disk
- `addImportExclusion` (bool, optional): Add to import exclusion list

**Response:** 200 OK

---

## 2. MOVIE LOOKUP & SEARCH

### GET /api/v3/movie/lookup
Search for movies on TMDB.

**Query Parameters:**
- `term` (string, required): Search term (title or TMDB ID)

**Response:** Array of movie search results

**Example:**
```json
[
  {
    "title": "Movie Title",
    "tmdbId": 12345,
    "year": 2024,
    "overview": "Description",
    "images": [...],
    "remotePoster": "https://image.tmdb.org/..."
  }
]
```

### GET /api/v3/movie/lookup/tmdb
Lookup movie by TMDB ID.

**Query Parameters:**
- `tmdbId` (int, required): TMDB ID

**Response:** Movie object

---

## 3. MOVIE FILES

### GET /api/v3/moviefile
Get movie files.

**Query Parameters:**
- `movieId` (int, optional): Filter by movie ID
- `movieFileIds` (int[], optional): Filter by specific file IDs

**Response:** Array of MovieFile objects

### GET /api/v3/moviefile/{id}
Get a specific movie file by ID.

**Path Parameters:**
- `id` (int, required): Movie file ID

**Response:** MovieFile object

### PUT /api/v3/moviefile/{id}
Update a movie file's metadata.

**Path Parameters:**
- `id` (int, required): Movie file ID

**Request Body:**
```json
{
  "id": 1,
  "quality": {
    "quality": {
      "id": 7,
      "name": "Bluray-1080p"
    }
  },
  "languages": [{"id": 1, "name": "English"}],
  "releaseGroup": "GROUP",
  "sceneName": "Movie.Title.2024.1080p.BluRay.x264-GROUP",
  "edition": "Director's Cut",
  "indexerFlags": 0
}
```

**Response:** Updated MovieFile object

### PUT /api/v3/moviefile/editor
Bulk update multiple movie files.

**Request Body:**
```json
{
  "movieFileIds": [1, 2, 3],
  "quality": {
    "quality": {
      "id": 7
    }
  },
  "languages": [{"id": 1}]
}
```

**Response:** Array of updated MovieFile objects

### DELETE /api/v3/moviefile/{id}
Delete a movie file.

**Path Parameters:**
- `id` (int, required): Movie file ID

**Response:** 200 OK

### DELETE /api/v3/moviefile/bulk
Bulk delete movie files.

**Request Body:**
```json
{
  "movieFileIds": [1, 2, 3]
}
```

**Response:** 200 OK

---

## 4. PERFORMERS

### GET /api/v3/performer
Get all performers.

**Response:** Array of Performer objects

**Example Response:**
```json
[
  {
    "id": 1,
    "fullName": "Performer Name",
    "foreignId": "stash:uuid",
    "gender": "female",
    "hairColor": "blonde",
    "ethnicity": "caucasian",
    "status": "active",
    "images": [
      {
        "coverType": "poster",
        "url": "/MediaCover/performer/1/poster.jpg"
      }
    ],
    "monitored": true,
    "qualityProfileId": 1,
    "rootFolderPath": "/movies",
    "searchOnAdd": true,
    "tags": []
  }
]
```

### GET /api/v3/performer/{id}
Get a specific performer by ID.

**Path Parameters:**
- `id` (int, required): Performer ID

**Response:** Performer object

### PUT /api/v3/performer/{id}
Update a performer.

**Path Parameters:**
- `id` (int, required): Performer ID

**Request Body:** Performer object with updated fields

**Response:** Updated performer object

---

## 5. HISTORY

### GET /api/v3/history
Get paginated history with filtering.

**Query Parameters:**
- `page` (int, optional): Page number (default: 1)
- `pageSize` (int, optional): Items per page (default: 10)
- `sortKey` (string, optional): Field to sort by (default: "date")
- `sortDirection` (string, optional): "ascending" or "descending"
- `eventType` (int, optional): Filter by event type
- `downloadId` (string, optional): Filter by download ID
- `movieIds` (int[], optional): Filter by movie IDs
- `includeMovie` (bool, optional): Include full movie object
- `languages` (int[], optional): Filter by language IDs
- `quality` (int[], optional): Filter by quality IDs

**Response:** Paginated history response

**Example Response:**
```json
{
  "page": 1,
  "pageSize": 10,
  "sortKey": "date",
  "sortDirection": "descending",
  "totalRecords": 100,
  "records": [
    {
      "id": 1,
      "movieId": 1,
      "sourceTitle": "Movie.Title.2024.1080p.BluRay.x264-GROUP",
      "quality": {
        "quality": {
          "id": 7,
          "name": "Bluray-1080p"
        }
      },
      "languages": [{"id": 1, "name": "English"}],
      "date": "2024-01-15T12:00:00Z",
      "eventType": "grabbed",
      "data": {},
      "downloadId": "download123"
    }
  ]
}
```

### GET /api/v3/history/since
Get history since a specific date.

**Query Parameters:**
- `date` (datetime, required): Start date (ISO 8601)
- `eventType` (int, optional): Filter by event type
- `includeMovie` (bool, optional): Include full movie object

**Response:** Array of history records

### GET /api/v3/history/movie
Get history for a specific movie.

**Query Parameters:**
- `movieId` (int, required): Movie ID
- `eventType` (int, optional): Filter by event type
- `includeMovie` (bool, optional): Include full movie object

**Response:** Array of history records

### POST /api/v3/history/failed/{id}
Mark a history item as failed.

**Path Parameters:**
- `id` (int, required): History ID

**Response:** 200 OK

---

## 6. CALENDAR

### GET /api/v3/calendar
Get movies releasing in a date range.

**Query Parameters:**
- `start` (datetime, optional): Start date (default: today)
- `end` (datetime, optional): End date (default: today + 2 days)
- `unmonitored` (bool, optional): Include unmonitored movies
- `tags` (string, optional): Comma-separated tag names

**Response:** Array of movie objects sorted by release date

**Example:**
```json
[
  {
    "id": 1,
    "title": "Movie Title",
    "releaseDate": "2024-01-15T00:00:00Z",
    "monitored": true,
    "hasFile": false,
    ...
  }
]
```

---

## 7. QUEUE (DOWNLOADS)

### GET /api/v3/queue
Get active downloads queue.

**Query Parameters:**
- `page` (int, optional): Page number
- `pageSize` (int, optional): Items per page
- `sortKey` (string, optional): Sort field
- `sortDirection` (string, optional): Sort direction
- `includeUnknownMovieItems` (bool, optional): Include unknown items
- `includeMovie` (bool, optional): Include full movie object
- `movieIds` (int[], optional): Filter by movie IDs
- `protocol` (string, optional): Filter by protocol ("torrent" or "usenet")
- `languages` (int[], optional): Filter by languages
- `quality` (int, optional): Filter by quality ID

**Response:** Paginated queue response

**Example Response:**
```json
{
  "page": 1,
  "pageSize": 20,
  "totalRecords": 5,
  "records": [
    {
      "id": 1,
      "movieId": 1,
      "title": "Movie Title",
      "size": 1073741824,
      "sizeleft": 536870912,
      "status": "downloading",
      "trackedDownloadStatus": "ok",
      "statusMessages": [],
      "downloadId": "download123",
      "protocol": "torrent",
      "downloadClient": "Transmission",
      "indexer": "Indexer Name",
      "quality": {
        "quality": {
          "id": 7,
          "name": "Bluray-1080p"
        }
      },
      "languages": [{"id": 1, "name": "English"}],
      "timeleft": "00:15:30",
      "estimatedCompletionTime": "2024-01-15T12:15:30Z"
    }
  ]
}
```

### DELETE /api/v3/queue/{id}
Remove an item from the queue.

**Path Parameters:**
- `id` (int, required): Queue item ID

**Query Parameters:**
- `removeFromClient` (bool, optional): Remove from download client (default: true)
- `blocklist` (bool, optional): Add to blocklist (default: false)
- `skipRedownload` (bool, optional): Skip automatic redownload (default: false)

**Response:** 200 OK

### DELETE /api/v3/queue/bulk
Remove multiple items from queue.

**Query Parameters:**
- `removeFromClient` (bool, optional): Remove from download client
- `blocklist` (bool, optional): Add to blocklist
- `skipRedownload` (bool, optional): Skip automatic redownload

**Request Body:**
```json
{
  "ids": [1, 2, 3]
}
```

**Response:** 200 OK

---

## 8. RELEASES (SEARCH)

### GET /api/v3/release
Search for releases.

**Query Parameters:**
- `movieId` (int, optional): Search for specific movie

**Response:** Array of release objects

**Example Response:**
```json
[
  {
    "guid": "indexer-release-guid",
    "quality": {
      "quality": {
        "id": 7,
        "name": "Bluray-1080p"
      }
    },
    "languages": [{"id": 1, "name": "English"}],
    "size": 1073741824,
    "title": "Movie.Title.2024.1080p.BluRay.x264-GROUP",
    "indexer": "Indexer Name",
    "indexerId": 1,
    "downloadUrl": "https://...",
    "infoUrl": "https://...",
    "approved": true,
    "temporarilyRejected": false,
    "rejected": false,
    "rejections": [],
    "publishDate": "2024-01-15T12:00:00Z",
    "seeders": 50,
    "leechers": 5,
    "protocol": "torrent",
    "movieId": 1
  }
]
```

### POST /api/v3/release
Download a release.

**Request Body:**
```json
{
  "guid": "indexer-release-guid",
  "indexerId": 1,
  "movieId": 1,
  "downloadClientId": 1
}
```

**Response:** Release object

---

## 9. INDEXERS

### GET /api/v3/indexer
Get all configured indexers.

**Response:** Array of indexer configurations

### GET /api/v3/indexer/{id}
Get specific indexer by ID.

**Path Parameters:**
- `id` (int, required): Indexer ID

**Response:** Indexer configuration

### POST /api/v3/indexer
Add a new indexer.

**Request Body:** Indexer configuration

**Response:** Created indexer with ID

### PUT /api/v3/indexer/{id}
Update an indexer.

**Path Parameters:**
- `id` (int, required): Indexer ID

**Request Body:** Updated indexer configuration

**Response:** Updated indexer

### DELETE /api/v3/indexer/{id}
Delete an indexer.

**Path Parameters:**
- `id` (int, required): Indexer ID

**Response:** 200 OK

---

## 10. DOWNLOAD CLIENTS

### GET /api/v3/downloadclient
Get all configured download clients.

**Response:** Array of download client configurations

### GET /api/v3/downloadclient/{id}
Get specific download client by ID.

**Path Parameters:**
- `id` (int, required): Download client ID

**Response:** Download client configuration

### POST /api/v3/downloadclient
Add a new download client.

**Request Body:** Download client configuration

**Response:** Created download client with ID

### PUT /api/v3/downloadclient/{id}
Update a download client.

**Path Parameters:**
- `id` (int, required): Download client ID

**Request Body:** Updated download client configuration

**Response:** Updated download client

### DELETE /api/v3/downloadclient/{id}
Delete a download client.

**Path Parameters:**
- `id` (int, required): Download client ID

**Response:** 200 OK

---

## 11. COMMANDS

### GET /api/v3/command
Get all running and queued commands.

**Response:** Array of command objects

**Example Response:**
```json
[
  {
    "id": 1,
    "name": "RefreshMovie",
    "status": "completed",
    "queued": "2024-01-15T12:00:00Z",
    "started": "2024-01-15T12:00:05Z",
    "ended": "2024-01-15T12:01:00Z",
    "duration": "00:00:55",
    "trigger": "manual",
    "message": "Completed",
    "body": {
      "movieId": 1
    }
  }
]
```

### GET /api/v3/command/{id}
Get a specific command by ID.

**Path Parameters:**
- `id` (int, required): Command ID

**Response:** Command object

### POST /api/v3/command
Execute a command.

**Request Body:**
```json
{
  "name": "RefreshMovie",
  "movieId": 1
}
```

**Available Commands:**
- `RefreshMovie`: Refresh movie metadata
- `RescanMovie`: Rescan movie files
- `RenameMovie`: Rename movie files
- `MoveMovie`: Move movie to new path
- `RssSync`: Sync RSS feeds
- `RefreshMonitoredDownloads`: Check download clients
- `DownloadedMoviesScan`: Scan for downloaded movies
- `MissingMoviesSearch`: Search for missing movies
- `Backup`: Create backup
- `MessagingCleanup`: Clean up old messages

**Response:** Created command with ID

### DELETE /api/v3/command/{id}
Cancel a running command.

**Path Parameters:**
- `id` (int, required): Command ID

**Response:** 200 OK

---

## 12. SYSTEM & CONFIGURATION

### GET /api/v3/system/status
Get system status and information.

**Response:**
```json
{
  "appName": "Whisparr",
  "instanceName": "Whisparr",
  "version": "3.0.0.0",
  "buildTime": "2024-01-15T00:00:00Z",
  "isDebug": false,
  "isProduction": true,
  "isAdmin": true,
  "isUserInteractive": false,
  "startupPath": "/app",
  "appData": "/config",
  "osName": "Linux",
  "osVersion": "5.15.0",
  "isNetCore": true,
  "isLinux": true,
  "isOsx": false,
  "isWindows": false,
  "isDocker": true,
  "mode": "console",
  "branch": "movies",
  "authentication": "forms",
  "databaseType": "sqlite",
  "databaseVersion": "3.40.0",
  "urlBase": "",
  "runtimeVersion": "7.0.0",
  "runtimeName": "netcore",
  "startTime": "2024-01-15T00:00:00Z"
}
```

### POST /api/v3/system/restart
Restart Whisparr.

**Response:**
```json
{
  "restarting": true
}
```

### POST /api/v3/system/shutdown
Shutdown Whisparr.

**Response:**
```json
{
  "shuttingDown": true
}
```

---

## 13. CONFIGURATION

### GET /api/v3/config/host
Get host configuration.

**Response:** Host config object

### PUT /api/v3/config/host
Update host configuration.

**Request Body:** Host config object

**Response:** Updated config

### GET /api/v3/config/naming
Get file naming configuration.

**Response:** Naming config object

### PUT /api/v3/config/naming
Update file naming configuration.

**Request Body:** Naming config object

**Response:** Updated config

### GET /api/v3/config/mediamanagement
Get media management configuration.

**Response:** Media management config

### PUT /api/v3/config/mediamanagement
Update media management configuration.

**Request Body:** Media management config

**Response:** Updated config

### GET /api/v3/config/ui
Get UI configuration.

**Response:** UI config object

### PUT /api/v3/config/ui
Update UI configuration.

**Request Body:** UI config object

**Response:** Updated config

---

## 14. QUALITY PROFILES

### GET /api/v3/qualityprofile
Get all quality profiles.

**Response:** Array of quality profile objects

### GET /api/v3/qualityprofile/{id}
Get specific quality profile by ID.

**Path Parameters:**
- `id` (int, required): Quality profile ID

**Response:** Quality profile object

### POST /api/v3/qualityprofile
Create a new quality profile.

**Request Body:** Quality profile configuration

**Response:** Created quality profile with ID

### PUT /api/v3/qualityprofile/{id}
Update a quality profile.

**Path Parameters:**
- `id` (int, required): Quality profile ID

**Request Body:** Updated quality profile

**Response:** Updated quality profile

### DELETE /api/v3/qualityprofile/{id}
Delete a quality profile.

**Path Parameters:**
- `id` (int, required): Quality profile ID

**Response:** 200 OK

---

## 15. TAGS

### GET /api/v3/tag
Get all tags.

**Response:** Array of tag objects

### GET /api/v3/tag/{id}
Get specific tag by ID.

**Path Parameters:**
- `id` (int, required): Tag ID

**Response:** Tag object

### POST /api/v3/tag
Create a new tag.

**Request Body:**
```json
{
  "label": "Tag Name"
}
```

**Response:** Created tag with ID

### PUT /api/v3/tag/{id}
Update a tag.

**Path Parameters:**
- `id` (int, required): Tag ID

**Request Body:**
```json
{
  "id": 1,
  "label": "Updated Tag Name"
}
```

**Response:** Updated tag

### DELETE /api/v3/tag/{id}
Delete a tag.

**Path Parameters:**
- `id` (int, required): Tag ID

**Response:** 200 OK

---

## 16. LOGS

### GET /api/v3/log
Get application logs.

**Query Parameters:**
- `page` (int, optional): Page number
- `pageSize` (int, optional): Items per page
- `sortKey` (string, optional): Sort field
- `sortDirection` (string, optional): Sort direction
- `level` (string, optional): Filter by log level

**Response:** Paginated log entries

### GET /api/v3/log/file
Get log files.

**Response:** Array of log file names

---

## 17. HEALTH

### GET /api/v3/health
Get system health checks.

**Response:** Array of health check objects

**Example Response:**
```json
[
  {
    "source": "IndexerStatusCheck",
    "type": "warning",
    "message": "Indexer unavailable: Indexer Name",
    "wikiUrl": "https://wiki.servarr.com/..."
  }
]
```

---

## 18. BLOCKLIST

### GET /api/v3/blocklist
Get blocklisted releases.

**Query Parameters:**
- `page` (int, optional): Page number
- `pageSize` (int, optional): Items per page
- `sortKey` (string, optional): Sort field
- `sortDirection` (string, optional): Sort direction

**Response:** Paginated blocklist entries

### DELETE /api/v3/blocklist/{id}
Remove from blocklist.

**Path Parameters:**
- `id` (int, required): Blocklist ID

**Response:** 200 OK

---

## Event Types

### MovieHistoryEventType
- `0` - Unknown
- `1` - Grabbed
- `2` - MovieFileImported
- `3` - DownloadFailed
- `4` - MovieFileDeleted
- `5` - MovieFileRenamed
- `6` - DownloadIgnored

---

## Common Query Parameters

### Pagination
- `page`: Page number (1-indexed)
- `pageSize`: Number of items per page
- `sortKey`: Field to sort by
- `sortDirection`: "ascending" or "descending"

### Filtering
Most list endpoints support filtering via query parameters specific to that resource type.

---

## Error Responses

All error responses follow this format:

```json
{
  "message": "Error description",
  "description": "Detailed error information"
}
```

**HTTP Status Codes:**
- `200` - Success
- `201` - Created
- `204` - No Content
- `400` - Bad Request
- `401` - Unauthorized
- `404` - Not Found
- `409` - Conflict
- `500` - Internal Server Error

---

## Notes

- All dates are in ISO 8601 format
- IDs are integers
- File sizes are in bytes
- Durations are in seconds or TimeSpan format
- Quality IDs map to predefined quality definitions
- Language IDs map to language definitions

---

## Implementation Guide: iOS App Patterns

### Movie Root Folder Move - Code Architecture

The iOS Stash app implements the root folder move workflow with the following components:

**View Layer (MovieEditView):**
```swift
// Capture original state at init
@State private var unmodifiedMovie: Movie
init(movie: Binding<Movie>) {
    self._movie = movie
    self._unmodifiedMovie = State(initialValue: movie.wrappedValue)
}

// Detect changes in Save button
Button {
    if movie.exists && hasRootFolderChanged() {
        showConfirmation = true  // Show confirmation alert
    } else {
        Task { await updateMovie() }  // Skip dialog
    }
}

// Confirmation Alert
.alert(
    "Move the movie files to \"\(movie.rootFolderPath ?? \"\")\"?",
    isPresented: $showConfirmation
) {
    Button("Move Files", role: .destructive) {
        Task { await updateMovie(moveFiles: true) }
    }
    Button("No") {
        Task { await updateMovie(moveFiles: false) }
    }
    Button("Cancel", role: .cancel) { }
}
```

**Change Detection:**
```swift
func hasRootFolderChanged() -> Bool {
    movie.rootFolderPath?.untrailingSlashIt != 
    unmodifiedMovie.rootFolderPath?.untrailingSlashIt
}
```

**State Restoration on Dismiss:**
```swift
.onDisappear {
    if !savedChanges {
        undoMovieChanges()  // Restore original values
    }
}
```

**API Call:**
```swift
func updateMovie(moveFiles: Bool = false) async {
    let success = await instance.movies.update(movie, moveFiles: moveFiles)
    if success {
        savedChanges = true
        dismiss()
    }
}
```

**Repository/API Layer:**
```swift
// Movies.swift
func update(_ movie: Movie, moveFiles: Bool = false) async -> Bool {
    await request(.update(movie, moveFiles))
}

private func performOperation(_ operation: Operation) async throws {
    case .update(let movie, let moveFiles):
        _ = try await dependencies.api.updateMovie(movie, moveFiles, instance)
}
```

### Key Design Patterns

1. **State Capture Pattern**: Original values are captured at view init, not during the edit
2. **Change Detection Pattern**: Compare edited values against captured originals
3. **Confirmation Dialog Pattern**: Only show for destructive operations when state actually changed
4. **Undo Pattern**: If user dismisses without saving, automatically restore original state
5. **Error Handling Pattern**: If API fails, stay in the form allowing retry

### Benefits

- **Safety**: User explicitly confirms before destructive file moves
- **Simplicity**: Dialog only appears when necessary
- **Resilience**: Original state preserved until explicitly saved
- **Flexibility**: User can choose to move files or just update metadata

---

## Additional Resources

- GitHub: https://github.com/Whisparr/Whisparr
- Wiki: https://wiki.servarr.com/whisparr
- Discord: https://discord.gg/whisparr
