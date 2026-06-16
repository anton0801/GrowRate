//
//  GrowthEngine.swift
//  GrowRate
//
//  Average daily gain, growth status vs the cross standard.
//

import Foundation

struct GrowthResult {
    var hasData: Bool
    var currentDay: Int
    var latestDay: Int
    var latestAvgGrams: Double
    var standardGrams: Double        // standard weight at latest measured day
    var deviationGrams: Double       // actual - standard
    var deviationPercent: Double
    var status: GrowthStatus
    var adgOverall: Double           // g/day since placement
    var adgRecent: Double            // g/day between last two samples
}

enum GrowthEngine {
    /// Status tolerance band around the standard (±%).
    static let tolerance = 0.03

    static func analyze(_ batch: Batch) -> GrowthResult {
        let sorted = batch.sortedWeights
        guard let last = sorted.last else {
            return GrowthResult(hasData: false, currentDay: batch.currentDay, latestDay: 0,
                                latestAvgGrams: batch.initialAvgWeightGrams, standardGrams: 0,
                                deviationGrams: 0, deviationPercent: 0, status: .noData,
                                adgOverall: 0, adgRecent: 0)
        }
        let latestDay = batch.day(for: last.date)
        let standard = batch.cross.standardWeight(day: latestDay)
        let dev = last.avgWeightGrams - standard
        let devPct = standard > 0 ? dev / standard : 0

        let status: GrowthStatus
        if devPct > tolerance { status = .ahead }
        else if devPct < -tolerance { status = .behind }
        else { status = .onTrack }

        // ADG overall
        let daysElapsed = max(1, latestDay)
        let adgOverall = (last.avgWeightGrams - batch.initialAvgWeightGrams) / Double(daysElapsed)

        // ADG recent (last two samples)
        var adgRecent = adgOverall
        if sorted.count >= 2 {
            let a = sorted[sorted.count - 2], b = sorted[sorted.count - 1]
            let dd = max(1, batch.day(for: b.date) - batch.day(for: a.date))
            adgRecent = (b.avgWeightGrams - a.avgWeightGrams) / Double(dd)
        }

        return GrowthResult(hasData: true, currentDay: batch.currentDay, latestDay: latestDay,
                            latestAvgGrams: last.avgWeightGrams, standardGrams: standard,
                            deviationGrams: dev, deviationPercent: devPct, status: status,
                            adgOverall: adgOverall, adgRecent: max(0, adgRecent))
    }
}
