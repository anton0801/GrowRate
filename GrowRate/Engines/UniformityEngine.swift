//
//  UniformityEngine.swift
//  GrowRate
//
//  Flock uniformity from a sample of individual weights (CV%, in-band share).
//

import SwiftUI

struct UniformityResult {
    var hasData: Bool
    var count: Int
    var mean: Double
    var stdDev: Double
    var cvPercent: Double
    var minW: Double
    var maxW: Double
    var percentInTargetBand: Double   // within ±10% of target
    var leaders: Int                  // > mean * 1.10
    var laggards: Int                 // < mean * 0.90
    var sortedWeights: [Double]
    var rating: String
    var ratingColor: Color
}

enum UniformityEngine {
    static func analyze(_ batch: Batch) -> UniformityResult {
        // Use the most recent weight entry that has individual weights.
        let entry = batch.sortedWeights.reversed().first { !$0.individualWeights.isEmpty }
        guard let e = entry, e.individualWeights.count >= 2 else {
            return UniformityResult(hasData: false, count: 0, mean: 0, stdDev: 0, cvPercent: 0,
                                    minW: 0, maxW: 0, percentInTargetBand: 0, leaders: 0,
                                    laggards: 0, sortedWeights: [], rating: "—", ratingColor: GR.textMuted)
        }
        let w = e.individualWeights
        let n = Double(w.count)
        let mean = w.reduce(0, +) / n
        let variance = w.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / n
        let sd = sqrt(variance)
        let cv = mean > 0 ? sd / mean * 100 : 0

        let target = batch.targetWeightGrams
        let inBand = w.filter { abs($0 - target) <= target * 0.10 }.count
        let leaders = w.filter { $0 > mean * 1.10 }.count
        let laggards = w.filter { $0 < mean * 0.90 }.count

        let rating: String
        let color: Color
        switch cv {
        case ..<8:  rating = "Excellent"; color = GR.green
        case ..<12: rating = "Good";      color = GR.green
        case ..<16: rating = "Fair";      color = GR.yellow
        default:    rating = "Poor";      color = GR.red
        }

        return UniformityResult(hasData: true, count: w.count, mean: mean, stdDev: sd,
                                cvPercent: cv, minW: w.min() ?? 0, maxW: w.max() ?? 0,
                                percentInTargetBand: Double(inBand) / n,
                                leaders: leaders, laggards: laggards,
                                sortedWeights: w.sorted(by: >),
                                rating: rating, ratingColor: color)
    }
}
