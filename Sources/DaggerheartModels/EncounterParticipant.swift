//
//  EncounterParticipant.swift
//  DaggerheartModels
//
//  Protocols for encounter participants, enabling the spotlight and
//  combat mutation APIs to work uniformly across adversary and player slots.
//

import Foundation

/// A participant in a Daggerheart encounter that can hold the spotlight.
///
/// All adversary, environment, and player slots conform to this protocol,
/// allowing the spotlight API to accept any participant type uniformly.
public protocol EncounterParticipant: Identifiable where ID == UUID {}

/// An encounter participant that tracks HP, Stress, and Conditions.
///
/// Conformed to by ``AdversarySlot`` and ``PlayerSlot``. Enables
/// unified combat mutation methods on ``EncounterSession`` without
/// requiring separate adversary- and player-specific overloads.
public protocol CombatParticipant: EncounterParticipant {
  var currentHP: Int { get set }
  var maxHP: Int { get }
  var currentStress: Int { get set }
  var maxStress: Int { get }
  var conditions: Set<Condition> { get set }
}
