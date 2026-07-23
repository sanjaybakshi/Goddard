//
//  GoddardProject.swift
//  Goddard
//
//  A saved project: optimizer parameters + an embedded (downscaled) PNG of the
//  goal image — self-contained, no file reference. Versioned with defaulted
//  decoding so files written by an older or
//  newer build still load (missing keys fall back to defaults) — the robustness
//  over a naive flat JSON.
//

import Foundation

struct GoddardProject: Codable {
    var schemaVersion: Int

    var lrPos: Float
    var lrValue: Float
    var lrSize: Float
    var maxMotion: Float
    var overlapWeight: Float

    var optimizerLongSide: Int
    var optimizerPointCount: Int
    var optimizerDotRadius: Float
    var invertRender: Bool

    var outputWidth: Int
    var outputHeight: Int

    // Renderer (display-only).
    var displayRadius: Float
    var falloffPower: Float
    var backgroundColor: SIMD3<Float>
    var dotColor: SIMD3<Float>

    // Output grade (display-only tonal curve on the composited frame).
    var outBlackPoint: Float
    var outWhitePoint: Float
    var outBrightness: Float
    var outContrast: Float
    var outGamma: Float

    // Goal image adjustments.
    var goalInvert: Bool
    var goalBlur: Float
    var goalBlackPoint: Float
    var goalWhitePoint: Float
    var goalBrightness: Float
    var goalContrast: Float
    var goalGamma: Float

    /// The goal image, embedded as PNG (downscaled). nil if no goal was set.
    /// Codable encodes Data as base64 in JSON — self-contained, no file reference.
    var goalImagePNG: Data?

    enum CodingKeys: String, CodingKey {
        case schemaVersion, lrPos, lrValue, lrSize, maxMotion, overlapWeight
        case optimizerLongSide, optimizerPointCount, optimizerDotRadius, invertRender
        case outputWidth, outputHeight, displayRadius, falloffPower
        case backgroundColor, dotColor
        case outBlackPoint, outWhitePoint, outBrightness, outContrast, outGamma
        case goalInvert, goalBlur, goalBlackPoint, goalWhitePoint
        case goalBrightness, goalContrast, goalGamma, goalImagePNG
    }

    init(schemaVersion: Int = 1,
         lrPos: Float, lrValue: Float, lrSize: Float, maxMotion: Float, overlapWeight: Float,
         optimizerLongSide: Int, optimizerPointCount: Int, optimizerDotRadius: Float,
         invertRender: Bool,
         outputWidth: Int, outputHeight: Int,
         displayRadius: Float, falloffPower: Float,
         backgroundColor: SIMD3<Float>, dotColor: SIMD3<Float>,
         outBlackPoint: Float, outWhitePoint: Float, outBrightness: Float,
         outContrast: Float, outGamma: Float,
         goalInvert: Bool, goalBlur: Float, goalBlackPoint: Float, goalWhitePoint: Float,
         goalBrightness: Float, goalContrast: Float, goalGamma: Float,
         goalImagePNG: Data?) {
        self.schemaVersion = schemaVersion
        self.lrPos = lrPos; self.lrValue = lrValue; self.lrSize = lrSize
        self.maxMotion = maxMotion; self.overlapWeight = overlapWeight
        self.optimizerLongSide = optimizerLongSide
        self.optimizerPointCount = optimizerPointCount
        self.optimizerDotRadius = optimizerDotRadius
        self.invertRender = invertRender
        self.outputWidth = outputWidth; self.outputHeight = outputHeight
        self.displayRadius = displayRadius; self.falloffPower = falloffPower
        self.backgroundColor = backgroundColor; self.dotColor = dotColor
        self.outBlackPoint = outBlackPoint; self.outWhitePoint = outWhitePoint
        self.outBrightness = outBrightness; self.outContrast = outContrast
        self.outGamma = outGamma
        self.goalInvert = goalInvert; self.goalBlur = goalBlur
        self.goalBlackPoint = goalBlackPoint; self.goalWhitePoint = goalWhitePoint
        self.goalBrightness = goalBrightness; self.goalContrast = goalContrast
        self.goalGamma = goalGamma
        self.goalImagePNG = goalImagePNG
    }

    /// Forward/backward-compatible decode: any missing key defaults, so a file
    /// from a different schema version still loads without throwing.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion       = try c.decodeIfPresent(Int.self,   forKey: .schemaVersion) ?? 1
        lrPos               = try c.decodeIfPresent(Float.self, forKey: .lrPos) ?? 0.0001
        lrValue             = try c.decodeIfPresent(Float.self, forKey: .lrValue) ?? 0
        lrSize              = try c.decodeIfPresent(Float.self, forKey: .lrSize) ?? 0
        maxMotion           = try c.decodeIfPresent(Float.self, forKey: .maxMotion) ?? 0.02
        overlapWeight       = try c.decodeIfPresent(Float.self, forKey: .overlapWeight) ?? 0
        optimizerLongSide   = try c.decodeIfPresent(Int.self,   forKey: .optimizerLongSide) ?? 512
        optimizerPointCount = try c.decodeIfPresent(Int.self,   forKey: .optimizerPointCount) ?? 10000
        optimizerDotRadius  = try c.decodeIfPresent(Float.self, forKey: .optimizerDotRadius) ?? 0.005
        invertRender        = try c.decodeIfPresent(Bool.self,  forKey: .invertRender) ?? false
        outputWidth         = try c.decodeIfPresent(Int.self,   forKey: .outputWidth) ?? 1280
        outputHeight        = try c.decodeIfPresent(Int.self,   forKey: .outputHeight) ?? 720
        displayRadius       = try c.decodeIfPresent(Float.self, forKey: .displayRadius) ?? 0.005
        falloffPower        = try c.decodeIfPresent(Float.self, forKey: .falloffPower) ?? 4
        backgroundColor     = try c.decodeIfPresent(SIMD3<Float>.self, forKey: .backgroundColor) ?? SIMD3(0.06, 0.06, 0.07)
        dotColor            = try c.decodeIfPresent(SIMD3<Float>.self, forKey: .dotColor) ?? SIMD3(1, 1, 1)
        outBlackPoint       = try c.decodeIfPresent(Float.self, forKey: .outBlackPoint) ?? 0
        outWhitePoint       = try c.decodeIfPresent(Float.self, forKey: .outWhitePoint) ?? 1
        outBrightness       = try c.decodeIfPresent(Float.self, forKey: .outBrightness) ?? 0
        outContrast         = try c.decodeIfPresent(Float.self, forKey: .outContrast) ?? 1
        outGamma            = try c.decodeIfPresent(Float.self, forKey: .outGamma) ?? 1
        goalInvert          = try c.decodeIfPresent(Bool.self,  forKey: .goalInvert) ?? false
        goalBlur            = try c.decodeIfPresent(Float.self, forKey: .goalBlur) ?? 0
        goalBlackPoint      = try c.decodeIfPresent(Float.self, forKey: .goalBlackPoint) ?? 0
        goalWhitePoint      = try c.decodeIfPresent(Float.self, forKey: .goalWhitePoint) ?? 1
        goalBrightness      = try c.decodeIfPresent(Float.self, forKey: .goalBrightness) ?? 0
        goalContrast        = try c.decodeIfPresent(Float.self, forKey: .goalContrast) ?? 1
        goalGamma           = try c.decodeIfPresent(Float.self, forKey: .goalGamma) ?? 1
        goalImagePNG        = try c.decodeIfPresent(Data.self,  forKey: .goalImagePNG)
    }

    func jsonData() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(self)
    }

    init(jsonData: Data) throws {
        self = try JSONDecoder().decode(GoddardProject.self, from: jsonData)
    }
}
