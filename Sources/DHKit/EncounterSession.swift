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
//  - AdversaryState, PlayerState, and EnvironmentState are immutable structs stored
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

#if canImport(FoundationEssentials)
  import FoundationEssentials
#endif

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

  /// The ID of the ``EncounterDefinition`` this session was created from.
  /// `nil` for sessions created directly (tests, blank sessions).
  public let definitionID: UUID?

  /// The modification date of the source definition at the time this session was created.
  /// Used by the registry to detect stale sessions. `nil` if not definition-backed.
  public let definitionSnapshotDate: Date?

  // MARK: Participants (private backing stores)
  private var _adversarySlots: [AdversaryState]
  private var _playerSlots: [PlayerState]
  private var _environmentSlots: [EnvironmentState]

  /// Read-only snapshot of all adversary slots.
  public var adversarySlots: [AdversaryState] { _adversarySlots }
  /// Read-only snapshot of all player slots.
  public var playerSlots: [PlayerState] { _playerSlots }
  /// Read-only snapshot of all environment slots.
  public var environmentSlots: [EnvironmentState] { _environmentSlots }

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
    adversarySlots: [AdversaryState] = [],
    playerSlots: [PlayerState] = [],
    environmentSlots: [EnvironmentState] = [],
    fearPool: Int = 0,
    hopePool: Int = 0,
    spotlightedSlotID: UUID? = nil,
    spotlightCount: Int = 0,
    gmNotes: String = "",
    definitionID: UUID? = nil,
    definitionSnapshotDate: Date? = nil
  ) {
    self.id = id
    self.name = name
    self._adversarySlots = adversarySlots
    self._playerSlots = playerSlots
    self._environmentSlots = environmentSlots
    self.fearPool = fearPool
    self.hopePool = hopePool
    self.spotlightedSlotID = spotlightedSlotID
    self.spotlightCount = spotlightCount
    self.gmNotes = gmNotes
    self.definitionID = definitionID
    self.definitionSnapshotDate = definitionSnapshotDate
  }

  // MARK: - Roster Management

  /// Add a new adversary slot populated from a catalog entry.
  public func add(adversary: Adversary, customName: String? = nil) {
    _adversarySlots.append(AdversaryState(from: adversary, customName: customName))
  }

  /// Add an environment slot.
  public func add(environment: DaggerheartEnvironment) {
    _environmentSlots.append(EnvironmentState(environmentID: environment.id))
  }

  /// Remove an adversary slot by ID.
  public func removeAdversary(withID id: UUID) {
    _adversarySlots.removeAll { $0.id == id }
    if spotlightedSlotID == id { spotlightedSlotID = nil }
  }

  // MARK: - Player Management

  /// Add a player slot to the encounter.
  public func add(player: PlayerState) {
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
  /// Adversary slots are marked ``AdversaryState/isDefeated`` when HP reaches 0.
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
  /// Clears ``AdversaryState/isDefeated`` if the adversary's HP rises above 0.
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
  public var activeAdversaries: [AdversaryState] {
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
    // Count occurrences of each adversary ID so duplicates can be named.
    var counts: [String: Int] = [:]
    for id in definition.adversaryIDs { counts[id, default: 0] += 1 }

    // Assign sequential custom names only when the same adversary appears more than once.
    var counters: [String: Int] = [:]
    let adversarySlots: [AdversaryState] = definition.adversaryIDs.compactMap { id in
      guard let adversary = compendium.adversary(id: id) else { return nil }
      guard (counts[id] ?? 0) > 1 else {
        return AdversaryState(from: adversary)
      }
      let n = (counters[id] ?? 0) + 1
      counters[id] = n
      return AdversaryState(from: adversary, customName: "\(adversary.name) \(n)")
    }

    let environmentSlots: [EnvironmentState] = definition.environmentIDs.compactMap { id in
      guard compendium.environment(id: id) != nil else { return nil }
      return EnvironmentState(environmentID: id)
    }

    let playerSlots: [PlayerState] = definition.playerConfigs.map { config in
      PlayerState(
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
      gmNotes: definition.gmNotes,
      definitionID: definition.id,
      definitionSnapshotDate: definition.modifiedAt
    )
  }
}

// MARK: - Codable

extension EncounterSession: @MainActor Codable {

  enum CodingKeys: String, CodingKey {
    case id, name
    case adversarySlots, playerSlots, environmentSlots
    case fearPool, hopePool, spotlightedSlotID, spotlightCount, gmNotes
    case definitionID, definitionSnapshotDate
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(name, forKey: .name)
    try c.encode(_adversarySlots, forKey: .adversarySlots)
    try c.encode(_playerSlots, forKey: .playerSlots)
    try c.encode(_environmentSlots, forKey: .environmentSlots)
    try c.encode(fearPool, forKey: .fearPool)
    try c.encode(hopePool, forKey: .hopePool)
    try c.encodeIfPresent(spotlightedSlotID, forKey: .spotlightedSlotID)
    try c.encode(spotlightCount, forKey: .spotlightCount)
    try c.encode(gmNotes, forKey: .gmNotes)
    try c.encodeIfPresent(definitionID, forKey: .definitionID)
    try c.encodeIfPresent(definitionSnapshotDate, forKey: .definitionSnapshotDate)
  }

  public convenience init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let id = try c.decode(UUID.self, forKey: .id)
    let name = try c.decode(String.self, forKey: .name)
    let adversarySlots = try c.decode([AdversaryState].self, forKey: .adversarySlots)
    let playerSlots = try c.decode([PlayerState].self, forKey: .playerSlots)
    let environmentSlots = try c.decode([EnvironmentState].self, forKey: .environmentSlots)
    let fearPool = try c.decode(Int.self, forKey: .fearPool)
    let hopePool = try c.decode(Int.self, forKey: .hopePool)
    let spotlightedSlotID = try c.decodeIfPresent(UUID.self, forKey: .spotlightedSlotID)
    let spotlightCount = try c.decode(Int.self, forKey: .spotlightCount)
    let gmNotes = try c.decode(String.self, forKey: .gmNotes)
    let definitionID = try c.decodeIfPresent(UUID.self, forKey: .definitionID)
    let definitionSnapshotDate = try c.decodeIfPresent(Date.self, forKey: .definitionSnapshotDate)
    self.init(
      id: id, name: name,
      adversarySlots: adversarySlots, playerSlots: playerSlots,
      environmentSlots: environmentSlots,
      fearPool: fearPool, hopePool: hopePool,
      spotlightedSlotID: spotlightedSlotID, spotlightCount: spotlightCount, gmNotes: gmNotes,
      definitionID: definitionID, definitionSnapshotDate: definitionSnapshotDate
    )
  }
}
