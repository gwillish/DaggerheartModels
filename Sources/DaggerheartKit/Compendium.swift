//
//  Compendium.swift
//  Encounter
//
//  Observable data store that loads Daggerheart catalog JSON from the
//  app bundle and provides lookup APIs for adversaries and environments.
//
//  Data sources (bundled JSON files in Encounter/Resources/):
//    adversaries.json  — from seansbox/daggerheart-srd .build/json/
//    environments.json — from seansbox/daggerheart-srd .build/json/
//
//  Both files contain a top-level JSON array of objects.
//  See docs/data-schema.md for the complete field reference.
//

import DaggerheartModels
import Foundation
import Logging
import Observation

// MARK: - CompendiumError

/// Errors that can occur while loading compendium data.
nonisolated public enum CompendiumError: Error, LocalizedError {
  case fileNotFound(String)
  case decodingFailed(String, Error)

  public var errorDescription: String? {
    switch self {
    case .fileNotFound(let name):
      return "Compendium resource '\(name)' not found in app bundle."
    case .decodingFailed(let name, let underlying):
      return "Failed to decode '\(name)': \(underlying.localizedDescription)"
    }
  }
}

// MARK: - Compendium

/// The central catalog of Daggerheart adversaries and environments.
///
/// `Compendium` is an `@Observable` class intended to be injected into
/// the SwiftUI environment once at app launch and shared across all views.
///
/// ```swift
/// // In EncounterApp.swift:
/// @State private var compendium = Compendium()
///
/// var body: some Scene {
///     WindowGroup {
///         ContentView()
///             .environment(compendium)
///             .task { try? await compendium.load() }
///     }
/// }
/// ```
///
/// ## Loading
/// Call ``load()`` once during app startup. It decodes both JSON files
/// from the bundle on a background task and publishes the results.
///
/// ## Homebrew
/// Call ``addAdversary(_:)`` / ``addEnvironment(_:)`` to merge homebrew
/// entries at runtime. Homebrew entries with the same `id` as an SRD entry
/// replace the SRD version.
@MainActor
@Observable
public final class Compendium {

  private let logger = Logger(label: "Compendium")

  // MARK: Published State

  /// SRD adversaries loaded from the bundle, keyed by slug.
  private var srdAdversariesByID: [String: Adversary] = [:]

  /// Community source packs, keyed by source ID then by adversary slug.
  /// Allows packs to be added and removed independently without a full rebuild.
  private var sourcesAdversariesByID: [String: [String: Adversary]] = [:]

  /// Homebrew adversaries added at runtime, keyed by slug.
  /// Homebrew entries with the same `id` as any source or SRD entry take priority.
  private var homebrewAdversariesByID: [String: Adversary] = [:]

  /// SRD environments loaded from the bundle, keyed by slug.
  private var srdEnvironmentsByID: [String: DaggerheartEnvironment] = [:]

  /// Community source pack environments, keyed by source ID then by environment slug.
  private var sourcesEnvironmentsByID: [String: [String: DaggerheartEnvironment]] = [:]

  /// Homebrew environments added at runtime, keyed by slug.
  private var homebrewEnvironmentsByID: [String: DaggerheartEnvironment] = [:]

  /// Cached result of the last adversary merge. `nil` when the cache is dirty.
  private var _cachedAdversariesByID: [String: Adversary]?

  /// Cached result of the last environment merge. `nil` when the cache is dirty.
  private var _cachedEnvironmentsByID: [String: DaggerheartEnvironment]?

  /// All adversaries merged in priority order: homebrew → sources → srd.
  /// Within sources, higher-priority packs should be inserted last to win conflicts.
  /// Result is cached; invalidated whenever any source bucket changes.
  public var adversariesByID: [String: Adversary] {
    if let cached = _cachedAdversariesByID { return cached }
    var merged = srdAdversariesByID
    for packAdversaries in sourcesAdversariesByID.values {
      merged.merge(packAdversaries) { _, source in source }
    }
    merged.merge(homebrewAdversariesByID) { _, homebrew in homebrew }
    _cachedAdversariesByID = merged
    return merged
  }

  /// All environments merged in priority order: homebrew → sources → srd.
  /// Result is cached; invalidated whenever any source bucket changes.
  public var environmentsByID: [String: DaggerheartEnvironment] {
    if let cached = _cachedEnvironmentsByID { return cached }
    var merged = srdEnvironmentsByID
    for packEnvironments in sourcesEnvironmentsByID.values {
      merged.merge(packEnvironments) { _, source in source }
    }
    merged.merge(homebrewEnvironmentsByID) { _, homebrew in homebrew }
    _cachedEnvironmentsByID = merged
    return merged
  }

  /// Sorted array of all adversaries (for list views).
  public var adversaries: [Adversary] {
    adversariesByID.values.sorted { $0.name < $1.name }
  }

  /// Sorted array of all environments.
  public var environments: [DaggerheartEnvironment] {
    environmentsByID.values.sorted { $0.name < $1.name }
  }

  /// Sorted array of homebrew-only adversaries.
  public var homebrewAdversaries: [Adversary] {
    homebrewAdversariesByID.values.sorted { $0.name < $1.name }
  }

  /// Sorted array of homebrew-only environments.
  public var homebrewEnvironments: [DaggerheartEnvironment] {
    homebrewEnvironmentsByID.values.sorted { $0.name < $1.name }
  }

  /// `true` while JSON loading is in progress.
  public private(set) var isLoading: Bool = false

  /// Non-nil if the last load attempt failed.
  public private(set) var loadError: CompendiumError?

  // MARK: - Init

  /// The bundle used to locate SRD JSON resources.
  private let bundle: Bundle

  /// Creates a compendium.
  ///
  /// - Parameter bundle: The bundle containing `adversaries.json` and
  ///   `environments.json`. Pass `nil` (the default) to use the `DaggerheartKit`
  ///   module bundle, which ships the full SRD data. Pass an explicit bundle in
  ///   tests or to exercise the error path when resources are absent.
  public init(bundle: Bundle? = nil) {
    // Bundle.module is internal and cannot appear in a default argument value,
    // so we resolve it here inside the module body instead.
    self.bundle = bundle ?? .module
  }

  // MARK: - Loading

  /// Load the SRD data from bundle resources.
  ///
  /// JSON decoding is performed on a background task; results are published
  /// back on the main actor. Safe to call multiple times — concurrent calls
  /// while a load is already in progress are ignored.
  ///
  /// Throws a ``CompendiumError`` if a resource is missing or malformed.
  /// The error is also stored in ``loadError`` for SwiftUI observation.
  public func load() async throws {
    guard !isLoading else {
      logger.debug("load() called while already loading — skipped")
      return
    }
    isLoading = true
    loadError = nil
    logger.info("Compendium load started")

    defer { isLoading = false }

    do {
      async let adversaries = Self.decodeArray(
        Adversary.self, fromResource: "adversaries", bundle: bundle)
      async let environments = Self.decodeArray(
        DaggerheartEnvironment.self, fromResource: "environments", bundle: bundle)
      let (loadedAdversaries, loadedEnvironments) = try await (adversaries, environments)

      srdAdversariesByID = Dictionary(uniqueKeysWithValues: loadedAdversaries.map { ($0.id, $0) })
      srdEnvironmentsByID = Dictionary(uniqueKeysWithValues: loadedEnvironments.map { ($0.id, $0) })
      _cachedAdversariesByID = nil
      _cachedEnvironmentsByID = nil
      logger.info(
        "Compendium loaded \(loadedAdversaries.count) adversaries, \(loadedEnvironments.count) environments"
      )
    } catch let error as CompendiumError {
      loadError = error
      logger.error("Compendium load failed: \(error.localizedDescription)")
      throw error
    } catch {
      let wrapped = CompendiumError.decodingFailed("unknown", error)
      loadError = wrapped
      logger.error("Compendium load failed (unexpected): \(error)")
      throw wrapped
    }
  }

  // MARK: - Lookup

  /// Look up an adversary by slug, respecting the full priority order:
  /// homebrew → sources → srd.
  public func adversary(id: String) -> Adversary? {
    adversariesByID[id]
  }

  /// Look up an environment by slug, respecting the full priority order:
  /// homebrew → sources → srd.
  public func environment(id: String) -> DaggerheartEnvironment? {
    environmentsByID[id]
  }

  /// Return all adversaries for a given tier.
  public func adversaries(tier: Int) -> [Adversary] {
    adversaries.filter { $0.tier == tier }
  }

  /// Return all adversaries of a given type.
  public func adversaries(type: AdversaryType) -> [Adversary] {
    adversaries.filter { $0.type == type }
  }

  /// Full-text search across adversary names and descriptions.
  /// Uses `localizedStandardContains` for diacritic- and case-insensitive matching.
  public func searchAdversaries(query: String) -> [Adversary] {
    guard !query.isEmpty else { return adversaries }
    return adversaries.filter {
      $0.name.localizedStandardContains(query) || $0.description.localizedStandardContains(query)
    }
  }

  // MARK: - SRD Reload

  /// Replace the SRD adversary and environment dictionaries.
  ///
  /// Called by `ContentStore` after downloading a new SRD content pack.
  /// The swap is atomic from the observation system's perspective.
  public func replaceSRDContent(adversaries: [Adversary], environments: [DaggerheartEnvironment]) {
    srdAdversariesByID = Dictionary(uniqueKeysWithValues: adversaries.map { ($0.id, $0) })
    srdEnvironmentsByID = Dictionary(uniqueKeysWithValues: environments.map { ($0.id, $0) })
    _cachedAdversariesByID = nil
    _cachedEnvironmentsByID = nil
    logger.info(
      "Compendium SRD content replaced: \(adversaries.count) adversaries, \(environments.count) environments"
    )
  }

  // MARK: - Source Pack Management

  /// Install or replace a community source pack.
  ///
  /// The `sourceID` is the stable identifier for the pack (e.g. `"expanded-adversary-compendium"`).
  /// Calling this again with the same `sourceID` replaces the previous pack entirely.
  public func replaceSourceContent(
    sourceID: String,
    adversaries: [Adversary],
    environments: [DaggerheartEnvironment]
  ) {
    sourcesAdversariesByID[sourceID] = Dictionary(
      uniqueKeysWithValues: adversaries.map { ($0.id, $0) })
    sourcesEnvironmentsByID[sourceID] = Dictionary(
      uniqueKeysWithValues: environments.map { ($0.id, $0) })
    _cachedAdversariesByID = nil
    _cachedEnvironmentsByID = nil
    logger.info(
      "Compendium source '\(sourceID)' replaced: \(adversaries.count) adversaries, \(environments.count) environments"
    )
  }

  /// Remove a community source pack entirely.
  /// No-op if the `sourceID` is not present.
  public func removeSourceContent(sourceID: String) {
    sourcesAdversariesByID.removeValue(forKey: sourceID)
    sourcesEnvironmentsByID.removeValue(forKey: sourceID)
    _cachedAdversariesByID = nil
    _cachedEnvironmentsByID = nil
    logger.info("Compendium source '\(sourceID)' removed")
  }

  // MARK: - Homebrew

  /// Add or replace a homebrew adversary.
  /// Homebrew entries shadow SRD and source pack entries with the same `id`.
  public func addAdversary(_ adversary: Adversary) {
    homebrewAdversariesByID[adversary.id] = adversary
    _cachedAdversariesByID = nil
  }

  /// Remove a homebrew adversary by slug. No-op if not present.
  public func removeHomebrewAdversary(id: String) {
    homebrewAdversariesByID.removeValue(forKey: id)
    _cachedAdversariesByID = nil
  }

  /// Add or replace a homebrew environment.
  public func addEnvironment(_ environment: DaggerheartEnvironment) {
    homebrewEnvironmentsByID[environment.id] = environment
    _cachedEnvironmentsByID = nil
  }

  /// Remove a homebrew environment by slug. No-op if not present.
  public func removeHomebrewEnvironment(id: String) {
    homebrewEnvironmentsByID.removeValue(forKey: id)
    _cachedEnvironmentsByID = nil
  }

  // MARK: - Private Helpers

  nonisolated private static func decodeArray<T: Decodable>(
    _ type: T.Type, fromResource name: String, bundle: Bundle
  ) async throws -> [T] {
    guard let url = bundle.url(forResource: name, withExtension: "json") else {
      throw CompendiumError.fileNotFound("\(name).json")
    }
    do {
      let data = try Data(contentsOf: url)
      return try JSONDecoder().decode([T].self, from: data)
    } catch let error as CompendiumError {
      throw error
    } catch {
      throw CompendiumError.decodingFailed("\(name).json", error)
    }
  }
}
