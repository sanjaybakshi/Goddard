//
//  ParameterPanelView.swift
//  Goddard
//
//  Right-hand inspector panel — generalized from calligramy's ParameterListView,
//  built on the reusable SectionBox + FloatSliderRow. Drives the optimizer live.
//

import SwiftUI
import SameEyesUIKit

struct ParameterPanelView: View {
    @EnvironmentObject var fViewModel: TgoddardViewModel

    @State private var showRun       = true
    @State private var showOptimizer = true
    @State private var showSetup     = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Inspector")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Divider()

                SectionBox("Run", isExpanded: $showRun) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Button(fViewModel.fRunning ? "Pause" : "Run") {
                                fViewModel.toggleRun()
                            }
                            Button("Reset") {
                                fViewModel.buildOptimizer()
                            }
                        }
                        Text(String(format: "loss  %.6f", fViewModel.fLoss))
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }

                SectionBox("Optimizer", isExpanded: $showOptimizer) {
                    VStack(spacing: 8) {
                        FloatSliderRow(title: "LR pos", store: fViewModel, undoKeyPath: \.fLrPos,
                                       value: $fViewModel.fLrPos, range: 0...0.1,
                                       fractionDigits: 4, actionName: "Change LR pos")
                        FloatSliderRow(title: "LR value", store: fViewModel, undoKeyPath: \.fLrValue,
                                       value: $fViewModel.fLrValue, range: 0...0.1,
                                       fractionDigits: 4, actionName: "Change LR value")
                        FloatSliderRow(title: "LR size", store: fViewModel, undoKeyPath: \.fLrSize,
                                       value: $fViewModel.fLrSize, range: 0...0.1,
                                       fractionDigits: 4, actionName: "Change LR size")
                        FloatSliderRow(title: "Max motion", store: fViewModel, undoKeyPath: \.fMaxMotion,
                                       value: $fViewModel.fMaxMotion, range: 0...0.1,
                                       fractionDigits: 4, actionName: "Change max motion")
                        FloatSliderRow(title: "Overlap wt", store: fViewModel, undoKeyPath: \.fOverlapWeight,
                                       value: $fViewModel.fOverlapWeight, range: 0...5,
                                       fractionDigits: 2, actionName: "Change overlap weight")
                    }
                    .padding(.top, 6)
                }

                SectionBox("Setup", isExpanded: $showSetup) {
                    VStack(alignment: .leading, spacing: 10) {
                        Stepper("Points: \(fViewModel.fPointCount)",
                                value: $fViewModel.fPointCount, in: 1...4096, step: 16)
                        Stepper("Image: \(fViewModel.fImageSize) px",
                                value: $fViewModel.fImageSize, in: 32...512, step: 32)
                        Text("Applied on Reset")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }
            }
            .padding()
        }
        .frame(minWidth: 250, maxWidth: 320)
        .background(.ultraThinMaterial)
    }
}
