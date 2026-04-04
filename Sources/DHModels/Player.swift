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
  /// A stable identifier for this player record.
  public let id: UUID
  /// The player character's name.
  public var name: String
  /// Maximum hit points for this character.
  public var maxHP: Int
  /// Maximum stress for this character.
  public var maxStress: Int
  /// The difficulty class for rolls made against this character.
  public var evasion: Int
  /// Damage threshold for a Major hit (marks 2 HP).
  public var thresholdMajor: Int
  /// Damage threshold for a Severe hit (marks 3 HP).
  public var thresholdSevere: Int
  /// Total number of Armor Slots available to this character.
  public var armorSlots: Int

  /// Creates a player record.
  ///
  /// - Parameters:
  ///   - id: Stable identifier; defaults to a new UUID.
  ///   - name: The player character's name.
  ///   - maxHP: Maximum hit points.
  ///   - maxStress: Maximum stress.
  ///   - evasion: The DC for rolls made against this PC.
  ///   - thresholdMajor: Damage threshold for a Major hit.
  ///   - thresholdSevere: Damage threshold for a Severe hit.
  ///   - armorSlots: Total Armor Score (number of Armor Slots).
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
