//
//  SessionRegistry.swift
//  Encounter
//
//  In-memory registry of live EncounterSessions, keyed by EncounterDefinition.ID.
//  Injected into the SwiftUI environment at app launch alongside Compendium
//  and EncounterStore.
//
//  Sessions are retained for the lifetime of the app process.
//  Use insert(_:) to restore pre-decoded sessions at startup.
//

import DHModels
import Foundation
import Observation

#if canImport(FoundationEssentials)
  import FoundationEssentials
#endif

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
  /// All live sessions currently held by this registry, keyed by definition ID.
  public private(set) var sessions: [UUID: EncounterSession] = [:]

  /// Creates an empty session registry.
  public init() {}

  /// Return the existing session for `definition.id`, or create and store a new one.
  public func session(
    for definition: EncounterDefinition,
    compendium: Compendium
  ) -> EncounterSession {
    if let existing = sessions[definition.id] { return existing }
    let newSession = EncounterSession.make(from: definition, using: compendium)
    sessions[definition.id] = newSession
    return newSession
  }

  /// Restore a pre-decoded session (e.g. loaded from disk at startup).
  /// Does not overwrite an existing live session for the same definition ID.
  public func insert(_ session: EncounterSession) {
    guard let defID = session.definitionID else { return }
    guard sessions[defID] == nil else { return }
    sessions[defID] = session
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
    for definition: EncounterDefinition,
    compendium: Compendium
  ) -> EncounterSession {
    let newSession = EncounterSession.make(from: definition, using: compendium)
    sessions[definition.id] = newSession
    return newSession
  }
}
