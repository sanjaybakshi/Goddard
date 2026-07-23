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

    private func makeProject() -> GoddardProject {
        var png: Data?
        if let goal = fGoalImage,
           let small = scaledToFit(goal, maxDimension: Self.goalImageStoreMax) {
            png = pngData(from: small)
        }
        return GoddardProject(lrPos: fLrPos, lrValue: fLrValue, lrSize: fLrSize,
                              maxMotion: fMaxMotion, overlapWeight: fOverlapWeight,
                              optimizerLongSide: fOptimizerLongSide,
                              optimizerPointCount: fOptimizerPointCount,
                              optimizerDotRadius: fOptimizerDotRadius,
                              invertRender: fInvertRender,
                              outputWidth: fOutputWidth, outputHeight: fOutputHeight,
                              displayRadius: fDisplayRadius, falloffPower: fFalloffPower,
                              backgroundColor: fBackgroundColor, dotColor: fDotColor,
                              outBlackPoint: fOutBlackPoint, outWhitePoint: fOutWhitePoint,
                              outBrightness: fOutBrightness, outContrast: fOutContrast,
                              outGamma: fOutGamma,
                              goalInvert: fGoalInvert, goalBlur: fGoalBlur,
                              goalBlackPoint: fGoalBlackPoint, goalWhitePoint: fGoalWhitePoint,
                              goalBrightness: fGoalBrightness, goalContrast: fGoalContrast,
                              goalGamma: fGoalGamma,
                              goalImagePNG: png)
    }

    private func apply(_ p: GoddardProject) {
        fLrPos = p.lrPos; fLrValue = p.lrValue; fLrSize = p.lrSize
        fMaxMotion = p.maxMotion; fOverlapWeight = p.overlapWeight
        fOptimizerLongSide = p.optimizerLongSide
        fOptimizerPointCount = p.optimizerPointCount
        fOptimizerDotRadius = p.optimizerDotRadius
        fInvertRender = p.invertRender
        fOutputWidth = p.outputWidth; fOutputHeight = p.outputHeight
        fDisplayRadius = p.displayRadius; fFalloffPower = p.falloffPower
        fBackgroundColor = p.backgroundColor; fDotColor = p.dotColor
        fOutBlackPoint = p.outBlackPoint; fOutWhitePoint = p.outWhitePoint
        fOutBrightness = p.outBrightness; fOutContrast = p.outContrast
        fOutGamma = p.outGamma

        fGoalInvert = p.goalInvert; fGoalBlur = p.goalBlur
        fGoalBlackPoint = p.goalBlackPoint; fGoalWhitePoint = p.goalWhitePoint
        fGoalBrightness = p.goalBrightness; fGoalContrast = p.goalContrast
        fGoalGamma = p.goalGamma

        // Goal image is embedded in the project — decode it (or nil → disk).
        fGoalImage = p.goalImagePNG.flatMap { cgImage(fromData: $0) }

        refreshGoalThumbnail()
        buildOptimizer()
    }
}
