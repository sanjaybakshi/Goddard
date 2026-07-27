//
//  TgoddardModel+FileIO.swift
//  Goddard
//
//  Reading/writing a Goddard project file (params + embedded goal PNG) as
//  versioned JSON. The model↔struct conversion is private; the file I/O
//  (writeProject / readProject) is the public surface.
//

import Foundation
import CoreGraphics
import SameEyesOptimizerKit

extension TgoddardModel {

    /// Write the current project (params + embedded goal PNG) to a JSON file.
    func writeProject(to url: URL) throws {
        try makeProject().jsonData().write(to: url, options: .atomic)
    }

    /// Read a project file, apply its params, resolve its goal image, and rebuild.
    func readProject(from url: URL) throws {
        let project = try GoddardProject(jsonData: Data(contentsOf: url))
        apply(project)
    }

    // model ↔ struct (in-memory)

    /// Max stored goal dimension — the goal only needs ~the optimize resolution,
    /// so downscaling keeps the embedded PNG (and the file) small.
    private static let goalImageStoreMax = 1024
    /// Max stored source dimension — larger than the goal since the source is the
    /// texture (it wants more detail), but still bounded to keep the file sane.
    private static let sourceImageStoreMax = 2048

    private func makeProject() -> GoddardProject {
        var png: Data?
        if let goal = fGoalImage,
           let small = scaledToFit(goal, maxDimension: Self.goalImageStoreMax) {
            png = pngData(from: small)
        }
        var srcPNG: Data?
        if let src = fSourceImage,
           let small = scaledToFit(src, maxDimension: Self.sourceImageStoreMax) {
            srcPNG = pngData(from: small)
        }
        return GoddardProject(lrPos: fLrPos, lrValue: fLrValue, lrSize: fLrSize,
                              maxMotion: fMaxMotion, overlapWeight: fOverlapWeight,
                              optimizerLongSide: fOptimizerLongSide,
                              optimizerPointCount: fOptimizerPointCount,
                              optimizerDotRadius: fOptimizerDotRadius,
                              invertRender: fInvertRender,
                              pointLayout: fPointLayout.rawValue,
                              outputWidth: fOutputWidth, outputHeight: fOutputHeight,
                              displayRadius: fDisplayRadius, falloffPower: fFalloffPower,
                              textured: fTextured,
                              backgroundColor: fBackgroundColor, dotColor: fDotColor,
                              outBlackPoint: fOutBlackPoint, outWhitePoint: fOutWhitePoint,
                              outBrightness: fOutBrightness, outContrast: fOutContrast,
                              outGamma: fOutGamma,
                              goalInvert: fGoalInvert, goalBlur: fGoalBlur,
                              goalBlackPoint: fGoalBlackPoint, goalWhitePoint: fGoalWhitePoint,
                              goalBrightness: fGoalBrightness, goalContrast: fGoalContrast,
                              goalGamma: fGoalGamma,
                              goalCenterX: fGoalCenterX, goalCenterY: fGoalCenterY, goalScale: fGoalScale,
                              goalImagePNG: png, sourceImagePNG: srcPNG)
    }

    private func apply(_ p: GoddardProject) {
        fLrPos = p.lrPos; fLrValue = p.lrValue; fLrSize = p.lrSize
        fMaxMotion = p.maxMotion; fOverlapWeight = p.overlapWeight
        fOptimizerLongSide = p.optimizerLongSide
        fOptimizerPointCount = p.optimizerPointCount
        fOptimizerDotRadius = p.optimizerDotRadius
        fInvertRender = p.invertRender
        fPointLayout = PointLayout(rawValue: p.pointLayout) ?? .random
        fOutputWidth = p.outputWidth; fOutputHeight = p.outputHeight
        fDisplayRadius = p.displayRadius; fFalloffPower = p.falloffPower
        fTextured = p.textured
        fBackgroundColor = p.backgroundColor; fDotColor = p.dotColor
        fOutBlackPoint = p.outBlackPoint; fOutWhitePoint = p.outWhitePoint
        fOutBrightness = p.outBrightness; fOutContrast = p.outContrast
        fOutGamma = p.outGamma

        fGoalInvert = p.goalInvert; fGoalBlur = p.goalBlur
        fGoalBlackPoint = p.goalBlackPoint; fGoalWhitePoint = p.goalWhitePoint
        fGoalBrightness = p.goalBrightness; fGoalContrast = p.goalContrast
        fGoalGamma = p.goalGamma
        fGoalCenterX = p.goalCenterX; fGoalCenterY = p.goalCenterY; fGoalScale = p.goalScale

        // Goal + source images are embedded in the project — decode them.
        fGoalImage = p.goalImagePNG.flatMap { cgImage(fromData: $0) }
        fSourceImage = p.sourceImagePNG.flatMap { cgImage(fromData: $0) }

        refreshGoalThumbnail()
        refreshSourceThumbnail()
        buildOptimizer()
    }
}
