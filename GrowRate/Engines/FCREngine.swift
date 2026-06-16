//
//  FCREngine.swift
//  GrowRate
//
//  Feed conversion ratio: feed eaten / live-weight gain. The economic heart.
//

import Foundation

struct PhaseFeed: Identifiable {
    let id = UUID()
    var phase: FeedPhase
    var kg: Double
    var percent: Double
}

struct FCRPoint: Identifiable {
    let id = UUID()
    var day: Int
    var fcr: Double
}

struct FCRResult {
    var hasData: Bool
    var feedKg: Double
    var gainKg: Double
    var fcr: Double                  // 0 if no gain logged
    var standardFCR: Double          // cross target at latest day
    var deltaVsStandard: Double      // fcr - standardFCR (negative = better)
    var isBetterThanStandard: Bool
    var phaseFeed: [PhaseFeed]
    var intervalFCRs: [FCRPoint]     // efficiency trend between samples
}

enum FCREngine {
    static func analyze(_ batch: Batch) -> FCRResult {
        let feedKg = batch.cumulativeFeedKg

        // Total live-weight gain of the flock (current mass - placed mass).
        let currentMassKg = batch.latestAvgGrams * Double(batch.currentCount) / 1000.0
        let placedMassKg = batch.initialAvgWeightGrams * Double(batch.initialCount) / 1000.0
        let gainKg = max(0, currentMassKg - placedMassKg)

        let fcr = gainKg > 0 ? feedKg / gainKg : 0
        let latestDay = batch.latestDay ?? batch.currentDay
        let stdFCR = batch.cross.standardFCR(day: latestDay)
        let delta = fcr > 0 ? fcr - stdFCR : 0

        // Feed per phase
        var phaseTotals: [FeedPhase: Double] = [:]
        for f in batch.feed { phaseTotals[f.phase, default: 0] += f.amountKg }
        let phaseFeed: [PhaseFeed] = FeedPhase.allCases.map { ph in
            let kg = phaseTotals[ph] ?? 0
            return PhaseFeed(phase: ph, kg: kg, percent: feedKg > 0 ? kg / feedKg : 0)
        }

        // Interval FCR trend between consecutive weight samples
        var intervals: [FCRPoint] = []
        let ws = batch.sortedWeights
        if ws.count >= 2 {
            for i in 1..<ws.count {
                let a = ws[i - 1], b = ws[i]
                let intervalFeed = batch.feed
                    .filter { $0.date > a.date && $0.date <= b.date }
                    .reduce(0) { $0 + $1.amountKg }
                let gain = (b.avgWeightGrams - a.avgWeightGrams) / 1000.0 * Double(batch.currentCount)
                if gain > 0 && intervalFeed > 0 {
                    intervals.append(FCRPoint(day: batch.day(for: b.date), fcr: intervalFeed / gain))
                }
            }
        }

        return FCRResult(hasData: feedKg > 0,
                         feedKg: feedKg, gainKg: gainKg, fcr: fcr,
                         standardFCR: stdFCR, deltaVsStandard: delta,
                         isBetterThanStandard: fcr > 0 && fcr <= stdFCR,
                         phaseFeed: phaseFeed, intervalFCRs: intervals)
    }
}
