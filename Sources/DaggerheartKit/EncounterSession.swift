//
//  EncounterSession.swift
//  Encounter
//
//  Runtime models for a live Daggerheart encounter.
//  These are the mutable, in-play tracking types — separate from the
//  static catalog definitions in Adversary.swift.
//
//  Design notes:
//  - EncounterSession is @Observable so SwiftUI views bind to it directly.
//  - AdversarySlot and EnvironmentSlot are structs stored in the session's
//    arrays; mutations flow through the session class.
//  - Fear and Hope are tracked on the session; individual adversary stress
//    contributes to Fear when thresholds are crossed (GM's discretion).
//  - The `activeSlotID` drives spotlight management in the UI.
//

import DaggerheartModels
import Foundation
import Logging
import Observation

// MARK: - AdversarySlot

/// A single adversary participant in a live encounter.
///
/// Wraps a reference to a catalog ``Adversary`` with runtime mutable state:
/// current HP, current Stress, defeat status, and an optional individual name
/// (useful when running multiple copies of the same adversary).
///
/// `maxHP` and `maxStress` are snapshotted from the catalog at slot-creation
/// time so that HP/stress clamping works correctly even if the source adversary
/// is later edited or removed from the ``Compendium`` (homebrew orphan safety).
nonisolated public struct AdversarySlot: Identifiable, Sendable, Equatable, Hashable {
  public let id: UUID
  /// The slug that identifies this adversary in the ``Compendium``.
  public let adversaryID: String
  /// Display name override (e.g. "Grimfang" for a named bandit leader).
  /// Falls back to the catalog name when `nil`.
  public var customName: String?

  // MARK: Stat Snapshot (from catalog at creation time)
  public let maxHP: Int
  public let maxStress: Int

  // MARK: Tracked Stats
  public var currentHP: Int
  public var currentStress: Int
  public var isDefeated: Bool
  public var conditions: Set<Condition>

  // MARK: - Init

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

  /// Convenience factory: create a slot pre-populated from a catalog entry.
  public static func from(_ adversary: Adversary, customName: String? = nil) -> AdversarySlot {
    AdversarySlot(
      adversaryID: adversary.id,
      customName: customName,
      maxHP: adversary.hp,
      maxStress: adversary.stress
    )
  }
}

// MARK: - EnvironmentSlot

/// An environment element active in the current encounter scene.
///
/// Environments have no HP or Stress — they are tracked only for
/// their features and activation state.
nonisolated public struct EnvironmentSlot: Identifiable, Sendable, Equatable, Hashable {
  public let id: UUID
  /// The slug identifying this environment in the ``Compendium``.
  public let environmentID: String
  /// Whether this environment element is currently active/visible to players.
  public var isActive: Bool

  public init(
    id: UUID = UUID(),
    environmentID: String,
    isActive: Bool = true
  ) {
    self.id = id
    self.environmentID = environmentID
    self.isActive = isActive
  }
}

// MARK: - EncounterSession

/// The live state of a Daggerheart encounter being run at the table.
///
/// `EncounterSession` is the central observable object for encounter views.
/// It holds:
/// - The roster of active adversary and environment slots.
/// - The GM's Fear pool and the party's Hope pool.
/// - Spotlight management (which adversary/environment is currently active).
/// - Round and turn counters.
/// - A freeform GM notes field.
///
/// ## Usage
/// Create a session by adding slots from the ``Compendium``, then pass it
/// through the environment to encounter views.
///
/// ```swift
/// let session = EncounterSession(name: "Bandit Ambush")
/// session.add(adversary: bandits.ironguard)
/// session.add(adversary: bandits.ironguard)   // second copy
/// session.add(environment: terrain.forestEdge)
/// ```
@MainActor
@Observable
public final class EncounterSession: Identifiable, Hashable {
  public nonisolated static func == (lhs: EncounterSession, rhs: EncounterSession) -> Bool {
    lhs.id == rhs.id
  }
  public nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }

  private let logger = Logger(label: "EncounterSession")

  // MARK: Identity
  public let id: UUID
  public var name: String

  // MARK: Participants
  public var adversarySlots: [AdversarySlot]
  public var playerSlots: [PlayerSlot]
  public var environmentSlots: [EnvironmentSlot]

  // MARK: Fear & Hope
  /// The GM's Fear pool. Increases when players roll with Fear,
  /// decreases when the GM spends Fear on adversary actions.
  public var fearPool: Int

  /// The party's Hope pool (total across all PCs). Tracked here for
  /// quick reference; primary source of truth is player character sheets.
  public var hopePool: Int

  // MARK: Spotlight
  /// The ID of the adversary slot (or environment slot) currently taking
  /// its turn. `nil` when it is the players' action phase.
  public var activeSlotID: UUID?

  // MARK: Round Tracking
  public var currentRound: Int
  public var turnOrder: [UUID]  // ordered slot IDs for this round

  // MARK: Notes
  public var gmNotes: String

  // MARK: - Init

  public init(
    id: UUID = UUID(),
    name: String,
    adversarySlots: [AdversarySlot] = [],
    playerSlots: [PlayerSlot] = [],
    environmentSlots: [EnvironmentSlot] = [],
    fearPool: Int = 0,
    hopePool: Int = 0,
    currentRound: Int = 1,
    gmNotes: String = ""
  ) {
    self.id = id
    self.name = name
    self.adversarySlots = adversarySlots
    self.playerSlots = playerSlots
    self.environmentSlots = environmentSlots
    self.fearPool = fearPool
    self.hopePool = hopePool
    self.activeSlotID = nil
    self.currentRound = currentRound
    self.turnOrder = adversarySlots.map(\.id) + playerSlots.map(\.id)
    self.gmNotes = gmNotes
  }

  // MARK: - Roster Management

  /// Add a new adversary slot populated from a catalog entry.
  public func add(adversary: Adversary, customName: String? = nil) {
    let slot = AdversarySlot.from(adversary, customName: customName)
    adversarySlots.append(slot)
    turnOrder.append(slot.id)
  }

  /// Add an environment slot.
  public func add(environment: DaggerheartEnvironment) {
    environmentSlots.append(EnvironmentSlot(environmentID: environment.id))
  }

  /// Remove an adversary slot by ID.
  public func removeAdversary(id: UUID) {
    adversarySlots.removeAll { $0.id == id }
    turnOrder.removeAll { $0 == id }
    if activeSlotID == id { activeSlotID = nil }
  }

  // MARK: - Player Management

  /// Add a player slot to the encounter.
  public func addPlayer(_ player: PlayerSlot) {
    playerSlots.append(player)
    turnOrder.append(player.id)
  }

  /// Remove a player slot by ID.
  public func removePlayer(id: UUID) {
    playerSlots.removeAll { $0.id == id }
    turnOrder.removeAll { $0 == id }
    if activeSlotID == id { activeSlotID = nil }
  }

  // MARK: - HP & Stress Mutations

  /// Apply damage to an adversary slot, clamping HP to 0.
  public func applyDamage(_ amount: Int, to slotID: UUID) {
    guard let index = adversarySlots.firstIndex(where: { $0.id == slotID }) else {
      logger.warning("applyDamage: slot \(slotID) not found")
      return
    }
    adversarySlots[index].currentHP = max(0, adversarySlots[index].currentHP - amount)
    if adversarySlots[index].currentHP == 0 {
      adversarySlots[index].isDefeated = true
      logger.info("Slot \(slotID) defeated")
    } else {
      logger.debug(
        "Slot \(slotID) took \(amount) damage, HP now \(self.adversarySlots[index].currentHP)")
    }
  }

  /// Apply stress to an adversary slot, clamping to the slot's snapshotted maximum.
  public func applyStress(_ amount: Int, to slotID: UUID) {
    guard let index = adversarySlots.firstIndex(where: { $0.id == slotID }) else {
      logger.warning("applyStress: slot \(slotID) not found")
      return
    }
    adversarySlots[index].currentStress = min(
      adversarySlots[index].maxStress,
      adversarySlots[index].currentStress + amount
    )
    logger.debug(
      "Slot \(slotID) stress now \(self.adversarySlots[index].currentStress)/\(self.adversarySlots[index].maxStress)"
    )
  }

  /// Heal an adversary slot, clamping HP to the slot's snapshotted maximum.
  public func heal(_ amount: Int, slotID: UUID) {
    guard let index = adversarySlots.firstIndex(where: { $0.id == slotID }) else {
      logger.warning("heal: slot \(slotID) not found")
      return
    }
    adversarySlots[index].currentHP = min(
      adversarySlots[index].maxHP,
      adversarySlots[index].currentHP + amount
    )
    if adversarySlots[index].currentHP > 0 {
      adversarySlots[index].isDefeated = false
    }
    logger.debug(
      "Slot \(slotID) healed \(amount), HP now \(self.adversarySlots[index].currentHP)/\(self.adversarySlots[index].maxHP)"
    )
  }

  // MARK: - Adversary Condition Management

  /// Apply a condition to an adversary slot.
  /// Per the SRD, the same condition does not stack (Set enforces this).
  /// `.custom` conditions with an empty or whitespace-only name are silently ignored.
  public func applyCondition(_ condition: Condition, to slotID: UUID) {
    if case .custom(let name) = condition,
      name.trimmingCharacters(in: .whitespaces).isEmpty
    {
      return
    }
    guard let index = adversarySlots.firstIndex(where: { $0.id == slotID }) else { return }
    adversarySlots[index].conditions.insert(condition)
  }

  /// Remove a condition from an adversary slot.
  public func removeCondition(_ condition: Condition, from slotID: UUID) {
    guard let index = adversarySlots.firstIndex(where: { $0.id == slotID }) else { return }
    adversarySlots[index].conditions.remove(condition)
  }

  // MARK: - Player HP & Stress Mutations

  /// Apply damage to a player slot, clamping HP to 0.
  public func applyPlayerDamage(_ amount: Int, to slotID: UUID) {
    guard let index = playerSlots.firstIndex(where: { $0.id == slotID }) else { return }
    playerSlots[index].currentHP = max(0, playerSlots[index].currentHP - amount)
  }

  /// Apply stress to a player slot, clamping to maximum.
  public func applyPlayerStress(_ amount: Int, to slotID: UUID) {
    guard let index = playerSlots.firstIndex(where: { $0.id == slotID }) else { return }
    playerSlots[index].currentStress = min(
      playerSlots[index].maxStress,
      playerSlots[index].currentStress + amount
    )
  }

  /// Heal a player slot, clamping HP to maximum.
  public func healPlayer(_ amount: Int, slotID: UUID) {
    guard let index = playerSlots.firstIndex(where: { $0.id == slotID }) else { return }
    playerSlots[index].currentHP = min(
      playerSlots[index].maxHP,
      playerSlots[index].currentHP + amount
    )
  }

  /// Clear stress from a player slot, clamping to 0.
  public func clearPlayerStress(_ amount: Int, slotID: UUID) {
    guard let index = playerSlots.firstIndex(where: { $0.id == slotID }) else { return }
    playerSlots[index].currentStress = max(0, playerSlots[index].currentStress - amount)
  }

  /// Mark one Armor Slot on a player (used to reduce damage severity).
  public func markPlayerArmorSlot(_ slotID: UUID) {
    guard let index = playerSlots.firstIndex(where: { $0.id == slotID }) else { return }
    guard playerSlots[index].currentArmorSlots > 0 else { return }
    playerSlots[index].currentArmorSlots -= 1
  }

  /// Restore one Armor Slot on a player (undo a mark, or recover via a rest ability).
  public func restorePlayerArmorSlot(_ slotID: UUID) {
    guard let index = playerSlots.firstIndex(where: { $0.id == slotID }) else { return }
    playerSlots[index].currentArmorSlots = min(
      playerSlots[index].armorSlots,
      playerSlots[index].currentArmorSlots + 1
    )
  }

  // MARK: - Player Condition Management

  /// Apply a condition to a player slot.
  /// `.custom` conditions with an empty or whitespace-only name are silently ignored.
  public func applyPlayerCondition(_ condition: Condition, to slotID: UUID) {
    if case .custom(let name) = condition,
      name.trimmingCharacters(in: .whitespaces).isEmpty
    {
      return
    }
    guard let index = playerSlots.firstIndex(where: { $0.id == slotID }) else { return }
    playerSlots[index].conditions.insert(condition)
  }

  /// Remove a condition from a player slot.
  public func removePlayerCondition(_ condition: Condition, from slotID: UUID) {
    guard let index = playerSlots.firstIndex(where: { $0.id == slotID }) else { return }
    playerSlots[index].conditions.remove(condition)
  }

  // MARK: - Fear & Hope

  public func incrementFear(by amount: Int = 1) {
    fearPool += amount
  }

  public func spendFear(_ amount: Int = 1) {
    fearPool = max(0, fearPool - amount)
  }

  public func incrementHope(by amount: Int = 1) {
    hopePool += amount
  }

  public func spendHope(_ amount: Int = 1) {
    hopePool = max(0, hopePool - amount)
  }

  // MARK: - Round Management

  /// Advance to the next round, resetting the turn position.
  public func advanceRound() {
    currentRound += 1
    activeSlotID = nil
    // Defeated adversaries are removed from the turn order for the new round.
    let defeatedIDs = Set(adversarySlots.filter(\.isDefeated).map(\.id))
    turnOrder = turnOrder.filter { !defeatedIDs.contains($0) }
    logger.info("Advanced to round \(self.currentRound), \(self.turnOrder.count) slots in order")
  }

  /// Turn order filtered to non-defeated participants.
  /// Defeated adversaries are excluded so `advanceTurn` never lands on them mid-round.
  private var activeTurnOrder: [UUID] {
    let defeatedIDs = Set(adversarySlots.filter(\.isDefeated).map(\.id))
    return turnOrder.filter { !defeatedIDs.contains($0) }
  }

  /// Set the active spotlight to the next slot in turn order, skipping defeated adversaries.
  public func advanceTurn() {
    let active = activeTurnOrder
    guard !active.isEmpty else {
      activeSlotID = nil
      return
    }
    if let current = activeSlotID,
      let currentIndex = active.firstIndex(of: current),
      currentIndex + 1 < active.count
    {
      activeSlotID = active[currentIndex + 1]
    } else {
      activeSlotID = active.first
    }
  }

  // MARK: - Computed Helpers

  /// All adversary slots still in the fight.
  public var activeAdversaries: [AdversarySlot] {
    adversarySlots.filter { !$0.isDefeated }
  }

  /// `true` when all adversary slots are defeated.
  public var isOver: Bool {
    !adversarySlots.isEmpty && adversarySlots.allSatisfy(\.isDefeated)
  }

  // MARK: - Factory

  /// Create a live encounter session from a saved definition.
  ///
  /// Resolves adversary and environment IDs through the compendium.
  /// IDs that do not resolve to a catalog entry are silently skipped
  /// (this handles orphaned homebrew references gracefully).
  ///
  /// - Parameters:
  ///   - definition: The encounter template to instantiate.
  ///   - compendium: The catalog used to resolve adversary/environment IDs.
  /// - Returns: A fresh `EncounterSession` ready for play.
  public static func start(
    from definition: EncounterDefinition,
    using compendium: Compendium
  ) -> EncounterSession {
    let adversarySlots: [AdversarySlot] = definition.adversaryIDs.compactMap { id in
      guard let adversary = compendium.adversary(id: id) else { return nil }
      return AdversarySlot.from(adversary)
    }

    let environmentSlots: [EnvironmentSlot] = definition.environmentIDs.compactMap { id in
      guard compendium.environment(id: id) != nil else { return nil }
      return EnvironmentSlot(environmentID: id)
    }

    let playerSlots: [PlayerSlot] = definition.playerConfigs.map { config in
      PlayerSlot(
        name: config.name,
        maxHP: config.maxHP,
        maxStress: config.maxStress,
        evasion: config.evasion,
        thresholdMajor: config.thresholdMajor,
        thresholdSevere: config.thresholdSevere,
        armorSlots: config.armorSlots
      )
    }

    return EncounterSession(
      name: definition.name,
      adversarySlots: adversarySlots,
      playerSlots: playerSlots,
      environmentSlots: environmentSlots,
      gmNotes: definition.gmNotes
    )
  }
}
