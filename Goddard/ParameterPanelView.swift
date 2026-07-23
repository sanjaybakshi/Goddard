//
//  ParameterPanelView.swift
//  Goddard
//
//  Right-hand inspector panel — generalized from calligramy's ParameterListView,
//  built on the reusable SectionBox + FloatSliderRow. Drives the optimizer live.
//

import SwiftUI
import UniformTypeIdentifiers
import SameEyesUIKit

struct ParameterPanelView: View {
    @EnvironmentObject var fModel: TgoddardModel

    @State private var showRun       = true
    @State private var showOptimizer = true
    @State private var showSetup     = false
    @State private var showGoalImporter = false

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
                            Button(fModel.fRunning ? "Pause" : "Run") {
                                fModel.toggleRun()
                            }
                            Button("Reset") {
                                fModel.buildOptimizer()
                            }
                        }
                        Button("Load Goal Image…") { showGoalImporter = true }
                        Text(String(format: "loss  %.6f", fModel.fLoss))
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }

                SectionBox("Optimizer", isExpanded: $showOptimizer) {
                    VStack(spacing: 8) {
                        FloatSliderRow(title: "LR pos", store: fModel, undoKeyPath: \.fLrPos,
                                       value: $fModel.fLrPos, range: 0...0.1,
                                       fractionDigits: 6, fieldWidth: 72, actionName: "Change LR pos")
                        FloatSliderRow(title: "LR value", store: fModel, undoKeyPath: \.fLrValue,
                                       value: $fModel.fLrValue, range: 0...0.1,
                                       fractionDigits: 6, fieldWidth: 72, actionName: "Change LR value")
                        FloatSliderRow(title: "LR size", store: fModel, undoKeyPath: \.fLrSize,
                                       value: $fModel.fLrSize, range: 0...0.1,
                                       fractionDigits: 6, fieldWidth: 72, actionName: "Change LR size")
                        FloatSliderRow(title: "Max motion", store: fModel, undoKeyPath: \.fMaxMotion,
                                       value: $fModel.fMaxMotion, range: 0...0.1,
                                       fractionDigits: 4, actionName: "Change max motion")
                        FloatSliderRow(title: "Overlap wt", store: fModel, undoKeyPath: \.fOverlapWeight,
                                       value: $fModel.fOverlapWeight, range: 0...5,
                                       fractionDigits: 2, actionName: "Change overlap weight")
                    }
                    .padding(.top, 6)
                }

                SectionBox("Setup", isExpanded: $showSetup) {
                    VStack(spacing: 8) {
                        IntSliderRow(title: "Points", store: fModel, undoKeyPath: \.fOptimizerPointCount,
                                     value: $fModel.fOptimizerPointCount, range: 1...20000,
                                     actionName: "Change point count")
                        IntSliderRow(title: "Optimize px", store: fModel, undoKeyPath: \.fOptimizerLongSide,
                                     value: $fModel.fOptimizerLongSide, range: 32...1024,
                                     actionName: "Change optimize resolution")
                        FloatSliderRow(title: "Dot radius", store: fModel, undoKeyPath: \.fOptimizerDotRadius,
                                       value: $fModel.fOptimizerDotRadius, range: 0.005...0.2,
                                       fractionDigits: 3, actionName: "Change dot radius")

                        Divider()

                        IntSliderRow(title: "Output W", store: fModel, undoKeyPath: \.fOutputWidth,
                                     value: $fModel.fOutputWidth, range: 64...8192,
                                     actionName: "Change output width")
                        IntSliderRow(title: "Output H", store: fModel, undoKeyPath: \.fOutputHeight,
                                     value: $fModel.fOutputHeight, range: 64...8192,
                                     actionName: "Change output height")
                        Text("Applied on Reset (output sets the optimize aspect)")
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
        .fileImporter(isPresented: $showGoalImporter,
                      allowedContentTypes: [.image],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                fModel.loadGoalImage(url: url)
            }
        }
    }
}
