import Foundation

/// Centralized GraphQL queries and fragments for StashDB.
/// All queries target the StashDB GraphQL API (https://stashdb.org/graphql).
struct StashDBQueries {
    
    // MARK: - Tag Constants
    
    /// StashDB tag ID for VR scenes
    static let vrTagId = "3da5244d-b0f9-48af-b5e1-d46ecedb4308"
    
    /// StashDB tag ID for compilation scenes
    static let compilationTagId = "6458e5cf-4f65-400b-9067-582141e2a329"
    
    // MARK: - Common Fragments
    
    static let performerFields = """
        id
        name
        gender
        scene_count
        is_favorite
        images {
            id
            url
            width
            height
        }
    """
    
    static let performerDetailFields = """
        id
        name
        disambiguation
        gender
        birth_date
        ethnicity
        country
        height
        career_start_year
        career_end_year
        scene_count
        is_favorite
        images {
            id
            url
            width
            height
        }
        urls {
            url
            type
        }
    """
    
    /// Lightweight scene fields for list/overview displays
    static let sceneOverviewFields = """
        id
        title
        date
        duration
        studio {
            id
            name
        }
        performers {
            performer {
                id
                name
                gender
            }
        }
        images {
            id
            url
            width
            height
        }
    """
    
    static let sceneFields = """
        id
        title
        details
        date
        duration
        studio {
            id
            name
        }
        performers {
            performer {
                id
                name
                gender
            }
        }
        tags {
            id
            name
        }
        images {
            id
            url
            width
            height
        }
        urls {
            url
            type
        }
    """
    
    static let sceneDetailFields = """
        id
        title
        details
        date
        release_date
        production_date
        duration
        director
        code
        deleted
        created
        updated
        studio {
            id
            name
            aliases
            deleted
            is_favorite
            created
            updated
        }
        performers {
            performer {
                id
                name
                gender
            }
        }
        tags {
            id
            name
        }
        images {
            id
            url
            width
            height
        }
    """
    
    static let studioFields = """
        id
        name
        aliases
        deleted
        is_favorite
        created
        updated
    """
    
    // MARK: - Performer Queries
    
    static let favoritePerformers = """
        query GetFavoritePerformers($page: Int!, $perPage: Int!) {
          queryPerformers(input: {
            is_favorite: true
            page: $page
            per_page: $perPage
            sort: NAME
            direction: ASC
          }) {
            count
            performers {
              \(performerDetailFields)
            }
          }
        }
    """
    
    static let favoritePerformersOverview = """
        query GetFavoritePerformersOverview($page: Int!, $perPage: Int!) {
          queryPerformers(input: {
            is_favorite: true
            page: $page
            per_page: $perPage
            sort: NAME
            direction: ASC
          }) {
            count
            performers {
              \(performerFields)
            }
          }
        }
    """
    
    static func performerDetails(id: String) -> String {
        """
        query FindPerformer($id: ID!) {
            findPerformer(id: $id) {
                \(performerDetailFields)
            }
        }
        """
    }
    
    static let searchPerformers = """
        query SearchPerformer($term: String!) {
            searchPerformer(term: $term) {
                id
                name
                birth_date
                country
                ethnicity
                height
                hair_color
                eye_color
                breast_type
                career_start_year
                career_end_year
                scene_count
                measurements {
                    cup_size
                    band_size
                    waist
                    hip
                }
                tattoos {
                    location
                    description
                }
                piercings {
                    location
                    description
                }
                images {
                    id
                    url
                    width
                    height
                }
                urls {
                    url
                    type
                }
            }
        }
    """
    
    // MARK: - Scene Queries
    
    static let performerScenesSimple = """
        query QueryScenes($performerId: ID!, $page: Int!, $perPage: Int!) {
          queryScenes(input: {
            performers: {
              value: [$performerId]
              modifier: INCLUDES
            }
            page: $page
            per_page: $perPage
          }) {
            count
            scenes {
              \(sceneFields)
            }
          }
        }
    """
    
    static let performerScenesWithTagFilter = """
        query QueryScenes($performerId: ID!, $excludedTags: [ID!]!, $page: Int!, $perPage: Int!) {
          queryScenes(input: {
            performers: {
              value: [$performerId]
              modifier: INCLUDES
            }
            tags: {
              value: $excludedTags
              modifier: EXCLUDES
            }
            page: $page
            per_page: $perPage
          }) {
            count
            scenes {
              \(sceneFields)
            }
          }
        }
    """
    
    static let performerSceneIdsSimple = """
        query QuerySceneIds($performerId: ID!, $page: Int!, $perPage: Int!) {
          queryScenes(input: {
            performers: { value: [$performerId], modifier: INCLUDES }
            page: $page
            per_page: $perPage
          }) {
            count
            scenes { id }
          }
        }
    """
    
    static let performerSceneIdsWithTagFilter = """
        query QuerySceneIds($performerId: ID!, $excludedTags: [ID!]!, $page: Int!, $perPage: Int!) {
          queryScenes(input: {
            performers: { value: [$performerId], modifier: INCLUDES }
            tags: { value: $excludedTags, modifier: EXCLUDES }
            page: $page
            per_page: $perPage
          }) {
            count
            scenes { id }
          }
        }
    """
    
    static func batchFindScenes(fields: String, queryBody: String) -> String {
        """
        query BatchFindScenes {
            \(queryBody)
        }
        """
    }
    
    static func scenesWithFilters(studiosFilter: String, performersFilter: String, dateFilter: String, tagsFilter: String, useOverviewFields: Bool = true) -> String {
        let fields = useOverviewFields ? sceneOverviewFields : sceneDetailFields
        return """
        query QueryScenes($page: Int!, $perPage: Int!) {
            queryScenes(
                input: { 
                    studios: \(studiosFilter),
                    performers: \(performersFilter),
                    date: \(dateFilter),
                    tags: \(tagsFilter),
                    page: $page,
                    per_page: $perPage
                }
            ) {
                count
                scenes {
                    \(fields)
                }
            }
        }
        """
    }
    
    // MARK: - Studio Queries
    
    static let favoriteStudios = """
        query QueryStudios($page: Int!, $perPage: Int!) {
            queryStudios(input: { is_favorite: true, page: $page, per_page: $perPage }) {
                count
                studios {
                    \(studioFields)
                }
            }
        }
    """
    
    // MARK: - Helper Functions
    
    /// Builds an array of excluded tag IDs based on filter options
    static func buildExcludedTags(excludeVR: Bool, excludeCompilations: Bool) -> [String] {
        var tags: [String] = []
        if excludeVR { tags.append(vrTagId) }
        if excludeCompilations { tags.append(compilationTagId) }
        return tags
    }
}
