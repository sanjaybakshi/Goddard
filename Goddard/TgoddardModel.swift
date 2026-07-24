//
//  TgoddardModel.swift
//  Goddard
//
//  The app model: owns the SameEyesOptimizerKit optimizer, its params, and the
//  goal image. Render-agnostic — it exposes a plain-Swift renderData() and owns a
//  TmetalViewModel bridge that turns it into SplatInstances for the canvas (so this
//  model needs no MetalKit import). Implicitly @MainActor under the target's
//  MainActor-default isolation. This file holds the class declaration, stored
//  properties, and the goal-image helpers; the optimizer lifecycle + off-main loop
//  live in TgoddardModel+Optimization.swift, and file I/O in TgoddardModel+FileIO.swift.
//

import Foundation
import Combine          // required for @Published's init(wrappedValue:)
import CoreGraphics
import MLX
import SameEyesOptimizerKit
import SameEyesUIKit

final class TgoddardModel: ObservableObject, UndoableStore {

    /// Render bridge the Metal canvas pulls from. Owned here; the bridge holds an
    /// unowned back-ref, so no retain cycle.
    lazy var fMetalViewModel = TmetalViewModel(model: self)

    // Live-tunable — applied to the optimizer at the top of each step.
    @Published var fLrPos:         Float = 0.0001
    @Published var fLrValue:       Float = 0
    @Published var fLrSize:        Float = 0
    @Published var fMaxMotion:     Float = 0.02
    @Published var fOverlapWeight: Float = 0.0

    // Optimizer setup — applied on rebuild (Reset). fOptimizerLongSide is the
    // long side of the aspect-matched grid; OptimizationFrame derives the other
    // axis from the output aspect.
    @Published var fOptimizerLongSide:   Int = 512
    @Published var fOptimizerPointCount: Int = 10000
    /// Initial dot radius as a fraction of the frame's long side.
    @Published var fOptimizerDotRadius:  Float = 0.005
    /// Render polarity for the optimizer's target match. false = dots emit light
    /// (fill the light regions; "white on black"); true = dots are ink (fill the
    /// dark regions; "black on white"). Baked into the loss at build → applied on Reset.
    @Published var fInvertRender: Bool = false

    // Output frame — user-specified, arbitrary aspect. Sets the optimize aspect
    // and the artifact resolution. Applied on rebuild (Reset).
    @Published var fOutputWidth:  Int = 1280
    @Published var fOutputHeight: Int = 720

    // Renderer — display-only, LIVE (no rebuild). fDisplayRadius = splat size as a
    // fraction of the drawable's short side; fFalloffPower = super-Gaussian
    // exponent (2 = Gaussian, higher = flatter).
    @Published var fDisplayRadius: Float = 0.005
    @Published var fFalloffPower:  Float = 4

    // Display colors — renderer-only (never seen by the optimizer). Background is
    // the canvas clear color; dot color tints the splats. rgb in [0,1].
    @Published var fBackgroundColor: SIMD3<Float> = SIMD3(0.06, 0.06, 0.07)
    @Published var fDotColor:        SIMD3<Float> = SIMD3(1, 1, 1)

    // Output grade — a tonal curve on the final composited frame (a renderer
    // post-process). Live; never touches the optimizer. Identity = no change.
    @Published var fOutBlackPoint: Float = 0
    @Published var fOutWhitePoint: Float = 1
    @Published var fOutBrightness: Float = 0
    @Published var fOutContrast:   Float = 1
    @Published var fOutGamma:      Float = 1

    // Goal image adjustments — applied to the target on rebuild (Reset); the
    // preview thumbnail (fGoalThumbnail) updates LIVE as these change.
    @Published var fGoalInvert:     Bool  = false { didSet { refreshGoalThumbnail() } }
    @Published var fGoalBlur:       Float = 0     { didSet { refreshGoalThumbnail() } }
    @Published var fGoalBlackPoint: Float = 0     { didSet { refreshGoalThumbnail() } }
    @Published var fGoalWhitePoint: Float = 1     { didSet { refreshGoalThumbnail() } }
    @Published var fGoalBrightness: Float = 0     { didSet { refreshGoalThumbnail() } }
    @Published var fGoalContrast:   Float = 1     { didSet { refreshGoalThumbnail() } }
    @Published var fGoalGamma:      Float = 1     { didSet { refreshGoalThumbnail() } }
    /// Processed-target preview (grayscale) reflecting goal image + adjustments.
    @Published private(set) var fGoalThumbnail: CGImage? = nil

    // Loop/optimizer state — written by TgoddardModel+Optimization.swift (a sibling
    // extension, so these can't be private(set)). The UI reads them; don't mutate
    // from views. Change run state only via start()/stop()/toggleRun().
    @Published var fRunning: Bool = false
    /// Debug: the optimizer's current loss-space render (grayscale), refreshed
    /// on demand by a button. nil until first requested.
    @Published var fDebugImage: CGImage? = nil

    /// Live run telemetry (loss + steps/sec) on its OWN observable so the step
    /// loop's ~10 Hz updates re-render only RunReadout, never the parameter panel.
    let fTelemetry = TrunTelemetry()

    /// The optimizer + its off-main loop. Managed in TgoddardModel+Optimization.swift.
    var fOptimizer: PointsOptimizer?
    var fLoopTask: Task<Void, Never>?
    /// Goal image the optimizer converges toward; nil → synthetic disk stand-in.
    /// Internal (not private) so TgoddardModel+FileIO can read/embed it.
    var fGoalImage: CGImage?

    // MARK: - Goal image

    /// Load a goal image from a file and rebuild the optimizer toward it. The
    /// image is held in memory; a saved project embeds a downscaled PNG copy, so
    /// no file reference/bookmark is needed.
    func loadGoalImage(url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let img = loadCGImage(from: url) else { return }
        fGoalImage = img
        refreshGoalThumbnail()
        buildOptimizer()
    }

    /// The current goal adjustments assembled from the model params.
    func currentGoalAdjustments() -> GoalAdjustments {
        GoalAdjustments(invert: fGoalInvert, blur: fGoalBlur,
                        blackPoint: fGoalBlackPoint, whitePoint: fGoalWhitePoint,
                        brightness: fGoalBrightness, contrast: fGoalContrast, gamma: fGoalGamma)
    }

    /// Recompute the small processed-target preview (grayscale) from the current
    /// goal image + adjustments. Live — driven by the goal-param didSets.
    func refreshGoalThumbnail() {
        guard let goal = fGoalImage else { fGoalThumbnail = nil; return }
        let frame = OptimizationFrame(outputWidth: fOutputWidth, outputHeight: fOutputHeight, longSide: 256)
        if let t = goalTarget(from: goal, width: frame.width, height: frame.height,
                              adjustments: currentGoalAdjustments()) {
            fGoalThumbnail = cgImage(fromMLX: t)
        }
    }
}
