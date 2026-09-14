# Testing Setup Instructions

## What I've Created

✅ **Mock Implementations:**
- `MockGraphQLClient.swift` - Returns test data instead of making network calls
- `MockSettingsStore.swift` - Controlled test environment

✅ **Test Utilities:**
- `TestData.swift` - Factory methods for creating test objects

✅ **Unit Tests:**
- `SceneListViewModelTests.swift` - 8 comprehensive tests
- `PerformerListViewModelTests.swift` - 6 comprehensive tests

---

## Next Steps (In Xcode)

### 1. Create Test Target
1. Open `Stash.xcodeproj` in Xcode
2. File → New → Target
3. Select "Unit Testing Bundle"
4. Name it `StashTests`
5. Click Finish

### 2. Add Test Files to Target
1. In Project Navigator, find the `StashTests` folder (filesystem)
2. Drag the `StashTests` folder into Xcode
3. When prompted:
   - ✅ Check "Copy items if needed"
   - ✅ Select "Create groups"
   - ✅ Add to target: `StashTests`

### 3. Configure Test Target
1. Select the `Stash` project in Project Navigator
2. Select `StashTests` target
3. Go to "Build Phases"
4. Ensure all `.swift` files are in "Compile Sources"
5. Go to "Build Settings"
6. Set "Code Coverage" to YES

### 4. Run Tests
- Press `⌘U` or Product → Test
- All tests should pass ✅

---

## Test Coverage

**SceneListViewModel:**
- ✅ Successful fetch
- ✅ Error handling
- ✅ Empty results
- ✅ Pagination (next page)
- ✅ Pagination (all loaded)
- ✅ Concurrent fetch prevention
- ✅ Search functionality
- ✅ Sort persistence

**PerformerListViewModel:**
- ✅ Successful fetch
- ✅ Error handling
- ✅ Pagination
- ✅ Search functionality
- ✅ Sort persistence

---

## Troubleshooting

**If tests don't appear:**
- Check that files are added to `StashTests` target
- Clean build folder: Product → Clean Build Folder (⇧⌘K)
- Rebuild: ⌘B

**If tests fail:**
- Check that `@testable import Stash` works
- Verify mock data is set up correctly
- Check that test target has access to app code
