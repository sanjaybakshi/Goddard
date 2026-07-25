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

    /// Current splats for the renderer to pull each frame — the optimized (goal)
    /// points from the optimizer snapshot PLUS the frozen non-goal points, so every
    /// point is drawn even though only the goal subset is in the optimizer.
    func currentSplats() -> [SplatInstance] {
        let radius = model.fDisplayRadius
        let nonGoal = model.fNonGoalPoints
        var out = [SplatInstance]()

        if let s = model.renderData() {
            out.reserveCapacity(s.points.count + nonGoal.count)
            for i in 0..<s.points.count {
                let v = i < s.values.count ? s.values[i] : 1
                out.append(SplatInstance(position: s.points[i], size: SIMD2(s.radius, s.radius), value: v))
            }
        } else {
            out.reserveCapacity(nonGoal.count)
        }

        for p in nonGoal {
            out.append(SplatInstance(position: p.position, size: SIMD2(radius, radius), value: p.value))
        }
        return out
    }
}
