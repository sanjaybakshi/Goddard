//
//  TgoddardViewModel.swift
//  Goddard
//
//  Owns the SameEyesOptimizerKit optimizer and drives it in a live loop, publishing a
//  grayscale preview of the current render for the (stub) canvas. Implicitly
//  @MainActor under the target's MainActor-default isolation, so the loop runs
//  on the main actor and yields between steps — MLX still runs its work on the
//  GPU; only orchestration + readback touch the main thread. Fine at stub image
//  sizes; move off-main when images/point counts grow.
//

import Foundation
import Combine          // required for @Published's init(wrappedValue:)
import CoreGraphics
import MLX
import SameEyesOptimizerKit
import SameEyesUIKit

final class TgoddardViewModel: ObservableObject, UndoableStore {

    // Live-tunable — applied to the optimizer at the top of each step.
    @Published var fLrPos:         Float = 0.01
    @Published var fLrValue:       Float = 0.01
    @Published var fLrSize:        Float = 0.005
    @Published var fMaxMotion:     Float = 0.02
    @Published var fOverlapWeight: Float = 0.0

    // Apply-on-rebuild (Reset).
    @Published var fPointCount: Int = 64
    @Published var fImageSize:  Int = 128

    // Read by the UI; mutate only via start()/stop()/toggleRun().
    @Published private(set) var fRunning: Bool = false
    @Published private(set) var fPreviewImage: CGImage? = nil
    @Published private(set) var fLoss: Float = 0

    private var fOptimizer: PointsOptimizer?
    private var fLoopTask: Task<Void, Never>?
    private var fWidth  = 128
    private var fHeight = 128

    // MARK: - Build / reset

    /// (Re)builds the optimizer with fresh random points against a stand-in goal
    /// image (a bright centered disk on black). Stops any running loop first.
    func buildOptimizer() {
        stop()

        let n = max(1, fPointCount)
        let W = max(8, fImageSize)
        let H = W
        fWidth = W; fHeight = H

        // Target: bright centered disk on black background.
        var target = [Float](repeating: 0, count: H * W)
        let cx = Float(W) / 2, cy = Float(H) / 2
        let r = Float(min(W, H)) * 0.3
        for y in 0..<H {
            for x in 0..<W {
                let dx = Float(x) - cx, dy = Float(y) - cy
                target[y * W + x] = (dx * dx + dy * dy <= r * r) ? 1 : 0
            }
        }
        let targetMLX = MLXArray(target).reshaped([1, 1, H, W])

        var pts = [Float](); pts.reserveCapacity(n * 2)
        for _ in 0..<n {
            pts.append(.random(in: 0...1))
            pts.append(.random(in: 0...1))
        }
        let ptsMLX = MLXArray(pts).reshaped([n, 2])
        let sizesMLX = MLXArray([Float](repeating: 0.06, count: n * 2)).reshaped([n, 2])
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
        fPreviewImage = Self.grayscaleImage(opt.renderPreview(), width: W, height: H)
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
        let W = fWidth, H = fHeight
        fLoopTask = Task { [weak self] in
            var i = 0
            while let self, self.fRunning, !Task.isCancelled {
                // Push current live params into the optimizer.
                opt.setLearningRates(pos: self.fLrPos, value: self.fLrValue, size: self.fLrSize)
                opt.setMaxMotionPerStep(self.fMaxMotion)
                opt.fOverlapWeight = self.fOverlapWeight

                let loss = opt.step()
                i += 1

                // Throttle readback/publish to every other step.
                if i % 2 == 0 {
                    self.fLoss = loss
                    if let cg = Self.grayscaleImage(opt.renderPreview(), width: W, height: H) {
                        self.fPreviewImage = cg
                    }
                }
                await Task.yield()
            }
        }
    }

    // MARK: - MLXArray → CGImage

    /// Converts a `[1,1,H,W]` float image (values ~[0,1], clamped) to an 8-bit
    /// grayscale CGImage.
    static func grayscaleImage(_ image: MLXArray, width: Int, height: Int) -> CGImage? {
        let floats = image.asArray(Float.self)
        let count = width * height
        guard floats.count >= count else { return nil }

        var bytes = [UInt8](repeating: 0, count: count)
        for i in 0..<count {
            let v = max(0, min(1, floats[i]))
            bytes[i] = UInt8(v * 255)
        }

        let cs = CGColorSpaceCreateDeviceGray()
        return bytes.withUnsafeMutableBytes { raw -> CGImage? in
            guard let ctx = CGContext(data: raw.baseAddress,
                                      width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width,
                                      space: cs,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue)
            else { return nil }
            return ctx.makeImage()
        }
    }
}
