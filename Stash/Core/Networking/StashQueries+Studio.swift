import Foundation

extension StashQueries {
    
    // MARK: - Studio Fragments
    
    static let studioFields = """
        id
        name
        image_path
        scene_count
        image_count
        gallery_count
        performer_count
        group_count
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
        details
        rating100
        favorite
        created_at
        updated_at
        o_counter
        ignore_auto_tag
        aliases
        urls
    """
    
    // MARK: - Studio Queries
    
    static func findStudios(searchText: String, page: Int, perPage: Int = 20, sort: String, direction: String = "ASC") -> String {
        return """
        query FindStudios {
            findStudios(filter: { q: "\(searchText)", per_page: \(perPage), page: \(page), sort: "\(sort)", direction: \(direction) }) {
                studios {
                    \(studioFields)
                    tags {
                        \(tagFields)
                    }
                    stash_ids {
                        stash_id
                        endpoint
                    }
                }
                count
            }
        }
        """
    }
    
    static func findStudio(id: String) -> String {
        return """
        query FindStudio {
            findStudio(id: "\(id)") {
                \(studioFields)
                tags {
                    \(tagFields)
                }
                stash_ids {
                    stash_id
                    endpoint
                }
            }
        }
        """
    }
    
    /// Find studios updated since a specific timestamp (for sync)
    static func findStudiosUpdatedSince(timestamp: String, page: Int = 1, perPage: Int = 100) -> String {
        return """
        query FindStudiosUpdatedSince {
            findStudios(
                filter: { per_page: \(perPage), page: \(page), sort: "updated_at", direction: DESC }
                studio_filter: { updated_at: { modifier: GREATER_THAN, value: "\(timestamp)" } }
            ) {
                studios {
                    \(studioFields)
                    tags {
                        \(tagFields)
                    }
                    stash_ids {
                        stash_id
                        endpoint
                    }
                }
                count
            }
        }
        """
    }
    static func findStudioTimestamps(page: Int, perPage: Int) -> String {
        return """
        query FindStudioTimestamps {
            findStudios(
                filter: { page: \(page), per_page: \(perPage) }
            ) {
                count
                studios {
                    id
                    updated_at
                }
            }
        }
        """
    }
    
    static func findStudiosScrape(name: String) -> String {
        let escapedName = name.replacingOccurrences(of: "\"", with: "\\\"")
        return """
        query FindStudiosScrape {
            findStudios(filter: { q: "\(escapedName)", page: 1, per_page: 5 }) {
                studios {
                    id
                    name
                }
            }
        }
        """
    }
}
