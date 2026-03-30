//
//  ContentFingerprint.swift
//  Encounter
//
//  Combined content fingerprint for staleness detection.
//  Stored on ContentSource after each successful fetch.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif
import Foundation

/// A combined fingerprint for a downloaded content pack.
///
/// `sha256` validates local file integrity and detects actual content changes.
/// `etag` enables conditional HTTP GET (`If-None-Match`) to skip re-downloading
/// unchanged content, saving bandwidth.
///
/// Both fields are computed from the HTTP response at fetch time and persisted
/// as part of ``ContentSource``.
nonisolated public struct ContentFingerprint: Codable, Equatable, Hashable, Sendable {
  /// SHA-256 hex digest of the downloaded bytes.
  public let sha256: String
  /// HTTP ETag from the last successful response, if the server provided one.
  public let etag: String?

  public init(sha256: String, etag: String? = nil) {
    self.sha256 = sha256
    self.etag = etag
  }
}
