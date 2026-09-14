# Stash iOS

A native iOS client for [Stash](https://stashapp.cc/), built with SwiftUI and featuring deep integration with Whisparr and StashDB. Provides a modern, feature-rich interface for browsing, managing, and streaming content from your Stash media server.

[![iOS CI](https://github.com/goonarr-maintainarr/stash-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/goonarr-maintainarr/stash-ios/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/goonarr-maintainarr/stash-ios)](https://github.com/goonarr-maintainarr/stash-ios/releases/latest)
[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-18.0+-blue.svg)](https://www.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/goonarr-maintainarr/stash-ios.git
cd stash-ios

# Open in Xcode
open Stash.xcodeproj

# Build and run (⌘R)
```

**Configure your server:**
1. Launch the app → Navigate to **Settings**
2. Enter your Stash server URL (e.g., `http://stash.local:9999/graphql` or `https://stash.example.com/graphql`)
3. Enter your API key (generate from Stash → Settings → Security)
4. Tap **Test Connection**

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Configuration](#configuration)
- [Architecture](#architecture)
- [Core Systems](#core-systems)
- [UI Components](#ui-components)
- [Testing](#testing)
- [Contributing](#contributing)
- [FAQ](#faq)
- [License](#license)

---

## Features

### 🎬 Media Management
- **Scene Browsing**: Paginated browsing with multiple layout modes (List, Compact, Grid), instant search, multi-column sorting, and deep tag/performer/studio filters.
- **Scene Detail & Markers**: Full metadata viewer, inline editing (rating, favorite, O-counter increment), marker timeline navigation, and StashDB scraping.
- **Interactive Scrubber**: Long-press thumbnail scrubbing with VTT sprite sheets, preview frame extraction, and haptic feedback.
- **Video Playback**: Native AVPlayer streaming with Picture-in-Picture (PiP), playback position resume tracking, and orientation-aware fullscreen controls.
- **Performer Profiles**: Complete biography display, aliases, career statistics, external links, gallery views, and StashDB cross-referencing.
- **Studio Hierarchies**: Studio browsing with parent/sub-studio hierarchy navigation, related scenes, and metadata scraping.
- **Tag Organization**: Comprehensive tag list, category filtering, and customizable followed tags.

### 🎯 Content Discovery
- **Home Dashboard**: Netflix-style horizontal carousels (Recently Added, Top Rated, Followed Tags, and Studio Spotlights).
- **Smart Categories**: Sort-based and tag-based discovery rows with user-customizable ordering.
- **iOS 18 Zoom Transitions**: Fluid card-to-detail animations powered by SwiftUI `matchedTransitionSource` and `.navigationTransition(.zoom)`.
- **Haptic & Spring Feedback**: Interactive feedback on buttons, cards, and scrubbing.

### 🔄 Integrations & Server Tools
- **Whisparr Deep Integration**: Real-time scene status updates via SignalR notifications, download queue & history management, and manual release search/matching.
- **StashDB Metadata Scraping**: Direct querying and automatic scraping of scenes, performers, and studios into your local Stash server.
- **Server Maintenance**: Trigger Stash library scans and generate metadata (covers, previews, sprites, markers, and transcodes) directly from Settings.

### ⚙️ Technical Highlights
- **Swift 6 Concurrency**: Full `async/await`, structured concurrency, and `@MainActor` state isolation.
- **@Observable Architecture**: Built on Swift Observation framework (no legacy Combine boilerplate).
- **GRDB Persistence**: Actor-isolated SQLite database layer with automated caching.
- **Nuke Image Pipeline**: Two-tier caching (150MB LRU memory + disk cache) with prefetching during scroll.

---

## Requirements

| Requirement | Version |
|-------------|---------|
| **iOS** | 18.0+ |
| **Xcode** | 16.0+ |
| **Swift** | 6.0+ |
| **Stash Server** | 0.24+ with GraphQL API enabled |
| **Whisparr** (Optional) | v3 API |
| **StashDB** (Optional) | API key for metadata enrichment |

---

## Configuration

### Server Settings

| Setting | Description | Example |
|---------|-------------|---------|
| **Stash URL** | GraphQL endpoint URL | `http://stash.local:9999/graphql` |
| **API Key** | Authentication token | Generate in Stash → Settings → Security |
| **Whisparr URL** | Whisparr server URL | `http://whisparr.local:8787` |
| **Whisparr API Key** | Whisparr authentication | Settings → General → API Key |
| **StashDB API Key** | StashDB authentication | [stashdb.org](https://stashdb.org) account |

### App Settings

| Setting | Description | Default |
|---------|-------------|---------|
| **NSFW Blur** | Blur thumbnails until tapped | Off |
| **Scene Previews** | Enable long-press video previews | On |
| **Cache TTL** | Local cache duration | 12 hours |
| **Page Size** | Items per page load | 40 |

---

## Architecture

### Layer Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                       │
│  SwiftUI Views, @Observable ViewModels, Managers             │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│                      DOMAIN LAYER                            │
│  Repositories, Services, Domain Models                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│                       CORE LAYER                             │
│  Networking, Persistence, Utilities                          │
└─────────────────────────────────────────────────────────────┘
```

### ViewModel Pattern

All ViewModels use **Swift Observation** (`@Observable`) with encapsulated state:

```swift
@MainActor
@Observable
final class SceneListViewModel {
    private(set) var listState = ListState<Scene>()
    
    var scenes: [Scene] { listState.displayedItems }
    var isLoading: Bool { listState.isLoading }
    
    private let repository: any SceneRepositoryProtocol
    
    func fetchItems(reset: Bool = false) async { ... }
}
```

### Manager Pattern

Complex ViewModels delegate to focused Manager classes:

```swift
@Observable
final class SceneDetailViewModel {
    private let dataManager: SceneDataManager        // Fetching
    private let playerManager: ScenePlayerManager    // AVPlayer
    private let scrapingManager: SceneScrapingManager // StashDB
}
```

### Repository Pattern

Repositories coordinate specialized services:

```swift
class SceneRepository: SceneRepositoryProtocol {
    private let cacheService: SceneCacheService
    private let fetchService: SceneFetchService
    private let mutationService: SceneMutationService
}
```

---

## Core Systems

### Networking

- **StashClient**: GraphQL with automatic retry and exponential backoff
- **WhisparrClient**: Full Whisparr v3 REST API (30+ endpoints)
- **StashDBClient**: StashDB GraphQL for metadata lookup

### Persistence

Actor-based GRDB SQLite:

| Table | Purpose | TTL |
|-------|---------|-----|
| `scenes` | Scene list cache | 12h |
| `scene_details` | Full scene data | 12h |
| `performers` | Performer cache | 12h |

### Image Caching

Nuke pipeline with:
- 150MB memory cache (LRU)
- Unlimited disk cache
- Automatic prefetching on scroll

---

## UI Components

### Scene Scrubbing

Long-press bottom 25% of thumbnail → drag to scrub through VTT sprites:

1. VTT parser extracts sprite coordinates
2. SpriteManager caches cropped frames
3. Haptic feedback on frame changes
4. Release navigates to scrubbed time

### Zoom Transitions

iOS 18 matched geometry transitions:

```swift
SceneCard(scene: scene)
    .matchedTransitionSource(id: scene.id, in: zoomTransition)

.navigationDestination(for: Scene.self) {
    SceneDetailView(...)
        .navigationTransition(.zoom(sourceID: $0.id, in: zoomTransition))
}
```

---

## Testing

```bash
# Run all tests
xcodebuild test -project Stash.xcodeproj -scheme Stash \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# In Xcode: ⌘U
```

Test structure:
```
StashTests/
├── Mocks/           # Protocol implementations
├── ViewModels/      # ViewModel unit tests
├── Repositories/    # Repository tests
└── Services/        # Service tests
```

---

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Quick Links
- [Open Issues](https://github.com/goonarr-maintainarr/stash-ios/issues)
- [Pull Requests](https://github.com/goonarr-maintainarr/stash-ios/pulls)
- [Discussions](https://github.com/goonarr-maintainarr/stash-ios/discussions)

---

## FAQ

### Connection Issues

**Q: "Connection failed" when testing server**

A: Verify:
- Server URL includes `/graphql` path
- API key is correct (regenerate in Stash if needed)
- Device is on same network as server
- Stash server is running and accessible

**Q: Images not loading**

A: Check:
- Server URL is HTTP (not HTTPS) for local servers
- Clear image cache in Settings → Clear Cache

### Performance

**Q: App feels slow on first load**

A: Initial sync downloads scene metadata. Subsequent loads use local cache (12h TTL).

**Q: High memory usage**

A: Clear image cache in Settings. The app caches thumbnails for fast scrolling.

### Whisparr

**Q: Whisparr scenes not syncing**

A: Ensure:
- Whisparr URL doesn't have trailing slash
- API key has full permissions
- Tap "Sync Library" to force refresh

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- [**Stash**](https://stashapp.cc/) - Open-source media server
- [**Whisparr**](https://whisparr.com/) - Download automation
- [**StashDB**](https://stashdb.org/) - Metadata database
- [**Nuke**](https://github.com/kean/Nuke) - Image loading
- [**GRDB**](https://github.com/groue/GRDB.swift) - SQLite toolkit

---

**Built with ❤️ for the Stash community**
