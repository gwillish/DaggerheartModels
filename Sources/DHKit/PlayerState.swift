//
//  PlayerState.swift
//  DHKit
//
//  A player character participant in a live encounter.
//  Tracks the combat-relevant subset of a PC's stats that the GM needs
//  during an encounter. This is intentionally not a full character sheet;
//  the primary source of truth for a PC's stats remains with the player.
//
//  Daggerheart Stats Reference:
//  - Evasion: The DC for rolls made against this PC (class-based + mods).
//  - Thresholds: Major/Severe damage thresholds (armor base + level + mods).
//  - Armor Slots: Marks available to reduce damage severity (equals Armor Score).
//

import DHModels
import Foundation

#if canImport(FoundationEssentials)
  import FoundationEssentials
#endif

/// A player character participant in a live encounter.
///
/// Tracks combat-relevant PC stats the GM needs to resolve hits and
/// track health during play. The full character sheet remains with the player.
nonisolated public struct PlayerState: CombatParticipant, Codable, Sendable, Equatable, Hashable {
  /// Stable slot identifier unique within the session.
  public let id: UUID
  /// The player character's name.
  public let name: String

  // MARK: Hit Points

  /// Maximum hit points.
  public let maxHP: Int
  /// Current HP; clamped to `0...maxHP` by ``EncounterSession``.
  public let currentHP: Int

  // MARK: Stress

  /// Maximum stress.
  public let maxStress: Int
  /// Current Stress; clamped to `0...maxStress` by ``EncounterSession``.
  public let currentStress: Int

  // MARK: Defense

  /// The DC for all rolls made against this PC.
  public let evasion: Int
  /// Damage at or above this triggers a Major hit (mark 2 HP).
  public let thresholdMajor: Int
  /// Damage at or above this triggers a Severe hit (mark 3 HP).
  public let thresholdSevere: Int

  // MARK: Armor

  /// Total Armor Score (number of Armor Slots available).
  public let armorSlots: Int
  /// Remaining unused Armor Slots.
  public let currentArmorSlots: Int

  // MARK: Conditions

  /// Active conditions on this player slot.
  public let conditions: Set<Condition>

  // MARK: - Init

  /// Creates a player slot with explicit stat values.
  ///
  /// In most cases prefer creating a ``PlayerConfig`` and letting
  /// ``EncounterSession/make(from:using:)`` build the slot automatically.
  ///
  /// - Parameters:
  ///   - id: Slot identifier; defaults to a new UUID.
  ///   - name: The player character's name.
  ///   - maxHP: Maximum hit points.
  ///   - currentHP: Starting HP; defaults to `maxHP`.
  ///   - maxStress: Maximum stress.
  ///   - currentStress: Starting Stress; defaults to `0`.
  ///   - evasion: The DC for rolls made against this PC.
  ///   - thresholdMajor: Damage threshold for a Major hit.
  ///   - thresholdSevere: Damage threshold for a Severe hit.
  ///   - armorSlots: Total Armor Score.
  ///   - currentArmorSlots: Remaining Armor Slots; defaults to `armorSlots`.
  ///   - conditions: Initial condition set; defaults to empty.
  public init(
    id: UUID = UUID(),
    name: String,
    maxHP: Int,
    currentHP: Int? = nil,
    maxStress: Int,
    currentStress: Int = 0,
    evasion: Int,
    thresholdMajor: Int,
    thresholdSevere: Int,
    armorSlots: Int,
    currentArmorSlots: Int? = nil,
    conditions: Set<Condition> = []
  ) {
    self.id = id
    self.name = name
    self.maxHP = maxHP
    self.currentHP = currentHP ?? maxHP
    self.maxStress = maxStress
    self.currentStress = currentStress
    self.evasion = evasion
    self.thresholdMajor = thresholdMajor
    self.thresholdSevere = thresholdSevere
    self.armorSlots = armorSlots
    self.currentArmorSlots = currentArmorSlots ?? armorSlots
    self.conditions = conditions
  }

  /// Returns a copy of this value with the specified mutable fields replaced.
  ///
  /// Omit any parameter to preserve the existing value. This is the preferred
  /// way to produce updated copies; it avoids repeating every unchanged field
  /// at mutation sites in ``EncounterSession``.
  public func applying(
    currentHP: Int? = nil,
    currentStress: Int? = nil,
    currentArmorSlots: Int? = nil,
    conditions: Set<Condition>? = nil
  ) -> PlayerState {
    PlayerState(
      id: id, name: name,
      maxHP: maxHP, currentHP: currentHP ?? self.currentHP,
      maxStress: maxStress, currentStress: currentStress ?? self.currentStress,
      evasion: evasion, thresholdMajor: thresholdMajor, thresholdSevere: thresholdSevere,
      armorSlots: armorSlots, currentArmorSlots: currentArmorSlots ?? self.currentArmorSlots,
      conditions: conditions ?? self.conditions
    )
  }
}
