# Goddard — Resolution Model (v1, splat-only)

The pipeline touches several distinct "resolutions." This spec names each,
declares which are authoritative, and defines every mapping — so resolution/aspect
handling is a designed invariant, not something patched after the fact.

**v1 approach: aspect-matched optimization grid** (mirrors calligramy). The
optimizer rasterizes to a **non-square** grid whose aspect equals the output
aspect. Aspect is handled by the grid dimensions themselves — no square+crop, no
renderer changes. Round dots come from per-axis size normalization (the renderer
scales σ per-axis by width/height; dividing size by each dimension cancels it).
The canonical code lives in the package: **`SameEyesOptimizerKit/OptimizationFrame.swift`**
(`OptimizationFrame(preferred:aspectWidth:aspectHeight:)` → `width × height`;
`normalizedSize(fraction:)` → per-axis `(w,h)` for round splats). Both apps use it
so aspect handling is defined once.

## Spaces

1. **Particle space** `[0,1]²` — where `points` / `ptSize` live (the model).
   Resolution-independent. **Authoritative for geometry.** Uniform `[0,1]²` seeding
   fills the frame at the correct aspect automatically (because the grid is
   aspect-matched).
2. **Optimization frame** `W_opt × H_opt` — **aspect-matched, non-square**. The user
   sets one dimension (`fPreferredSize`); the other is derived from the output
   aspect via `OptimizationFrame`. The MLX renderer rasterizes here; loss/gradients
   here. `renderPoints` is used unchanged.
3. **Output frame** `W_out × H_out` — user-typed, explicit, arbitrary aspect.
   **Authoritative for aspect ratio and the artifact's canonical resolution.** Its
   aspect defines the optimization frame's aspect.
4. **Goal image** — source `W_goal × H_goal`, aspect-fit (letterbox) into the
   optimization frame → grayscale → MLX target `[1,1,H_opt,W_opt]`.
5. **Display / drawable** — window points × backing scale. Shows the (non-square)
   rendered frame at its native aspect, fit into the canvas, at backing resolution.

## Mappings

- **Grid sizing:** `OptimizationFrame(preferred: fPreferredSize, aspectWidth:
  W_out, aspectHeight: H_out)` → `W_opt × H_opt`. (calligramy keys this off the
  *goal* aspect; Goddard keys it off the *output* aspect, since output is
  user-controlled independent of the goal.)
- **Particle → position:** normalized `(x,y)` → `(x·(W_opt−1), y·(H_opt−1))`
  (`renderPoints` as-is). Position → clip space for Metal via
  `mlxPointsToSIMD2ClipSpace`, resolution-independent.
- **Particle → size:** `frame.normalizedSize(fraction:)` gives per-axis `(w,h)` so
  σx == σy → **round dots on any aspect**, `renderPoints` unchanged.
- **Goal → target:** aspect-fit (letterbox) into the optimization frame → grayscale
  (`mlxGrayscale(from:)`) → `[1,1,H_opt,W_opt]`. Grayscale because the loss is
  grayscale-only; color is display-only. Letterbox bars appear **only** when the
  goal's aspect ≠ the output aspect — the one place letterboxing lives.
- **Frame → display/export:** render the non-square frame directly; no crop. Fit
  into the window (display) or render at `W_out × H_out` (export).

## Invariant

- **Optimization-frame aspect == output aspect** (guaranteed by deriving the grid
  from the output via `OptimizationFrame`). Target and render always share the
  exact `W_opt × H_opt` grid.

## Display / Retina

- The drawable shows the frame at its native aspect, fit into the window canvas,
  sized at **backing resolution** (`autoResizeDrawable` + `contentsScale =
  backingScaleFactor`). Retina only changes drawable pixel count + crispness.
- Positions/sizes computed in normalized/clip space; the Gaussian is evaluated
  analytically per fragment. No pixel-space math in the geometry.

## Accepted v1 fidelity gap

The MLX loss renderer sums Gaussians **on the grid**; the Metal display evaluates
them **analytically per fragment**. What you see is not pixel-identical to what is
optimized. Accepted for v1.

## Out of scope (v1)

- Texture sampling / image particles (adds a source-texture resolution + a
  differentiable bilinear sampler in the optimizer + display mip/filtering).
- Export at output resolution (render the frame at `W_out × H_out`, or Metal
  render-to-texture) — the model supports it; not built yet.
