//
//  ParameterPanelView.swift
//  Goddard
//
//  Right-hand inspector panel — generalized from calligramy's ParameterListView,
//  built on the reusable SectionBox + FloatSliderRow. Drives the optimizer live.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SameEyesUIKit

struct ParameterPanelView: View {
    @EnvironmentObject var fModel: TgoddardModel
    @Environment(\.undoManager) private var undoManager

    @State private var showRun       = true
    @State private var showGoalImage = true
    @State private var showOptimizer = true
    @State private var showDebug     = false
    @State private var showSetup     = false
    @State private var showRenderer  = true
    @State private var showOutput    = false
    @State private var showProject   = true
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
                        RunReadout(telemetry: fModel.fTelemetry)
                    }
                    .padding(.top, 6)
                }

                SectionBox("Goal Image", isExpanded: $showGoalImage) {
                    VStack(alignment: .leading, spacing: 10) {
                        Button("Load Goal Image…") { showGoalImporter = true }

                        if let thumb = fModel.fGoalThumbnail {
                            Image(decorative: thumb, scale: 1.0)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 160)
                                .border(Color.secondary.opacity(0.3))
                        } else {
                            Text("No goal image loaded")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Toggle("Invert", isOn: Binding(
                            get: { fModel.fGoalInvert },
                            set: { fModel.setValue(\.fGoalInvert, to: $0,
                                                   named: "Toggle invert", using: undoManager) }))

                        FloatSliderRow(title: "Blur", store: fModel, undoKeyPath: \.fGoalBlur,
                                       value: $fModel.fGoalBlur, range: 0...0.2,
                                       fractionDigits: 3, actionName: "Change goal blur")
                        FloatSliderRow(title: "Black point", store: fModel, undoKeyPath: \.fGoalBlackPoint,
                                       value: $fModel.fGoalBlackPoint, range: 0...1,
                                       fractionDigits: 3, actionName: "Change black point")
                        FloatSliderRow(title: "White point", store: fModel, undoKeyPath: \.fGoalWhitePoint,
                                       value: $fModel.fGoalWhitePoint, range: 0...1,
                                       fractionDigits: 3, actionName: "Change white point")
                        FloatSliderRow(title: "Brightness", store: fModel, undoKeyPath: \.fGoalBrightness,
                                       value: $fModel.fGoalBrightness, range: -1...1,
                                       fractionDigits: 3, actionName: "Change brightness")
                        FloatSliderRow(title: "Contrast", store: fModel, undoKeyPath: \.fGoalContrast,
                                       value: $fModel.fGoalContrast, range: 0...3,
                                       fractionDigits: 3, actionName: "Change contrast")
                        FloatSliderRow(title: "Gamma", store: fModel, undoKeyPath: \.fGoalGamma,
                                       value: $fModel.fGoalGamma, range: 0.1...4,
                                       fractionDigits: 3, actionName: "Change gamma")
                        Text("Preview is live; applied to optimization on Reset")
                            .font(.caption)
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
                        FloatSliderRow(title: "Dot radius", store: fModel, undoKeyPath: \.fOptimizerDotRadius,
                                       value: $fModel.fOptimizerDotRadius, range: 0.001...0.2,
                                       fractionDigits: 4, actionName: "Change dot radius")
                        Text("Applied on Reset")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }

                SectionBox("Debug", isExpanded: $showDebug) {
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Render optimizer image") { fModel.refreshDebugImage() }
                        if let img = fModel.fDebugImage {
                            Image(decorative: img, scale: 1.0)
                                .resizable()
                                .interpolation(.none)
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 160)
                                .border(Color.secondary.opacity(0.3))
                        }
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
                        Picker("", selection: Binding(
                            get: { fModel.fInvertRender },
                            set: { fModel.setValue(\.fInvertRender, to: $0,
                                                   named: "Change polarity", using: undoManager) })) {
                            Text("White on black").tag(false)
                            Text("Black on white").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text("Applied on Reset")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }

                SectionBox("Renderer", isExpanded: $showRenderer) {
                    VStack(spacing: 8) {
                        IntSliderRow(title: "Output W", store: fModel, undoKeyPath: \.fOutputWidth,
                                     value: $fModel.fOutputWidth, range: 64...8192,
                                     actionName: "Change output width")
                        IntSliderRow(title: "Output H", store: fModel, undoKeyPath: \.fOutputHeight,
                                     value: $fModel.fOutputHeight, range: 64...8192,
                                     actionName: "Change output height")
                        Text("Output applied on Reset (sets the optimize aspect)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider()

                        FloatSliderRow(title: "Display radius", store: fModel, undoKeyPath: \.fDisplayRadius,
                                       value: $fModel.fDisplayRadius, range: 0.001...0.2,
                                       fractionDigits: 4, actionName: "Change display radius")
                        FloatSliderRow(title: "Flatness", store: fModel, undoKeyPath: \.fFalloffPower,
                                       value: $fModel.fFalloffPower, range: 1...16,
                                       fractionDigits: 1, actionName: "Change flatness")

                        Divider()

                        ColorPicker("Background", selection: colorBinding(\.fBackgroundColor,
                                    named: "Change background color"), supportsOpacity: false)
                        ColorPicker("Dot color", selection: colorBinding(\.fDotColor,
                                    named: "Change dot color"), supportsOpacity: false)

                        Text("Display radius, flatness, and colors are live")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }

                SectionBox("Output", isExpanded: $showOutput) {
                    VStack(spacing: 8) {
                        FloatSliderRow(title: "Black point", store: fModel, undoKeyPath: \.fOutBlackPoint,
                                       value: $fModel.fOutBlackPoint, range: 0...1,
                                       fractionDigits: 3, actionName: "Change output black point")
                        FloatSliderRow(title: "White point", store: fModel, undoKeyPath: \.fOutWhitePoint,
                                       value: $fModel.fOutWhitePoint, range: 0...1,
                                       fractionDigits: 3, actionName: "Change output white point")
                        FloatSliderRow(title: "Brightness", store: fModel, undoKeyPath: \.fOutBrightness,
                                       value: $fModel.fOutBrightness, range: -1...1,
                                       fractionDigits: 3, actionName: "Change output brightness")
                        FloatSliderRow(title: "Contrast", store: fModel, undoKeyPath: \.fOutContrast,
                                       value: $fModel.fOutContrast, range: 0...3,
                                       fractionDigits: 3, actionName: "Change output contrast")
                        FloatSliderRow(title: "Gamma", store: fModel, undoKeyPath: \.fOutGamma,
                                       value: $fModel.fOutGamma, range: 0.1...4,
                                       fractionDigits: 3, actionName: "Change output gamma")
                        Text("Tonal grade on the rendered frame; live")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }

                SectionBox("Project", isExpanded: $showProject) {
                    HStack {
                        Button("Open Project…") { openProject() }
                        Button("Save Project…") { saveProject() }
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

    /// Bridges a model `SIMD3<Float>` rgb color to a SwiftUI `Color` for a
    /// ColorPicker, routing writes through the undo layer (each pick = one step).
    private func colorBinding(_ keyPath: ReferenceWritableKeyPath<TgoddardModel, SIMD3<Float>>,
                              named: String) -> Binding<Color> {
        Binding(
            get: {
                let c = fModel[keyPath: keyPath]
                return Color(.sRGB, red: Double(c.x), green: Double(c.y), blue: Double(c.z))
            },
            set: { newColor in
                let ns = NSColor(newColor).usingColorSpace(.sRGB) ?? .white
                let rgb = SIMD3<Float>(Float(ns.redComponent),
                                       Float(ns.greenComponent),
                                       Float(ns.blueComponent))
                fModel.setValue(keyPath, to: rgb, named: named, using: undoManager)
            })
    }

    /// A .goddardproject file type derived from the extension (no Info.plist needed).
    private var projectType: UTType {
        UTType(filenameExtension: "goddardproject") ?? .json
    }

    private func saveProject() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [projectType]
        panel.nameFieldStringValue = "Untitled.goddardproject"
        if panel.runModal() == .OK, let url = panel.url {
            try? fModel.writeProject(to: url)
        }
    }

    private func openProject() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [projectType]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            try? fModel.readProject(from: url)
        }
    }
}
