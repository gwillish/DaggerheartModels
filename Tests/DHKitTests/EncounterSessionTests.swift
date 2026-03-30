//
//  EncounterSessionTests.swift
//  DaggerheartKitTests
//
//  Unit tests for EncounterSession mutations, AdversaryState stat snapshots,
//  PlayerState session integration, and EncounterSession factory (start from definition).
//

import DHModels
import Testing

@testable import DHKit

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif
import Foundation

// MARK: - EncounterSession

@MainActor struct EncounterSessionTests {

  private func makeSession() -> EncounterSession {
    EncounterSession(name: "Test Encounter")
  }

  private func makeSoldier() -> Adversary {
    Adversary(
      id: "ironguard-soldier",
      name: "Ironguard Soldier",
      tier: 1,
      role: .bruiser,
      flavorText: "A disciplined mercenary.",
      difficulty: 11,
      thresholdMajor: 5,
      thresholdSevere: 10,
      hp: 6,
      stress: 3,
      attackModifier: "+3",
      attackName: "Longsword",
      attackRange: .veryClose,
      damage: "1d10+3 phy"
    )
  }

  @Test func addAdversaryPopulatesSlot() {
    let session = makeSession()
    let soldier = makeSoldier()
    session.add(adversary: soldier)

    #expect(session.adversarySlots.count == 1)
    #expect(session.adversarySlots[0].currentHP == 6)
    #expect(session.adversarySlots[0].currentStress == 0)
    #expect(session.adversarySlots[0].isDefeated == false)
  }

  @Test func applyDamageReducesHP() {
    let session = makeSession()
    let soldier = makeSoldier()
    session.add(adversary: soldier)
    let slot = session.adversarySlots[0]

    session.applyDamage(4, to: slot.id)
    #expect(session.adversarySlots[0].currentHP == 2)
  }

  @Test func applyDamageToZeroMarksDefeated() {
    let session = makeSession()
    let soldier = makeSoldier()
    session.add(adversary: soldier)
    let slot = session.adversarySlots[0]

    session.applyDamage(100, to: slot.id)
    #expect(session.adversarySlots[0].currentHP == 0)
    #expect(session.adversarySlots[0].isDefeated == true)
    #expect(session.activeAdversaries.isEmpty)
  }

  @Test func fearAndHopeMutations() {
    let session = makeSession()
    session.incrementFear(by: 3)
    #expect(session.fearPool == 3)

    session.spendFear(by: 2)
    #expect(session.fearPool == 1)

    session.spendFear(by: 10)  // clamped
    #expect(session.fearPool == 0)

    session.incrementHope(by: 5)
    session.spendHope(by: 2)
    #expect(session.hopePool == 3)
  }

  @Test func isOverWhenAllDefeated() {
    let session = makeSession()
    let soldier = makeSoldier()
    session.add(adversary: soldier)
    #expect(session.isOver == false)

    let slot = session.adversarySlots[0]
    session.applyDamage(999, to: slot.id)
    #expect(session.isOver == true)
  }

  @Test func spotlightCountStartsAtZero() {
    let session = makeSession()
    #expect(session.spotlightCount == 0)
  }

  @Test func spotlightIncrementsSporlightCount() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    let slot = session.adversarySlots[0]

    session.spotlight(id: slot.id)
    #expect(session.spotlightCount == 1)
    #expect(session.spotlightedSlotID == slot.id)

    session.yieldSpotlight()
    #expect(session.spotlightedSlotID == nil)
    #expect(session.spotlightCount == 1)  // count doesn't reset on yield
  }

  @Test func spotlightMultipleTimesAccumulates() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    session.add(adversary: makeSoldier())
    let first = session.adversarySlots[0]
    let second = session.adversarySlots[1]

    session.spotlight(id: first.id)
    session.spotlight(id: second.id)
    #expect(session.spotlightCount == 2)
    #expect(session.spotlightedSlotID == second.id)
  }

  // MARK: Adversary Conditions

  @Test func adversarySlotStartsWithNoConditions() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    #expect(session.adversarySlots[0].conditions.isEmpty)
  }

  @Test func applyConditionToAdversarySlot() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    let slot = session.adversarySlots[0]

    session.applyCondition(.restrained, to: slot.id)
    #expect(session.adversarySlots[0].conditions.contains(.restrained))
  }

  @Test func removeConditionFromAdversarySlot() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    let slot = session.adversarySlots[0]

    session.applyCondition(.hidden, to: slot.id)
    session.removeCondition(.hidden, from: slot.id)
    #expect(!session.adversarySlots[0].conditions.contains(.hidden))
  }

  @Test func conditionsDoNotStack() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    let slot = session.adversarySlots[0]

    session.applyCondition(.vulnerable, to: slot.id)
    session.applyCondition(.vulnerable, to: slot.id)
    #expect(session.adversarySlots[0].conditions.count == 1)
  }

  @Test func emptyCustomConditionOnAdversaryIsRejected() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    let slot = session.adversarySlots[0]

    session.applyCondition(.custom(""), to: slot.id)
    #expect(session.adversarySlots[0].conditions.isEmpty)
  }

  @Test func whitespaceCustomConditionOnAdversaryIsRejected() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    let slot = session.adversarySlots[0]

    session.applyCondition(.custom("   "), to: slot.id)
    #expect(session.adversarySlots[0].conditions.isEmpty)
  }

  @Test func customConditionOnAdversarySlot() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    let slot = session.adversarySlots[0]

    session.applyCondition(.custom("Enraged"), to: slot.id)
    #expect(session.adversarySlots[0].conditions.contains(.custom("Enraged")))
  }
}

// MARK: - PlayerState Session Integration

@MainActor struct PlayerStateSessionTests {

  private func makeSession() -> EncounterSession {
    EncounterSession(name: "Test Encounter")
  }

  private func makeSoldier() -> Adversary {
    Adversary(
      id: "ironguard-soldier",
      name: "Ironguard Soldier",
      tier: 1,
      role: .bruiser,
      flavorText: "A disciplined mercenary.",
      difficulty: 11,
      thresholdMajor: 5,
      thresholdSevere: 10,
      hp: 6,
      stress: 3,
      attackModifier: "+3",
      attackName: "Longsword",
      attackRange: .veryClose,
      damage: "1d10+3 phy"
    )
  }

  private func makePlayer() -> PlayerState {
    PlayerState(
      name: "Aldric",
      maxHP: 6,
      maxStress: 6,
      evasion: 12,
      thresholdMajor: 8,
      thresholdSevere: 15,
      armorSlots: 3
    )
  }

  @Test func addPlayerSlotToSession() {
    let session = makeSession()
    session.add(player: makePlayer())
    #expect(session.playerSlots.count == 1)
    #expect(session.playerSlots[0].name == "Aldric")
  }

  @Test func spotlightCyclesThroughBothSlotTypes() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    session.add(player: makePlayer())

    let adversarySlot = session.adversarySlots[0]
    let playerSlot = session.playerSlots[0]

    session.spotlight(id: adversarySlot.id)
    #expect(session.spotlightedSlotID == adversarySlot.id)

    session.spotlight(id: playerSlot.id)
    #expect(session.spotlightedSlotID == playerSlot.id)
  }

  @Test func applyDamageToPlayerSlot() {
    let session = makeSession()
    session.add(player: makePlayer())
    let slot = session.playerSlots[0]

    session.applyDamage(2, to: slot.id)
    #expect(session.playerSlots[0].currentHP == 4)
  }

  @Test func playerDamageClampsToZero() {
    let session = makeSession()
    session.add(player: makePlayer())
    let slot = session.playerSlots[0]

    session.applyDamage(100, to: slot.id)
    #expect(session.playerSlots[0].currentHP == 0)
  }

  @Test func applyStressToPlayerSlot() {
    let session = makeSession()
    session.add(player: makePlayer())
    let slot = session.playerSlots[0]

    session.applyStress(3, to: slot.id)
    #expect(session.playerSlots[0].currentStress == 3)
  }

  @Test func playerStressClampsToMax() {
    let session = makeSession()
    session.add(player: makePlayer())
    let slot = session.playerSlots[0]

    session.applyStress(100, to: slot.id)
    #expect(session.playerSlots[0].currentStress == 6)
  }

  @Test func healPlayerSlot() {
    let session = makeSession()
    session.add(player: makePlayer())
    let slot = session.playerSlots[0]

    session.applyDamage(4, to: slot.id)
    session.applyHealing(2, to: slot.id)
    #expect(session.playerSlots[0].currentHP == 4)
  }

  @Test func healPlayerClampsToMax() {
    let session = makeSession()
    session.add(player: makePlayer())
    let slot = session.playerSlots[0]

    session.applyDamage(2, to: slot.id)
    session.applyHealing(100, to: slot.id)
    #expect(session.playerSlots[0].currentHP == 6)
  }

  @Test func reducePlayerStress() {
    let session = makeSession()
    session.add(player: makePlayer())
    let slot = session.playerSlots[0]

    session.applyStress(4, to: slot.id)
    session.reduceStress(2, for: slot.id)
    #expect(session.playerSlots[0].currentStress == 2)
  }

  @Test func markArmorSlotOnPlayer() {
    let session = makeSession()
    session.add(player: makePlayer())
    let slotID = session.playerSlots[0].id

    session.markArmorSlot(for: slotID)
    #expect(session.playerSlots[0].currentArmorSlots == 2)
  }

  @Test func markArmorSlotClampsToZero() {
    let session = makeSession()
    var player = makePlayer()
    player = PlayerState(
      name: player.name, maxHP: player.maxHP, maxStress: player.maxStress,
      evasion: player.evasion, thresholdMajor: player.thresholdMajor,
      thresholdSevere: player.thresholdSevere, armorSlots: 1
    )
    session.add(player: player)
    let slotID = session.playerSlots[0].id

    session.markArmorSlot(for: slotID)
    session.markArmorSlot(for: slotID)  // already at 0
    #expect(session.playerSlots[0].currentArmorSlots == 0)
  }

  @Test func emptyCustomConditionOnPlayerIsRejected() {
    let session = makeSession()
    session.add(player: makePlayer())
    let slot = session.playerSlots[0]

    session.applyCondition(.custom(""), to: slot.id)
    #expect(session.playerSlots[0].conditions.isEmpty)
  }

  @Test func applyConditionToPlayerSlot() {
    let session = makeSession()
    session.add(player: makePlayer())
    let slot = session.playerSlots[0]

    session.applyCondition(.vulnerable, to: slot.id)
    #expect(session.playerSlots[0].conditions.contains(.vulnerable))
  }

  @Test func removeConditionFromPlayerSlot() {
    let session = makeSession()
    session.add(player: makePlayer())
    let slot = session.playerSlots[0]

    session.applyCondition(.hidden, to: slot.id)
    session.removeCondition(.hidden, from: slot.id)
    #expect(!session.playerSlots[0].conditions.contains(.hidden))
  }

  @Test func removePlayerFromSession() {
    let session = makeSession()
    session.add(player: makePlayer())
    let slotID = session.playerSlots[0].id

    session.removePlayer(withID: slotID)
    #expect(session.playerSlots.isEmpty)
    #expect(session.spotlightedSlotID == nil)
  }
}

// MARK: - EncounterSession Factory

@MainActor struct EncounterSessionFactoryTests {

  private func makeCompendium() -> Compendium {
    let comp = Compendium()
    comp.addAdversary(
      Adversary(
        id: "ironguard-soldier", name: "Ironguard Soldier",
        tier: 1, role: .bruiser, flavorText: "A disciplined mercenary.",
        difficulty: 11, thresholdMajor: 5, thresholdSevere: 10,
        hp: 6, stress: 3, attackModifier: "+3", attackName: "Longsword",
        attackRange: .veryClose, damage: "1d10+3 phy"
      ))
    comp.addEnvironment(
      DaggerheartEnvironment(
        id: "collapsing-bridge", name: "Collapsing Bridge",
        flavorText: "A rope-and-plank bridge."
      ))
    return comp
  }

  @Test func sessionFromDefinitionPopulatesSlots() {
    let compendium = makeCompendium()
    var def = EncounterDefinition(name: "Test Battle")
    def.adversaryIDs = ["ironguard-soldier", "ironguard-soldier"]
    def.environmentIDs = ["collapsing-bridge"]
    def.playerConfigs = [
      PlayerConfig(
        name: "Aldric", maxHP: 6, maxStress: 6,
        evasion: 12, thresholdMajor: 8, thresholdSevere: 15, armorSlots: 3
      )
    ]

    let session = EncounterSession.make(from: def, using: compendium)

    #expect(session.name == "Test Battle")
    #expect(session.adversarySlots.count == 2)
    #expect(session.adversarySlots[0].currentHP == 6)
    #expect(session.playerSlots.count == 1)
    #expect(session.playerSlots[0].name == "Aldric")
    #expect(session.environmentSlots.count == 1)
    #expect(session.spotlightCount == 0)
    #expect(session.fearPool == 0)
  }

  @Test func sessionFromDefinitionSkipsUnknownAdversaries() {
    let compendium = makeCompendium()
    var def = EncounterDefinition(name: "Test")
    def.adversaryIDs = ["ironguard-soldier", "nonexistent-creature"]

    let session = EncounterSession.make(from: def, using: compendium)
    #expect(session.adversarySlots.count == 1)
  }

  @Test func sessionFromDefinitionPreservesGMNotes() {
    let compendium = makeCompendium()
    var def = EncounterDefinition(name: "Test")
    def.gmNotes = "Remember the secret door."

    let session = EncounterSession.make(from: def, using: compendium)
    #expect(session.gmNotes == "Remember the secret door.")
  }

  @Test func sessionFromDefinitionHasNoInitialSpotlight() {
    let compendium = makeCompendium()
    var def = EncounterDefinition(name: "Test")
    def.adversaryIDs = ["ironguard-soldier"]
    def.playerConfigs = [
      PlayerConfig(
        name: "Aldric", maxHP: 6, maxStress: 6,
        evasion: 12, thresholdMajor: 8, thresholdSevere: 15, armorSlots: 3
      )
    ]

    let session = EncounterSession.make(from: def, using: compendium)
    #expect(session.spotlightedSlotID == nil)
    #expect(session.spotlightCount == 0)
  }
}

// MARK: - AdversaryState stat snapshot

@MainActor struct AdversaryStateSnapshotTests {

  private func makeSoldier() -> Adversary {
    Adversary(
      id: "ironguard-soldier", name: "Ironguard Soldier", tier: 1, role: .bruiser,
      flavorText: "A disciplined mercenary.", difficulty: 11,
      thresholdMajor: 5, thresholdSevere: 10, hp: 6, stress: 3,
      attackModifier: "+3", attackName: "Longsword",
      attackRange: .veryClose, damage: "1d10+3 phy"
    )
  }

  @Test func slotSnapshotsMaxHPAndMaxStress() {
    let soldier = makeSoldier()
    let slot = AdversaryState(adversaryID: soldier.id, maxHP: soldier.hp, maxStress: soldier.stress)
    #expect(slot.maxHP == 6)
    #expect(slot.maxStress == 3)
  }

  @Test func applyStressClampedToSnapshotMax() {
    let session = EncounterSession(name: "Test")
    session.add(adversary: makeSoldier())
    let slot = session.adversarySlots[0]

    session.applyStress(100, to: slot.id)
    #expect(session.adversarySlots[0].currentStress == 3)
  }

  @Test func applyStressAccumulatesCorrectly() {
    let session = EncounterSession(name: "Test")
    session.add(adversary: makeSoldier())
    let slot = session.adversarySlots[0]

    session.applyStress(1, to: slot.id)
    session.applyStress(1, to: slot.id)
    #expect(session.adversarySlots[0].currentStress == 2)
  }

  @Test func healClampedToSnapshotMaxHP() {
    let session = EncounterSession(name: "Test")
    session.add(adversary: makeSoldier())
    let slot = session.adversarySlots[0]

    session.applyDamage(4, to: slot.id)
    session.applyHealing(100, to: slot.id)
    #expect(session.adversarySlots[0].currentHP == 6)
  }

  @Test func healFromZeroUnsetsDefeated() {
    let session = EncounterSession(name: "Test")
    session.add(adversary: makeSoldier())
    let slot = session.adversarySlots[0]

    session.applyDamage(999, to: slot.id)
    #expect(session.adversarySlots[0].isDefeated == true)
    session.applyHealing(6, to: slot.id)
    #expect(session.adversarySlots[0].isDefeated == false)
    #expect(session.adversarySlots[0].currentHP == 6)
  }
}
