//
//  PlayerSlot.swift
//  Encounter
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

import Foundation

/// A player character participant in a live encounter.
///
/// Tracks combat-relevant PC stats the GM needs to resolve hits and
/// track health during play. The full character sheet remains with the player.
public struct PlayerSlot: CombatParticipant, Sendable, Equatable, Hashable {
  public let id: UUID
  public let name: String

  // MARK: Hit Points
  public let maxHP: Int
  public let currentHP: Int

  // MARK: Stress
  public let maxStress: Int
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
  public let conditions: Set<Condition>

  // MARK: - Init

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

  /// Returns a copy of this slot with the specified mutable fields replaced.
  ///
  /// Omit any parameter to preserve the existing value. This is the preferred
  /// way to produce updated copies; it avoids repeating every unchanged field
  /// at mutation sites in ``EncounterSession``.
  public func applying(
    currentHP: Int? = nil,
    currentStress: Int? = nil,
    currentArmorSlots: Int? = nil,
    conditions: Set<Condition>? = nil
  ) -> PlayerSlot {
    PlayerSlot(
      id: id, name: name,
      maxHP: maxHP, currentHP: currentHP ?? self.currentHP,
      maxStress: maxStress, currentStress: currentStress ?? self.currentStress,
      evasion: evasion, thresholdMajor: thresholdMajor, thresholdSevere: thresholdSevere,
      armorSlots: armorSlots, currentArmorSlots: currentArmorSlots ?? self.currentArmorSlots,
      conditions: conditions ?? self.conditions
    )
  }
}
