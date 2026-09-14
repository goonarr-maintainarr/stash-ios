import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "StashClient")

// MARK: - Protocol

/// Protocol defining the Stash GraphQL API client interface.
/// Stash uses GraphQL for all data queries and mutations.
protocol StashClientProtocol: Sendable {
    /// Executes a GraphQL query.
    func fetch<T: Decodable>(query: String, variables: [String: Any]?, url: URL, apiKey: String) async throws -> T
    
    /// Fetches library statistics.
    func fetchStats(url: URL, apiKey: String) async throws -> Stats
}


// MARK: - Client Implementation

/// GraphQL client for communicating with Stash servers.
///
/// This client provides:
/// - Automatic retry logic with exponential backoff for network failures
/// - GraphQL error handling and parsing
/// - Dedicated methods for common queries (stats, logs, job queue)
///
/// All methods require the server URL and API key to be passed explicitly,
/// allowing the same client to communicate with multiple Stash instances.
final class StashClient: StashClientProtocol, Sendable {
    
    // MARK: - Configuration
    
    /// Maximum number of retry attempts for network failures
    private static let maxRetries = 3
    
    /// Base delay in seconds for exponential backoff (1s, 2s, 4s)
    private static let baseRetryDelay: Double = 1.0
    
    private let session: URLSession
    private let settings: any SettingsStoreProtocol
    
    // MARK: - Initialization
    
    init(settings: any SettingsStoreProtocol = SettingsStore.shared) {
        self.session = URLSession(configuration: GraphQLClientConfiguration.stashConfiguration())
        self.settings = settings
    }
    
    // MARK: - Public Methods
    
    /// Executes a GraphQL query with automatic retry logic.
    /// - Parameters:
    ///   - query: The GraphQL query string
    ///   - variables: Optional variables for the query
    ///   - url: The Stash server GraphQL endpoint URL
    ///   - apiKey: The API key for authentication
    /// - Returns: Decoded response of type T
    func fetch<T: Decodable>(query: String, variables: [String: Any]?, url: URL, apiKey: String) async throws -> T {
        let result: T = try await fetchWithRetry(query: query, variables: variables, url: url, apiKey: apiKey, retries: Self.maxRetries)
        return result
    }
    
    /// Fetches library statistics from Stash.
    func fetchStats(url: URL, apiKey: String) async throws -> Stats {
        logger.debug("📊 Fetching library stats")
        struct StatsResult: Decodable {
            let stats: Stats
        }
        let result: StatsResult = try await fetch(query: StashQueries.stats, variables: nil, url: url, apiKey: apiKey)
        logger.info("✅ Fetched library stats: \(result.stats.scene_count) scenes, \(result.stats.performer_count) performers")
        return result.stats
    }
    
    /// Fetches the job queue from Stash.
    func fetchJobQueue(url: URL, apiKey: String) async throws -> [Job] {
        logger.debug("📋 Fetching job queue")
        let result: JobQueueResult = try await fetch(query: StashQueries.jobQueue, variables: nil, url: url, apiKey: apiKey)
        logger.debug("✅ Fetched \(result.jobQueue?.count ?? 0) jobs")
        return result.jobQueue ?? []
    }
    
    /// Fetches recent log entries from Stash.
    func fetchLogs(url: URL, apiKey: String) async throws -> [Log] {
        logger.debug("📝 Fetching recent logs")
        let result: LogsResult = try await fetch(query: StashQueries.logs, variables: nil, url: url, apiKey: apiKey)
        logger.debug("✅ Fetched \(result.logs?.count ?? 0) log entries")
        return result.logs ?? []
    }
    
    // MARK: - Private Helpers
    
    /// Performs a fetch with automatic retry logic for network failures.
    private func fetchWithRetry<T: Decodable>(query: String, variables: [String: Any]?, url: URL, apiKey: String, retries: Int) async throws -> T {
        do {
            return try await performFetch(query: query, variables: variables, url: url, apiKey: apiKey)
        } catch {
            guard retries > 0 else {
                throw error
            }
            
            // Only retry on network-related errors
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed:
                    let attempt = Self.maxRetries - retries + 1
                    let delay = UInt64(Self.baseRetryDelay * pow(2.0, Double(attempt - 1)) * 1_000_000_000)
                    logger.warning("⚠️ Network error (\(urlError.localizedDescription)). Retrying in \(Double(delay) / 1_000_000_000)s... (\(retries) attempts left)")
                    try? await Task.sleep(nanoseconds: delay)
                    return try await fetchWithRetry(query: query, variables: variables, url: url, apiKey: apiKey, retries: retries - 1)
                default:
                    throw error
                }
            }
            throw error
        }
    }
    
    /// Performs the actual GraphQL fetch operation using shared executor.
    private func performFetch<T: Decodable>(query: String, variables: [String: Any]?, url: URL, apiKey: String) async throws -> T {
        let executor = GraphQLExecutor(session: session, logger: logger)
        return try await executor.execute(
            query: query,
            variables: variables ?? [:],
            url: url,
            apiKey: apiKey,
            acceptedStatusCodes: 200...299,
            createEncodingError: { StashAPIError.networkError(.encodingFailed) },
            createInvalidResponseError: { StashAPIError.invalidResponse },
            createHttpError: { StashAPIError.networkError(.httpError(statusCode: $0, response: nil)) },
            createDecodingError: { StashAPIError.networkError(.decodingFailed($0)) },
            createApiError: { StashAPIError.graphQLErrors($0) }
        )
    }
}
