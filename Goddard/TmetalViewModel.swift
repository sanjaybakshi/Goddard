//
//  TmetalViewModel.swift
//  Goddard
//
//  Render bridge between the model (TgoddardModel) and the Metal canvas. The
//  canvas PULLS from here each display-link tick (mirrors calligramy's
//  TmetalViewModel). This is the only Goddard type that knows about SplatInstance;
//  the model stays render-agnostic.
//

import simd
import Metal
import CoreGraphics
import SameEyesMetalKit

final class TmetalViewModel {
    unowned let model: TgoddardModel

    init(model: TgoddardModel) {
        self.model = model
    }

    /// Render uniforms (falloff, dot color) for the current frame — display-only.
    func renderUniforms(viewport: SIMD2<Float>) -> RenderUniforms {
        RenderUniforms(viewport: viewport,
                       falloffPower: model.fFalloffPower,
                       splatColor: model.fDotColor)
    }

    /// Canvas clear color for the current frame (the display background). Pulled by
    /// the canvas each tick so it stays live as the user picks a color.
    func backgroundClearColor() -> MTLClearColor {
        let c = model.fBackgroundColor
        return MTLClearColor(red: Double(c.x), green: Double(c.y), blue: Double(c.z), alpha: 1)
    }

    /// Tonal grade for the output post-process pass — display-only, live.
    func gradeUniforms() -> GradeUniforms {
        GradeUniforms(blackPoint: model.fOutBlackPoint,
                      whitePoint: model.fOutWhitePoint,
                      brightness: model.fOutBrightness,
                      contrast: model.fOutContrast,
                      gamma: model.fOutGamma)
    }

    /// Current splats for the renderer to pull each frame — the optimized (goal)
    /// points from the optimizer snapshot PLUS the frozen non-goal points, so every
    /// point is drawn even though only the goal subset is in the optimizer.
    func currentSplats() -> [SplatInstance] {
        let radius = model.fDisplayRadius
        let excluded = model.fExcludedPoints
        var out = [SplatInstance]()

        if let s = model.renderData() {
            out.reserveCapacity(s.points.count + excluded.count)
            for i in 0..<s.points.count {
                let v = i < s.values.count ? s.values[i] : 1
                out.append(SplatInstance(position: s.points[i], size: SIMD2(s.radius, s.radius), value: v))
            }
        } else {
            out.reserveCapacity(excluded.count)
        }

        for p in excluded {
            out.append(SplatInstance(position: p.position, size: SIMD2(radius, radius), value: p.value))
        }
        return out
    }

    /// The source image the canvas uploads as a texture (passthrough; the canvas owns
    /// the MTLTexture since it owns the device).
    var sourceImage: CGImage? { model.fSourceImage }

    /// The draw batch for this frame: textured quads when textured mode is on and a
    /// source is loaded; otherwise flat splats.
    func currentBatch() -> PrimitiveBatch {
        guard model.fTextured, model.fSourceImage != nil else {
            return .splats(currentSplats())
        }
        return .texturedSplats(currentTexturedSplats())
    }

    /// Textured instances: optimized points carry their frozen source UV (fOptimizedUVs)
    /// as they move; excluded points sample the source where they sit (uvCenter = position).
    private func currentTexturedSplats() -> [TexturedSplatInstance] {
        let size = SIMD2<Float>(model.fDisplayRadius, model.fDisplayRadius)
        let uvs = model.fOptimizedUVs
        var out = [TexturedSplatInstance]()

        if let s = model.renderData() {
            out.reserveCapacity(s.points.count + model.fExcludedPoints.count)
            for i in 0..<s.points.count {
                let uv = i < uvs.count ? uvs[i] : s.points[i]
                out.append(TexturedSplatInstance(position: s.points[i], size: size, uvCenter: uv))
            }
        }
        for p in model.fExcludedPoints {
            out.append(TexturedSplatInstance(position: p.position, size: size, uvCenter: p.position))
        }
        return out
    }

    /// Source-UV patch half-extent for textured mode — matches the on-screen dot
    /// footprint (decision 1a). `fDisplayRadius` is a fraction of the short side;
    /// convert to per-axis UV using the frame aspect so patches tile at grid init.
    func uvHalf() -> SIMD2<Float> {
        let w = Float(max(1, model.fOutputWidth)), h = Float(max(1, model.fOutputHeight))
        let short = min(w, h)
        let r = model.fDisplayRadius
        return SIMD2(r * short / w, r * short / h)
    }
}
