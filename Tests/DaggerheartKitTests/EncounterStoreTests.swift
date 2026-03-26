//
//  EncounterStoreTests.swift
//  DaggerheartKitTests
//
//  Unit tests for EncounterStore: create, save, delete, duplicate, load.
//  Also covers EncounterStoreError descriptions.
//

import DaggerheartModels
import Foundation
import Testing

@testable import DaggerheartKit

// MARK: - EncounterStoreError

struct EncounterStoreErrorTests {

  @Test func notFoundDescription() {
    let id = UUID()
    let error = EncounterStoreError.notFound(id)
    #expect(error.errorDescription == "No encounter definition found with ID \(id).")
  }

  @Test func saveFailedDescription() {
    let id = UUID()
    let underlying = CocoaError(.fileWriteNoPermission)
    let error = EncounterStoreError.saveFailed(id, underlying)
    #expect(error.errorDescription?.hasPrefix("Failed to save encounter \(id):") == true)
  }

  @Test func deleteFailedDescription() {
    let id = UUID()
    let underlying = CocoaError(.fileNoSuchFile)
    let error = EncounterStoreError.deleteFailed(id, underlying)
    #expect(error.errorDescription?.hasPrefix("Failed to delete encounter \(id):") == true)
  }
}

@MainActor struct EncounterStoreTests {

  private func makeStore() throws -> EncounterStore {
    let dir = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return EncounterStore(directory: dir)
  }

  // MARK: create

  @Test func createAddsToDefinitions() async throws {
    let store = try makeStore()
    try await store.create(name: "Bandit Camp")
    #expect(store.definitions.count == 1)
    #expect(store.definitions[0].name == "Bandit Camp")
  }

  @Test func createPersistsToFile() async throws {
    let store = try makeStore()
    try await store.create(name: "Bandit Camp")

    let store2 = EncounterStore(directory: store.directory)
    await store2.load()
    #expect(store2.definitions.count == 1)
    #expect(store2.definitions[0].name == "Bandit Camp")
  }

  @Test func createMultipleProducesDistinctDefinitions() async throws {
    let store = try makeStore()
    try await store.create(name: "Encounter A")
    try await store.create(name: "Encounter B")
    #expect(store.definitions.count == 2)
    let ids = store.definitions.map(\.id)
    #expect(Set(ids).count == 2)
  }

  // MARK: save

  @Test func savePersistsMutations() async throws {
    let store = try makeStore()
    try await store.create(name: "Original")
    var def = store.definitions[0]
    def.name = "Updated"
    def.gmNotes = "Remember the trap."
    try await store.save(def)

    let store2 = EncounterStore(directory: store.directory)
    await store2.load()
    #expect(store2.definitions.count == 1)
    #expect(store2.definitions[0].name == "Updated")
    #expect(store2.definitions[0].gmNotes == "Remember the trap.")
  }

  @Test func saveUpdatesInMemoryDefinition() async throws {
    let store = try makeStore()
    try await store.create(name: "Original")
    var def = store.definitions[0]
    def.name = "Renamed"
    try await store.save(def)
    #expect(store.definitions[0].name == "Renamed")
  }

  @Test func saveUnknownIDThrows() async throws {
    let store = try makeStore()
    let orphan = EncounterDefinition(name: "Ghost")
    await #expect(throws: (any Error).self) {
      try await store.save(orphan)
    }
  }

  // MARK: delete

  @Test func deleteRemovesFromDefinitions() async throws {
    let store = try makeStore()
    try await store.create(name: "Encounter A")
    try await store.create(name: "Encounter B")
    let idToDelete = try #require(store.definitions.first(where: { $0.name == "Encounter A" })).id

    try await store.delete(id: idToDelete)
    #expect(store.definitions.count == 1)
    #expect(store.definitions[0].name == "Encounter B")
  }

  @Test func deleteRemovesFileFromDisk() async throws {
    let store = try makeStore()
    try await store.create(name: "Temp")
    let id = store.definitions[0].id
    try await store.delete(id: id)

    let store2 = EncounterStore(directory: store.directory)
    await store2.load()
    #expect(store2.definitions.isEmpty)
  }

  @Test func deleteUnknownIDThrows() async throws {
    let store = try makeStore()
    await #expect(throws: (any Error).self) {
      try await store.delete(id: UUID())
    }
  }

  // MARK: duplicate

  @Test func duplicateCreatesIndependentCopy() async throws {
    let store = try makeStore()
    try await store.create(name: "Original")
    var def = store.definitions[0]
    def.gmNotes = "Some notes."
    try await store.save(def)

    try await store.duplicate(id: def.id)
    #expect(store.definitions.count == 2)

    let copy = try #require(store.definitions.first(where: { $0.id != def.id }))
    #expect(copy.name == "Original (Copy)")
    #expect(copy.gmNotes == "Some notes.")
    #expect(copy.createdAt >= def.createdAt)
  }

  @Test func duplicateMutationDoesNotAffectOriginal() async throws {
    let store = try makeStore()
    try await store.create(name: "Original")
    let originalID = store.definitions[0].id

    try await store.duplicate(id: originalID)
    let copyID = try #require(store.definitions.first(where: { $0.id != originalID })).id

    var copy = try #require(store.definitions.first(where: { $0.id == copyID }))
    copy.name = "Mutated Copy"
    try await store.save(copy)

    let original = try #require(store.definitions.first(where: { $0.id == originalID }))
    #expect(original.name == "Original")
  }

  @Test func duplicateUnknownIDThrows() async throws {
    let store = try makeStore()
    await #expect(throws: (any Error).self) {
      try await store.duplicate(id: UUID())
    }
  }

  // MARK: load

  @Test func loadReconstitutesFromFiles() async throws {
    let store = try makeStore()
    let def = EncounterDefinition(name: "From File")
    try JSONEncoder().encode(def).write(
      to: store.directory.appending(path: "\(def.id.uuidString).encounter.json")
    )
    await store.load()
    #expect(store.definitions.count == 1)
    #expect(store.definitions[0].name == "From File")
    #expect(store.definitions[0].id == def.id)
  }

  @Test func loadIgnoresNonEncounterFiles() async throws {
    let store = try makeStore()
    try Data("noise".utf8).write(to: store.directory.appending(path: "readme.txt"))
    await store.load()
    #expect(store.definitions.isEmpty)
  }

  @Test func loadIgnoresCorruptFiles() async throws {
    let store = try makeStore()
    let def = EncounterDefinition(name: "Good Encounter")
    try JSONEncoder().encode(def).write(
      to: store.directory.appending(path: "\(def.id.uuidString).encounter.json")
    )
    try Data("not valid json".utf8).write(
      to: store.directory.appending(path: "corrupt.encounter.json")
    )
    await store.load()
    #expect(store.definitions.count == 1)
    #expect(store.definitions[0].name == "Good Encounter")
  }

  // MARK: sort order

  @Test func definitionsSortedByModifiedAtDescending() async throws {
    let store = try makeStore()
    try await store.create(name: "Alpha")

    var alpha = store.definitions[0]
    let now = Date.now
    let earlier = EncounterDefinition(
      id: UUID(), name: "Beta",
      createdAt: now.addingTimeInterval(-60),
      modifiedAt: now.addingTimeInterval(-60)
    )
    let latest = EncounterDefinition(
      id: UUID(), name: "Gamma",
      createdAt: now.addingTimeInterval(-10),
      modifiedAt: now.addingTimeInterval(-10)
    )
    let encoder = JSONEncoder()
    try encoder.encode(earlier).write(
      to: store.directory.appending(path: "\(earlier.id.uuidString).encounter.json")
    )
    try encoder.encode(latest).write(
      to: store.directory.appending(path: "\(latest.id.uuidString).encounter.json")
    )
    alpha.gmNotes = "touched last"
    try await store.save(alpha)
    await store.load()

    #expect(store.definitions.count == 3)
    #expect(store.definitions[0].name == "Alpha")
    #expect(store.definitions[1].name == "Gamma")
    #expect(store.definitions[2].name == "Beta")

    let dates = store.definitions.map(\.modifiedAt)
    for i in 0..<(dates.count - 1) {
      #expect(dates[i] >= dates[i + 1], "definitions[\(i)] should be >= definitions[\(i+1)]")
    }
  }
}
