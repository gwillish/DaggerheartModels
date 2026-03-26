//
//  ContentStoreError.swift
//  Encounter
//
//  Typed errors for ContentStore, ContentFetcher, and ContentWriter.
//

import Foundation

/// Errors produced by the content loading and update pipeline.
nonisolated public enum ContentStoreError: Error, LocalizedError, Sendable {
  /// The source is currently throttled by exponential backoff.
  case fetchThrottled(sourceID: String, until: Date)
  /// A network or URLSession error occurred during fetch.
  case networkError(sourceID: String, underlying: Error)
  /// The downloaded data could not be decoded as valid content.
  case decodingFailed(sourceID: String, underlying: Error)
  /// The atomic file write failed.
  case writeFailed(sourceID: String, underlying: Error)
  /// Reading a content file from disk failed.
  case readFailed(sourceID: String, underlying: Error)
  /// The content is structurally invalid (e.g. empty adversary ID).
  case invalidContent(sourceID: String, reason: String)

  public var errorDescription: String? {
    switch self {
    case .fetchThrottled(let id, let until):
      return "Source '\(id)' is throttled until \(until.formatted(.dateTime))."
    case .networkError(let id, let error):
      return "Network error for '\(id)': \(error.localizedDescription)"
    case .decodingFailed(let id, let error):
      return "Decode failed for '\(id)': \(error.localizedDescription)"
    case .writeFailed(let id, let error):
      return "Write failed for '\(id)': \(error.localizedDescription)"
    case .readFailed(let id, let error):
      return "Read failed for '\(id)': \(error.localizedDescription)"
    case .invalidContent(let id, let reason):
      return "Invalid content from '\(id)': \(reason)"
    }
  }
}
