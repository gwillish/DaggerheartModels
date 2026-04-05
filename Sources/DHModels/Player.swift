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
  /// The player character's level (1–10).
  public var level: Int
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
  ///   - level: The character's level (1–10); defaults to `1`.
  ///   - maxHP: Maximum hit points.
  ///   - maxStress: Maximum stress.
  ///   - evasion: The DC for rolls made against this PC.
  ///   - thresholdMajor: Damage threshold for a Major hit.
  ///   - thresholdSevere: Damage threshold for a Severe hit.
  ///   - armorSlots: Total Armor Score (number of Armor Slots).
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

  /// Snapshots this player's current stats into a ``PlayerConfig`` for use
  /// in an ``EncounterDefinition`` or session creation.
  public func asConfig() -> PlayerConfig {
    PlayerConfig(
      id: id,
      name: name,
      level: level,
      maxHP: maxHP,
      maxStress: maxStress,
      evasion: evasion,
      thresholdMajor: thresholdMajor,
      thresholdSevere: thresholdSevere,
      armorSlots: armorSlots
    )
  }
}
