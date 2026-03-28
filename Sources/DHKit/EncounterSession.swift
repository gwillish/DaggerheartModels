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
//  - The `spotlightedSlotID` drives spotlight management in the UI.
//

import DHModels
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
nonisolated public struct AdversarySlot: CombatParticipant, Sendable, Equatable, Hashable {
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
  public static func make(from adversary: Adversary, customName: String? = nil) -> AdversarySlot {
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
nonisolated public struct EnvironmentSlot: EncounterParticipant, Sendable, Equatable, Hashable {
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
  /// The ID of the adversary, environment, or player slot currently in the spotlight.
  /// `nil` when it is the players' action phase.
  public var spotlightedSlotID: UUID?

  /// Running total of spotlight grants in this encounter.
  public var spotlightCount: Int

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
    spotlightCount: Int = 0,
    gmNotes: String = ""
  ) {
    self.id = id
    self.name = name
    self.adversarySlots = adversarySlots
    self.playerSlots = playerSlots
    self.environmentSlots = environmentSlots
    self.fearPool = fearPool
    self.hopePool = hopePool
    self.spotlightedSlotID = nil
    self.spotlightCount = spotlightCount
    self.gmNotes = gmNotes
  }

  // MARK: - Roster Management

  /// Add a new adversary slot populated from a catalog entry.
  public func add(adversary: Adversary, customName: String? = nil) {
    let slot = AdversarySlot.make(from: adversary, customName: customName)
    adversarySlots.append(slot)
  }

  /// Add an environment slot.
  public func add(environment: DaggerheartEnvironment) {
    environmentSlots.append(EnvironmentSlot(environmentID: environment.id))
  }

  /// Remove an adversary slot by ID.
  public func removeAdversary(id: UUID) {
    adversarySlots.removeAll { $0.id == id }
    if spotlightedSlotID == id { spotlightedSlotID = nil }
  }

  // MARK: - Player Management

  /// Add a player slot to the encounter.
  public func add(player: PlayerSlot) {
    playerSlots.append(player)
  }

  /// Remove a player slot by ID.
  public func removePlayer(id: UUID) {
    playerSlots.removeAll { $0.id == id }
    if spotlightedSlotID == id { spotlightedSlotID = nil }
  }

  // MARK: - Spotlight

  /// Grant the spotlight to an adversary, environment, or player slot.
  ///
  /// Increments ``spotlightCount`` on every call. The GM typically
  /// spends 1 Fear (tracked separately on ``fearPool``) when seizing
  /// the spotlight to act.
  public func spotlight(_ participant: some EncounterParticipant) {
    spotlightedSlotID = participant.id
    spotlightCount += 1
  }

  /// Yield the spotlight back to the players, ending the GM's turn.
  ///
  /// Clears ``spotlightedSlotID``. The spotlight returning to the players
  /// is the natural end of a GM turn in Daggerheart.
  public func yieldSpotlight() {
    spotlightedSlotID = nil
  }

  // MARK: - HP & Stress Mutations

  /// Apply damage to any combat participant, clamping HP to 0.
  /// Adversary slots are marked ``AdversarySlot/isDefeated`` when HP reaches 0.
  public func applyDamage(_ amount: Int, to participant: some CombatParticipant) {
    let id = participant.id
    if let i = adversarySlots.firstIndex(where: { $0.id == id }) {
      adversarySlots[i].currentHP = max(0, adversarySlots[i].currentHP - amount)
      if adversarySlots[i].currentHP == 0 {
        adversarySlots[i].isDefeated = true
        logger.info("Slot \(id) defeated")
      } else {
        logger.debug("Slot \(id) took \(amount) damage, HP now \(self.adversarySlots[i].currentHP)")
      }
      return
    }
    if let i = playerSlots.firstIndex(where: { $0.id == id }) {
      playerSlots[i].currentHP = max(0, playerSlots[i].currentHP - amount)
    }
  }

  /// Heal any combat participant, clamping HP to the slot's maximum.
  /// Clears ``AdversarySlot/isDefeated`` if the adversary's HP rises above 0.
  public func heal(_ amount: Int, to participant: some CombatParticipant) {
    let id = participant.id
    if let i = adversarySlots.firstIndex(where: { $0.id == id }) {
      adversarySlots[i].currentHP = min(
        adversarySlots[i].maxHP, adversarySlots[i].currentHP + amount)
      if adversarySlots[i].currentHP > 0 { adversarySlots[i].isDefeated = false }
      logger.debug(
        "Slot \(id) healed \(amount), HP now \(self.adversarySlots[i].currentHP)/\(self.adversarySlots[i].maxHP)"
      )
      return
    }
    if let i = playerSlots.firstIndex(where: { $0.id == id }) {
      playerSlots[i].currentHP = min(playerSlots[i].maxHP, playerSlots[i].currentHP + amount)
    }
  }

  /// Apply stress to any combat participant, clamping to the slot's maximum.
  public func applyStress(_ amount: Int, to participant: some CombatParticipant) {
    let id = participant.id
    if modifying(
      in: &adversarySlots, id: id,
      { $0.currentStress = min($0.maxStress, $0.currentStress + amount) })
    {
      return
    }
    modifying(in: &playerSlots, id: id) {
      $0.currentStress = min($0.maxStress, $0.currentStress + amount)
    }
  }

  /// Reduce stress on any combat participant, clamping to 0.
  public func reduceStress(_ amount: Int, from participant: some CombatParticipant) {
    let id = participant.id
    if modifying(
      in: &adversarySlots, id: id, { $0.currentStress = max(0, $0.currentStress - amount) })
    {
      return
    }
    modifying(in: &playerSlots, id: id) { $0.currentStress = max(0, $0.currentStress - amount) }
  }

  // MARK: - Condition Management

  /// Apply a condition to any combat participant.
  /// Per the SRD, the same condition cannot stack — ``Set`` enforces this.
  /// `.custom` conditions with an empty or whitespace-only name are silently ignored.
  public func applyCondition(_ condition: Condition, to participant: some CombatParticipant) {
    if case .custom(let name) = condition,
      name.trimmingCharacters(in: .whitespaces).isEmpty
    {
      return
    }
    let id = participant.id
    if modifying(in: &adversarySlots, id: id, { $0.conditions.insert(condition) }) { return }
    modifying(in: &playerSlots, id: id) { $0.conditions.insert(condition) }
  }

  /// Remove a condition from any combat participant.
  public func removeCondition(_ condition: Condition, from participant: some CombatParticipant) {
    let id = participant.id
    if modifying(in: &adversarySlots, id: id, { $0.conditions.remove(condition) }) { return }
    modifying(in: &playerSlots, id: id) { $0.conditions.remove(condition) }
  }

  // MARK: - Armor Slot Management

  /// Mark one Armor Slot on a player (used to reduce damage severity).
  public func markArmorSlot(for slotID: UUID) {
    guard let index = playerSlots.firstIndex(where: { $0.id == slotID }) else { return }
    guard playerSlots[index].currentArmorSlots > 0 else { return }
    playerSlots[index].currentArmorSlots -= 1
  }

  /// Restore one Armor Slot on a player (undo a mark, or recover via a rest ability).
  public func restoreArmorSlot(for slotID: UUID) {
    guard let index = playerSlots.firstIndex(where: { $0.id == slotID }) else { return }
    playerSlots[index].currentArmorSlots = min(
      playerSlots[index].armorSlots,
      playerSlots[index].currentArmorSlots + 1
    )
  }

  // MARK: - Fear & Hope

  public func incrementFear(by amount: Int = 1) {
    fearPool += amount
  }

  public func spendFear(by amount: Int = 1) {
    fearPool = max(0, fearPool - amount)
  }

  public func incrementHope(by amount: Int = 1) {
    hopePool += amount
  }

  public func spendHope(by amount: Int = 1) {
    hopePool = max(0, hopePool - amount)
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

  // MARK: - Private Helpers

  @discardableResult
  private func modifying<S: CombatParticipant>(
    in slots: inout [S], id: UUID, _ body: (inout S) -> Void
  ) -> Bool {
    guard let i = slots.firstIndex(where: { $0.id == id }) else { return false }
    body(&slots[i])
    return true
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
  public static func make(
    from definition: EncounterDefinition,
    using compendium: Compendium
  ) -> EncounterSession {
    let adversarySlots: [AdversarySlot] = definition.adversaryIDs.compactMap { id in
      guard let adversary = compendium.adversary(id: id) else { return nil }
      return AdversarySlot.make(from: adversary)
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
