//
//  GoalPlacementOverlay.swift
//  Goddard
//
//  Interactive goal-placement editor drawn over the Metal canvas. Because it's an
//  overlay on the aspect-fit MetalCanvasView, its GeometryReader size IS the canvas
//  rect, so normalized [0,1] maps by plain × size (Step-1 rule) — no letterbox math.
//  It uses the kit's `placedRect` (same helper the optimizer target uses), so what
//  you drag is exactly the target that will be built on Reset.
//
//  Move: drag the body → writes fGoalCenterX/Y (one undo entry via setValues).
//  Resize: drag a corner → scales about the center → writes fGoalScale (beginEdit/
//  commitEdit). Center-anchored for v1.
//

import SwiftUI
import SameEyesOptimizerKit   // placedRect
import SameEyesUIKit          // UndoableStore.setValues / commitEdit

struct GoalPlacementOverlay: View {
    @ObservedObject var model: TgoddardModel
    @Environment(\.undoManager) private var undoManager

    private let space = "goalPlacement"
    private let handleSize: CGFloat = 12

    // Drag session state.
    @State private var startCenter: SIMD2<Float>? = nil
    @State private var resize: ResizeSession? = nil

    /// Which corner is grabbed; the opposite corner is the fixed anchor.
    private enum Corner: CaseIterable, Hashable {
        case topLeft, topRight, bottomLeft, bottomRight
        func point(in r: CGRect) -> CGPoint {
            switch self {
            case .topLeft:     return CGPoint(x: r.minX, y: r.minY)
            case .topRight:    return CGPoint(x: r.maxX, y: r.minY)
            case .bottomLeft:  return CGPoint(x: r.minX, y: r.maxY)
            case .bottomRight: return CGPoint(x: r.maxX, y: r.maxY)
            }
        }
        func opposite(in r: CGRect) -> CGPoint {
            switch self {
            case .topLeft:     return CGPoint(x: r.maxX, y: r.maxY)
            case .topRight:    return CGPoint(x: r.minX, y: r.maxY)
            case .bottomLeft:  return CGPoint(x: r.maxX, y: r.minY)
            case .bottomRight: return CGPoint(x: r.minX, y: r.minY)
            }
        }
    }

    /// Captured once at resize-drag start (independent of any stale rect).
    private struct ResizeSession {
        let anchor: CGPoint      // fixed opposite corner (points)
        let diag: CGVector       // anchor → grabbed corner at start
        let fitted: CGSize       // scale-1 fit size (points)
        let startScale: Float
        let startCX: Float
        let startCY: Float
    }

    var body: some View {
        GeometryReader { geo in
            if let goal = model.fGoalImage {
                let aspect = CGFloat(goal.width) / CGFloat(max(1, goal.height))
                let rect = placedRect(contentAspect: aspect,
                                      frameSize: geo.size,
                                      center: CGPoint(x: Double(model.fGoalCenterX),
                                                      y: Double(model.fGoalCenterY)),
                                      scale: CGFloat(model.fGoalScale))
                ZStack(alignment: .topLeading) {
                    Image(decorative: goal, scale: 1.0)
                        .resizable()
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .opacity(0.40)
                        .allowsHitTesting(false)

                    Rectangle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(.white)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .contentShape(Rectangle())
                        .gesture(moveGesture(size: geo.size))

                    ForEach(Corner.allCases, id: \.self) { corner in
                        Circle()
                            .fill(.white)
                            .overlay(Circle().stroke(.black.opacity(0.7), lineWidth: 1))
                            .frame(width: handleSize, height: handleSize)
                            .position(corner.point(in: rect))
                            .gesture(resizeGesture(corner: corner, aspect: aspect, size: geo.size))
                    }
                }
            }
        }
        .coordinateSpace(name: space)
    }

    // MARK: - Move (center), one undo entry via setValues

    private func moveGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(space))
            .onChanged { value in
                if startCenter == nil { startCenter = SIMD2(model.fGoalCenterX, model.fGoalCenterY) }
                guard let s = startCenter, size.width > 0, size.height > 0 else { return }
                let dx = Float(value.translation.width / size.width)
                let dy = Float(value.translation.height / size.height)
                model.fGoalCenterX = min(1, max(0, s.x + dx))
                model.fGoalCenterY = min(1, max(0, s.y + dy))
            }
            .onEnded { _ in
                guard let s = startCenter else { return }
                startCenter = nil
                let endX = model.fGoalCenterX, endY = model.fGoalCenterY
                // Restore, then setValues → captures start as previous → one undo entry.
                model.fGoalCenterX = s.x; model.fGoalCenterY = s.y
                model.setValues(\.fGoalCenterX, to: endX, \.fGoalCenterY, to: endY,
                                named: "Move goal", using: undoManager)
            }
    }

    // MARK: - Resize (opposite-corner-anchored, aspect-locked) → scale + center

    private func resizeGesture(corner: Corner, aspect: CGFloat, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
            .onChanged { value in
                // Capture the session once, from the model — not a possibly-stale rect.
                if resize == nil {
                    let s0 = model.fGoalScale, cx0 = model.fGoalCenterX, cy0 = model.fGoalCenterY
                    let startRect = placedRect(contentAspect: aspect, frameSize: size,
                                               center: CGPoint(x: Double(cx0), y: Double(cy0)),
                                               scale: CGFloat(s0))
                    let o = corner.opposite(in: startRect)
                    let c0 = corner.point(in: startRect)
                    let denom = max(0.0001, s0)
                    resize = ResizeSession(anchor: o,
                                           diag: CGVector(dx: c0.x - o.x, dy: c0.y - o.y),
                                           fitted: CGSize(width: startRect.width / CGFloat(denom),
                                                          height: startRect.height / CGFloat(denom)),
                                           startScale: s0, startCX: cx0, startCY: cy0)
                }
                guard let r = resize, size.width > 0, size.height > 0 else { return }

                // Scale = projection of the cursor onto the start diagonal (1 at start).
                let dd = r.diag.dx * r.diag.dx + r.diag.dy * r.diag.dy
                guard dd > 0.0001 else { return }
                let px = value.location.x - r.anchor.x, py = value.location.y - r.anchor.y
                let ratio = (px * r.diag.dx + py * r.diag.dy) / dd
                let newScale = min(2, max(0.05, Float(CGFloat(r.startScale) * ratio)))

                // Aspect-locked size, anchored at the fixed opposite corner.
                let nW = r.fitted.width * CGFloat(newScale)
                let nH = r.fitted.height * CGFloat(newScale)
                let sx: CGFloat = r.diag.dx >= 0 ? 1 : -1
                let sy: CGFloat = r.diag.dy >= 0 ? 1 : -1
                let cx = r.anchor.x + sx * nW / 2
                let cy = r.anchor.y + sy * nH / 2

                model.fGoalScale = newScale
                model.fGoalCenterX = Float(cx / size.width)
                model.fGoalCenterY = Float(cy / size.height)
            }
            .onEnded { _ in
                guard let r = resize else { return }
                resize = nil
                let endScale = model.fGoalScale, endCX = model.fGoalCenterX, endCY = model.fGoalCenterY
                // Restore to start, then one atomic undoable set (scale + center).
                model.fGoalScale = r.startScale; model.fGoalCenterX = r.startCX; model.fGoalCenterY = r.startCY
                model.setValues(\.fGoalScale, to: endScale,
                                \.fGoalCenterX, to: endCX,
                                \.fGoalCenterY, to: endCY,
                                named: "Scale goal", using: undoManager)
            }
    }
}
