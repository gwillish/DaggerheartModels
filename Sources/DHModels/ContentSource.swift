//
//  ContentSource.swift
//  Encounter
//
//  A registered community content source (a URL pointing to a .dhpack file,
//  or a locally imported .dhpack file with no remote URL).
//  Persisted to Application Support so the source list survives app restarts.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif
import Foundation

/// A registered content source for community adversary and environment packs.
///
/// Sources come in two flavours:
/// - **Remote** — a version-pinned URL (see ADR-0017). The user adds a URL;
///   `ContentStore` fetches and caches the pack. Refresh is user-initiated with
///   exponential backoff on failures (see ADR-0027).
/// - **Local import** — a `.dhpack` file opened from Files, AirDrop, or Mail.
///   `url` is `nil`. The pack content is written to disk and reloaded on every
///   launch exactly like a remote source. Removal requires explicit user action
///   (tracked in a separate issue; `ContentStore.removeSource(id:)` is the API).
///
/// ## Persistence
/// The array of registered `ContentSource` values is stored in
/// `Application Support/gwillish.Encounter/sources/index.json`.
/// The pack content itself lives in
/// `Application Support/gwillish.Encounter/sources/<id>/`.
///
/// ## Date fields
/// All `Date` properties are stored as ISO8601 Zulu strings per ADR-0013.
nonisolated public struct ContentSource: Codable, Identifiable, Equatable, Hashable, Sendable {

  /// Stable, lowercase slug identifying this source, e.g. `"expanded-adversary-compendium"`.
  /// Used as a directory name and as the key in ``Compendium``'s sources tier.
  public let id: String

  /// Display name shown in the source management UI.
  public var name: String

  /// Remote URL of the `.dhpack` file, or `nil` for locally imported packs.
  ///
  /// When `nil`, `ContentStore.fetchSource(id:)` is a no-op for this source.
  /// Must be version-pinned when set (see ADR-0017).
  public var url: URL?

  /// ISO8601 Zulu date of the last successful fetch or import.
  /// Nil if this source has never been successfully loaded.
  /// Always stored and compared in UTC per ADR-0013.
  public var lastFetched: Date?

  /// Content fingerprint from the last successful fetch.
  /// Nil for locally imported packs (no HTTP response to fingerprint).
  public var fingerprint: ContentFingerprint?

  /// Number of consecutive fetch failures since the last successful fetch.
  /// Always 0 for local imports (they are never re-fetched automatically).
  public private(set) var consecutiveFailures: Int

  /// The earliest date at which the next fetch attempt is permitted.
  /// Nil means fetching is allowed immediately, or the source is a local import.
  /// Set by exponential backoff whenever a remote fetch fails.
  public private(set) var nextAllowedFetch: Date?

  // MARK: - Init

  /// Create a remote source (with a URL to fetch from).
  public init(
    id: String,
    name: String,
    url: URL,
    lastFetched: Date? = nil,
    fingerprint: ContentFingerprint? = nil,
    consecutiveFailures: Int = 0,
    nextAllowedFetch: Date? = nil
  ) {
    self.id = id
    self.name = name
    self.url = url
    self.lastFetched = lastFetched
    self.fingerprint = fingerprint
    self.consecutiveFailures = consecutiveFailures
    self.nextAllowedFetch = nextAllowedFetch
  }

  /// Create a local import source (no remote URL).
  public init(id: String, name: String, importedAt date: Date = .now) {
    self.id = id
    self.name = name
    self.url = nil
    self.lastFetched = date
    self.fingerprint = nil
    self.consecutiveFailures = 0
    self.nextAllowedFetch = nil
  }

  // MARK: - Convenience

  /// `true` if this source was locally imported rather than fetched from a URL.
  public var isLocalImport: Bool { url == nil }

  // MARK: - Throttle check

  /// Returns `true` if backoff is currently active for this source.
  /// Always `false` for local imports.
  public func isThrottled(at date: Date = .now) -> Bool {
    guard let next = nextAllowedFetch else { return false }
    return date < next
  }

  // MARK: - Backoff mutations
  //
  // These return new values rather than mutating in place, keeping ContentSource
  // a pure value type and making the state transitions easy to test.

  /// Returns a copy with exponential backoff applied for one additional failure.
  ///
  /// Delay formula: `min(1h × 2^consecutiveFailures, 7 days)`
  /// - 1st failure  → 1 hour
  /// - 2nd failure  → 2 hours
  /// - 3rd failure  → 4 hours
  /// - …
  /// - 10th failure → capped at 7 days
  public func recordingFailure(at date: Date = .now) -> ContentSource {
    var updated = self
    let shiftAmount = min(consecutiveFailures, 62)
    let hours = Double(1 << shiftAmount)  // 1, 2, 4, 8, …
    let delay = min(hours * 3_600, 7 * 24 * 3_600)  // cap at 7 days
    updated.consecutiveFailures += 1
    updated.nextAllowedFetch = date.addingTimeInterval(delay)
    return updated
  }

  /// Returns a copy recording a successful remote fetch, resetting all backoff state.
  public func recordingSuccess(fingerprint: ContentFingerprint, at date: Date = .now)
    -> ContentSource
  {
    var updated = self
    updated.lastFetched = date
    updated.fingerprint = fingerprint
    updated.consecutiveFailures = 0
    updated.nextAllowedFetch = nil
    return updated
  }
}
