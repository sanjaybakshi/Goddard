//
//  TmetalViewModel.swift
//  Goddard
//
//  Render bridge between the model (TgoddardModel) and the Metal canvas. The canvas
//  PULLS from here each display-link tick. This is the only Goddard type that builds
//  SameEyesMetalKit QuadInstances; the model stays render-agnostic.
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

    // MARK: - Frame-level

    func frameUniforms(viewport: SIMD2<Float>) -> FrameUniforms {
        FrameUniforms(viewport: viewport)
    }

    /// Canvas clear color (the display background). Pulled each tick so it stays live.
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

    /// The source image the canvas uploads as a texture (the canvas owns the MTLTexture).
    var sourceImage: CGImage? { model.fSourceImage }

    // MARK: - This frame's quad instances

    /// Material + instances + material params. Textured when textured mode is on and a
    /// source is loaded; otherwise gaussian dots.
    func currentQuads() -> (material: Material, instances: [QuadInstance], params: SIMD4<Float>) {
        if model.fTextured, model.fSourceImage != nil {
            return (.textured, texturedInstances(), .zero)
        }
        return (.gaussian, gaussianInstances(), SIMD4(model.fFalloffPower, 0, 0, 0))
    }

    /// Gaussian dots — optimized points (snapshot) + frozen excluded points. Color rgb =
    /// dot color; color.a = the point's value (brightness), used as alpha by the material.
    private func gaussianInstances() -> [QuadInstance] {
        let size = SIMD2<Float>(model.fDisplayRadius, model.fDisplayRadius)
        let dc = model.fDotColor
        var out = [QuadInstance]()
        if let s = model.renderData() {
            out.reserveCapacity(s.points.count + model.fExcludedPoints.count)
            for i in 0..<s.points.count {
                let v = i < s.values.count ? s.values[i] : 1
                out.append(QuadInstance(position: s.points[i], size: size,
                                        color: SIMD4(dc.x, dc.y, dc.z, v)))
            }
        }
        for p in model.fExcludedPoints {
            out.append(QuadInstance(position: p.position, size: size,
                                    color: SIMD4(dc.x, dc.y, dc.z, p.value)))
        }
        return out
    }

    /// Textured quads — optimized points carry their frozen source UV (fOptimizedUVs) as
    /// they move; excluded points sample the source where they sit.
    private func texturedInstances() -> [QuadInstance] {
        let size = SIMD2<Float>(model.fDisplayRadius, model.fDisplayRadius)
        let uvh = uvHalf()
        let uvs = model.fOptimizedUVs
        var out = [QuadInstance]()
        if let s = model.renderData() {
            out.reserveCapacity(s.points.count + model.fExcludedPoints.count)
            for i in 0..<s.points.count {
                let uv = i < uvs.count ? uvs[i] : s.points[i]
                out.append(QuadInstance(position: s.points[i], size: size, uvCenter: uv, uvHalf: uvh))
            }
        }
        for p in model.fExcludedPoints {
            out.append(QuadInstance(position: p.position, size: size, uvCenter: p.position, uvHalf: uvh))
        }
        return out
    }

    /// Source-UV patch half-extent — matches the on-screen dot footprint, aspect-corrected
    /// (fDisplayRadius is a fraction of the short side).
    private func uvHalf() -> SIMD2<Float> {
        let w = Float(max(1, model.fOutputWidth)), h = Float(max(1, model.fOutputHeight))
        let short = min(w, h)
        let r = model.fDisplayRadius
        return SIMD2(r * short / w, r * short / h)
    }
}
