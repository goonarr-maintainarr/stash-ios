# Potential Upgrades

This document outlines potential architectural improvements and library upgrades for the Stash iOS app.

---

## Apollo GraphQL Codegen

### Overview

Apollo iOS is a strongly-typed GraphQL client that auto-generates Swift types from your GraphQL schema and queries.

### What You'd Get

#### 1. Auto-generated Type-Safe DTOs

```swift
// You write this query:
query FindPerformers($page: Int!) {
  findPerformers(filter: { page: $page }) {
    performers { id name birthdate }
  }
}

// Apollo generates this Swift code automatically:
struct FindPerformersQuery: GraphQLQuery {
  struct Data: SelectionSet {
    var findPerformers: FindPerformers
    struct FindPerformers: SelectionSet {
      var performers: [Performer]
      struct Performer: SelectionSet {
        var id: String
        var name: String?
        var birthdate: String?
      }
    }
  }
}
```

#### 2. Schema Validation at Build Time

- If you query a field that doesn't exist → **compile error**
- No more runtime "Cannot query field X" errors
- Catches API mismatches before they hit production

#### 3. Automatic Response Caching

- Apollo has a normalized cache (like CoreData but for GraphQL)
- Fetch policies: `.cacheFirst`, `.networkOnly`, `.cacheAndNetwork`
- Automatic cache updates when mutations complete

#### 4. Type-Safe Variables

```swift
let query = FindPerformersQuery(page: 1, perPage: 20)
// Compiler ensures correct types for all variables
```

### Tradeoffs

| Concern | Impact |
|---------|--------|
| **Dependency** | ~2MB framework via Swift Package Manager |
| **Build time** | Codegen runs on every build (can add 5-15s) |
| **Flexibility** | Harder to customize response handling |
| **Learning curve** | Apollo-specific patterns and APIs |
| **Migration cost** | Would require rewriting GraphQLClient and all ViewModels |

### Current Assessment

| Factor | Assessment |
|--------|------------|
| Query complexity | ~5-10 queries → manageable manually |
| API stability | Stash API evolves → codegen would help |
| Current solution | DTO pattern provides good decoupling |
| Rewrite cost | High - significant refactor needed |

### Recommendation

The DTO pattern currently implemented (`PerformerDTO`, `SceneDTO`, etc.) provides **80% of the benefit with 20% of the effort**. Apollo would be worth considering if:

- The app grows to 20+ different queries
- Stash API changes frequently break the app
- Real-time subscriptions are needed
- The normalized cache would significantly improve UX

### Resources

- [Apollo iOS Documentation](https://www.apollographql.com/docs/ios/)
- [Apollo iOS GitHub](https://github.com/apollographql/apollo-ios)
- [Stash GraphQL Schema](https://github.com/stashapp/stash) (introspection endpoint)

---

## Other Potential Upgrades

### SwiftData Migration

Replace GRDB with Apple's SwiftData for persistence. 

**Pros:** Native Apple framework, SwiftUI integration, CloudKit sync
**Cons:** iOS 17+ only, less flexible than GRDB

### Async/Await Refactoring

Continue migrating remaining Combine publishers to async/await for simpler concurrency.

### Modularization

Split into Swift packages:
- `StashCore` - Models, DTOs
- `StashAPI` - GraphQL client, networking
- `StashDB` - Database layer
- `StashUI` - Views, ViewModels

**Benefit:** Faster builds, clearer boundaries, testability
