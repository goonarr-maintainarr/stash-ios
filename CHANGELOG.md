# Changelog

All notable changes to Stash iOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- iOS 18 zoom transitions for scene navigation
- **Performer zoom transitions** on Home page cards
- Scene thumbnail scrubbing with VTT sprite support
- Bounce animations on tap interactions
- Floating video player with PiP support
- StashDB favorites integration on Home page
- **Top Performers row** on Home page
- Studio list with shimmer loading states

### Changed
- Migrated ViewModels from `ObservableObject` to `@Observable` macro
- Refactored to `ListState<T>` for unified pagination state
- Updated minimum iOS version to 18.0

### Fixed
- Scene list pagination stability
- Pull-to-refresh no longer shows full-screen shimmer
- Sort persistence across app restarts

---

## [1.0.0] - 2025-01-01

### Added
- Initial release
- Scene browsing with pagination, search, and sorting
- Scene detail view with metadata editing
- Video playback with resume time tracking
- Performer browsing and detail views
- Tag-based filtering and followed tags
- Whisparr integration (library sync, queue monitoring)
- StashDB metadata scraping
- Home page with category carousels
- GRDB-based local caching (12-hour TTL)
- Nuke image caching
- WebSocket subscriptions for job updates
- Dark theme optimized for media viewing
