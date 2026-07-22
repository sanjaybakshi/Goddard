//
//  MetalCanvasView.swift
//  Goddard
//
//  Step 2 of the Metal splat view: an MTKView that draws Gaussian splats as
//  instanced quads. For now it renders a few HARDCODED splats to confirm they
//  come out round on a non-square canvas. Live data from the optimizer, and
//  swapping out the CPU-readback canvas, come next.
//

import SwiftUI
import MetalKit

// Layout must match `Splat` / `SplatUniforms` in Shaders.metal.
struct GPUSplat {
    var pos: SIMD2<Float>     // center, normalized [0,1] (y down)
    var size: SIMD2<Float>   // half-extent as a fraction of the short side
    var value: Float         // density / brightness
}

struct SplatUniforms {
    var viewport: SIMD2<Float>
}

struct MetalCanvasView: NSViewRepresentable {

    func makeCoordinator() -> Renderer { Renderer() }

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

    func updateNSView(_ nsView: MTKView, context: Context) { }

    /// Renderer / MTKViewDelegate — builds the Gaussian-splat pipeline and draws
    /// the instanced quads.
    final class Renderer: NSObject, MTKViewDelegate {
        let device: MTLDevice?
        private let queue: MTLCommandQueue?
        private var pipeline: MTLRenderPipelineState?
        private var splatBuffer: MTLBuffer?
        private var splatCount = 0

        override init() {
            let dev = MTLCreateSystemDefaultDevice()
            self.device = dev
            self.queue = dev?.makeCommandQueue()
            super.init()
        }

        func setup(_ view: MTKView) {
            buildPipeline(view)
            buildHardcodedSplats()
        }

        private func buildPipeline(_ view: MTKView) {
            guard let device, let library = device.makeDefaultLibrary() else { return }
            let d = MTLRenderPipelineDescriptor()
            d.label = "Gaussian splat"
            d.vertexFunction = library.makeFunction(name: "vertex_splat")
            d.fragmentFunction = library.makeFunction(name: "fragment_gaussian")

            let color = d.colorAttachments[0]!
            color.pixelFormat = view.colorPixelFormat
            color.isBlendingEnabled = true
            color.rgbBlendOperation = .add
            color.alphaBlendOperation = .add
            color.sourceRGBBlendFactor = .one
            color.destinationRGBBlendFactor = .oneMinusSourceAlpha
            color.sourceAlphaBlendFactor = .one
            color.destinationAlphaBlendFactor = .oneMinusSourceAlpha

            pipeline = try? device.makeRenderPipelineState(descriptor: d)
        }

        private func buildHardcodedSplats() {
            guard let device else { return }
            let r: Float = 0.05
            let splats = [
                GPUSplat(pos: SIMD2(0.5, 0.5), size: SIMD2(r, r), value: 1.0),
                GPUSplat(pos: SIMD2(0.2, 0.3), size: SIMD2(r, r), value: 0.8),
                GPUSplat(pos: SIMD2(0.8, 0.3), size: SIMD2(r, r), value: 0.8),
                GPUSplat(pos: SIMD2(0.5, 0.8), size: SIMD2(r, r), value: 0.6),
            ]
            splatCount = splats.count
            splatBuffer = device.makeBuffer(bytes: splats,
                                            length: MemoryLayout<GPUSplat>.stride * splats.count,
                                            options: .storageModeShared)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }

        func draw(in view: MTKView) {
            guard let queue, let pipeline, let splatBuffer, splatCount > 0,
                  let pass = view.currentRenderPassDescriptor,
                  let drawable = view.currentDrawable,
                  let cmd = queue.makeCommandBuffer(),
                  let encoder = cmd.makeRenderCommandEncoder(descriptor: pass)
            else { return }

            var uniforms = SplatUniforms(
                viewport: SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height))
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setVertexBuffer(splatBuffer, offset: 0, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<SplatUniforms>.stride, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: splatCount)

            encoder.endEncoding()
            cmd.present(drawable)
            cmd.commit()
        }
    }
}
