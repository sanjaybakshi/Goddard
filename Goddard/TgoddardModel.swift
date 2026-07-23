//
//  TgoddardModel.swift
//  Goddard
//
//  The app model: owns the SameEyesOptimizerKit optimizer, its params, and the
//  live loop. Render-agnostic — it exposes a plain-Swift renderData() and
//  owns a TmetalViewModel bridge that turns it into SplatInstances for the canvas
//  (so this model needs no MetalKit import). Implicitly @MainActor under the
//  target's MainActor-default isolation; the loop runs on the main actor and
//  yields between steps (MLX runs its work on the GPU). Fine at stub sizes.
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

    // Output frame — user-specified, arbitrary aspect. Sets the optimize aspect
    // and the artifact resolution. Applied on rebuild (Reset).
    @Published var fOutputWidth:  Int = 1280
    @Published var fOutputHeight: Int = 720

    // Read by the UI; mutate only via start()/stop()/toggleRun().
    @Published private(set) var fRunning: Bool = false
    @Published private(set) var fLoss: Float = 0

    private var fOptimizer: PointsOptimizer?
    private var fLoopTask: Task<Void, Never>?
    /// Goal image the optimizer converges toward; nil → synthetic disk stand-in.
    /// Internal (not private) so TgoddardModel+FileIO can read/embed it.
    var fGoalImage: CGImage?

    // MARK: - Build / reset

    /// (Re)builds the optimizer with fresh random points against a stand-in goal
    /// image (a bright centered disk on black). Stops any running loop first.
    func buildOptimizer() {
        stop()

        let n = max(1, fOptimizerPointCount)

        // Aspect-matched grid from the long-side dimension + output aspect
        // (SameEyesOptimizerKit). Non-square; renderPoints handles it directly.
        let frame = OptimizationFrame(outputWidth: fOutputWidth,
                                      outputHeight: fOutputHeight,
                                      longSide: max(8, fOptimizerLongSide))
        let W = frame.width, H = frame.height

        // Target: the loaded goal image (aspect-fit + grayscale into the frame),
        // else a stand-in bright centered disk on black.
        let targetMLX: MLXArray
        if let goal = fGoalImage, let t = goalTarget(from: goal, width: W, height: H) {
            targetMLX = t
        } else {
            var target = [Float](repeating: 0, count: H * W)
            let cx = Float(W) / 2, cy = Float(H) / 2
            let r = Float(min(W, H)) * 0.3
            for y in 0..<H {
                for x in 0..<W {
                    let dx = Float(x) - cx, dy = Float(y) - cy
                    target[y * W + x] = (dx * dx + dy * dy <= r * r) ? 1 : 0
                }
            }
            targetMLX = MLXArray(target).reshaped([1, 1, H, W])
        }

        // Seed dots uniformly in [0,1]² — fills the aspect-matched frame correctly.
        var pts = [Float](); pts.reserveCapacity(n * 2)
        for _ in 0..<n {
            pts.append(.random(in: 0...1))
            pts.append(.random(in: 0...1))
        }
        let ptsMLX = MLXArray(pts).reshaped([n, 2])

        // Per-axis sizes so dots render round on the non-square grid.
        let (sw, sh) = frame.normalizedSize(radiusFraction: Double(fOptimizerDotRadius))
        var sizesArr = [Float](); sizesArr.reserveCapacity(n * 2)
        for _ in 0..<n { sizesArr.append(sw); sizesArr.append(sh) }
        let sizesMLX = MLXArray(sizesArr).reshaped([n, 2])

        let valsMLX = MLXArray([Float](repeating: 0.8, count: n))

        var cfg = PointsOptimizer.OptimizerConfig()
        cfg.lrPos = fLrPos
        cfg.lrValue = fLrValue
        cfg.lrSize = fLrSize
        cfg.maxMotion = fMaxMotion
        cfg.overlapWeight = fOverlapWeight

        let rcfg = PointsOptimizer.RendererConfig(imageWidth: W, imageHeight: H,
                                                  invert: false, radiusScale: 1.0)

        let opt = PointsOptimizer(config: cfg, rendererConfig: rcfg,
                                  initialPtSize: sizesMLX, target: targetMLX)
        opt.fpm = PointsModel(points: ptsMLX, ptSize: sizesMLX, ptValues: valsMLX)
        fOptimizer = opt

        fLoss = 0
    }

    /// Load a goal image from a file and rebuild the optimizer toward it. The
    /// image is held in memory; a saved project embeds a downscaled PNG copy, so
    /// no file reference/bookmark is needed.
    func loadGoalImage(url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let img = loadCGImage(from: url) else { return }
        fGoalImage = img
        buildOptimizer()
    }

    // MARK: - Run control

    func start() {
        guard fOptimizer != nil else { return }
        fRunning = true
        startLoopIfNeeded()
    }

    func stop() {
        fRunning = false
        fLoopTask?.cancel()
        fLoopTask = nil
    }

    func toggleRun() { fRunning ? stop() : start() }

    private func startLoopIfNeeded() {
        guard fLoopTask == nil, let opt = fOptimizer else { return }
        // Step OFF the main thread (mirrors AdamAnt) so heavy 512-res / 10k-point
        // steps don't jank the 60fps display. The render side pulls via the
        // optimizer's locked snapshotForRender(); step() itself is intentionally
        // unlocked (a benign race, as in AdamAnt) to keep the loop unblocked.
        fLoopTask = Task.detached { [weak self, opt] in
            var i = 0
            while !Task.isCancelled {
                guard let self else { break }
                // Pull live params + run flag from the main actor each step.
                let params = await MainActor.run {
                    () -> (lrPos: Float, lrValue: Float, lrSize: Float, maxMotion: Float, overlap: Float)? in
                    self.fRunning
                        ? (self.fLrPos, self.fLrValue, self.fLrSize, self.fMaxMotion, self.fOverlapWeight)
                        : nil
                }
                guard let p = params else { break }   // stopped

                opt.setLearningRates(pos: p.lrPos, value: p.lrValue, size: p.lrSize)
                opt.setMaxMotionPerStep(p.maxMotion)
                opt.fOverlapWeight = p.overlap

                let loss = opt.step()
                i += 1
                if i % 2 == 0 {
                    await MainActor.run { self.fLoss = loss }
                }
                await Task.yield()
            }
        }
    }

    /// Plain-Swift conversion of the current optimizer state for the render bridge
    /// (MLX → Swift arrays). Fixed radius for now. Reads via the optimizer's locked
    /// snapshotForRender(), so it's safe to call from the render thread while the
    /// background loop steps.
    func renderData() -> (points: [SIMD2<Float>], values: [Float], radius: Float)? {
        guard let opt = fOptimizer else { return nil }
        let (ptsMLX, _, valsMLX) = opt.snapshotForRender()
        return (mlxArrayToSIMD2Vector(ptsMLX), mlxArrayToFloatVector(valsMLX), fOptimizerDotRadius)
    }

}
