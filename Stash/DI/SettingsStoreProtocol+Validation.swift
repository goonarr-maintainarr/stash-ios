import Foundation

extension SettingsStoreProtocol {
    /// Validates the Stash server configuration and returns the server URL.
    /// - Returns: The validated Stash server `URL`.
    /// - Throws: `AppError.repository(.invalidConfiguration)` if the URL is invalid or empty.
    func validateStashConfiguration() throws -> URL {
        guard let url = self.url else {
            throw AppError.repository(.invalidConfiguration)
        }
        return url
    }
    
    /// Validates the Whisparr integration configuration.
    /// - Throws: `AppError.repository(.invalidConfiguration)` if the Whisparr URL or API key is missing.
    func validateWhisparrConfiguration() throws {
        guard !whisparrUrl.isEmpty, !whisparrApiKey.isEmpty else {
            throw AppError.repository(.invalidConfiguration)
        }
    }
}
