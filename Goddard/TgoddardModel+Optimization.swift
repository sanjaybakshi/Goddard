//
//  TgoddardModel+Optimization.swift
//  Goddard
//
//  The optimizer lifecycle: (re)build against the current goal + params, the
//  off-main step loop, and the render/debug pulls. Split out of TgoddardModel
//  (which keeps the stored properties + goal-image helpers), mirroring calligramy's
//  CalligramDocument+Optimization. The step loop also measures throughput via a
//  moving average of per-step time and reports it as steps/sec ~once a second.
//

import Foundation
import CoreGraphics
import MLX
import SameEyesOptimizerKit

extension TgoddardModel {

    // MARK: - Build / reset

    /// (Re)builds the optimizer with fresh random points against the goal image
    /// (aspect-fit + grayscale + adjustments), else a stand-in bright disk on black.
    /// Stops any running loop first.
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
        if let goal = fGoalImage,
           let t = goalTarget(from: goal, width: W, height: H, adjustments: currentGoalAdjustments()) {
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
                                                  invert: fInvertRender, radiusScale: 1.0)

        let opt = PointsOptimizer(config: cfg, rendererConfig: rcfg,
                                  initialPtSize: sizesMLX, target: targetMLX)
        opt.fpm = PointsModel(points: ptsMLX, ptSize: sizesMLX, ptValues: valsMLX)
        fOptimizer = opt

        fTelemetry.loss = 0
    }

    // MARK: - Run control

    func start() {
        guard fOptimizer != nil else { return }
        fRunning = true
        startLoopIfNeeded()
    }

    func stop() {
        fRunning = false
        fTelemetry.stepsPerSecond = 0
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
            // Moving average of seconds-per-step (recent-weighted): a lone slow
            // step barely moves it, a sustained change settles in a few samples.
            // Seeded at 5ms; 1 / avg is the reported steps/sec.
            var stepAvgSec = 0.005
            var lastReport = CFAbsoluteTimeGetCurrent()

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

                // Time the step. step() ends in .item(), which forces the MLX eval,
                // so this wall-clock span captures real compute — no extra sync added.
                let t0 = CFAbsoluteTimeGetCurrent()
                let loss = opt.step()
                let dt = CFAbsoluteTimeGetCurrent() - t0
                stepAvgSec = 0.8 * stepAvgSec + 0.2 * dt      // moving average

                // Report telemetry at ~10 Hz (display cadence, not loop cadence).
                // Writes land on TrunTelemetry, so only RunReadout re-renders.
                let now = CFAbsoluteTimeGetCurrent()
                if now - lastReport >= 0.1 {
                    lastReport = now
                    let sps = stepAvgSec > 0 ? 1.0 / stepAvgSec : 0
                    await MainActor.run {
                        self.fTelemetry.loss = loss
                        self.fTelemetry.stepsPerSecond = sps
                    }
                }
                await Task.yield()
            }
        }
    }

    // MARK: - Render / debug pulls

    /// Plain-Swift conversion of the current optimizer state for the render bridge
    /// (MLX → Swift arrays). Reads via the optimizer's locked snapshotForRender(),
    /// so it's safe to call from the render thread while the background loop steps.
    func renderData() -> (points: [SIMD2<Float>], values: [Float], radius: Float)? {
        guard let opt = fOptimizer else { return nil }
        let (ptsMLX, _, valsMLX) = opt.snapshotForRender()
        return (mlxArrayToSIMD2Vector(ptsMLX), mlxArrayToFloatVector(valsMLX), fDisplayRadius)
    }

    /// One-shot debug render: the optimizer's current loss-space image (the
    /// grayscale render `renderPoints` produces) → `fDebugImage`. Driven by a button.
    func refreshDebugImage() {
        guard let opt = fOptimizer else { return }
        fDebugImage = cgImage(fromMLX: opt.renderPreview())
    }
}
