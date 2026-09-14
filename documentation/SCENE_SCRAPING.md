# Scene Scraping Implementation - iOS

This document explains how to implement scene scraping functionality in the Stash iOS app, including query-based search, fingerprint matching, and fragment-based scraping.

## Table of Contents

- [Overview](#overview)
- [GraphQL Queries](#graphql-queries)
- [Data Models](#data-models)
- [Scraper Service](#scraper-service)
- [UI Implementation](#ui-implementation)
- [Usage Examples](#usage-examples)

---

## Overview

Stash supports three methods for scraping scene metadata:

1. **Query String Search** - Search by text (scene title, keywords)
2. **Fingerprint Matching** - Match by file hash (MD5, OSHASH, PHASH)
3. **Fragment-Based Search** - Search with partial metadata (title, code, date, URL)

### When to Use Each Method

| Method | Best For | Accuracy | Speed |
|--------|----------|----------|-------|
| **Query** | Manual search, user input | Low-Medium | Fast |
| **Fingerprint** | Automatic identification | High | Fast |
| **Fragment** | Partial metadata import | Medium-High | Fast |

---

## GraphQL Queries

### 1. Scrape by Query String

```graphql
query ScrapeSingleSceneByQuery(
  $source: ScraperSourceInput!,
  $query: String!
) {
  scrapeSingleScene(
    source: $source,
    input: { query: $query }
  ) {
    title
    code
    details
    director
    urls
    date
    image
    studio {
      name
      url
      image
      remote_site_id
    }
    performers {
      name
      gender
      url
      twitter
      instagram
      birthdate
      ethnicity
      country
      eye_color
      height
      measurements
      fake_tits
      career_length
      tattoos
      piercings
      aliases
      images
      details
      death_date
      hair_color
      weight
      remote_site_id
      tags {
        name
      }
    }
    tags {
      name
    }
    movies {
      name
      url
      date
      director
      synopsis
      front_image
      back_image
      studio {
        name
      }
    }
    remote_site_id
    duration
    fingerprints {
      hash
      algorithm
    }
  }
}
```

**Variables:**
```json
{
  "source": {
    "stash_box_index": 0
  },
  "query": "Scene Title 2024"
}
```

Or use a specific scraper:
```json
{
  "source": {
    "scraper_id": "builtin_stashdb"
  },
  "query": "Scene Title"
}
```

---

### 2. Scrape by Fingerprint (Scene ID)

```graphql
query ScrapeSingleSceneByFingerprint(
  $source: ScraperSourceInput!,
  $scene_id: ID!
) {
  scrapeSingleScene(
    source: $source,
    input: { scene_id: $scene_id }
  ) {
    title
    code
    details
    director
    urls
    date
    image
    studio { name url image remote_site_id }
    performers {
      name
      gender
      url
      images
      remote_site_id
    }
    tags { name }
    remote_site_id
    duration
  }
}
```

**Variables:**
```json
{
  "source": {
    "stash_box_index": 0
  },
  "scene_id": "123"
}
```

---

### 3. Scrape by Fragment

```graphql
query ScrapeSingleSceneByFragment(
  $source: ScraperSourceInput!,
  $scene_input: ScrapedSceneInput!
) {
  scrapeSingleScene(
    source: $source,
    input: { scene_input: $scene_input }
  ) {
    title
    code
    details
    director
    urls
    date
    image
    studio { name url image remote_site_id }
    performers {
      name
      gender
      url
      images
      remote_site_id
    }
    tags { name }
    remote_site_id
    duration
  }
}
```

**Variables:**
```json
{
  "source": {
    "stash_box_index": 0
  },
  "scene_input": {
    "title": "Partial Title",
    "code": "ABC-123",
    "date": "2024-01-15",
    "urls": ["https://example.com/scene/123"],
    "details": "Scene description",
    "director": "Director Name",
    "remote_site_id": "12345"
  }
}
```

---

### Get Available Scrapers

```graphql
query ListScrapers {
  listScrapers {
    id
    name
    scene {
      supported_scrapes
    }
    performer {
      supported_scrapes
    }
    gallery {
      supported_scrapes
    }
    movie {
      supported_scrapes
    }
  }
}
```

**Response:**
```json
{
  "data": {
    "listScrapers": [
      {
        "id": "builtin_stashdb",
        "name": "stash-box",
        "scene": {
          "supported_scrapes": ["FRAGMENT", "NAME", "URL"]
        }
      }
    ]
  }
}
```

---

### Scrape by URL

For direct URL scraping:

```graphql
query ScrapeSceneURL($url: String!) {
  scrapeSceneURL(url: $url) {
    title
    code
    details
    director
    urls
    date
    image
    studio { name }
    performers { name }
    tags { name }
  }
}
```

**Variables:**
```json
{
  "url": "https://example.com/scene/12345"
}
```

---

## Data Models

### Swift Models

```swift
import Foundation

// MARK: - Scraper Source

struct ScraperSource: Codable {
    let stashBoxIndex: Int?
    let stashBoxEndpoint: String?
    let scraperID: String?
    
    enum CodingKeys: String, CodingKey {
        case stashBoxIndex = "stash_box_index"
        case stashBoxEndpoint = "stash_box_endpoint"
        case scraperID = "scraper_id"
    }
}

// MARK: - Scraped Scene

struct ScrapedScene: Codable, Identifiable {
    let id = UUID()
    let title: String?
    let code: String?
    let details: String?
    let director: String?
    let urls: [String]?
    let date: String?
    let image: String?
    let studio: ScrapedStudio?
    let performers: [ScrapedPerformer]?
    let tags: [ScrapedTag]?
    let remoteSiteID: String?
    let duration: Int?
    let fingerprints: [ScrapedFingerprint]?
    
    enum CodingKeys: String, CodingKey {
        case title, code, details, director, urls, date, image
        case studio, performers, tags, duration, fingerprints
        case remoteSiteID = "remote_site_id"
    }
}

// MARK: - Scraped Studio

struct ScrapedStudio: Codable {
    let name: String
    let url: String?
    let image: String?
    let remoteSiteID: String?
    
    enum CodingKeys: String, CodingKey {
        case name, url, image
        case remoteSiteID = "remote_site_id"
    }
}

// MARK: - Scraped Performer

struct ScrapedPerformer: Codable, Identifiable {
    let id = UUID()
    let name: String
    let gender: String?
    let url: String?
    let twitter: String?
    let instagram: String?
    let birthdate: String?
    let ethnicity: String?
    let country: String?
    let eyeColor: String?
    let height: String?
    let measurements: String?
    let fakeTits: String?
    let careerLength: String?
    let tattoos: String?
    let piercings: String?
    let aliases: String?
    let images: [String]?
    let details: String?
    let deathDate: String?
    let hairColor: String?
    let weight: String?
    let remoteSiteID: String?
    let tags: [ScrapedTag]?
    
    enum CodingKeys: String, CodingKey {
        case name, gender, url, twitter, instagram, birthdate
        case ethnicity, country, height, measurements
        case tattoos, piercings, aliases, images, details, weight, tags
        case eyeColor = "eye_color"
        case fakeTits = "fake_tits"
        case careerLength = "career_length"
        case deathDate = "death_date"
        case hairColor = "hair_color"
        case remoteSiteID = "remote_site_id"
    }
}

// MARK: - Scraped Tag

struct ScrapedTag: Codable, Identifiable {
    let id = UUID()
    let name: String
}

// MARK: - Scraped Fingerprint

struct ScrapedFingerprint: Codable {
    let hash: String
    let algorithm: String
}

// MARK: - Scene Fragment Input

struct SceneFragmentInput: Codable {
    let title: String?
    let code: String?
    let details: String?
    let director: String?
    let urls: [String]?
    let date: String?
    let remoteSiteID: String?
    
    enum CodingKeys: String, CodingKey {
        case title, code, details, director, urls, date
        case remoteSiteID = "remote_site_id"
    }
    
    init(title: String? = nil,
         code: String? = nil,
         details: String? = nil,
         director: String? = nil,
         urls: [String]? = nil,
         date: String? = nil,
         remoteSiteID: String? = nil) {
        self.title = title
        self.code = code
        self.details = details
        self.director = director
        self.urls = urls
        self.date = date
        self.remoteSiteID = remoteSiteID
    }
}

// MARK: - Scraper Info

struct ScraperInfo: Codable, Identifiable {
    let id: String
    let name: String
    let scene: ScraperTypeInfo?
    let performer: ScraperTypeInfo?
    let gallery: ScraperTypeInfo?
    let movie: ScraperTypeInfo?
}

struct ScraperTypeInfo: Codable {
    let supportedScrapes: [String]
    
    enum CodingKeys: String, CodingKey {
        case supportedScrapes = "supported_scrapes"
    }
}
```

---

## Scraper Service

### SceneScraperService.swift

```swift
import Foundation

enum ScrapeMethod {
    case query(String)
    case fingerprint(String) // scene ID
    case fragment(SceneFragmentInput)
    case url(String)
}

enum ScraperError: Error {
    case noResults
    case networkError(Error)
    case invalidResponse
    case scraperNotAvailable
}

class SceneScraperService {
    private let graphQLService: GraphQLService
    
    init(graphQLService: GraphQLService) {
        self.graphQLService = graphQLService
    }
    
    // MARK: - Scrape Scene
    
    func scrapeScene(
        method: ScrapeMethod,
        source: ScraperSource
    ) async throws -> [ScrapedScene] {
        switch method {
        case .query(let query):
            return try await scrapeByQuery(query: query, source: source)
        case .fingerprint(let sceneID):
            return try await scrapeByFingerprint(sceneID: sceneID, source: source)
        case .fragment(let fragment):
            return try await scrapeByFragment(fragment: fragment, source: source)
        case .url(let url):
            return try await scrapeByURL(url: url)
        }
    }
    
    // MARK: - Scrape by Query
    
    private func scrapeByQuery(
        query: String,
        source: ScraperSource
    ) async throws -> [ScrapedScene] {
        let queryString = """
        query ScrapeSingleSceneByQuery($source: ScraperSourceInput!, $query: String!) {
          scrapeSingleScene(source: $source, input: { query: $query }) {
            title
            code
            details
            director
            urls
            date
            image
            studio { name url image remote_site_id }
            performers {
              name
              gender
              url
              images
              remote_site_id
            }
            tags { name }
            remote_site_id
            duration
          }
        }
        """
        
        let variables: [String: Any] = [
            "source": encodeSource(source),
            "query": query
        ]
        
        let response: GraphQLResponse<ScrapeSingleSceneData> = try await graphQLService.query(
            query: queryString,
            variables: variables
        )
        
        return response.data.scrapeSingleScene
    }
    
    // MARK: - Scrape by Fingerprint
    
    private func scrapeByFingerprint(
        sceneID: String,
        source: ScraperSource
    ) async throws -> [ScrapedScene] {
        let queryString = """
        query ScrapeSingleSceneByFingerprint($source: ScraperSourceInput!, $scene_id: ID!) {
          scrapeSingleScene(source: $source, input: { scene_id: $scene_id }) {
            title
            code
            details
            director
            urls
            date
            image
            studio { name url image remote_site_id }
            performers {
              name
              gender
              url
              images
              remote_site_id
            }
            tags { name }
            remote_site_id
            duration
          }
        }
        """
        
        let variables: [String: Any] = [
            "source": encodeSource(source),
            "scene_id": sceneID
        ]
        
        let response: GraphQLResponse<ScrapeSingleSceneData> = try await graphQLService.query(
            query: queryString,
            variables: variables
        )
        
        return response.data.scrapeSingleScene
    }
    
    // MARK: - Scrape by Fragment
    
    private func scrapeByFragment(
        fragment: SceneFragmentInput,
        source: ScraperSource
    ) async throws -> [ScrapedScene] {
        let queryString = """
        query ScrapeSingleSceneByFragment($source: ScraperSourceInput!, $scene_input: ScrapedSceneInput!) {
          scrapeSingleScene(source: $source, input: { scene_input: $scene_input }) {
            title
            code
            details
            director
            urls
            date
            image
            studio { name url image remote_site_id }
            performers {
              name
              gender
              url
              images
              remote_site_id
            }
            tags { name }
            remote_site_id
            duration
          }
        }
        """
        
        let variables: [String: Any] = [
            "source": encodeSource(source),
            "scene_input": encodeFragment(fragment)
        ]
        
        let response: GraphQLResponse<ScrapeSingleSceneData> = try await graphQLService.query(
            query: queryString,
            variables: variables
        )
        
        return response.data.scrapeSingleScene
    }
    
    // MARK: - Scrape by URL
    
    private func scrapeByURL(url: String) async throws -> [ScrapedScene] {
        let queryString = """
        query ScrapeSceneURL($url: String!) {
          scrapeSceneURL(url: $url) {
            title
            code
            details
            director
            urls
            date
            image
            studio { name url image remote_site_id }
            performers {
              name
              gender
              url
              images
              remote_site_id
            }
            tags { name }
            remote_site_id
            duration
          }
        }
        """
        
        let variables: [String: Any] = ["url": url]
        
        let response: GraphQLResponse<ScrapeSceneURLData> = try await graphQLService.query(
            query: queryString,
            variables: variables
        )
        
        guard let scene = response.data.scrapeSceneURL else {
            throw ScraperError.noResults
        }
        
        return [scene]
    }
    
    // MARK: - Get Available Scrapers
    
    func getAvailableScrapers() async throws -> [ScraperInfo] {
        let queryString = """
        query ListScrapers {
          listScrapers {
            id
            name
            scene {
              supported_scrapes
            }
            performer {
              supported_scrapes
            }
            gallery {
              supported_scrapes
            }
            movie {
              supported_scrapes
            }
          }
        }
        """
        
        let response: GraphQLResponse<ListScrapersData> = try await graphQLService.query(
            query: queryString,
            variables: nil
        )
        
        return response.data.listScrapers
    }
    
    // MARK: - Helper Methods
    
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
    
    private func encodeFragment(_ fragment: SceneFragmentInput) -> [String: Any] {
        var dict: [String: Any] = [:]
        if let title = fragment.title { dict["title"] = title }
        if let code = fragment.code { dict["code"] = code }
        if let details = fragment.details { dict["details"] = details }
        if let director = fragment.director { dict["director"] = director }
        if let urls = fragment.urls { dict["urls"] = urls }
        if let date = fragment.date { dict["date"] = date }
        if let remoteSiteID = fragment.remoteSiteID {
            dict["remote_site_id"] = remoteSiteID
        }
        return dict
    }
}

// MARK: - Response Types

struct ScrapeSingleSceneData: Codable {
    let scrapeSingleScene: [ScrapedScene]
}

struct ScrapeSceneURLData: Codable {
    let scrapeSceneURL: ScrapedScene?
}

struct ListScrapersData: Codable {
    let listScrapers: [ScraperInfo]
}
```

---

## UI Implementation

### SwiftUI Scene Scraper View

```swift
import SwiftUI

struct SceneScraperView: View {
    let scene: Scene
    @StateObject private var viewModel: SceneScraperViewModel
    
    init(scene: Scene, scraperService: SceneScraperService) {
        self.scene = scene
        _viewModel = StateObject(wrappedValue: SceneScraperViewModel(
            scene: scene,
            scraperService: scraperService
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search options
                searchMethodPicker
                
                // Results list
                if viewModel.isLoading {
                    ProgressView("Scraping...")
                        .padding()
                } else if let error = viewModel.error {
                    errorView(error)
                } else if viewModel.results.isEmpty {
                    emptyView
                } else {
                    resultsList
                }
            }
            .navigationTitle("Scrape Scene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Dismiss
                    }
                }
            }
        }
        .task {
            await viewModel.loadScrapers()
            await viewModel.autoScrape()
        }
    }
    
    private var searchMethodPicker: some View {
        VStack(spacing: 16) {
            // Scraper source picker
            Picker("Source", selection: $viewModel.selectedSource) {
                ForEach(viewModel.availableScrapers) { scraper in
                    Text(scraper.name).tag(scraper.id)
                }
            }
            .pickerStyle(.menu)
            
            // Method picker
            Picker("Method", selection: $viewModel.selectedMethod) {
                Text("Fingerprint").tag(ScraperMethod.fingerprint(scene.id))
                Text("Query").tag(ScraperMethod.query(""))
                Text("Fragment").tag(ScraperMethod.fragment(SceneFragmentInput()))
                Text("URL").tag(ScraperMethod.url(""))
            }
            .pickerStyle(.segmented)
            
            // Input field based on method
            switch viewModel.selectedMethod {
            case .query:
                TextField("Search query", text: $viewModel.queryInput)
                    .textFieldStyle(.roundedBorder)
            case .url:
                TextField("Scene URL", text: $viewModel.urlInput)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
            case .fragment:
                fragmentInputFields
            case .fingerprint:
                Text("Using scene fingerprints")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Scrape button
            Button(action: { Task { await viewModel.scrape() } }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Scrape")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private var fragmentInputFields: some View {
        VStack(spacing: 8) {
            TextField("Title", text: $viewModel.fragmentTitle)
                .textFieldStyle(.roundedBorder)
            TextField("Code", text: $viewModel.fragmentCode)
                .textFieldStyle(.roundedBorder)
            TextField("Date (YYYY-MM-DD)", text: $viewModel.fragmentDate)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var resultsList: some View {
        List {
            ForEach(viewModel.results) { result in
                ScrapedSceneRow(scrapedScene: result) {
                    Task { await viewModel.applyResult(result) }
                }
            }
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No results found")
                .font(.headline)
            Text("Try a different search method or query")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)
            Text("Error")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct ScrapedSceneRow: View {
    let scrapedScene: ScrapedScene
    let onApply: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and code
            HStack {
                Text(scrapedScene.title ?? "Untitled")
                    .font(.headline)
                Spacer()
                if let code = scrapedScene.code {
                    Text(code)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Studio and date
            HStack {
                if let studio = scrapedScene.studio {
                    Text(studio.name)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                Spacer()
                if let date = scrapedScene.date {
                    Text(date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Performers
            if let performers = scrapedScene.performers, !performers.isEmpty {
                Text(performers.map { $0.name }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Apply button
            Button(action: onApply) {
                Text("Apply to Scene")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}
```

---

### ViewModel

```swift
import Foundation
import Combine

@MainActor
class SceneScraperViewModel: ObservableObject {
    @Published var results: [ScrapedScene] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var availableScrapers: [ScraperInfo] = []
    @Published var selectedSource = "builtin_stashdb"
    @Published var selectedMethod: ScraperMethodType = .fingerprint
    @Published var queryInput = ""
    @Published var urlInput = ""
    @Published var fragmentTitle = ""
    @Published var fragmentCode = ""
    @Published var fragmentDate = ""
    
    private let scene: Scene
    private let scraperService: SceneScraperService
    
    enum ScraperMethodType {
        case query, fingerprint, fragment, url
    }
    
    init(scene: Scene, scraperService: SceneScraperService) {
        self.scene = scene
        self.scraperService = scraperService
    }
    
    func loadScrapers() async {
        do {
            availableScrapers = try await scraperService.getAvailableScrapers()
        } catch {
            self.error = error
        }
    }
    
    func autoScrape() async {
        // Try fingerprint first (most accurate)
        let source = ScraperSource(
            stashBoxIndex: 0,
            stashBoxEndpoint: nil,
            scraperID: nil
        )
        
        do {
            isLoading = true
            error = nil
            results = try await scraperService.scrapeScene(
                method: .fingerprint(scene.id),
                source: source
            )
        } catch {
            // Fingerprint failed, could fall back to fragment if we have metadata
            self.error = error
        }
        isLoading = false
    }
    
    func scrape() async {
        let source = ScraperSource(
            stashBoxIndex: selectedSource == "stashbox" ? 0 : nil,
            stashBoxEndpoint: nil,
            scraperID: selectedSource == "stashbox" ? nil : selectedSource
        )
        
        let method: ScrapeMethod
        switch selectedMethod {
        case .query:
            method = .query(queryInput)
        case .fingerprint:
            method = .fingerprint(scene.id)
        case .fragment:
            method = .fragment(SceneFragmentInput(
                title: fragmentTitle.isEmpty ? nil : fragmentTitle,
                code: fragmentCode.isEmpty ? nil : fragmentCode,
                date: fragmentDate.isEmpty ? nil : fragmentDate
            ))
        case .url:
            method = .url(urlInput)
        }
        
        do {
            isLoading = true
            error = nil
            results = try await scraperService.scrapeScene(method: method, source: source)
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    func applyResult(_ result: ScrapedScene) async {
        // Apply the scraped data to the scene
        // This would call sceneUpdate mutation
    }
}
```

---

## Usage Examples

### Example 1: Auto-scrape with Fingerprint

```swift
let scene = // ... existing scene
let scraperService = SceneScraperService(graphQLService: graphQLService)

Task {
    let source = ScraperSource(stashBoxIndex: 0, stashBoxEndpoint: nil, scraperID: nil)
    
    do {
        let results = try await scraperService.scrapeScene(
            method: .fingerprint(scene.id),
            source: source
        )
        
        if let match = results.first {
            print("Found match: \(match.title ?? "Unknown")")
            // Apply to scene
        }
    } catch {
        print("Scrape failed: \(error)")
    }
}
```

---

### Example 2: Manual Query Search

```swift
let scraperService = SceneScraperService(graphQLService: graphQLService)

Task {
    let source = ScraperSource(stashBoxIndex: 0, stashBoxEndpoint: nil, scraperID: nil)
    
    let results = try await scraperService.scrapeScene(
        method: .query("Hot Scene 2024"),
        source: source
    )
    
    print("Found \(results.count) matches")
    for result in results {
        print("- \(result.title ?? "Untitled")")
    }
}
```

---

### Example 3: Fragment Search

```swift
let fragment = SceneFragmentInput(
    title: "Scene Title",
    code: "ABC-123",
    date: "2024-01-15"
)

let scraperService = SceneScraperService(graphQLService: graphQLService)

Task {
    let source = ScraperSource(stashBoxIndex: 0, stashBoxEndpoint: nil, scraperID: nil)
    
    let results = try await scraperService.scrapeScene(
        method: .fragment(fragment),
        source: source
    )
    
    // Show results to user
}
```

---

### Example 4: URL Scrape

```swift
let scraperService = SceneScraperService(graphQLService: graphQLService)

Task {
    let results = try await scraperService.scrapeScene(
        method: .url("https://example.com/scene/12345"),
        source: ScraperSource(stashBoxIndex: nil, stashBoxEndpoint: nil, scraperID: nil)
    )
    
    if let scene = results.first {
        print("Scraped: \(scene.title ?? "Unknown")")
    }
}
```

---

## Implementation Strategy

### Recommended Flow

1. **Initial Load**: Try fingerprint matching first (most accurate)
2. **Fallback**: If no fingerprint match, show search UI
3. **User Choice**: Let user choose method (query, fragment, URL)
4. **Results**: Display all matches in a list
5. **Apply**: User selects match and applies to scene

### Best Practices

- Cache scraper list (they don't change often)
- Show loading indicators during scraping
- Handle errors gracefully (network issues, no results)
- Allow users to preview before applying
- Support batch scraping for multiple scenes
- Provide manual edit option if scraping fails

---

## Add to GraphQLQueries.swift

```swift
// MARK: - Scene Scraping

static let scrapeSingleSceneByQuery = """
query ScrapeSingleSceneByQuery($source: ScraperSourceInput!, $query: String!) {
    scrapeSingleScene(source: $source, input: { query: $query }) {
        title
        code
        details
        director
        urls
        date
        image
        studio { name url image remote_site_id }
        performers { name gender url images remote_site_id }
        tags { name }
        remote_site_id
        duration
    }
}
"""

static let scrapeSingleSceneByFingerprint = """
query ScrapeSingleSceneByFingerprint($source: ScraperSourceInput!, $scene_id: ID!) {
    scrapeSingleScene(source: $source, input: { scene_id: $scene_id }) {
        title
        code
        details
        director
        urls
        date
        image
        studio { name url image remote_site_id }
        performers { name gender url images remote_site_id }
        tags { name }
        remote_site_id
        duration
    }
}
"""

static let listScrapers = """
query ListScrapers {
    listScrapers {
        id
        name
        scene { supported_scrapes }
        performer { supported_scrapes }
        gallery { supported_scrapes }
        movie { supported_scrapes }
    }
}
"""
```
