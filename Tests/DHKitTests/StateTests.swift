//
//  StateTests.swift
//  DHKitTests
//
//  Unit tests for the session state value types: PlayerState, AdversaryState, EnvironmentState.
//

import DHModels
import Testing

@testable import DHKit

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif
import Foundation

// MARK: - PlayerState

struct PlayerStateTests {

  @Test func playerSlotInitializesWithCorrectDefaults() {
    let slot = PlayerState(
      name: "Aldric",
      maxHP: 6,
      maxStress: 6,
      evasion: 12,
      thresholdMajor: 8,
      thresholdSevere: 15,
      armorSlots: 3
    )
    #expect(slot.name == "Aldric")
    #expect(slot.currentHP == 6)
    #expect(slot.currentStress == 0)
    #expect(slot.currentArmorSlots == 3)
    #expect(slot.conditions.isEmpty)
  }

  @Test func playerSlotEquality() {
    let id = UUID()
    let slot1 = PlayerState(
      id: id, name: "A", maxHP: 6, maxStress: 6,
      evasion: 10, thresholdMajor: 5, thresholdSevere: 10, armorSlots: 2
    )
    let slot2 = PlayerState(
      id: id, name: "A", maxHP: 6, maxStress: 6,
      evasion: 10, thresholdMajor: 5, thresholdSevere: 10, armorSlots: 2
    )
    #expect(slot1 == slot2)
  }
}

// MARK: - AdversaryState

struct AdversaryStateTests {

  @Test func adversarySlotInitializesWithCorrectDefaults() {
    let slot = AdversaryState(adversaryID: "ironguard-soldier", maxHP: 6, maxStress: 3)
    #expect(slot.currentHP == 6)
    #expect(slot.currentStress == 0)
    #expect(slot.isDefeated == false)
    #expect(slot.conditions.isEmpty)
    #expect(slot.customName == nil)
  }

  @Test func adversarySlotConvenienceInitFromAdversary() {
    let adversary = Adversary(
      id: "bandit", name: "Bandit",
      tier: 1, role: .minion, flavorText: "A common thug.",
      difficulty: 8, thresholdMajor: 3, thresholdSevere: 6,
      hp: 4, stress: 2, attackModifier: "+1", attackName: "Dagger",
      attackRange: .veryClose, damage: "1d6 phy"
    )
    let slot = AdversaryState(from: adversary, customName: "Grim")
    #expect(slot.adversaryID == "bandit")
    #expect(slot.maxHP == 4)
    #expect(slot.maxStress == 2)
    #expect(slot.customName == "Grim")
  }

  @Test func adversarySlotApplyingPreservesUnchangedFields() {
    let slot = AdversaryState(adversaryID: "orc", maxHP: 8, maxStress: 4)
    let updated = slot.applying(currentHP: 5)
    #expect(updated.currentHP == 5)
    #expect(updated.maxHP == 8)
    #expect(updated.adversaryID == "orc")
    #expect(updated.id == slot.id)
  }
}

// MARK: - EnvironmentState

struct EnvironmentStateTests {

  @Test func environmentSlotDefaultsToActive() {
    let slot = EnvironmentState(environmentID: "arcane-storm")
    #expect(slot.isActive == true)
    #expect(slot.environmentID == "arcane-storm")
  }

  @Test func environmentSlotApplyingTogglesActive() {
    let slot = EnvironmentState(environmentID: "collapsing-bridge", isActive: true)
    let deactivated = slot.applying(isActive: false)
    #expect(deactivated.isActive == false)
    #expect(deactivated.id == slot.id)
    #expect(deactivated.environmentID == slot.environmentID)
  }
}
