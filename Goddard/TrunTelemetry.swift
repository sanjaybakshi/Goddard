//
//  TrunTelemetry.swift
//  Goddard
//
//  Live run telemetry (loss + optimizer throughput), kept on its OWN observable —
//  deliberately not on TgoddardModel. The off-main step loop updates this at a
//  display cadence (~10 Hz); because it's separate from the model, those updates
//  fire objectWillChange only for the small RunReadout view that observes it, and
//  never invalidate the parameter panel (which observes TgoddardModel).
//

import Foundation
import Combine          // required for @Published's init(wrappedValue:)

final class TrunTelemetry: ObservableObject {
    /// Latest optimizer loss.
    @Published var loss: Float = 0
    /// Measured optimizer throughput (steps/sec); 0 when stopped.
    @Published var stepsPerSecond: Double = 0
}
