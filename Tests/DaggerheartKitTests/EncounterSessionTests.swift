//
//  EncounterSessionTests.swift
//  DaggerheartKitTests
//
//  Unit tests for EncounterSession mutations, AdversarySlot stat snapshots,
//  PlayerSlot session integration, and EncounterSession factory (start from definition).
//

import DaggerheartModels
import Foundation
import Testing

@testable import DaggerheartKit

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
      type: .bruiser,
      description: "A disciplined mercenary.",
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
    let slotID = session.adversarySlots[0].id

    session.applyDamage(4, to: slotID)
    #expect(session.adversarySlots[0].currentHP == 2)
  }

  @Test func applyDamageToZeroMarksDefeated() {
    let session = makeSession()
    let soldier = makeSoldier()
    session.add(adversary: soldier)
    let slotID = session.adversarySlots[0].id

    session.applyDamage(100, to: slotID)
    #expect(session.adversarySlots[0].currentHP == 0)
    #expect(session.adversarySlots[0].isDefeated == true)
    #expect(session.activeAdversaries.isEmpty)
  }

  @Test func fearAndHopeMutations() {
    let session = makeSession()
    session.incrementFear(by: 3)
    #expect(session.fearPool == 3)

    session.spendFear(2)
    #expect(session.fearPool == 1)

    session.spendFear(10)  // clamped
    #expect(session.fearPool == 0)

    session.incrementHope(by: 5)
    session.spendHope(2)
    #expect(session.hopePool == 3)
  }

  @Test func isOverWhenAllDefeated() {
    let session = makeSession()
    let soldier = makeSoldier()
    session.add(adversary: soldier)
    #expect(session.isOver == false)

    let slotID = session.adversarySlots[0].id
    session.applyDamage(999, to: slotID)
    #expect(session.isOver == true)
  }

  @Test func advanceRoundIncrementsCounter() {
    let session = makeSession()
    #expect(session.currentRound == 1)
    session.advanceRound()
    #expect(session.currentRound == 2)
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
    let slotID = session.adversarySlots[0].id

    session.applyCondition(.restrained, to: slotID)
    #expect(session.adversarySlots[0].conditions.contains(.restrained))
  }

  @Test func removeConditionFromAdversarySlot() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    let slotID = session.adversarySlots[0].id

    session.applyCondition(.hidden, to: slotID)
    session.removeCondition(.hidden, from: slotID)
    #expect(!session.adversarySlots[0].conditions.contains(.hidden))
  }

  @Test func conditionsDoNotStack() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    let slotID = session.adversarySlots[0].id

    session.applyCondition(.vulnerable, to: slotID)
    session.applyCondition(.vulnerable, to: slotID)
    #expect(session.adversarySlots[0].conditions.count == 1)
  }

  @Test func emptyCustomConditionOnAdversaryIsRejected() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    let slotID = session.adversarySlots[0].id

    session.applyCondition(.custom(""), to: slotID)
    #expect(session.adversarySlots[0].conditions.isEmpty)
  }

  @Test func whitespaceCustomConditionOnAdversaryIsRejected() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    let slotID = session.adversarySlots[0].id

    session.applyCondition(.custom("   "), to: slotID)
    #expect(session.adversarySlots[0].conditions.isEmpty)
  }

  @Test func customConditionOnAdversarySlot() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    let slotID = session.adversarySlots[0].id

    session.applyCondition(.custom("Enraged"), to: slotID)
    #expect(session.adversarySlots[0].conditions.contains(.custom("Enraged")))
  }

  // MARK: Turn Order

  @Test func advanceTurnSkipsDefeatedAdversary() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    session.add(adversary: makeSoldier())

    let firstID = session.turnOrder[0]
    let secondID = session.turnOrder[1]

    session.applyDamage(999, to: firstID)
    session.advanceTurn()
    #expect(session.activeSlotID == secondID)
  }

  @Test func advanceTurnSkipsDefeatedMidRound() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    session.add(adversary: makeSoldier())
    session.add(adversary: makeSoldier())

    let firstID = session.turnOrder[0]
    let secondID = session.turnOrder[1]
    let thirdID = session.turnOrder[2]

    session.advanceTurn()
    session.advanceTurn()
    #expect(session.activeSlotID == secondID)

    session.applyDamage(999, to: thirdID)
    session.advanceTurn()
    #expect(session.activeSlotID == firstID)
  }

  @Test func advanceTurnCyclesSlots() {
    let session = makeSession()
    let soldier = makeSoldier()
    session.add(adversary: soldier)
    session.add(adversary: soldier)

    let first = session.turnOrder[0]
    let second = session.turnOrder[1]

    session.advanceTurn()
    #expect(session.activeSlotID == first)

    session.advanceTurn()
    #expect(session.activeSlotID == second)

    session.advanceTurn()
    #expect(session.activeSlotID == first)
  }
}

// MARK: - PlayerSlot Session Integration

@MainActor struct PlayerSlotSessionTests {

  private func makeSession() -> EncounterSession {
    EncounterSession(name: "Test Encounter")
  }

  private func makeSoldier() -> Adversary {
    Adversary(
      id: "ironguard-soldier",
      name: "Ironguard Soldier",
      tier: 1,
      type: .bruiser,
      description: "A disciplined mercenary.",
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

  private func makePlayer() -> PlayerSlot {
    PlayerSlot(
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
    session.addPlayer(makePlayer())
    #expect(session.playerSlots.count == 1)
    #expect(session.playerSlots[0].name == "Aldric")
  }

  @Test func turnOrderIncludesPlayersAndAdversaries() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    session.addPlayer(makePlayer())
    #expect(session.turnOrder.count == 2)
  }

  @Test func advanceTurnCyclesThroughBothSlotTypes() {
    let session = makeSession()
    session.add(adversary: makeSoldier())
    session.addPlayer(makePlayer())

    session.advanceTurn()
    #expect(session.activeSlotID == session.turnOrder[0])

    session.advanceTurn()
    #expect(session.activeSlotID == session.turnOrder[1])
  }

  @Test func applyDamageToPlayerSlot() {
    let session = makeSession()
    session.addPlayer(makePlayer())
    let slotID = session.playerSlots[0].id

    session.applyPlayerDamage(2, to: slotID)
    #expect(session.playerSlots[0].currentHP == 4)
  }

  @Test func playerDamageClampsToZero() {
    let session = makeSession()
    session.addPlayer(makePlayer())
    let slotID = session.playerSlots[0].id

    session.applyPlayerDamage(100, to: slotID)
    #expect(session.playerSlots[0].currentHP == 0)
  }

  @Test func applyStressToPlayerSlot() {
    let session = makeSession()
    session.addPlayer(makePlayer())
    let slotID = session.playerSlots[0].id

    session.applyPlayerStress(3, to: slotID)
    #expect(session.playerSlots[0].currentStress == 3)
  }

  @Test func playerStressClampsToMax() {
    let session = makeSession()
    session.addPlayer(makePlayer())
    let slotID = session.playerSlots[0].id

    session.applyPlayerStress(100, to: slotID)
    #expect(session.playerSlots[0].currentStress == 6)
  }

  @Test func healPlayerSlot() {
    let session = makeSession()
    session.addPlayer(makePlayer())
    let slotID = session.playerSlots[0].id

    session.applyPlayerDamage(4, to: slotID)
    session.healPlayer(2, slotID: slotID)
    #expect(session.playerSlots[0].currentHP == 4)
  }

  @Test func healPlayerClampsToMax() {
    let session = makeSession()
    session.addPlayer(makePlayer())
    let slotID = session.playerSlots[0].id

    session.applyPlayerDamage(2, to: slotID)
    session.healPlayer(100, slotID: slotID)
    #expect(session.playerSlots[0].currentHP == 6)
  }

  @Test func clearPlayerStress() {
    let session = makeSession()
    session.addPlayer(makePlayer())
    let slotID = session.playerSlots[0].id

    session.applyPlayerStress(4, to: slotID)
    session.clearPlayerStress(2, slotID: slotID)
    #expect(session.playerSlots[0].currentStress == 2)
  }

  @Test func markArmorSlotOnPlayer() {
    let session = makeSession()
    session.addPlayer(makePlayer())
    let slotID = session.playerSlots[0].id

    session.markPlayerArmorSlot(slotID)
    #expect(session.playerSlots[0].currentArmorSlots == 2)
  }

  @Test func markArmorSlotClampsToZero() {
    let session = makeSession()
    var player = makePlayer()
    player = PlayerSlot(
      name: player.name, maxHP: player.maxHP, maxStress: player.maxStress,
      evasion: player.evasion, thresholdMajor: player.thresholdMajor,
      thresholdSevere: player.thresholdSevere, armorSlots: 1
    )
    session.addPlayer(player)
    let slotID = session.playerSlots[0].id

    session.markPlayerArmorSlot(slotID)
    session.markPlayerArmorSlot(slotID)  // already at 0
    #expect(session.playerSlots[0].currentArmorSlots == 0)
  }

  @Test func emptyCustomConditionOnPlayerIsRejected() {
    let session = makeSession()
    session.addPlayer(makePlayer())
    let slotID = session.playerSlots[0].id

    session.applyPlayerCondition(.custom(""), to: slotID)
    #expect(session.playerSlots[0].conditions.isEmpty)
  }

  @Test func applyConditionToPlayerSlot() {
    let session = makeSession()
    session.addPlayer(makePlayer())
    let slotID = session.playerSlots[0].id

    session.applyPlayerCondition(.vulnerable, to: slotID)
    #expect(session.playerSlots[0].conditions.contains(.vulnerable))
  }

  @Test func removeConditionFromPlayerSlot() {
    let session = makeSession()
    session.addPlayer(makePlayer())
    let slotID = session.playerSlots[0].id

    session.applyPlayerCondition(.hidden, to: slotID)
    session.removePlayerCondition(.hidden, from: slotID)
    #expect(!session.playerSlots[0].conditions.contains(.hidden))
  }

  @Test func removePlayerFromSession() {
    let session = makeSession()
    session.addPlayer(makePlayer())
    let slotID = session.playerSlots[0].id

    session.removePlayer(id: slotID)
    #expect(session.playerSlots.isEmpty)
    #expect(!session.turnOrder.contains(slotID))
  }
}

// MARK: - EncounterSession Factory

@MainActor struct EncounterSessionFactoryTests {

  private func makeCompendium() -> Compendium {
    let comp = Compendium()
    comp.addAdversary(
      Adversary(
        id: "ironguard-soldier", name: "Ironguard Soldier",
        tier: 1, type: .bruiser, description: "A disciplined mercenary.",
        difficulty: 11, thresholdMajor: 5, thresholdSevere: 10,
        hp: 6, stress: 3, attackModifier: "+3", attackName: "Longsword",
        attackRange: .veryClose, damage: "1d10+3 phy"
      ))
    comp.addEnvironment(
      DaggerheartEnvironment(
        id: "collapsing-bridge", name: "Collapsing Bridge",
        description: "A rope-and-plank bridge."
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

    let session = EncounterSession.start(from: def, using: compendium)

    #expect(session.name == "Test Battle")
    #expect(session.adversarySlots.count == 2)
    #expect(session.adversarySlots[0].currentHP == 6)
    #expect(session.playerSlots.count == 1)
    #expect(session.playerSlots[0].name == "Aldric")
    #expect(session.environmentSlots.count == 1)
    #expect(session.currentRound == 1)
    #expect(session.fearPool == 0)
  }

  @Test func sessionFromDefinitionSkipsUnknownAdversaries() {
    let compendium = makeCompendium()
    var def = EncounterDefinition(name: "Test")
    def.adversaryIDs = ["ironguard-soldier", "nonexistent-creature"]

    let session = EncounterSession.start(from: def, using: compendium)
    #expect(session.adversarySlots.count == 1)
  }

  @Test func sessionFromDefinitionPreservesGMNotes() {
    let compendium = makeCompendium()
    var def = EncounterDefinition(name: "Test")
    def.gmNotes = "Remember the secret door."

    let session = EncounterSession.start(from: def, using: compendium)
    #expect(session.gmNotes == "Remember the secret door.")
  }

  @Test func sessionFromDefinitionBuildsTurnOrder() {
    let compendium = makeCompendium()
    var def = EncounterDefinition(name: "Test")
    def.adversaryIDs = ["ironguard-soldier"]
    def.playerConfigs = [
      PlayerConfig(
        name: "Aldric", maxHP: 6, maxStress: 6,
        evasion: 12, thresholdMajor: 8, thresholdSevere: 15, armorSlots: 3
      )
    ]

    let session = EncounterSession.start(from: def, using: compendium)
    #expect(session.turnOrder.count == 2)
  }
}

// MARK: - AdversarySlot stat snapshot

@MainActor struct AdversarySlotSnapshotTests {

  private func makeSoldier() -> Adversary {
    Adversary(
      id: "ironguard-soldier", name: "Ironguard Soldier", tier: 1, type: .bruiser,
      description: "A disciplined mercenary.", difficulty: 11,
      thresholdMajor: 5, thresholdSevere: 10, hp: 6, stress: 3,
      attackModifier: "+3", attackName: "Longsword",
      attackRange: .veryClose, damage: "1d10+3 phy"
    )
  }

  @Test func slotSnapshotsMaxHPAndMaxStress() {
    let slot = AdversarySlot.from(makeSoldier())
    #expect(slot.maxHP == 6)
    #expect(slot.maxStress == 3)
  }

  @Test func applyStressClampedToSnapshotMax() {
    let session = EncounterSession(name: "Test")
    session.add(adversary: makeSoldier())
    let slotID = session.adversarySlots[0].id

    session.applyStress(100, to: slotID)
    #expect(session.adversarySlots[0].currentStress == 3)
  }

  @Test func applyStressAccumulatesCorrectly() {
    let session = EncounterSession(name: "Test")
    session.add(adversary: makeSoldier())
    let slotID = session.adversarySlots[0].id

    session.applyStress(1, to: slotID)
    session.applyStress(1, to: slotID)
    #expect(session.adversarySlots[0].currentStress == 2)
  }

  @Test func healClampedToSnapshotMaxHP() {
    let session = EncounterSession(name: "Test")
    session.add(adversary: makeSoldier())
    let slotID = session.adversarySlots[0].id

    session.applyDamage(4, to: slotID)
    session.heal(100, slotID: slotID)
    #expect(session.adversarySlots[0].currentHP == 6)
  }

  @Test func healFromZeroUnsetsDefeated() {
    let session = EncounterSession(name: "Test")
    session.add(adversary: makeSoldier())
    let slotID = session.adversarySlots[0].id

    session.applyDamage(999, to: slotID)
    #expect(session.adversarySlots[0].isDefeated == true)
    session.heal(6, slotID: slotID)
    #expect(session.adversarySlots[0].isDefeated == false)
    #expect(session.adversarySlots[0].currentHP == 6)
  }
}
