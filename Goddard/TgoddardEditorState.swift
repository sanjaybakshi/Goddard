//
//  TgoddardEditorState.swift
//  Goddard
//
//  Transient editor / UI state — deliberately separate from TgoddardModel (which
//  holds the document/persisted state) and from TrunTelemetry (live run readout).
//  Nothing here is saved to a project; it's just "what is the UI doing right now."
//  Same pattern as TrunTelemetry: pull a distinct concern onto its own observable.
//

import Foundation
import Combine          // required for @Published's init(wrappedValue:)

final class TgoddardEditorState: ObservableObject {
    /// When true, the goal-placement overlay is shown on the canvas for editing.
    @Published var editingGoalPlacement = false
}
