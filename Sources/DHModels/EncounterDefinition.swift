//
//  EncounterDefinition.swift
//  Encounter
//
//  A saveable, shareable encounter template.
//  Captures the GM's prep work: which adversaries and environments to include,
//  which players are at the table, and any notes.
//
//  To run an encounter, create an EncounterSession from a definition
//  using EncounterSession(from:using:).
//
//  Catalog vs. Runtime Split:
//  - Definition stores adversary/environment IDs (references into the Compendium).
//  - Session resolves those IDs into live AdversaryState and EnvironmentState
//    instances with mutable HP, Stress, and condition tracking.
//

import Foundation

#if canImport(FoundationEssentials)
  import FoundationEssentials
#endif

// MARK: - PlayerConfig

/// Configuration for a single player character in an encounter definition.
///
/// This is the `Codable`, value-type counterpart of ``PlayerState``.
/// When an ``EncounterSession`` is started from a definition, each
/// `PlayerConfig` becomes a ``PlayerState`` with fresh runtime state.
nonisolated public struct PlayerConfig: Codable, Sendable, Equatable, Hashable, Identifiable {
  public let id: UUID
  public let name: String
  /// The player character's level (1–10). Defaults to `1` when absent in JSON.
  public let level: Int
  public let maxHP: Int
  public let maxStress: Int
  public let evasion: Int
  public let thresholdMajor: Int
  public let thresholdSevere: Int
  public let armorSlots: Int

  public init(
    id: UUID = UUID(),
    name: String,
    level: Int = 1,
    maxHP: Int,
    maxStress: Int,
    evasion: Int,
    thresholdMajor: Int,
    thresholdSevere: Int,
    armorSlots: Int
  ) {
    self.id = id
    self.name = name
    self.level = level
    self.maxHP = maxHP
    self.maxStress = maxStress
    self.evasion = evasion
    self.thresholdMajor = thresholdMajor
    self.thresholdSevere = thresholdSevere
    self.armorSlots = armorSlots
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    level = try container.decodeIfPresent(Int.self, forKey: .level) ?? 1
    maxHP = try container.decode(Int.self, forKey: .maxHP)
    maxStress = try container.decode(Int.self, forKey: .maxStress)
    evasion = try container.decode(Int.self, forKey: .evasion)
    thresholdMajor = try container.decode(Int.self, forKey: .thresholdMajor)
    thresholdSevere = try container.decode(Int.self, forKey: .thresholdSevere)
    armorSlots = try container.decode(Int.self, forKey: .armorSlots)
  }
}

// MARK: - EncounterDefinition

/// A saveable, shareable encounter template.
///
/// `EncounterDefinition` captures the GM's prep work: which adversaries
/// and environments to include, which players are at the table, and any
/// notes. It is a pure value type with full `Codable` conformance,
/// suitable for persistence to disk, CloudKit, or JSON export.
///
/// To run an encounter, create an ``EncounterSession`` from a definition
/// using ``EncounterSession/init(from:using:)``.
nonisolated public struct EncounterDefinition: Codable, Sendable, Equatable, Hashable, Identifiable
{
  public let id: UUID
  public var name: String

  /// Adversary catalog IDs. Duplicates represent multiple copies of the same adversary.
  public var adversaryIDs: [String]

  /// Environment catalog IDs.
  public var environmentIDs: [String]

  /// Player character configurations for this encounter.
  public var playerConfigs: [PlayerConfig]

  /// Freeform GM notes for encounter prep.
  public var gmNotes: String

  // MARK: Timestamps

  /// When this definition was first created.
  public let createdAt: Date

  /// Stamped by ``EncounterStore/save(_:)`` — do not set directly.
  public var modifiedAt: Date

  public init(
    id: UUID = UUID(),
    name: String,
    adversaryIDs: [String] = [],
    environmentIDs: [String] = [],
    playerConfigs: [PlayerConfig] = [],
    gmNotes: String = "",
    createdAt: Date = .now,
    modifiedAt: Date = .now
  ) {
    self.id = id
    self.name = name
    self.adversaryIDs = adversaryIDs
    self.environmentIDs = environmentIDs
    self.playerConfigs = playerConfigs
    self.gmNotes = gmNotes
    self.createdAt = createdAt
    self.modifiedAt = modifiedAt
  }
}
