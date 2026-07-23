//
//  MetalCanvasView.swift
//  Goddard
//
//  Hosts an MTKView and draws through SameEyesMetalKit's MetalRenderer. Data is
//  PULLED each display-link tick: the delegate calls `metal.currentSplats()` in
//  `draw(in:)` and hands the result to the renderer. No SwiftUI-state-driven
//  redraws — the display link is the clock (mirrors calligramy). The canvas is
//  letterboxed to the output aspect by the caller (`.aspectRatio`), so positions
//  map 1:1. Depends only on the TmetalViewModel bridge, never the model directly.
//

import SwiftUI
import MetalKit
import SameEyesMetalKit

struct MetalCanvasView: NSViewRepresentable {
    let metal: TmetalViewModel

    func makeCoordinator() -> Renderer { Renderer(metal: metal) }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = context.coordinator.device
        view.delegate = context.coordinator
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1)
        view.autoResizeDrawable = true
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 60
        context.coordinator.setup(view)
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.metal = metal
    }

    /// Owns the device/queue + package renderer; pulls data from the bridge each frame.
    final class Renderer: NSObject, MTKViewDelegate {
        let device: MTLDevice?
        var metal: TmetalViewModel
        private let queue: MTLCommandQueue?
        private var renderer: MetalRenderer?

        init(metal: TmetalViewModel) {
            self.metal = metal
            let dev = MTLCreateSystemDefaultDevice()
            self.device = dev
            self.queue = dev?.makeCommandQueue()
            super.init()
        }

        func setup(_ view: MTKView) {
            guard let device else { return }
            renderer = MetalRenderer(device: device, colorPixelFormat: view.colorPixelFormat)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }

        func draw(in view: MTKView) {
            guard let queue, let renderer,
                  let drawable = view.currentDrawable,
                  let cmd = queue.makeCommandBuffer()
            else { return }

            let splats = metal.currentSplats()              // pulled each tick
            let viewport = SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height))
            renderer.render([.splats(splats)],
                            uniforms: metal.renderUniforms(viewport: viewport),
                            grade: metal.gradeUniforms(),
                            clearColor: metal.backgroundClearColor(),
                            drawable: drawable.texture,
                            commandBuffer: cmd)
            cmd.present(drawable)
            cmd.commit()
        }
    }
}
