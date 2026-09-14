# Performer Mutations - GraphQL API

This document provides GraphQL mutations for creating and updating performers in Stash.

## Table of Contents

- [Create Performer](#create-performer)
- [Update Performer](#update-performer)
- [Update Performer Image](#update-performer-image-only)
- [Available Enums](#available-enums)
- [Swift Models](#swift-models)

---

## Create Performer

### Mutation

```graphql
mutation CreatePerformer($input: PerformerCreateInput!) {
  performerCreate(input: $input) {
    id
    name
    disambiguation
    urls
    gender
    birthdate
    ethnicity
    country
    eye_color
    height_cm
    measurements
    fake_tits
    penis_length
    circumcised
    career_length
    tattoos
    piercings
    alias_list
    favorite
    tags {
      id
      name
    }
    image_path
    scene_count
    image_count
    gallery_count
    group_count
    rating100
    details
    death_date
    hair_color
    weight
    ignore_auto_tag
    created_at
    updated_at
    stash_ids {
      endpoint
      stash_id
    }
  }
}
```

### Variables

```json
{
  "input": {
    "name": "Jane Doe",
    "disambiguation": "Performer",
    "urls": ["https://example.com/janedoe"],
    "gender": "FEMALE",
    "birthdate": "1990-05-15",
    "ethnicity": "Caucasian",
    "country": "USA",
    "eye_color": "Blue",
    "height_cm": 170,
    "measurements": "34-24-36",
    "fake_tits": "No",
    "career_length": "2015-2020",
    "tattoos": "Rose on left shoulder",
    "piercings": "Belly button",
    "alias_list": ["Jane", "J. Doe"],
    "favorite": false,
    "tag_ids": ["1", "2", "3"],
    "image": "https://example.com/image.jpg",
    "rating100": 85,
    "details": "Award-winning performer",
    "death_date": null,
    "hair_color": "Blonde",
    "weight": 60,
    "ignore_auto_tag": false,
    "stash_ids": [
      {
        "endpoint": "https://stashdb.org/graphql",
        "stash_id": "abc123"
      }
    ]
  }
}
```

### Response

```json
{
  "data": {
    "performerCreate": {
      "id": "123",
      "name": "Jane Doe",
      "disambiguation": "Performer",
      "urls": ["https://example.com/janedoe"],
      "gender": "FEMALE",
      "birthdate": "1990-05-15",
      "ethnicity": "Caucasian",
      "country": "USA",
      "eye_color": "Blue",
      "height_cm": 170,
      "measurements": "34-24-36",
      "fake_tits": "No",
      "penis_length": null,
      "circumcised": null,
      "career_length": "2015-2020",
      "tattoos": "Rose on left shoulder",
      "piercings": "Belly button",
      "alias_list": ["Jane", "J. Doe"],
      "favorite": false,
      "tags": [
        {
          "id": "1",
          "name": "Tag One"
        },
        {
          "id": "2",
          "name": "Tag Two"
        }
      ],
      "image_path": "/performer/123/image.jpg",
      "scene_count": 0,
      "image_count": 0,
      "gallery_count": 0,
      "group_count": 0,
      "rating100": 85,
      "details": "Award-winning performer",
      "death_date": null,
      "hair_color": "Blonde",
      "weight": 60,
      "ignore_auto_tag": false,
      "created_at": "2024-12-23T16:51:28Z",
      "updated_at": "2024-12-23T16:51:28Z",
      "stash_ids": [
        {
          "endpoint": "https://stashdb.org/graphql",
          "stash_id": "abc123"
        }
      ]
    }
  }
}
```

### Minimal Create Example

Only `name` is required:

```json
{
  "input": {
    "name": "John Doe"
  }
}
```

---

## Update Performer

### Mutation

```graphql
mutation UpdatePerformer($input: PerformerUpdateInput!) {
  performerUpdate(input: $input) {
    id
    name
    disambiguation
    urls
    gender
    birthdate
    ethnicity
    country
    eye_color
    height_cm
    measurements
    fake_tits
    penis_length
    circumcised
    career_length
    tattoos
    piercings
    alias_list
    favorite
    tags {
      id
      name
    }
    image_path
    scene_count
    image_count
    gallery_count
    group_count
    rating100
    details
    death_date
    hair_color
    weight
    ignore_auto_tag
    created_at
    updated_at
    stash_ids {
      endpoint
      stash_id
    }
  }
}
```

### Variables

```json
{
  "input": {
    "id": "123",
    "name": "Jane Doe Updated",
    "favorite": true,
    "rating100": 95,
    "height_cm": 172,
    "tag_ids": ["1", "2", "4"]
  }
}
```

**Note:** Only include fields you want to update. The `id` field is required.

### Response

```json
{
  "data": {
    "performerUpdate": {
      "id": "123",
      "name": "Jane Doe Updated",
      "disambiguation": "Performer",
      "urls": ["https://example.com/janedoe"],
      "gender": "FEMALE",
      "birthdate": "1990-05-15",
      "ethnicity": "Caucasian",
      "country": "USA",
      "eye_color": "Blue",
      "height_cm": 172,
      "measurements": "34-24-36",
      "fake_tits": "No",
      "penis_length": null,
      "circumcised": null,
      "career_length": "2015-2020",
      "tattoos": "Rose on left shoulder",
      "piercings": "Belly button",
      "alias_list": ["Jane", "J. Doe"],
      "favorite": true,
      "tags": [
        {
          "id": "1",
          "name": "Tag One"
        },
        {
          "id": "2",
          "name": "Tag Two"
        },
        {
          "id": "4",
          "name": "Tag Four"
        }
      ],
      "image_path": "/performer/123/image.jpg",
      "scene_count": 5,
      "image_count": 2,
      "gallery_count": 1,
      "group_count": 3,
      "rating100": 95,
      "details": "Award-winning performer",
      "death_date": null,
      "hair_color": "Blonde",
      "weight": 60,
      "ignore_auto_tag": false,
      "created_at": "2024-12-23T16:51:28Z",
      "updated_at": "2024-12-23T17:00:00Z",
      "stash_ids": [
        {
          "endpoint": "https://stashdb.org/graphql",
          "stash_id": "abc123"
        }
      ]
    }
  }
}
```

---

## Update Performer Image Only

### Mutation

```graphql
mutation UpdatePerformerImage($performerId: ID!, $imageData: String!) {
  performerUpdate(input: {
    id: $performerId
    image: $imageData
  }) {
    id
    name
    image_path
  }
}
```

### Variables - Base64 Image

```json
{
  "performerId": "123",
  "imageData": "data:image/jpeg;base64,/9j/4AAQSkZJRg..."
}
```

### Variables - URL

```json
{
  "performerId": "123",
  "imageData": "https://example.com/new-image.jpg"
}
```

### Response

```json
{
  "data": {
    "performerUpdate": {
      "id": "123",
      "name": "Jane Doe",
      "image_path": "/performer/123/image.jpg"
    }
  }
}
```

---

## Available Enums

### Gender

```
MALE
FEMALE
TRANSGENDER_MALE
TRANSGENDER_FEMALE
INTERSEX
NON_BINARY
```

### Circumcised

```
CUT
UNCUT
```

---

## Swift Models

### Input Models

```swift
struct PerformerCreateInput: Encodable {
    let name: String
    let disambiguation: String?
    let urls: [String]?
    let gender: Gender?
    let birthdate: String?
    let ethnicity: String?
    let country: String?
    let eye_color: String?
    let height_cm: Int?
    let measurements: String?
    let fake_tits: String?
    let penis_length: Double?
    let circumcised: Circumcised?
    let career_length: String?
    let tattoos: String?
    let piercings: String?
    let alias_list: [String]?
    let favorite: Bool?
    let tag_ids: [String]?
    let image: String?
    let stash_ids: [StashIDInput]?
    let rating100: Int?
    let details: String?
    let death_date: String?
    let hair_color: String?
    let weight: Int?
    let ignore_auto_tag: Bool?
}

struct PerformerUpdateInput: Encodable {
    let id: String
    let name: String?
    let disambiguation: String?
    let urls: [String]?
    let gender: Gender?
    let birthdate: String?
    let ethnicity: String?
    let country: String?
    let eye_color: String?
    let height_cm: Int?
    let measurements: String?
    let fake_tits: String?
    let penis_length: Double?
    let circumcised: Circumcised?
    let career_length: String?
    let tattoos: String?
    let piercings: String?
    let alias_list: [String]?
    let favorite: Bool?
    let tag_ids: [String]?
    let image: String?
    let stash_ids: [StashIDInput]?
    let rating100: Int?
    let details: String?
    let death_date: String?
    let hair_color: String?
    let weight: Int?
    let ignore_auto_tag: Bool?
}
```

### Enums

```swift
enum Gender: String, Codable {
    case male = "MALE"
    case female = "FEMALE"
    case transgenderMale = "TRANSGENDER_MALE"
    case transgenderFemale = "TRANSGENDER_FEMALE"
    case intersex = "INTERSEX"
    case nonBinary = "NON_BINARY"
}

enum Circumcised: String, Codable {
    case cut = "CUT"
    case uncut = "UNCUT"
}
```

### Supporting Models

```swift
struct StashIDInput: Codable {
    let endpoint: String
    let stash_id: String
}

struct PerformerCreateResult: Decodable {
    let performerCreate: Performer
}

struct PerformerUpdateResult: Decodable {
    let performerUpdate: Performer
}
```

---

## Usage Examples

### Add to GraphQLQueries.swift

```swift
// MARK: - Performer Mutations

static let createPerformer = """
mutation CreatePerformer($input: PerformerCreateInput!) {
    performerCreate(input: $input) {
        id
        name
        disambiguation
        urls
        gender
        birthdate
        ethnicity
        country
        eye_color
        height_cm
        measurements
        fake_tits
        career_length
        tattoos
        piercings
        alias_list
        favorite
        image_path
        rating100
        details
        created_at
        updated_at
        tags {
            id
            name
        }
        stash_ids {
            endpoint
            stash_id
        }
    }
}
"""

static let updatePerformer = """
mutation UpdatePerformer($input: PerformerUpdateInput!) {
    performerUpdate(input: $input) {
        id
        name
        disambiguation
        urls
        gender
        birthdate
        ethnicity
        country
        eye_color
        height_cm
        measurements
        favorite
        image_path
        rating100
        details
        updated_at
        tags {
            id
            name
        }
    }
}
"""

static let updatePerformerImage = """
mutation UpdatePerformerImage($performerId: ID!, $imageData: String!) {
    performerUpdate(input: {
        id: $performerId
        image: $imageData
    }) {
        id
        name
        image_path
    }
}
"""
```

### Add to GraphQLClient.swift

```swift
func createPerformer(input: PerformerCreateInput, url: URL, apiKey: String) async throws -> Performer {
    let variables: [String: Any] = [
        "input": try input.asDictionary()
    ]
    
    let result: PerformerCreateResult = try await fetch(
        query: GraphQLQueries.createPerformer,
        variables: variables,
        url: url,
        apiKey: apiKey
    )
    
    return result.performerCreate
}

func updatePerformer(input: PerformerUpdateInput, url: URL, apiKey: String) async throws -> Performer {
    let variables: [String: Any] = [
        "input": try input.asDictionary()
    ]
    
    let result: PerformerUpdateResult = try await fetch(
        query: GraphQLQueries.updatePerformer,
        variables: variables,
        url: url,
        apiKey: apiKey
    )
    
    return result.performerUpdate
}

func updatePerformerImage(performerId: String, imageData: String, url: URL, apiKey: String) async throws -> Performer {
    let variables: [String: Any] = [
        "performerId": performerId,
        "imageData": imageData
    ]
    
    let result: PerformerUpdateResult = try await fetch(
        query: GraphQLQueries.updatePerformerImage,
        variables: variables,
        url: url,
        apiKey: apiKey
    )
    
    return result.performerUpdate
}
```

### Helper Extension

```swift
extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw NSError(domain: "EncodingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert to dictionary"])
        }
        return dictionary
    }
}
```

### Usage in ViewModel

```swift
// Create performer
let input = PerformerCreateInput(
    name: "Jane Doe",
    gender: .female,
    birthdate: "1990-05-15",
    favorite: false,
    rating100: 85
)

let performer = try await GraphQLClient.shared.createPerformer(
    input: input,
    url: stashURL,
    apiKey: apiKey
)

// Update performer
let updateInput = PerformerUpdateInput(
    id: "123",
    favorite: true,
    rating100: 95
)

let updatedPerformer = try await GraphQLClient.shared.updatePerformer(
    input: updateInput,
    url: stashURL,
    apiKey: apiKey
)

// Update image
let updatedPerformer = try await GraphQLClient.shared.updatePerformerImage(
    performerId: "123",
    imageData: "https://example.com/image.jpg",
    url: stashURL,
    apiKey: apiKey
)
```

---

## Notes

- **Required fields**: Only `name` is required for creating a performer, all other fields are optional
- **Date format**: Dates should be in `YYYY-MM-DD` format (e.g., `"1990-05-15"`)
- **Image field**: Accepts either a URL string or a base64 data URL
- **Rating**: `rating100` is on a scale of 0-100
- **Tags**: Use `tag_ids` array with string IDs to associate tags
- **Updates**: Only include fields you want to change in update mutations
- **StashDB IDs**: Can link to external StashDB entries for metadata sync
