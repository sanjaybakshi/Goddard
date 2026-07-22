//
//  Shaders.metal
//  Goddard
//
//  Gaussian-splat core, ported/trimmed from calligramy's Shaders.metal.
//  Instanced quads: 6 vertices per splat, N instances in one draw. Positions and
//  sizes arrive NORMALIZED ([0,1] within the frame); the vertex shader converts
//  to pixels using the drawable (viewport) size, so a splat with equal size.x/.y
//  renders round on any aspect (equal pixel extent on both axes).
//

#include <metal_stdlib>
using namespace metal;

struct Splat {
    float2 pos;    // center, normalized [0,1] (y down)
    float2 size;   // half-extent as a fraction of the drawable's short side
    float  value;  // density / brightness (0..1)
};

struct SplatUniforms {
    float2 viewport;   // drawable size in pixels
};

struct VertexOut {
    float4 position [[position]];
    float2 quadCoord;   // [0,1] within the quad
    float  value;
};

vertex VertexOut vertex_splat(uint vid                       [[vertex_id]],
                              uint iid                       [[instance_id]],
                              constant Splat*        splats   [[buffer(0)]],
                              constant SplatUniforms& u       [[buffer(1)]]) {
    const float2 corners[6] = {
        float2(0,0), float2(0,1), float2(1,1),
        float2(0,0), float2(1,1), float2(1,0)
    };
    float2 corner = corners[vid];
    Splat s = splats[iid];

    // Isotropic pixel extent (short side as reference) → round when size.x==size.y.
    float ref = min(u.viewport.x, u.viewport.y);
    float2 halfPx  = s.size * ref;
    float2 centrePx = s.pos * u.viewport;                 // normalized → pixels
    float2 px = centrePx + (corner - 0.5) * 2.0 * halfPx;

    // Pixel → clip (NDC), y flipped (pixel y is down, clip y is up).
    float2 clip = float2(px.x / u.viewport.x * 2.0 - 1.0,
                         1.0 - px.y / u.viewport.y * 2.0);

    VertexOut out;
    out.position  = float4(clip, 0.0, 1.0);
    out.quadCoord = corner;
    out.value     = s.value;
    return out;
}

fragment float4 fragment_gaussian(VertexOut in [[stage_in]]) {
    float2 centeredUV = in.quadCoord * 2.0 - 1.0;      // [-1,1]
    float  r    = length(centeredUV);
    float  aa   = fwidth(r);
    float  mask = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, r);
    float  gaussian = exp(-r * r);
    float  alpha = mask * gaussian * in.value;
    float3 color = float3(1.0);                         // white dots for v1
    return float4(color * alpha, alpha);                // premultiplied alpha
}
