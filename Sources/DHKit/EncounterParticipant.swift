//
//  EncounterParticipant.swift
//  DHKit
//
//  Protocols for encounter participants, enabling the spotlight and
//  combat mutation APIs to work uniformly across adversary and player slots.
//

import DHModels

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif
import Foundation

/// A participant in a Daggerheart encounter that can hold the spotlight.
///
/// All adversary, environment, and player slots conform to this protocol,
/// allowing the spotlight API to accept any participant type uniformly.
nonisolated public protocol EncounterParticipant: Identifiable where ID == UUID {}

/// An encounter participant that tracks HP, Stress, and Conditions.
///
/// Conformed to by ``AdversaryState`` and ``PlayerState``. Used as a read/display
/// contract; all mutations are performed by ``EncounterSession`` via UUID.
nonisolated public protocol CombatParticipant: EncounterParticipant {
  var currentHP: Int { get }
  var maxHP: Int { get }
  var currentStress: Int { get }
  var maxStress: Int { get }
  var conditions: Set<Condition> { get }
}
