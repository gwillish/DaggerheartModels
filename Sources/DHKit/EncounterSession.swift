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
//  - AdversarySlot, PlayerSlot, and EnvironmentSlot are immutable structs stored
//    in private backing arrays; mutations replace the affected struct wholesale
//    (copy-with-update). Public computed properties expose read-only snapshots.
//  - Fear and Hope are tracked on the session; individual adversary stress
//    contributes to Fear when thresholds are crossed (GM's discretion).
//  - The `spotlightedSlotID` drives spotlight management in the UI.
//

import DHModels
import Foundation
import Logging
import Observation

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

  // MARK: Participants (private backing stores)
  private var _adversarySlots: [AdversarySlot]
  private var _playerSlots: [PlayerSlot]
  private var _environmentSlots: [EnvironmentSlot]

  /// Read-only snapshot of all adversary slots.
  public var adversarySlots: [AdversarySlot] { _adversarySlots }
  /// Read-only snapshot of all player slots.
  public var playerSlots: [PlayerSlot] { _playerSlots }
  /// Read-only snapshot of all environment slots.
  public var environmentSlots: [EnvironmentSlot] { _environmentSlots }

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
    self._adversarySlots = adversarySlots
    self._playerSlots = playerSlots
    self._environmentSlots = environmentSlots
    self.fearPool = fearPool
    self.hopePool = hopePool
    self.spotlightedSlotID = nil
    self.spotlightCount = spotlightCount
    self.gmNotes = gmNotes
  }

  // MARK: - Roster Management

  /// Add a new adversary slot populated from a catalog entry.
  public func add(adversary: Adversary, customName: String? = nil) {
    _adversarySlots.append(AdversarySlot(from: adversary, customName: customName))
  }

  /// Add an environment slot.
  public func add(environment: DaggerheartEnvironment) {
    _environmentSlots.append(EnvironmentSlot(environmentID: environment.id))
  }

  /// Remove an adversary slot by ID.
  public func removeAdversary(withID id: UUID) {
    _adversarySlots.removeAll { $0.id == id }
    if spotlightedSlotID == id { spotlightedSlotID = nil }
  }

  // MARK: - Player Management

  /// Add a player slot to the encounter.
  public func add(player: PlayerSlot) {
    _playerSlots.append(player)
  }

  /// Remove a player slot by ID.
  public func removePlayer(withID id: UUID) {
    _playerSlots.removeAll { $0.id == id }
    if spotlightedSlotID == id { spotlightedSlotID = nil }
  }

  // MARK: - Spotlight

  /// Grant the spotlight to an adversary, environment, or player slot.
  ///
  /// Increments ``spotlightCount`` on every call. The GM typically
  /// spends 1 Fear (tracked separately on ``fearPool``) when seizing
  /// the spotlight to act.
  public func spotlight(id: UUID) {
    spotlightedSlotID = id
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

  /// Apply damage to a combat participant by ID, clamping HP to 0.
  /// Adversary slots are marked ``AdversarySlot/isDefeated`` when HP reaches 0.
  public func applyDamage(_ amount: Int, to id: UUID) {
    if let i = _adversarySlots.firstIndex(where: { $0.id == id }) {
      let s = _adversarySlots[i]
      let newHP = max(0, s.currentHP - amount)
      _adversarySlots[i] = s.applying(currentHP: newHP, isDefeated: newHP == 0 ? true : nil)
      if newHP == 0 {
        logger.info("Slot \(id) defeated")
      } else {
        logger.debug("Slot \(id) took \(amount) damage, HP now \(newHP)")
      }
      return
    }
    if let i = _playerSlots.firstIndex(where: { $0.id == id }) {
      _playerSlots[i] = _playerSlots[i].applying(
        currentHP: max(0, _playerSlots[i].currentHP - amount))
      return
    }
    logger.warning("applyDamage: no slot found for id \(id)")
  }

  /// Heal a combat participant by ID, clamping HP to the slot's maximum.
  /// Clears ``AdversarySlot/isDefeated`` if the adversary's HP rises above 0.
  public func applyHealing(_ amount: Int, to id: UUID) {
    if let i = _adversarySlots.firstIndex(where: { $0.id == id }) {
      let s = _adversarySlots[i]
      let newHP = min(s.maxHP, s.currentHP + amount)
      _adversarySlots[i] = s.applying(
        currentHP: newHP, isDefeated: newHP > 0 ? false : s.isDefeated)
      logger.debug("Slot \(id) healed \(amount), HP now \(newHP)/\(s.maxHP)")
      return
    }
    if let i = _playerSlots.firstIndex(where: { $0.id == id }) {
      let s = _playerSlots[i]
      _playerSlots[i] = s.applying(currentHP: min(s.maxHP, s.currentHP + amount))
      return
    }
    logger.warning("applyHealing: no slot found for id \(id)")
  }

  /// Apply stress to a combat participant by ID, clamping to the slot's maximum.
  public func applyStress(_ amount: Int, to id: UUID) {
    if let i = _adversarySlots.firstIndex(where: { $0.id == id }) {
      let s = _adversarySlots[i]
      _adversarySlots[i] = s.applying(currentStress: min(s.maxStress, s.currentStress + amount))
      return
    }
    if let i = _playerSlots.firstIndex(where: { $0.id == id }) {
      let s = _playerSlots[i]
      _playerSlots[i] = s.applying(currentStress: min(s.maxStress, s.currentStress + amount))
      return
    }
    logger.warning("applyStress: no slot found for id \(id)")
  }

  /// Reduce stress on a combat participant by ID, clamping to 0.
  public func reduceStress(_ amount: Int, for id: UUID) {
    if let i = _adversarySlots.firstIndex(where: { $0.id == id }) {
      let s = _adversarySlots[i]
      _adversarySlots[i] = s.applying(currentStress: max(0, s.currentStress - amount))
      return
    }
    if let i = _playerSlots.firstIndex(where: { $0.id == id }) {
      let s = _playerSlots[i]
      _playerSlots[i] = s.applying(currentStress: max(0, s.currentStress - amount))
      return
    }
    logger.warning("reduceStress: no slot found for id \(id)")
  }

  // MARK: - Condition Management

  /// Apply a condition to a combat participant by ID.
  /// Per the SRD, the same condition cannot stack — ``Set`` enforces this.
  /// `.custom` conditions with an empty or whitespace-only name are silently ignored.
  public func applyCondition(_ condition: Condition, to id: UUID) {
    if case .custom(let name) = condition,
      name.trimmingCharacters(in: .whitespaces).isEmpty
    {
      return
    }
    if let i = _adversarySlots.firstIndex(where: { $0.id == id }) {
      var updated = _adversarySlots[i].conditions
      updated.insert(condition)
      _adversarySlots[i] = _adversarySlots[i].applying(conditions: updated)
      return
    }
    if let i = _playerSlots.firstIndex(where: { $0.id == id }) {
      var updated = _playerSlots[i].conditions
      updated.insert(condition)
      _playerSlots[i] = _playerSlots[i].applying(conditions: updated)
      return
    }
    logger.warning("applyCondition: no slot found for id \(id)")
  }

  /// Remove a condition from a combat participant by ID.
  public func removeCondition(_ condition: Condition, from id: UUID) {
    if let i = _adversarySlots.firstIndex(where: { $0.id == id }) {
      var updated = _adversarySlots[i].conditions
      updated.remove(condition)
      _adversarySlots[i] = _adversarySlots[i].applying(conditions: updated)
      return
    }
    if let i = _playerSlots.firstIndex(where: { $0.id == id }) {
      var updated = _playerSlots[i].conditions
      updated.remove(condition)
      _playerSlots[i] = _playerSlots[i].applying(conditions: updated)
      return
    }
    logger.warning("removeCondition: no slot found for id \(id)")
  }

  // MARK: - Armor Slot Management

  /// Mark one Armor Slot on a player (used to reduce damage severity).
  public func markArmorSlot(for slotID: UUID) {
    guard let i = _playerSlots.firstIndex(where: { $0.id == slotID }) else { return }
    let s = _playerSlots[i]
    guard s.currentArmorSlots > 0 else { return }
    _playerSlots[i] = s.applying(currentArmorSlots: s.currentArmorSlots - 1)
  }

  /// Restore one Armor Slot on a player (undo a mark, or recover via a rest ability).
  public func restoreArmorSlot(for slotID: UUID) {
    guard let i = _playerSlots.firstIndex(where: { $0.id == slotID }) else { return }
    let s = _playerSlots[i]
    _playerSlots[i] = s.applying(currentArmorSlots: min(s.armorSlots, s.currentArmorSlots + 1))
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
    _adversarySlots.filter { !$0.isDefeated }
  }

  /// `true` when all adversary slots are defeated.
  public var isOver: Bool {
    !_adversarySlots.isEmpty && _adversarySlots.allSatisfy(\.isDefeated)
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
      return AdversarySlot(from: adversary)
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
