# Error Handling Guide

## Overview

This project uses a **standardized, layered error handling system** defined in `AppError.swift`. All errors flow through a unified `AppError` type for consistent handling across the application.

## Architecture

```
┌─────────────────────────────────────┐
│          AppError (Root)            │
│  - User-friendly messages           │
│  - Technical details                │
│  - Recovery suggestions             │
│  - Retry logic                      │
└─────────────────────────────────────┘
                 ▲
                 │
    ┌────────────┼────────────┐
    │            │            │
┌───▼────┐  ┌───▼───┐  ┌────▼────┐
│Network │  │  DB   │  │  Repo   │
│Error   │  │ Error │  │  Error  │
└────────┘  └───────┘  └─────────┘
    │            │            │
┌───▼────┐  ┌───▼───┐  ┌────▼────┐
│ Stash  │  │Whisparr│ │StashDB  │
│API Err │  │API Err │ │API Err  │
└────────┘  └────────┘ └─────────┘
```

## Error Types

### 1. NetworkError
Low-level network failures:
```swift
enum NetworkError {
    case noConnection           // No internet
    case timeout                // Request timed out
    case invalidURL(String)     // Malformed URL
    case httpError(statusCode: Int, response: Data?)
    case encodingFailed         // Request encoding failed
    case decodingFailed(Error)  // Response parsing failed
    case cancelled              // Request cancelled
    case unknown(URLError)      // Other network error
}
```

### 2. DatabaseError
Local persistence issues:
```swift
enum DatabaseError {
    case notInitialized         // DB not ready
    case migrationFailed(String)
    case queryFailed(String)
    case corruptedData(String)
    case diskFull
}
```

### 3. RepositoryError
Data layer business logic:
```swift
enum RepositoryError {
    case invalidConfiguration   // Bad app config
    case notFound               // Item doesn't exist
    case alreadyExists          // Duplicate
    case concurrencyConflict    // Race condition
    case syncFailed(String)     // Sync issue
}
```

### 4. API-Specific Errors
```swift
enum StashAPIError {
    case invalidResponse
    case graphQLErrors([String])
    case unauthorizedAPIKey
    case networkError(NetworkError)
}

enum WhisparrAPIError {
    case invalidResponse
    case notFound
    case unauthorizedAPIKey
    case validationErrors([WhisparrValidationError])
    case networkError(NetworkError)
}

enum StashDBError {
    case invalidResponse
    case unauthorizedAPIKey
    case rateLimited
    case networkError(NetworkError)
}
```

### 5. ValidationError
User input validation:
```swift
enum ValidationError {
    case emptyField(String)
    case invalidFormat(String)
    case outOfRange(String, min: Int?, max: Int?)
    case custom(String)
}
```

## Usage by Layer

### In Network Clients (StashClient, WhisparrClient, etc.)

**Always throw specific API errors:**

```swift
// ❌ OLD WAY - Generic errors
throw StashError.httpError(statusCode: statusCode)

// ✅ NEW WAY - Specific, structured errors
throw StashAPIError.networkError(.httpError(statusCode: statusCode, response: data))

// ✅ GraphQL errors
throw StashAPIError.graphQLErrors(errorMessages)

// ✅ Auth errors
throw StashAPIError.unauthorizedAPIKey
```

### In Repositories

**Convert client errors to AppError and add context:**

```swift
func getScene(id: String) async throws -> Scene {
    let url = try validateConfiguration() // Throws RepositoryError.invalidConfiguration
    
    do {
        let result: SceneResult = try await apiClient.fetch(...)
        
        if let scene = result.scene {
            return scene
        } else {
            throw AppError.notFound("Scene")
        }
        
    } catch let error as StashAPIError {
        // Wrap API error in AppError
        throw AppError.stashAPI(error)
    } catch let error as URLError {
        // Convert network error
        throw AppError.network(error.toNetworkError())
    } catch {
        // Fallback for unknown errors
        throw AppError.unknown(error)
    }
}
```

### In ViewModels

**Catch errors and convert to UI state:**

```swift
@MainActor
class SceneListViewModel: ObservableObject {
    @Published var state: ViewState = .loading
    
    func fetchScenes() async {
        state = .loading
        
        do {
            let scenes = try await repository.getScenes()
            state = .content(scenes)
            
        } catch let error as AppError {
            // Log if needed
            if error.shouldLog {
                Logger.scenes.error("Failed to fetch: \(error.localizedDescription)")
            }
            
            // Show user-friendly message
            state = .error(error.localizedDescription ?? "Unknown error")
            
            // Optional: Show recovery suggestion
            if let suggestion = error.recoverySuggestion {
                // Display suggestion to user
            }
            
        } catch {
            // This should rarely happen - convert to AppError
            let appError = error.toAppError()
            state = .error(appError.localizedDescription ?? "Unknown error")
        }
    }
}
```

### In Views

**Display error messages from ViewModel state:**

```swift
struct SceneListView: View {
    @StateObject var viewModel: SceneListViewModel
    
    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
                
            case .content(let scenes):
                List(scenes) { scene in
                    SceneRow(scene: scene)
                }
                
            case .error(let message):
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
                .refreshable {
                    await viewModel.fetchScenes()
                }
            }
        }
    }
}
```

## Error Properties

Every `AppError` provides:

### 1. User Message
```swift
error.errorDescription  // User-friendly message
// "No internet connection"
```

### 2. Technical Details
```swift
error.failureReason  // Technical details for debugging
// "HTTP 500: Internal server error"
```

### 3. Recovery Suggestion
```swift
error.recoverySuggestion  // How to fix
// "Check your internet connection and try again"
```

### 4. Retry Logic
```swift
if error.isRetryable {
    // Show retry button
}
```

### 5. Logging
```swift
if error.shouldLog {
    Logger.app.error("Error: \(error.localizedDescription)")
}
```

## Migration Guide

### Old Pattern
```swift
// Old RepositoryError
catch {
    throw RepositoryError.networkError(error)
}
```

### New Pattern
```swift
// New standardized approach
catch let error as StashAPIError {
    throw AppError.stashAPI(error)
} catch let error as URLError {
    throw AppError.network(error.toNetworkError())
} catch {
    throw AppError.unknown(error)
}
```

## Best Practices

### ✅ DO

1. **Throw specific errors at the source:**
   ```swift
   throw StashAPIError.unauthorizedAPIKey  // Specific
   ```

2. **Wrap errors as they cross layers:**
   ```swift
   catch let error as StashAPIError {
       throw AppError.stashAPI(error)  // Wrap at boundary
   }
   ```

3. **Convert to UI state in ViewModels:**
   ```swift
   catch let error as AppError {
       state = .error(error.localizedDescription)
   }
   ```

4. **Use error properties:**
   ```swift
   if error.isRetryable {
       // Show retry button
   }
   ```

5. **Log with context:**
   ```swift
   if error.shouldLog {
       Logger.network.error("Failed to fetch scenes: \(error.localizedDescription)")
   }
   ```

### ❌ DON'T

1. **Don't lose error context:**
   ```swift
   // ❌ BAD - Lost context
   catch {
       throw AppError.unknown(error)
   }
   
   // ✅ GOOD - Preserve type
   catch let error as StashAPIError {
       throw AppError.stashAPI(error)
   }
   ```

2. **Don't expose technical details to users:**
   ```swift
   // ❌ BAD
   Text("Decoding error: keyNotFound(CodingKeys)")
   
   // ✅ GOOD
   Text(error.localizedDescription)  // "Failed to parse server response"
   ```

3. **Don't throw generic errors from clients:**
   ```swift
   // ❌ BAD
   throw NSError(domain: "Error", code: 500)
   
   // ✅ GOOD
   throw StashAPIError.networkError(.httpError(statusCode: 500, response: data))
   ```

4. **Don't handle errors in multiple places:**
   ```swift
   // ❌ BAD - Logging in Repository AND ViewModel
   
   // ✅ GOOD - Log once in ViewModel, throw from Repository
   ```

## Testing

### Mock Errors in Tests
```swift
class MockStashClient: StashClientProtocol {
    var errorToThrow: AppError?
    
    func fetch<T>(...) async throws -> T {
        if let error = errorToThrow {
            throw error
        }
        return mockData as! T
    }
}

func testErrorHandling() async {
    let mockClient = MockStashClient()
    mockClient.errorToThrow = .network(.noConnection)
    
    let viewModel = SceneListViewModel(client: mockClient)
    await viewModel.fetchScenes()
    
    // Assert error state
    XCTAssertEqual(viewModel.state, .error("No internet connection"))
}
```

## Common Scenarios

### Scenario 1: Network Timeout
```swift
// Client throws
throw StashAPIError.networkError(.timeout)

// Repository wraps
throw AppError.stashAPI(.networkError(.timeout))

// ViewModel converts
state = .error("Request timed out")

// User sees
"Request timed out"
"Check your connection speed or try again later"
[Retry Button] (because error.isRetryable == true)
```

### Scenario 2: Invalid API Key
```swift
// Client throws
throw StashAPIError.unauthorizedAPIKey

// Repository wraps
throw AppError.stashAPI(.unauthorizedAPIKey)

// ViewModel converts
state = .error("Invalid API key")

// User sees
"Invalid API key"
"Check your API key in Settings"
[No Retry] (because error.isRetryable == false)
```

### Scenario 3: Item Not Found
```swift
// Repository throws
throw AppError.notFound("Scene")

// ViewModel converts
state = .error("Scene not found")

// User sees
"Scene not found"
"Try refreshing or check if the item was deleted"
[No Error Log] (because error.shouldLog == false)
```

## Summary

The standardized error handling system provides:
- **Consistency** - Same pattern across all layers
- **Type Safety** - Swift compiler catches issues
- **User Experience** - Clear, helpful error messages
- **Debuggability** - Technical details preserved
- **Testability** - Easy to mock and test

Follow this guide to ensure robust, user-friendly error handling throughout the app.
