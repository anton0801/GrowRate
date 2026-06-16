//
//  YieldEngine.swift
//  GrowRate
//
//  Dressing yield, revenue vs cost, batch margin.
//

import Foundation

struct YieldResult {
    var dressingPercent: Double
    var liveAvgKg: Double
    var dressedPerBirdKg: Double
    var totalLiveKg: Double
    var totalDressedKg: Double
    var revenue: Double
    var totalCost: Double
    var margin: Double
    var marginPerBird: Double
    var breakEvenPriceDressed: Double
    var isProfit: Bool
    var hasPrice: Bool
}

enum YieldEngine {
    static func analyze(_ batch: Batch) -> YieldResult {
        let cost = CostEngine.analyze(batch)
        let liveAvgKg = batch.latestAvgGrams / 1000.0
        let dressing = cost.dressingPercent
        let dressedPerBirdKg = liveAvgKg * dressing
        let totalLiveKg = liveAvgKg * Double(batch.currentCount)
        let totalDressedKg = dressedPerBirdKg * Double(batch.currentCount)

        let price = batch.salePricePerKgDressed
        let revenue = totalDressedKg * price
        let margin = revenue - cost.totalCost
        let marginPerBird = batch.currentCount > 0 ? margin / Double(batch.currentCount) : 0
        let breakEven = totalDressedKg > 0 ? cost.totalCost / totalDressedKg : 0

        return YieldResult(dressingPercent: dressing, liveAvgKg: liveAvgKg,
                           dressedPerBirdKg: dressedPerBirdKg, totalLiveKg: totalLiveKg,
                           totalDressedKg: totalDressedKg, revenue: revenue,
                           totalCost: cost.totalCost, margin: margin, marginPerBird: marginPerBird,
                           breakEvenPriceDressed: breakEven, isProfit: margin >= 0,
                           hasPrice: price > 0)
    }
}
