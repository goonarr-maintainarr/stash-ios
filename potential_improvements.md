# Potential Improvements & Technical Debt

This document tracks architectural improvements and modernization opportunities for the Stash iOS app. It is intended to persist across development sessions.

---

## 🏗️ High Priority: Architecture & Cleanup

### 1. List State Consolidation (Generic `ListState<T>`)
**Impact:** High | **Effort:** Medium
Consolidate duplicated logic in `SceneListViewModel`, `PerformerListViewModel`, `StudioListViewModel`, and `WhisparrSceneListViewModel`.

**Plan:**
1.  Create `struct ListState<Item>: Sendable`.
2.  Move `items`, `displayedItems`, `currentPage`, `searchText` properties here.
3.  Move `appendPage()`, `updateContent()`, `updateItemInPlace()` logic here.
4.  Update ViewModels to hold a `var state = ListState<Model>()` property.

**Benefit:** Deletes ~500 lines of duplicate code; fixes pagination/search bugs in one place.

### 2. Modernize App Launch (`MainTabView`)
**Impact:** Medium | **Effort:** Low
Refactor the legacy `ViewModelFactory` pattern in `MainTabView`.

**Plan:**
1.  Remove `class ViewModelFactory: ObservableObject`.
2.  Use `@State` to initialize ViewModels directly in `MainTabView`.
3.  Inject dependencies via `DependencyContainer`.

**Benefit:** Simplifies app graph; aligns with iOS 17+ best practices.

### 3. Unified Image Prefetching
**Impact:** Medium | **Effort:** Low
Consistent "upcoming image" prefetching across all lists (Scenes, Performers).

**Plan:**
1.  Define protocol `PrefetchableRepository`.
2.  Add `prefetchUpcomingImages(from index: Int)` helper in `ListViewModel` (or equivalent).
3.  Ensure `loadMore()` triggers this prefetch.

**Benefit:** Eliminates image "pop-in" during fast scrolling.

---

## 🛠️ Medium Priority: Maintenance & Swift 6

### 4. Swift 6 Strict Concurrency
**Impact:** Medium | **Effort:** Medium
Prepare for Swift 6 compiler mode.

**Tasks:**
- [ ] Audit `Task { ... }` calls; ensure they are cancelled on `deinit` or view disappearance.
- [ ] Verify `Sendable` conformance for all Domain models.
- [ ] Enable `SWIFT_STRICT_CONCURRENCY` in build settings to identify issues.

### 5. Remove Combine
**Impact:** Low | **Effort:** Low
Remove residual Combine imports now that `@Observable` is adopted.

**Locations:**
- `DatabaseObservable.swift`
- Various ViewModels still importing `Combine`.

---

## 🧪 Testing

### 6. ViewModel Unit Tests
**Impact:** High (Long term) | **Effort:** Medium
Add basic unit tests for the core ViewModels.

**Focus:**
- `HomeViewModel` (Category loading)
- `SceneListViewModel` (Pagination logic)

---

> _Last Updated: 2025-12-31_
