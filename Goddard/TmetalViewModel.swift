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

    /// Current splats for the renderer to pull each frame.
    func currentSplats() -> [SplatInstance] {
        guard let s = model.renderData() else { return [] }
        var out = [SplatInstance](); out.reserveCapacity(s.points.count)
        for i in 0..<s.points.count {
            let v = i < s.values.count ? s.values[i] : 1
            out.append(SplatInstance(position: s.points[i], size: SIMD2(s.radius, s.radius), value: v))
        }
        return out
    }
}
