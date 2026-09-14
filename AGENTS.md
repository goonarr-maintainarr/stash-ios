# AI Agent Maintenance Guide (stash-ios)

This document provides orientation, architecture patterns, command references, and maintenance rules for AI agents maintaining this repository.

---

## 1. Project Overview & Architecture

- **Platform**: iOS 18.0+, iPadOS 18.0+, macOS Catalyst.
- **Language**: Swift 6.0 with Swift Concurrency (`async/await`, `@MainActor`, `Sendable`).
- **UI Framework**: SwiftUI with iOS 18 zoom transitions and interactive gestures.
- **Architecture**: MVVM with Repository Pattern & Decomposed Manager classes.
- **State Management**: Swift Observation framework (`@Observable`, `@Bindable`).
- **Persistence**: GRDB (SQLite) with reactive database observations.
- **Network**: URLSession + GraphQL client for Stash API, SignalR WebSocket client for Whisparr.
- **Video Player**: AVKit / AVPlayer with Picture-in-Picture floating mini-player.

---

## 2. Directory Layout

```
Stash/
├── App/                # App entrypoint & theme definitions
├── Core/
│   ├── Extensions/     # Foundation & Swift extensions (Array+Sorting, URL+WebSocket)
│   ├── Networking/     # GraphQL queries, StashClient, StashDBClient, SignalR
│   ├── Persistence/    # GRDB AppDatabase, StashDatabase, WhisparrDatabase
│   ├── Services/       # Subscription service, floating player, image prefetch
│   └── Utilities/      # DateFormatters, HapticManager, VTTParser
├── DI/                 # Dependency container, SettingsStore
├── Domain/             # Models, DTOs, Enums, Protocols
└── Presentation/       # Features (Home, Scenes, Performers, Studios, Whisparr, Settings)
StashTests/             # 51 test suites (348 unit tests) using XCTest
```

---

## 3. Essential Maintenance Commands

### Xcodebuild Commands
```bash
# Build the application
xcodebuild build -project Stash.xcodeproj -scheme Stash -destination 'generic/platform=iOS'

# Run unit tests (in Xcode, select Stash scheme and press ⌘U)
# Note: CLI testing requires simulator runtime matching current Xcode base SDK:
xcodebuild test -project Stash.xcodeproj -scheme Stash -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:StashTests
```

### Adding New Test Files
`StashTests` is configured with `PBXFileSystemSynchronizedRootGroup`.
Any `.swift` file added inside `StashTests/` is automatically included in the test target without modifying `project.pbxproj`.

---

## 4. Key Implementation Rules & Invariants

1. **Zero PII Policy**:
   - Never commit personal names, real email addresses, internal IP addresses (`192.168.x.x`), private tokens, or Apple Developer Team IDs (`DEVELOPMENT_TEAM`).
   - Use placeholder URLs like `https://stash.example.com` or `Secrets.serverUrl`.
2. **Swift Concurrency & Actor Isolation**:
   - ViewModels and UI managers must be marked `@MainActor`.
   - Background repositories and parsers should conform to `Sendable` or be `nonisolated`.
3. **Observation vs Legacy Combine**:
   - Prefer `@Observable` over `ObservableObject` / `@Published` for new ViewModels.
4. **Test Coverage Invariants**:
   - When adding or modifying models, formatters, or managers, add corresponding tests in `StashTests/`.
   - Use `TestData.swift` extensions (`Scene.testScene()`, `Performer.testPerformer()`, `Stats.testStats()`) for test data creation.
5. **Git Commit Hygiene**:
   - Use Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `refactor:`).
   - Maintain author identity: `Goonarr Maintainers <maintainers@goonarr.dev>`.
