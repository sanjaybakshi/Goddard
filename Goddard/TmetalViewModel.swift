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
import SameEyesMetalKit

final class TmetalViewModel {
    unowned let model: TgoddardModel

    init(model: TgoddardModel) {
        self.model = model
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
