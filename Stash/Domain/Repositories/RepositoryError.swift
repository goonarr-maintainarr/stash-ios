import Foundation

// RepositoryError is now defined in AppError.swift as part of the standardized error hierarchy.
// This file is kept for backward compatibility during migration.

// Note: The new RepositoryError has the following cases:
// - .invalidConfiguration
// - .notFound
// - .alreadyExists
// - .concurrencyConflict
// - .syncFailed(String)
//
// Migration guide:
// - .invalidConfiguration(String) -> .invalidConfiguration (message now in context)
// - .networkError(Error) -> Should be wrapped in AppError.network() at call site
// - .apiError(String) -> Should be wrapped in AppError.stashAPI() or similar
// - .cacheError(Error) -> Should be wrapped in AppError.database() at call site
// - .notFound -> .notFound (same)
// - .unknown(Error) -> Should be wrapped in AppError.unknown() at call site
