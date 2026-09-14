import Foundation
import Combine

/// Indicates where data was fetched from
enum DataSource {
    /// Data came from local cache
    case cache
    
    /// Data came from API
    case api
    
    /// Data came from multiple sources
    case mixed
}
