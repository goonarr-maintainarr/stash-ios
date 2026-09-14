# Studio CRUD Operations - iOS

This document covers all Studio operations including Create, Read, Update, Delete, Search, and Scraping with complete GraphQL queries, responses, and Swift implementations.

## Table of Contents

- [Data Model](#data-model)
- [Read Operations](#read-operations)
- [Create Studio](#create-studio)
- [Update Studio](#update-studio)
- [Delete Studio](#delete-studio)
- [Search & Filter](#search--filter)
- [Scrape Studio](#scrape-studio)
- [Swift Implementation](#swift-implementation)

---

## Data Model

### Studio Type

```graphql
type Studio {
  id: ID!
  name: String!
  urls: [String!]!
  parent_studio: Studio
  child_studios: [Studio!]!
  aliases: [String!]!
  tags: [Tag!]!
  ignore_auto_tag: Boolean!
  image_path: String
  
  # Counts (with optional depth for child studios)
  scene_count(depth: Int): Int!
  image_count(depth: Int): Int!
  gallery_count(depth: Int): Int!
  performer_count(depth: Int): Int!
  group_count(depth: Int): Int!
  
  stash_ids: [StashID!]!
  rating100: Int        # 1-100 rating
  favorite: Boolean!
  details: String
  created_at: Time!
  updated_at: Time!
  o_counter: Int        # O count
}
```

### Swift Model

```swift
import Foundation

struct Studio: Codable, Identifiable {
    let id: String
    let name: String
    let urls: [String]
    let parentStudio: Studio?
    let childStudios: [Studio]
    let aliases: [String]
    let tags: [Tag]
    let ignoreAutoTag: Bool
    let imagePath: String?
    
    // Counts
    let sceneCount: Int
    let imageCount: Int
    let galleryCount: Int
    let performerCount: Int
    let groupCount: Int
    
    let stashIds: [StashID]
    let rating100: Int?
    let favorite: Bool
    let details: String?
    let createdAt: String
    let updatedAt: String
    let oCounter: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, urls, aliases, tags, details, favorite
        case parentStudio = "parent_studio"
        case childStudios = "child_studios"
        case ignoreAutoTag = "ignore_auto_tag"
        case imagePath = "image_path"
        case sceneCount = "scene_count"
        case imageCount = "image_count"
        case galleryCount = "gallery_count"
        case performerCount = "performer_count"
        case groupCount = "group_count"
        case stashIds = "stash_ids"
        case rating100 = "rating100"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case oCounter = "o_counter"
    }
}

// Simplified studio (for parent/child references)
struct SimpleStudio: Codable, Identifiable {
    let id: String
    let name: String
    let imagePath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case imagePath = "image_path"
    }
}
```

---

## Read Operations

### Get Single Studio

```graphql
query FindStudio($id: ID!) {
  findStudio(id: $id) {
    id
    name
    urls
    parent_studio {
      id
      name
      image_path
    }
    child_studios {
      id
      name
      image_path
    }
    aliases
    tags {
      id
      name
    }
    ignore_auto_tag
    image_path
    scene_count
    image_count
    gallery_count
    performer_count
    group_count
    stash_ids {
      endpoint
      stash_id
    }
    rating100
    favorite
    details
    created_at
    updated_at
    o_counter
  }
}
```

**Variables:**
```json
{
  "id": "123"
}
```

**Response:**
```json
{
  "data": {
    "findStudio": {
      "id": "123",
      "name": "Brazzers",
      "urls": ["https://brazzers.com"],
      "parent_studio": {
        "id": "456",
        "name": "MindGeek",
        "image_path": "/studio/456/image.jpg"
      },
      "child_studios": [],
      "aliases": ["Brazzers Network"],
      "tags": [
        { "id": "10", "name": "Premium" }
      ],
      "ignore_auto_tag": false,
      "image_path": "/studio/123/image.jpg",
      "scene_count": 1543,
      "image_count": 45,
      "gallery_count": 12,
      "performer_count": 234,
      "group_count": 5,
      "stash_ids": [
        {
          "endpoint": "https://stashdb.org/graphql",
          "stash_id": "abc123"
        }
      ],
      "rating100": 85,
      "favorite": true,
      "details": "Premium adult content studio",
      "created_at": "2023-01-15T10:30:00Z",
      "updated_at": "2024-12-26T15:20:00Z",
      "o_counter": 523
    }
  }
}
```

---

### Get All Studios (Paginated)

```graphql
query FindStudios($filter: FindFilterType, $studio_filter: StudioFilterType) {
  findStudios(filter: $filter, studio_filter: $studio_filter) {
    count
    studios {
      id
      name
      urls
      parent_studio {
        id
        name
      }
      aliases
      image_path
      scene_count
      favorite
      rating100
      created_at
      updated_at
    }
  }
}
```

**Variables:**
```json
{
  "filter": {
    "q": "",
    "page": 1,
    "per_page": 25,
    "sort": "name",
    "direction": "ASC"
  },
  "studio_filter": {
    "is_missing": null
  }
}
```

**Response:**
```json
{
  "data": {
    "findStudios": {
      "count": 150,
      "studios": [
        {
          "id": "123",
          "name": "Brazzers",
          "urls": ["https://brazzers.com"],
          "parent_studio": {
            "id": "456",
            "name": "MindGeek"
          },
          "aliases": ["Brazzers Network"],
          "image_path": "/studio/123/image.jpg",
          "scene_count": 1543,
          "favorite": true,
          "rating100": 85,
          "created_at": "2023-01-15T10:30:00Z",
          "updated_at": "2024-12-26T15:20:00Z"
        }
        // ... more studios
      ]
    }
  }
}
```

---

## Create Studio

```graphql
mutation StudioCreate($input: StudioCreateInput!) {
  studioCreate(input: $input) {
    id
    name
    urls
    parent_studio {
      id
      name
    }
    aliases
    tags {
      id
      name
    }
    image_path
    rating100
    favorite
    details
    ignore_auto_tag
    stash_ids {
      endpoint
      stash_id
    }
  }
}
```

**Variables:**
```json
{
  "input": {
    "name": "New Studio",
    "urls": ["https://newstudio.com"],
    "parent_id": "456",
    "image": "data:image/jpeg;base64,/9j/4AAQSkZJRg...",
    "stash_ids": [
      {
        "endpoint": "https://stashdb.org/graphql",
        "stash_id": "xyz789"
      }
    ],
    "rating100": 80,
    "favorite": false,
    "details": "New adult content studio",
    "aliases": ["New Studio Network"],
    "tag_ids": ["10", "20"],
    "ignore_auto_tag": false
  }
}
```

**Response:**
```json
{
  "data": {
    "studioCreate": {
      "id": "789",
      "name": "New Studio",
      "urls": ["https://newstudio.com"],
      "parent_studio": {
        "id": "456",
        "name": "MindGeek"
      },
      "aliases": ["New Studio Network"],
      "tags": [
        { "id": "10", "name": "Premium" },
        { "id": "20", "name": "HD" }
      ],
      "image_path": "/studio/789/image.jpg",
      "rating100": 80,
      "favorite": false,
      "details": "New adult content studio",
      "ignore_auto_tag": false,
      "stash_ids": [
        {
          "endpoint": "https://stashdb.org/graphql",
          "stash_id": "xyz789"
        }
      ]
    }
  }
}
```

---

## Update Studio

```graphql
mutation StudioUpdate($input: StudioUpdateInput!) {
  studioUpdate(input: $input) {
    id
    name
    urls
    parent_studio {
      id
      name
    }
    aliases
    tags {
      id
      name
    }
    image_path
    rating100
    favorite
    details
    ignore_auto_tag
    updated_at
  }
}
```

**Variables:**
```json
{
  "input": {
    "id": "123",
    "name": "Brazzers Updated",
    "urls": ["https://brazzers.com", "https://brazzers.net"],
    "parent_id": "456",
    "image": "data:image/jpeg;base64,/9j/4AAQSkZJRg...",
    "rating100": 90,
    "favorite": true,
    "details": "Updated description",
    "aliases": ["Brazzers Network", "Brazzers Official"],
    "tag_ids": ["10", "20", "30"],
    "ignore_auto_tag": false
  }
}
```

**Response:**
```json
{
  "data": {
    "studioUpdate": {
      "id": "123",
      "name": "Brazzers Updated",
      "urls": ["https://brazzers.com", "https://brazzers.net"],
      "parent_studio": {
        "id": "456",
        "name": "MindGeek"
      },
      "aliases": ["Brazzers Network", "Brazzers Official"],
      "tags": [
        { "id": "10", "name": "Premium" },
        { "id": "20", "name": "HD" },
        { "id": "30", "name": "4K" }
      ],
      "image_path": "/studio/123/image.jpg",
      "rating100": 90,
      "favorite": true,
      "details": "Updated description",
      "ignore_auto_tag": false,
      "updated_at": "2024-12-26T22:53:00Z"
    }
  }
}
```

---

## Delete Studio

```graphql
mutation StudioDestroy($input: StudioDestroyInput!) {
  studioDestroy(input: $input)
}
```

**Variables:**
```json
{
  "input": {
    "id": "123"
  }
}
```

**Response:**
```json
{
  "data": {
    "studioDestroy": true
  }
}
```

---

## Search & Filter

### Search by Name

```graphql
query SearchStudios($query: String!) {
  findStudios(filter: { q: $query, per_page: 20 }) {
    count
    studios {
      id
      name
      image_path
      scene_count
      parent_studio {
        id
        name
      }
    }
  }
}
```

**Variables:**
```json
{
  "query": "Brazzers"
}
```

---

### Filter Favorites

```graphql
query FavoriteStudios {
  findStudios(
    filter: { per_page: 50, sort: "name", direction: "ASC" }
    studio_filter: { is_favorite: "true" }
  ) {
    count
    studios {
      id
      name
      image_path
      scene_count
      favorite
    }
  }
}
```

---

### Get Studios with Depth Count

Get scene count including child studios:

```graphql
query StudioWithDepthCount($id: ID!) {
  findStudio(id: $id) {
    id
    name
    scene_count(depth: -1)      # -1 = all children
    child_studios {
      id
      name
      scene_count
    }
  }
}
```

**Variables:**
```json
{
  "id": "456"
}
```

**Response:**
```json
{
  "data": {
    "findStudio": {
      "id": "456",
      "name": "MindGeek",
      "scene_count": 5234,       // Includes all child studio scenes
      "child_studios": [
        {
          "id": "123",
          "name": "Brazzers",
          "scene_count": 1543
        },
        {
          "id": "789",
          "name": "Reality Kings",
          "scene_count": 2103
        }
      ]
    }
  }
}
```

---

## Scrape Studio

### Scrape by Name

```graphql
query ScrapeSingleStudio($source: ScraperSourceInput!, $query: String!) {
  scrapeSingleStudio(source: $source, input: { query: $query }) {
    stored_id
    name
    urls
    parent {
      name
      urls
    }
    image
    details
    aliases
    tags {
      name
    }
    remote_site_id
  }
}
```

**Variables:**
```json
{
  "source": {
    "stash_box_index": 0
  },
  "query": "Brazzers"
}
```

**Response:**
```json
{
  "data": {
    "scrapeSingleStudio": [
      {
        "stored_id": null,
        "name": "Brazzers",
        "urls": ["https://brazzers.com"],
        "parent": {
          "name": "MindGeek",
          "urls": ["https://mindgeek.com"]
        },
        "image": "https://stashdb.org/studios/123/image.jpg",
        "details": "Premium adult entertainment studio founded in 2005",
        "aliases": "Brazzers Network",
        "tags": [
          { "name": "Premium" },
          { "name": "4K" }
        ],
        "remote_site_id": "abc123"
      }
    ]
  }
}
```

---

### Scrape by Stash ID

```graphql
query ScrapeSingleStudioByStashID($source: ScraperSourceInput!, $stash_id: String!) {
  scrapeSingleStudio(source: $source, input: { query: $stash_id }) {
    stored_id
    name
    urls
    parent {
      name
      urls
    }
    image
    details
    aliases
    tags {
      name
    }
    remote_site_id
  }
}
```

**Variables:**
```json
{
  "source": {
    "stash_box_index": 0
  },
  "stash_id": "abc123"
}
```

---

## Swift Implementation

### Studio Service

```swift
import Foundation

class StudioService {
    private let graphQLService: GraphQLService
    
    init(graphQLService: GraphQLService) {
        self.graphQLService = graphQLService
    }
    
    // MARK: - Read
    
    func getStudio(id: String) async throws -> Studio {
        let query = """
        query FindStudio($id: ID!) {
          findStudio(id: $id) {
            id
            name
            urls
            parent_studio { id name image_path }
            child_studios { id name image_path }
            aliases
            tags { id name }
            ignore_auto_tag
            image_path
            scene_count
            image_count
            gallery_count
            performer_count
            group_count
            stash_ids { endpoint stash_id }
            rating100
            favorite
            details
            created_at
            updated_at
            o_counter
          }
        }
        """
        
        struct Response: Codable {
            let findStudio: Studio
        }
        
        let response: GraphQLResponse<Response> = try await graphQLService.query(
            query: query,
            variables: ["id": id]
        )
        
        return response.data.findStudio
    }
    
    func getAllStudios(page: Int = 1, perPage: Int = 25, sort: String = "name", direction: String = "ASC") async throws -> (count: Int, studios: [Studio]) {
        let query = """
        query FindStudios($filter: FindFilterType) {
          findStudios(filter: $filter) {
            count
            studios {
              id
              name
              urls
              parent_studio { id name }
              aliases
              image_path
              scene_count
              favorite
              rating100
              created_at
              updated_at
            }
          }
        }
        """
        
        struct Response: Codable {
            let findStudios: FindStudiosResult
        }
        
        struct FindStudiosResult: Codable {
            let count: Int
            let studios: [Studio]
        }
        
        let variables: [String: Any] = [
            "filter": [
                "page": page,
                "per_page": perPage,
                "sort": sort,
                "direction": direction
            ]
        ]
        
        let response: GraphQLResponse<Response> = try await graphQLService.query(
            query: query,
            variables: variables
        )
        
        return (response.data.findStudios.count, response.data.findStudios.studios)
    }
    
    func searchStudios(query: String) async throws -> [Studio] {
        let gqlQuery = """
        query SearchStudios($query: String!) {
          findStudios(filter: { q: $query, per_page: 20 }) {
            studios {
              id
              name
              image_path
              scene_count
              parent_studio { id name }
              favorite
            }
          }
        }
        """
        
        struct Response: Codable {
            let findStudios: FindStudiosResult
        }
        
        struct FindStudiosResult: Codable {
            let studios: [Studio]
        }
        
        let response: GraphQLResponse<Response> = try await graphQLService.query(
            query: gqlQuery,
            variables: ["query": query]
        )
        
        return response.data.findStudios.studios
    }
    
    // MARK: - Create
    
    func createStudio(input: StudioCreateInput) async throws -> Studio {
        let mutation = """
        mutation StudioCreate($input: StudioCreateInput!) {
          studioCreate(input: $input) {
            id
            name
            urls
            parent_studio { id name }
            aliases
            tags { id name }
            image_path
            rating100
            favorite
            details
            ignore_auto_tag
          }
        }
        """
        
        struct Response: Codable {
            let studioCreate: Studio
        }
        
        let response: GraphQLResponse<Response> = try await graphQLService.mutate(
            mutation: mutation,
            variables: ["input": try input.asDictionary()]
        )
        
        return response.data.studioCreate
    }
    
    // MARK: - Update
    
    func updateStudio(input: StudioUpdateInput) async throws -> Studio {
        let mutation = """
        mutation StudioUpdate($input: StudioUpdateInput!) {
          studioUpdate(input: $input) {
            id
            name
            urls
            parent_studio { id name }
            aliases
            tags { id name }
            image_path
            rating100
            favorite
            details
            ignore_auto_tag
            updated_at
          }
        }
        """
        
        struct Response: Codable {
            let studioUpdate: Studio
        }
        
        let response: GraphQLResponse<Response> = try await graphQLService.mutate(
            mutation: mutation,
            variables: ["input": try input.asDictionary()]
        )
        
        return response.data.studioUpdate
    }
    
    // MARK: - Delete
    
    func deleteStudio(id: String) async throws {
        let mutation = """
        mutation StudioDestroy($input: StudioDestroyInput!) {
          studioDestroy(input: $input)
        }
        """
        
        struct Response: Codable {
            let studioDestroy: Bool
        }
        
        let _: GraphQLResponse<Response> = try await graphQLService.mutate(
            mutation: mutation,
            variables: ["input": ["id": id]]
        )
    }
    
    // MARK: - Scrape
    
    func scrapeStudio(query: String, source: ScraperSource) async throws -> [ScrapedStudio] {
        let gqlQuery = """
        query ScrapeSingleStudio($source: ScraperSourceInput!, $query: String!) {
          scrapeSingleStudio(source: $source, input: { query: $query }) {
            stored_id
            name
            urls
            parent { name urls }
            image
            details
            aliases
            tags { name }
            remote_site_id
          }
        }
        """
        
        struct Response: Codable {
            let scrapeSingleStudio: [ScrapedStudio]
        }
        
        let variables: [String: Any] = [
            "source": encodeSource(source),
            "query": query
        ]
        
        let response: GraphQLResponse<Response> = try await graphQLService.query(
            query: gqlQuery,
            variables: variables
        )
        
        return response.data.scrapeSingleStudio
    }
    
    private func encodeSource(_ source: ScraperSource) -> [String: Any] {
        var dict: [String: Any] = [:]
        if let index = source.stashBoxIndex {
            dict["stash_box_index"] = index
        }
        if let endpoint = source.stashBoxEndpoint {
            dict["stash_box_endpoint"] = endpoint
        }
        if let scraperID = source.scraperID {
            dict["scraper_id"] = scraperID
        }
        return dict
    }
}

// MARK: - Input Models

struct StudioCreateInput: Codable {
    let name: String
    let urls: [String]?
    let parentId: String?
    let image: String?
    let stashIds: [StashIDInput]?
    let rating100: Int?
    let favorite: Bool?
    let details: String?
    let aliases: [String]?
    let tagIds: [String]?
    let ignoreAutoTag: Bool?
    
    enum CodingKeys: String, CodingKey {
        case name, urls, image, details, aliases, favorite
        case parentId = "parent_id"
        case stashIds = "stash_ids"
        case rating100 = "rating100"
        case tagIds = "tag_ids"
        case ignoreAutoTag = "ignore_auto_tag"
    }
}

struct StudioUpdateInput: Codable {
    let id: String
    let name: String?
    let urls: [String]?
    let parentId: String?
    let image: String?
    let stashIds: [StashIDInput]?
    let rating100: Int?
    let favorite: Bool?
    let details: String?
    let aliases: [String]?
    let tagIds: [String]?
    let ignoreAutoTag: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, name, urls, image, details, aliases, favorite
        case parentId = "parent_id"
        case stashIds = "stash_ids"
        case rating100 = "rating100"
        case tagIds = "tag_ids"
        case ignoreAutoTag = "ignore_auto_tag"
    }
}

// Helper extension
extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "EncodingError", code: 0)
        }
        return dict
    }
}
```

---

## Related Documentation

- [SCENE_SCRAPING.md](SCENE_SCRAPING.md) - Scene scraping (similar to studio scraping)
- [TAGGER_CONFIGURATION.md](TAGGER_CONFIGURATION.md) - Tagger config with studio field exclusions
- [GRAPHQL_API.md](GRAPHQL_API.md) - General GraphQL API reference
