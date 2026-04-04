//
//  Player.swift
//  DHModels
//
//  A persistent record of a player character tracked by the GM across encounters.
//

import Foundation

#if canImport(FoundationEssentials)
  import FoundationEssentials
#endif

// MARK: - Player

/// A persistent record of a player character tracked by the GM across encounters.
///
/// `Player` is the canonical global identity for a PC. It carries the same
/// stat fields as ``PlayerConfig`` — the encounter-snapshot counterpart —
/// but exists independently of any encounter or party.
///
/// Use ``asConfig()`` to snapshot a `Player` into a ``PlayerConfig`` for
/// use in an ``EncounterDefinition``.
nonisolated public struct Player: Codable, Sendable, Equatable, Hashable, Identifiable {
  public let id: UUID
  public var name: String
  public var maxHP: Int
  public var maxStress: Int
  public var evasion: Int
  public var thresholdMajor: Int
  public var thresholdSevere: Int
  public var armorSlots: Int

  public init(
    id: UUID = UUID(),
    name: String,
    maxHP: Int,
    maxStress: Int,
    evasion: Int,
    thresholdMajor: Int,
    thresholdSevere: Int,
    armorSlots: Int
  ) {
    self.id = id
    self.name = name
    self.maxHP = maxHP
    self.maxStress = maxStress
    self.evasion = evasion
    self.thresholdMajor = thresholdMajor
    self.thresholdSevere = thresholdSevere
    self.armorSlots = armorSlots
  }

  /// Snapshots this player's current stats into a ``PlayerConfig`` for use
  /// in an ``EncounterDefinition`` or session creation.
  public func asConfig() -> PlayerConfig {
    PlayerConfig(
      id: id,
      name: name,
      maxHP: maxHP,
      maxStress: maxStress,
      evasion: evasion,
      thresholdMajor: thresholdMajor,
      thresholdSevere: thresholdSevere,
      armorSlots: armorSlots
    )
  }
}
