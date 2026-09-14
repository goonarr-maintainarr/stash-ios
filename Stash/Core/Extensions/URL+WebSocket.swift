import Foundation

extension URL {
    /// Converts an http/https URL to its ws/wss equivalent.
    var webSocketURL: URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        if components?.scheme == "http" {
            components?.scheme = "ws"
        } else if components?.scheme == "https" {
            components?.scheme = "wss"
        }
        return components?.url ?? self
    }
}
