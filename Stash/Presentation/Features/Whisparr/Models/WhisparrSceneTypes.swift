import Foundation

/// Sorting options specific to Whisparr scene lists.
enum WhisparrSortType: String, CaseIterable, Identifiable {
    /// Sort alphabetically by title.
    case title = "title"
    /// Sort by year released.
    case year = "year"
    /// Sort by date added to Whisparr.
    case dateAdded = "date_added"
    /// Sort by file size.
    case fileSize = "file_size"
    /// Sort by digital release date.
    case releaseDate = "release_date"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .title: return "Title"
        case .year: return "Year"
        case .dateAdded: return "Added"
        case .fileSize: return "File Size"
        case .releaseDate: return "Digital Release"
        }
    }
    
    var iconName: String {
        switch self {
        case .title: return "textformat.abc"
        case .year: return "calendar"
        case .dateAdded: return "calendar.badge.plus"
        case .fileSize: return "internaldrive"
        case .releaseDate: return "play.tv"
        }
    }
}

/// Filter criteria for Whisparr scene lists.
enum WhisparrFilterType: String, CaseIterable, Identifiable {
    /// Show all movies.
    case all = "all"
    /// Show only monitored movies.
    case monitored = "monitored"
    /// Show only unmonitored movies.
    case unmonitored = "unmonitored"
    /// Show movies missing from disk.
    case missing = "missing"
    /// Show movies monitored but missing from disk.
    case wanted = "wanted"
    /// Show movies available on disk.
    case downloaded = "downloaded"
    /// Show movies available on disk but not monitored.
    case dangling = "dangling"
    /// Show movies that do not meet the quality profile cutoff.
    case cutoffUnmet = "cutoff_unmet"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .all: return "All Movies"
        case .monitored: return "Monitored"
        case .unmonitored: return "Unmonitored"
        case .missing: return "Missing"
        case .wanted: return "Wanted"
        case .downloaded: return "Downloaded"
        case .dangling: return "Dangling"
        case .cutoffUnmet: return "Cutoff Unmet"
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "rectangle.stack"
        case .monitored: return "bookmark.fill"
        case .unmonitored: return "bookmark"
        case .missing: return "exclamationmark.magnifyingglass"
        case .wanted: return "sparkle.magnifyingglass"
        case .downloaded: return "internaldrive"
        case .dangling: return "questionmark.square"
        case .cutoffUnmet: return "scissors"
        }
    }
}
