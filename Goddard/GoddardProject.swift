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

    var outputWidth: Int
    var outputHeight: Int

    // Renderer (display-only).
    var displayRadius: Float
    var falloffPower: Float

    /// The goal image, embedded as PNG (downscaled). nil if no goal was set.
    /// Codable encodes Data as base64 in JSON — self-contained, no file reference.
    var goalImagePNG: Data?

    enum CodingKeys: String, CodingKey {
        case schemaVersion, lrPos, lrValue, lrSize, maxMotion, overlapWeight
        case optimizerLongSide, optimizerPointCount, optimizerDotRadius
        case outputWidth, outputHeight, displayRadius, falloffPower, goalImagePNG
    }

    init(schemaVersion: Int = 1,
         lrPos: Float, lrValue: Float, lrSize: Float, maxMotion: Float, overlapWeight: Float,
         optimizerLongSide: Int, optimizerPointCount: Int, optimizerDotRadius: Float,
         outputWidth: Int, outputHeight: Int,
         displayRadius: Float, falloffPower: Float, goalImagePNG: Data?) {
        self.schemaVersion = schemaVersion
        self.lrPos = lrPos; self.lrValue = lrValue; self.lrSize = lrSize
        self.maxMotion = maxMotion; self.overlapWeight = overlapWeight
        self.optimizerLongSide = optimizerLongSide
        self.optimizerPointCount = optimizerPointCount
        self.optimizerDotRadius = optimizerDotRadius
        self.outputWidth = outputWidth; self.outputHeight = outputHeight
        self.displayRadius = displayRadius; self.falloffPower = falloffPower
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
        outputWidth         = try c.decodeIfPresent(Int.self,   forKey: .outputWidth) ?? 1280
        outputHeight        = try c.decodeIfPresent(Int.self,   forKey: .outputHeight) ?? 720
        displayRadius       = try c.decodeIfPresent(Float.self, forKey: .displayRadius) ?? 0.005
        falloffPower        = try c.decodeIfPresent(Float.self, forKey: .falloffPower) ?? 4
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
