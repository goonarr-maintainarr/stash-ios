# Bug Reports

This document tracks known issues and bugs in the Stash iOS application.

---

## [BUG-001] Scraped Performers Not Applying to Scenes

**Date Reported:** 2025-12-23
**Date Fixed:** 2025-12-26
**Status:** Fixed
**Severity:** High
**Category:** Metadata / Scraping

### Fix Summary
- Added `stored_id` field to `ScrapedPerformer` model to use server-provided IDs
- Updated `resolvePerformerIds` to use `stored_id` first, with fuzzy matching fallback
- Added logging for unresolved performers

### Description
When scraping a scene and assigning performers, the UI and logs indicate a successful operation ("Applied scrape results"), but the performers are not added to the scene. Other metadata (tags, title, etc.) applies correctly.

### Symptoms
- Assigning a performer from a scrape result appears to work, but the performer is not added to the scene.
- Other scraped metadata (tags, title, date, etc.) applies successfully.
- App logs show success: `✅ Applied scrape results to scene`.
- Subsequent refreshes of the scene do not show the newly assigned performers.

### Suspected Root Causes
1. **Performer Resolution Failure:** The `SceneScrapeService` resolves performers by exact name match only. If the performer name returned by the scraper doesn't exactly match the name in the local Stash database, the ID is not resolved, and an empty list is sent to the server.
2. **Silent Failure in Resolve:** If performer resolution fails, the code continues to the mutation with an empty/incomplete list instead of notifying the user or attempting to create the performer.
3. **Cache Invalidation Issue:** The service performs a mutation and then executes a fresh fetch. If the subsequent `findScene` query returns a cached response from the server or local network layer, the newly applied changes are not reflected in the UI.
4. **DTO Decoding Limitation:** The `UpdateResult` internal struct in `SceneScrapeService.applyScrapeResult` only decodes the `id` from the mutation response, discarding the full updated scene data returned by the server.

### Reproduction Steps
1. Open a scene that is missing performers/tags.
2. Tap "Scrape Scene" and select a StashBox source.
3. Select a result and navigate to the "Review Changes" screen.
4. Toggle "Use Performers" and/or "Use Tags".
5. Apply the changes (checkmark icon).
6. Observe that the scene detail view returns but does not show the new performers/tags.

### Proposed Fixes
- **Use Mutation Result:** Update `SceneScrapeService.applyScrapeResult` to decode and return the `Scene` object returned by the `sceneUpdate` mutation rather than re-fetching.
- **Improve Resolution:** Enhance `resolvePerformerIds` to use fuzzy matching or alias lookups.
- **Merge Improvements:** Ensure that if `fetchService.getScene` fails during merging, it doesn't silently skip the update.
- **User Feedback:** Warn the user if some performers could not be resolved locally.

---

## [BUG-002] Whisparr Queue UI Flashing

**Date Reported:** 2025-12-23
**Status:** Open
**Severity:** Medium
**Category:** UI / Performance

### Description
The Whisparr Downloads screen (Activity View) exhibits significant "flashing" or flickering while downloads are active. The list header and rows appear to re-render or shift constantly.

### Symptoms
- The loading spinner in the "Tasks" header appears and disappears every 1-2 seconds.
- Row contents (progress percentages, time remaining) update so frequently that the UI feels unstable.
- Performance impact on the device due to constant network requests and UI invalidation.

### Suspected Root Causes
1. **Excessive Polling Frequency:** `WhisparrQueueManager` uses a 1-second polling interval for active queues. Combined with network latency, this leads to a near-constant "loading" state.
2. **Aggressive `isLoading` Toggles:** The `fetchQueue` method sets `isLoading = true` at the start of every network request. Because requests happen every second, the UI is in a constant state of transitioning between loading and idle.
3. **Inefficient `Equatable` Check:** The manager checks `self.items != queueItems` before updating the UI. However, `WhisparrQueueItem` includes fields like `sizeleft` and `timeleft` which change with every byte downloaded. This makes the "Smart Update" check always true, forcing a full SwiftUI list refresh every second.
4. **Redundant Server Commands:** The manager calls `whisparrClient.refreshDownloads` before every queue fetch. This server-side command triggers Whisparr to scan all download clients, which is an expensive operation to perform every second.

### Reproduction Steps
1. Add a scene to Whisparr and ensure it starts downloading.
2. Navigate to the "Downloads" tab in the app.
3. Observe the "Tasks" header and the list rows.
4. Note the flickering of the loading spinner and the constant refreshes.

### Proposed Fixes
- **Increase Polling Interval:** Slow down active polling to 5-10 seconds.
- **Background Refresh Quietly:** Remove the `isLoading` toggle for background polling; only show it for intentional user-initiated refreshes (pull-to-refresh).
- **Throttle UI Updates:** Only publish changes to the `items` array if significant data has changed (e.g., status change or significant progress jump) or use a timer to throttle updates to 2Hz.
- **Optimize Server Interaction:** Only call `refreshDownloads` occasionally (e.g., every 30-60 seconds) rather than before every queue fetch.

---

## [BUG-003] App Crashes on Network Loss

**Date Reported:** 2025-12-23
**Status:** Open
**Severity:** Critical
**Category:** Stability / Networking

### Description
The application consistently crashes when network connectivity is lost (e.g., switching to Airplane Mode, disabling WiFi, or moving out of cellular range).

### Symptoms
- Immediate termination of the app when networking state changes to disconnected.
- Logs may indicate unhandled `URLError` or force-unwraps failing in network callback closures.

### Suspected Root Causes
1. **Force Unwrapping URLs:** Some services might force-unwrap the server URL from settings during a background fetch without checking if it's still accessible or valid.
2. **WebSocket Handshake Failure:** `GraphQLWebSocketClient` might throw an unhandled exception if the socket is interrupted while sending a message or heartbeats.
3. **Infinite Retry Loops:** Overly aggressive retry logic without proper `Task` cancellation handling might lead to a crash if the app attempts to re-fetch too rapidly on a dead connection.
4. **Concurrency Edge Cases:** Async tasks that finish after the connection is lost might attempt to force-decode invalid or empty data chunks.

### Reproduction Steps
1. Open the app and ensure it is connected to a Stash instance.
2. Initiate a network-heavy view (e.g., Scene List or Home sections).
3. Switch the device to Airplane Mode.
4. Observe the app's behavior (it should crash shortly after).

### Proposed Fixes
- **Audit Force Unwraps:** Replace all `!` on URLs and Configuration objects with safe `guard let` or `if let` checks.
- **Improve Error Handling in Loops:** Wrap the background polling tasks in `WhisparrQueueService` and `SyncService` with more robust network-specific check-ins.
- **WebSocket Resilience:** Ensure `GraphQLWebSocketClient` gracefully handles `notConnectedToInternet` errors without propagating fatal exceptions.
- **Reachability Monitoring:** Implement a reachability observer to pause background networking tasks when the connection is lost.
---

## [BUG-004] Scene Scraper Hangs (Infinite Loading)

**Date Reported:** 2025-12-23
**Status:** Open
**Severity:** High
**Category:** Metadata / Scraping

### Description
When initiating a scene scrape by selecting a StashBox source, the application displays the "Scraping Scene..." loading spinner indefinitely. No results are ever returned, and no error message is shown to the user.

**Note:** This issue primarily affects **newly added scenes**. Older scenes that have been in the library longer seem to scrape successfully, suggesting a potential dependency on cached metadata or a race condition with recent imports.

### Symptoms
- Selecting a scraper from the "Scrape Scene" list triggers the loading overlay.
- The spinner stays on screen for minutes without timing out or advancing.
- The only way to exit is to dismiss the sheet/view manually.
- No network error is displayed, suggesting the request might be hanging or the response is being silently ignored.

### Suspected Root Causes
1. **Query vs. Mutation Mismatch:** The `StashQueries.scrapeSingleScene` is defined as a `query` in the codebase, but the `SceneScrapeService` implementation refers to it as a "mutation." If the Stash server requires this specific operation to be a GraphQL mutation, the request may fail or hang.
2. **Missing Scraper ID:** The `scrapeScene` method currently passes `nil` for the `scraperId`. While it provides the StashBox endpoint, some configurations require a specific scraper ID to be selected from the source.
3. **Input Schema Incompatibility:** The `ScrapeSingleSceneInput` variable being sent contains only a `query` field. Some versions of Stash require additional fields or a different structure (e.g., `scene_index`, `scraped_item`) in the input object to process the request correctly.
4. **Silent API Error Handle:** If the API returns a 200 OK but with a `null` data field or non-standard error structure, the `fetchWithErrorWrapping` might not be catching it correctly, leaving the UI state in `isScraping = true` forever.
5. **Cache/State Dependency:** Since older scenes work and newer ones don't, there may be a dependency on the `scenes` or `scene_details` database tables being fully populated before a scrape can initiate. If the scene is so new that its details aren't fully indexed or cached locally, the scraper logic might be failing to resolve identifiers.

### Reproduction Steps
1. Navigate to a Scene Detail view.
2. Tap the "Scrape" button (from the menu or detail actions).
3. Select a configured StashBox source (e.g., "StashDB").
4. Observe the infinite loading spinner.

### Proposed Fixes
- **Audit GraphQL Operation:** Verify if `scrapeSingleScene` should be a `mutation` and update `StashQueries.swift` accordingly.
- **Improved Input Validation:** Log the exact GraphQL variables being sent to ensure they match the server's expected `ScrapeSingleSceneInput` schema.
- **Add Request Timeout UI:** Implement a UI-level timeout that reverts the loading state if no response is received within 30-60 seconds.
- **Handle Null Results:** Ensure `SceneDetailViewModel` handles cases where `sceneRepository.scrapeScene` returns an empty array or `nil` by showing a "No results found" message instead of stuck loading.
