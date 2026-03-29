//
//  EncounterStore.swift
//  Encounter
//
//  Persistence layer for EncounterDefinition documents.
//  Each definition is stored as a JSON file named <UUID>.encounter.json
//  in a single flat directory.
//
//  Storage location (resolved once at app launch via defaultDirectory()):
//    iCloud available:  <ubiquityContainer>/Documents/Encounters/
//    iCloud unavailable: <applicationSupport>/Encounters/
//
//  iCloud Drive syncs the ubiquity container automatically with no
//  CloudKit record API required. Requires the iCloud Documents capability
//  and an NSUbiquitousContainers entry in Info.plist.
//

import DHModels
import Foundation
import Observation

// MARK: - EncounterStoreError

/// Errors thrown by ``EncounterStore`` operations.
nonisolated public enum EncounterStoreError: Error, LocalizedError, Sendable {
  case notFound(UUID)
  case saveFailed(UUID, String)
  case deleteFailed(UUID, String)

  public var errorDescription: String? {
    switch self {
    case .notFound(let id):
      return "No encounter definition found with ID \(id)."
    case .saveFailed(let id, let description):
      return "Failed to save encounter \(id): \(description)"
    case .deleteFailed(let id, let description):
      return "Failed to delete encounter \(id): \(description)"
    }
  }
}

// MARK: - EncounterStore

/// Persistence layer for ``EncounterDefinition`` documents.
///
/// Each definition is stored as a single JSON file (`<UUID>.encounter.json`)
/// in a flat directory. iCloud Drive syncs the directory automatically when
/// the app is configured with the iCloud Documents capability.
///
/// Inject into the SwiftUI environment at app launch:
///
/// ```swift
/// @State private var store = EncounterStore(directory: EncounterStore.localDirectory)
///
/// var body: some Scene {
///     WindowGroup {
///         ContentView()
///             .environment(store)
///             .task {
///                 let dir = await EncounterStore.defaultDirectory()
///                 store.relocate(to: dir)
///                 await store.load()
///             }
///     }
/// }
/// ```
@Observable @MainActor
public final class EncounterStore {

  // MARK: Public State

  /// All loaded encounter definitions, sorted by `modifiedAt` descending.
  public private(set) var definitions: [EncounterDefinition] = []

  /// The directory where `.encounter.json` files are stored.
  public private(set) var directory: URL

  /// `true` while a `load()` is in progress.
  public private(set) var isLoading = false

  /// Non-nil if the last `load()` failed at the directory level.
  public private(set) var loadError: (any Error)?

  // MARK: Reentrancy tracking
  private var savesInFlight: Set<UUID> = []
  private var deletesInFlight: Set<UUID> = []
  private var duplicatesInFlight: Set<UUID> = []
  private var createInFlight = false

  // MARK: - Init

  public init(directory: URL) {
    self.directory = directory
  }

  // MARK: - Directory Resolution

  /// Returns the preferred storage directory, using iCloud when available.
  ///
  /// `url(forUbiquityContainerIdentifier:)` may perform file-system operations.
  /// Marked `@concurrent` so the body runs on the cooperative thread pool even
  /// when called from a `@MainActor` context (required in Swift 6.2+).
  @concurrent
  nonisolated public static func defaultDirectory() async -> URL {
    await resolveDefaultDirectory()
  }

  @concurrent
  nonisolated private static func resolveDefaultDirectory() async -> URL {
    #if canImport(Darwin)
      let fm = FileManager.default
      if let ubiquity = fm.url(forUbiquityContainerIdentifier: nil) {
        let dir =
          ubiquity
          .appending(path: "Documents")
          .appending(path: "Encounters")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
      }
    #endif
    return Self.localDirectory
  }

  @concurrent
  nonisolated private static func readAllEncounters(from dir: URL) async throws
    -> [EncounterDefinition]
  {
    let fm = FileManager.default
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let contents = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [])
    let decoder = JSONDecoder()
    return
      contents
      .filter { $0.lastPathComponent.hasSuffix(".encounter.json") }
      .compactMap { url -> EncounterDefinition? in
        guard let data = try? Data(contentsOf: url),
          let def = try? decoder.decode(EncounterDefinition.self, from: data)
        else { return nil }
        return def
      }
  }

  @concurrent
  nonisolated private static func writeEncounter(_ definition: EncounterDefinition, to url: URL)
    async throws
  {
    // Create directory defensively so persist() works even if
    // called before load() has had a chance to create it.
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    // JSONEncoder is allocated per-call because JSONEncoder is not
    // Sendable in Swift 6 and cannot be safely shared across tasks.
    let data = try JSONEncoder().encode(definition)
    try data.write(to: url, options: .atomic)
  }

  @concurrent
  nonisolated private static func deleteEncounter(at url: URL) async throws {
    try FileManager.default.removeItem(at: url)
  }

  /// Local Application Support directory. A pure URL — no file I/O performed.
  nonisolated public static var localDirectory: URL {
    let base =
      FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    return base.appending(path: "Encounters")
  }

  /// Switches the storage directory and clears `definitions`.
  /// Call `load()` afterwards to populate from the new location.
  public func relocate(to newDirectory: URL) {
    directory = newDirectory
    definitions = []
  }

  // MARK: - Load

  /// Reads all `.encounter.json` files from `directory`.
  ///
  /// If a load is already in progress, this call returns immediately without
  /// waiting for the existing load to complete and without triggering a second
  /// load. Callers that need fresh data should await the first load before calling again.
  ///
  /// Corrupt or unreadable individual files are skipped silently.
  /// Valid definitions are published via ``definitions``, sorted by
  /// `modifiedAt` descending. Directory-level errors are stored in ``loadError``.
  public func load() async {
    // EncounterStore is a single shared instance loaded once at app startup.
    // Concurrent calls to load() are a programming error, not a normal operating
    // condition — use precondition so violations surface immediately in debug builds.
    precondition(!isLoading, "load() called while a load is already in progress")
    isLoading = true
    loadError = nil
    defer { isLoading = false }

    let dir = directory
    do {
      let loaded = try await Self.readAllEncounters(from: dir)
      definitions = loaded.sorted { $0.modifiedAt > $1.modifiedAt }
    } catch {
      loadError = error
    }
  }

  // MARK: - Create

  /// Creates a new ``EncounterDefinition``, persists it, and inserts it
  /// into ``definitions``.
  ///
  /// If a create operation is already in flight, this call returns immediately
  /// without creating a second definition. Callers that need to ensure creation
  /// occurred should await this call to completion before calling again.
  public func create(name: String) async throws {
    guard !createInFlight else { return }
    createInFlight = true
    defer { createInFlight = false }
    let def = EncounterDefinition(name: name)
    try await persist(def)
    insertSorted(def)
  }

  // MARK: - Save

  /// Persists an updated definition to disk and refreshes ``definitions``.
  ///
  /// The store stamps `modifiedAt = .now` before writing, so the sort order
  /// invariant is maintained regardless of whether the caller has updated
  /// individual properties through their `didSet` observers.
  ///
  /// If a save for the same definition ID is already in flight, this call
  /// returns immediately without writing or queuing. Callers that need to
  /// ensure the latest value is persisted should await the first save before
  /// calling again.
  ///
  /// - Throws: ``EncounterStoreError/notFound(_:)`` if the ID is not in
  ///   the current ``definitions``.
  public func save(_ definition: EncounterDefinition) async throws {
    guard !savesInFlight.contains(definition.id) else { return }
    savesInFlight.insert(definition.id)
    defer { savesInFlight.remove(definition.id) }
    guard definitions.contains(where: { $0.id == definition.id }) else {
      throw EncounterStoreError.notFound(definition.id)
    }
    var stamped = definition
    stamped.modifiedAt = .now
    try await persist(stamped)
    updateInPlace(stamped)
  }

  // MARK: - Delete

  /// Removes a definition from memory and deletes its backing file.
  ///
  /// If a delete for the same ID is already in flight, this call returns
  /// immediately. Callers that need to ensure deletion occurred should await
  /// the first call to completion before calling again.
  ///
  /// - Throws: ``EncounterStoreError/notFound(_:)`` if the ID is unknown.
  public func delete(id: UUID) async throws {
    guard !deletesInFlight.contains(id) else { return }
    deletesInFlight.insert(id)
    defer { deletesInFlight.remove(id) }
    guard definitions.contains(where: { $0.id == id }) else {
      throw EncounterStoreError.notFound(id)
    }
    let url = fileURL(for: id)
    do {
      try await Self.deleteEncounter(at: url)
    } catch {
      throw EncounterStoreError.deleteFailed(id, error.localizedDescription)
    }
    definitions.removeAll { $0.id == id }
  }

  // MARK: - Duplicate

  /// Creates an independent copy of an existing definition with a new UUID,
  /// `createdAt`, and a `" (Copy)"` suffix on the name. Persists it and
  /// adds it to ``definitions``.
  ///
  /// If a duplicate for the same source ID is already in flight, this call
  /// returns immediately without creating a second copy. Callers that need
  /// a second copy should await the first call to completion before calling again.
  ///
  /// The copy is inserted with `createdAt = modifiedAt = .now`, so it sorts
  /// to the top of ``definitions``.
  ///
  /// - Note: All content fields of ``EncounterDefinition`` must be listed
  ///   explicitly here. When adding new fields to `EncounterDefinition`,
  ///   update this method to include them.
  ///
  /// - Throws: ``EncounterStoreError/notFound(_:)`` if the source ID is unknown.
  public func duplicate(id: UUID) async throws {
    guard !duplicatesInFlight.contains(id) else { return }
    duplicatesInFlight.insert(id)
    defer { duplicatesInFlight.remove(id) }
    guard let original = definitions.first(where: { $0.id == id }) else {
      throw EncounterStoreError.notFound(id)
    }
    let copy = EncounterDefinition(
      name: "\(original.name) (Copy)",
      adversaryIDs: original.adversaryIDs,
      environmentIDs: original.environmentIDs,
      playerConfigs: original.playerConfigs,
      gmNotes: original.gmNotes
    )
    try await persist(copy)
    insertSorted(copy)
  }

  // MARK: - Private Helpers

  private func fileURL(for id: UUID) -> URL {
    directory.appending(path: "\(id.uuidString).encounter.json")
  }

  private func persist(_ definition: EncounterDefinition) async throws {
    let url = fileURL(for: definition.id)
    do {
      try await Self.writeEncounter(definition, to: url)
    } catch {
      throw EncounterStoreError.saveFailed(definition.id, error.localizedDescription)
    }
  }

  // Appends then re-sorts the full array. O(n log n), appropriate for
  // GM-scale encounter lists (tens to low hundreds of items).
  private func insertSorted(_ definition: EncounterDefinition) {
    definitions.append(definition)
    definitions.sort { $0.modifiedAt > $1.modifiedAt }
  }

  private func updateInPlace(_ definition: EncounterDefinition) {
    guard let idx = definitions.firstIndex(where: { $0.id == definition.id }) else {
      assertionFailure("updateInPlace called for unknown id \(definition.id)")
      return
    }
    definitions[idx] = definition
    definitions.sort { $0.modifiedAt > $1.modifiedAt }
  }
}
