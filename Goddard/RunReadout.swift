//
//  RunReadout.swift
//  Goddard
//
//  The live loss + steps/sec lines in the Run section. Its own View struct on
//  purpose: it is the ONLY view that observes TrunTelemetry, so the loop's ~10 Hz
//  updates re-render just these two lines — not the whole parameter panel. The
//  parent passes the telemetry object down; only this view subscribes to it.
//

import SwiftUI

struct RunReadout: View {
    @ObservedObject var telemetry: TrunTelemetry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(format: "loss  %.6f", telemetry.loss))
            Text(telemetry.stepsPerSecond > 0
                 ? String(format: "%.0f steps/sec", telemetry.stepsPerSecond)
                 : "— steps/sec")
        }
        .font(.system(.callout, design: .monospaced))
        .foregroundStyle(.secondary)
    }
}
