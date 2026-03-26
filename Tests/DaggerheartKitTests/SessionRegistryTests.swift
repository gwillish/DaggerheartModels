//
//  SessionRegistryTests.swift
//  DaggerheartKitTests
//
//  Unit tests for SessionRegistry: session creation, caching, clearing,
//  and resetSession behavior.
//

import DaggerheartModels
import Foundation
import Testing

@testable import DaggerheartKit

@MainActor struct SessionRegistryTests {

  private func makeCompendium() -> Compendium {
    let c = Compendium()
    c.addAdversary(
      Adversary(
        id: "goblin", name: "Goblin", tier: 1, type: .minion,
        description: "Small and cunning.", difficulty: 10,
        thresholdMajor: 5, thresholdSevere: 10, hp: 3, stress: 2,
        attackModifier: "+2", attackName: "Rusty Blade",
        attackRange: .veryClose, damage: "1d4 phy"
      ))
    return c
  }

  private func makeDefinition(adversaryIDs: [String] = ["goblin"]) -> EncounterDefinition {
    EncounterDefinition(name: "Test Battle", adversaryIDs: adversaryIDs)
  }

  @Test func sessionIsCreatedOnFirstAccess() {
    let registry = SessionRegistry()
    let compendium = makeCompendium()
    let def = makeDefinition()

    let session = registry.session(for: def.id, definition: def, compendium: compendium)
    #expect(session.adversarySlots.count == 1)
  }

  @Test func sameSessionReturnedOnSubsequentCalls() {
    let registry = SessionRegistry()
    let compendium = makeCompendium()
    let def = makeDefinition()

    let s1 = registry.session(for: def.id, definition: def, compendium: compendium)
    let s2 = registry.session(for: def.id, definition: def, compendium: compendium)
    #expect(s1 === s2)
  }

  @Test func clearSessionRemovesEntry() {
    let registry = SessionRegistry()
    let compendium = makeCompendium()
    let def = makeDefinition()

    _ = registry.session(for: def.id, definition: def, compendium: compendium)
    registry.clearSession(for: def.id)
    #expect(registry.sessions[def.id] == nil)
  }

  @Test func resetSessionCreatesNewSession() {
    let registry = SessionRegistry()
    let compendium = makeCompendium()
    let def1 = makeDefinition(adversaryIDs: ["goblin"])

    let s1 = registry.session(for: def1.id, definition: def1, compendium: compendium)
    s1.applyDamage(2, to: s1.adversarySlots[0].id)
    #expect(s1.adversarySlots[0].currentHP == 1)

    let s2 = registry.resetSession(for: def1.id, definition: def1, compendium: compendium)

    #expect(s2 !== s1)
    #expect(s2.adversarySlots[0].currentHP == 3)
  }

  @Test func resetSessionReplacesStoredSession() {
    let registry = SessionRegistry()
    let compendium = makeCompendium()
    let def = makeDefinition()

    let s1 = registry.session(for: def.id, definition: def, compendium: compendium)
    let s2 = registry.resetSession(for: def.id, definition: def, compendium: compendium)

    let s3 = registry.session(for: def.id, definition: def, compendium: compendium)
    #expect(s3 === s2)
    #expect(s3 !== s1)
  }

  @Test func resetSessionReflectsNewDefinition() {
    let registry = SessionRegistry()
    let compendium = makeCompendium()
    let def1 = makeDefinition(adversaryIDs: ["goblin"])
    var def2 = def1
    def2.adversaryIDs = ["goblin", "goblin"]

    _ = registry.session(for: def1.id, definition: def1, compendium: compendium)
    let s2 = registry.resetSession(for: def2.id, definition: def2, compendium: compendium)

    #expect(s2.adversarySlots.count == 2)
  }
}
