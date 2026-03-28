//
//  SessionRegistry.swift
//  Encounter
//
//  In-memory registry of live EncounterSessions, keyed by EncounterDefinition.ID.
//  Injected into the SwiftUI environment at app launch alongside Compendium
//  and EncounterStore.
//
//  Sessions are retained for the lifetime of the app process.
//  Cross-launch persistence is a future enhancement.
//

import DHModels
import Foundation
import Observation

/// In-memory registry of live ``EncounterSession`` objects, keyed by definition ID.
///
/// Inject once at app launch:
/// ```swift
/// @State private var sessionRegistry = SessionRegistry()
///
/// ContentView()
///     .environment(sessionRegistry)
/// ```
///
/// Retrieve or create a session via ``session(for:definition:compendium:)``.
/// The same session is returned on every call for a given definition ID until
/// ``clearSession(for:)`` is called.
@MainActor
@Observable
public final class SessionRegistry {
  public private(set) var sessions: [UUID: EncounterSession] = [:]

  public init() {}

  /// Return the existing session for `definitionID`, or create and store a new one.
  public func session(
    for definitionID: UUID,
    definition: EncounterDefinition,
    compendium: Compendium
  ) -> EncounterSession {
    if let existing = sessions[definitionID] { return existing }
    let newSession = EncounterSession.make(from: definition, using: compendium)
    sessions[definitionID] = newSession
    return newSession
  }

  /// Remove the stored session so the next call to ``session(for:definition:compendium:)``
  /// starts a fresh session.
  public func clearSession(for definitionID: UUID) {
    sessions.removeValue(forKey: definitionID)
  }

  /// Discard the existing session and immediately create a fresh one from the given definition.
  ///
  /// Use this when the GM wants to restart an encounter from scratch without navigating away.
  @discardableResult
  public func resetSession(
    for definitionID: UUID,
    definition: EncounterDefinition,
    compendium: Compendium
  ) -> EncounterSession {
    let newSession = EncounterSession.make(from: definition, using: compendium)
    sessions[definitionID] = newSession
    return newSession
  }
}
