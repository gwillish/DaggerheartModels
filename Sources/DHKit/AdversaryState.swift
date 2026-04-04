//
//  AdversaryState.swift
//  DHKit
//
//  A single adversary participant in a live encounter.
//

import DHModels
import Foundation

#if canImport(FoundationEssentials)
  import FoundationEssentials
#endif

/// A single adversary participant in a live encounter.
///
/// Wraps a reference to a catalog ``Adversary`` with runtime state:
/// current HP, current Stress, defeat status, and an optional individual name
/// (useful when running multiple copies of the same adversary).
///
/// `maxHP` and `maxStress` are snapshotted from the catalog at creation
/// time so that HP/stress clamping works correctly even if the source adversary
/// is later edited or removed from the ``Compendium`` (homebrew orphan safety).
///
/// All properties are immutable. Mutations are performed by ``EncounterSession``,
/// which replaces values wholesale (copy-with-update pattern).
nonisolated public struct AdversaryState: CombatParticipant, Codable, Sendable, Equatable, Hashable
{
  /// Stable slot identifier unique within the session.
  public let id: UUID
  /// The slug that identifies this adversary in the ``Compendium``.
  public let adversaryID: String
  /// Display name override (e.g. "Grimfang" for a named bandit leader).
  /// Falls back to the catalog name when `nil`.
  public let customName: String?

  // MARK: Stat Snapshot (from catalog at creation time)

  /// Maximum HP snapshotted from the catalog entry at slot creation time.
  public let maxHP: Int
  /// Maximum Stress snapshotted from the catalog entry at slot creation time.
  public let maxStress: Int

  // MARK: Tracked Stats

  /// Current HP; clamped to `0...maxHP` by ``EncounterSession``.
  public let currentHP: Int
  /// Current Stress; clamped to `0...maxStress` by ``EncounterSession``.
  public let currentStress: Int
  /// `true` once HP reaches 0.
  public let isDefeated: Bool
  /// Active conditions on this adversary slot.
  public let conditions: Set<Condition>

  // MARK: - Init

  /// Creates an adversary slot with explicit stat values.
  ///
  /// Prefer ``init(from:customName:)`` when constructing from a catalog entry.
  ///
  /// - Parameters:
  ///   - id: Slot identifier; defaults to a new UUID.
  ///   - adversaryID: Catalog slug for the source adversary.
  ///   - customName: Optional display name override.
  ///   - maxHP: Maximum HP (snapshotted from catalog).
  ///   - maxStress: Maximum Stress (snapshotted from catalog).
  ///   - currentHP: Starting HP; defaults to `maxHP`.
  ///   - currentStress: Starting Stress; defaults to `0`.
  ///   - isDefeated: Whether the slot starts defeated; defaults to `false`.
  ///   - conditions: Initial condition set; defaults to empty.
  public init(
    id: UUID = UUID(),
    adversaryID: String,
    customName: String? = nil,
    maxHP: Int,
    maxStress: Int,
    currentHP: Int? = nil,
    currentStress: Int = 0,
    isDefeated: Bool = false,
    conditions: Set<Condition> = []
  ) {
    self.id = id
    self.adversaryID = adversaryID
    self.customName = customName
    self.maxHP = maxHP
    self.maxStress = maxStress
    self.currentHP = currentHP ?? maxHP
    self.currentStress = currentStress
    self.isDefeated = isDefeated
    self.conditions = conditions
  }

  /// Convenience initializer: creates state pre-populated from a catalog entry.
  public init(from adversary: Adversary, customName: String? = nil) {
    self.init(
      adversaryID: adversary.id,
      customName: customName,
      maxHP: adversary.hp,
      maxStress: adversary.stress
    )
  }

  /// Returns a copy of this value with the specified mutable fields replaced.
  ///
  /// Omit any parameter to preserve the existing value. This is the preferred
  /// way to produce updated copies; it avoids repeating every unchanged field
  /// at mutation sites in ``EncounterSession``.
  public func applying(
    currentHP: Int? = nil,
    currentStress: Int? = nil,
    isDefeated: Bool? = nil,
    conditions: Set<Condition>? = nil
  ) -> AdversaryState {
    AdversaryState(
      id: id, adversaryID: adversaryID, customName: customName,
      maxHP: maxHP, maxStress: maxStress,
      currentHP: currentHP ?? self.currentHP,
      currentStress: currentStress ?? self.currentStress,
      isDefeated: isDefeated ?? self.isDefeated,
      conditions: conditions ?? self.conditions
    )
  }
}
