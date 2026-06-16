//
//  CostEngine.swift
//  GrowRate
//
//  Cost per kilogram of live and dressed weight.
//

import Foundation

struct CostResult {
    var feedCost: Double
    var chickCost: Double
    var otherCost: Double
    var totalCost: Double
    var liveMassKg: Double
    var dressedMassKg: Double
    var dressingPercent: Double
    var costPerKgLive: Double
    var costPerKgDressed: Double
    var costPerBird: Double
    var feedCostShare: Double        // 0...1
}

enum CostEngine {
    static func analyze(_ batch: Batch) -> CostResult {
        let feedCost = batch.cumulativeFeedKg * batch.feedPricePerKg
        let chickCost = Double(batch.initialCount) * batch.chickPricePerHead
        let other = batch.otherCostsTotal
        let total = feedCost + chickCost + other

        let liveMassKg = batch.latestAvgGrams * Double(batch.currentCount) / 1000.0
        let dressing = batch.actualDressedWeightPerBirdGrams > 0 && batch.latestAvgGrams > 0
            ? min(1, batch.actualDressedWeightPerBirdGrams / batch.latestAvgGrams)
            : batch.cross.dressingPercent
        let dressedMassKg = liveMassKg * dressing

        let perKgLive = liveMassKg > 0 ? total / liveMassKg : 0
        let perKgDressed = dressedMassKg > 0 ? total / dressedMassKg : 0
        let perBird = batch.currentCount > 0 ? total / Double(batch.currentCount) : 0

        return CostResult(feedCost: feedCost, chickCost: chickCost, otherCost: other,
                          totalCost: total, liveMassKg: liveMassKg, dressedMassKg: dressedMassKg,
                          dressingPercent: dressing,
                          costPerKgLive: perKgLive, costPerKgDressed: perKgDressed,
                          costPerBird: perBird,
                          feedCostShare: total > 0 ? feedCost / total : 0)
    }
}
