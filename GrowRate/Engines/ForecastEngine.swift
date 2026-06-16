//
//  ForecastEngine.swift
//  GrowRate
//
//  Projects the date the target weight is reached at the current growth rate,
//  and finds the "diminishing-returns" point where extra feeding stops paying.
//
//  Marginal model (per bird, from the cross standard):
//    F(d)  = cumulativeFCR(d) * (W(d) - W(0)) / 1000   [kg feed eaten by day d]
//    f(d)  = F(d) - F(d-1)                              [feed eaten on day d]
//    g(d)  = W(d) - W(d-1)                              [grams gained on day d]
//    marginalFCR(d) = f(d) / (g(d)/1000)               [kg feed / kg of that day's gain]
//    marginalCost(d) = marginalFCR(d) * feedPricePerKg [money per extra kg of gain]
//  As the bird matures g(d) falls and f(d) rises, so marginalCost rises. The
//  economic optimum is the last day marginalCost is still below the live price.
//

import Foundation

struct ForecastResult {
    var hasProjection: Bool
    var adgUsed: Double               // g/day
    var alreadyReached: Bool
    var daysToTarget: Int?            // from today
    var targetDate: Date?
    var targetDay: Int?               // day on feed when target reached
    var plateauDay: Int               // biological diminishing-returns day
    var optimalSlaughterDay: Int?     // economic optimum (needs live price)
    var marginalCostNow: Double       // money per kg of gain at current day
    var marginalCostSeries: [ChartPoint]
    var note: String
}

enum ForecastEngine {

    // MARK: Standard-curve marginals (per bird)

    private static func cumFeedKg(_ c: CrossPreset, _ day: Int) -> Double {
        let gain = max(0, c.standardWeight(day: day) - c.standardWeight(day: 0))
        return c.standardFCR(day: day) * gain / 1000.0
    }
    private static func dailyGain(_ c: CrossPreset, _ day: Int) -> Double {
        let d = max(1, day)
        return max(0.1, c.standardWeight(day: d) - c.standardWeight(day: d - 1))
    }
    private static func dailyFeedKg(_ c: CrossPreset, _ day: Int) -> Double {
        let d = max(1, day)
        return max(0, cumFeedKg(c, d) - cumFeedKg(c, d - 1))
    }
    static func marginalFCR(_ c: CrossPreset, _ day: Int) -> Double {
        dailyFeedKg(c, day) / (dailyGain(c, day) / 1000.0)
    }
    static func marginalCost(_ batch: Batch, _ day: Int) -> Double {
        marginalFCR(batch.cross, day) * batch.feedPricePerKg
    }

    static func analyze(_ batch: Batch) -> ForecastResult {
        let c = batch.cross
        let maxDay = (c.curve.keys.max() ?? 70) + 30

        // Marginal cost series (from current day forward, plus a little history)
        let startDay = max(1, batch.currentDay - 7)
        let series: [ChartPoint] = stride(from: startDay, through: maxDay, by: 1).map {
            ChartPoint(x: Double($0), y: marginalCost(batch, $0))
        }
        let marginalNow = marginalCost(batch, max(1, batch.currentDay))

        // Biological plateau: peak daily gain, then first day gain < 60% of peak
        var peak = 0.0, peakDay = 1
        for d in 1...maxDay {
            let g = dailyGain(c, d)
            if g > peak { peak = g; peakDay = d }
        }
        var plateau = peakDay
        for d in peakDay...maxDay where dailyGain(c, d) < peak * 0.6 { plateau = d; break }

        // Economic optimum: first day marginal cost exceeds live price
        var optimal: Int? = nil
        if batch.marketPricePerKgLive > 0 {
            for d in 1...maxDay where marginalCost(batch, d) >= batch.marketPricePerKgLive {
                optimal = d; break
            }
        }

        // Weight projection from logged data
        let g = GrowthEngine.analyze(batch)
        guard let last = batch.sortedWeights.last, g.hasData else {
            return ForecastResult(hasProjection: false, adgUsed: 0, alreadyReached: false,
                                  daysToTarget: nil, targetDate: nil, targetDay: nil,
                                  plateauDay: plateau, optimalSlaughterDay: optimal,
                                  marginalCostNow: marginalNow, marginalCostSeries: series,
                                  note: "Log at least one sample weight to project the slaughter date.")
        }

        let adg = g.adgRecent > 0 ? g.adgRecent : g.adgOverall
        let latestDay = batch.day(for: last.date)

        if last.avgWeightGrams >= batch.targetWeightGrams {
            return ForecastResult(hasProjection: true, adgUsed: adg, alreadyReached: true,
                                  daysToTarget: 0, targetDate: last.date, targetDay: latestDay,
                                  plateauDay: plateau, optimalSlaughterDay: optimal,
                                  marginalCostNow: marginalNow, marginalCostSeries: series,
                                  note: "Target weight already reached on day \(latestDay).")
        }

        guard adg > 0 else {
            return ForecastResult(hasProjection: false, adgUsed: 0, alreadyReached: false,
                                  daysToTarget: nil, targetDate: nil, targetDay: nil,
                                  plateauDay: plateau, optimalSlaughterDay: optimal,
                                  marginalCostNow: marginalNow, marginalCostSeries: series,
                                  note: "Growth rate is flat — add another sample to project.")
        }

        let remainingGrams = batch.targetWeightGrams - last.avgWeightGrams
        let daysFromLast = Int(ceil(remainingGrams / adg))
        let targetDay = latestDay + daysFromLast
        let targetDate = Calendar.current.date(byAdding: .day, value: daysFromLast, to: last.date)
        let daysFromToday = targetDate.map {
            Calendar.current.dateComponents([.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: $0)).day ?? 0
        }

        var note = "At \(Int(adg)) g/day the target is reached on day \(targetDay)."
        if let opt = optimal, opt <= targetDay {
            note += " Marginal feed cost overtakes live price around day \(opt) — slaughtering earlier may pay more."
        }

        return ForecastResult(hasProjection: true, adgUsed: adg, alreadyReached: false,
                              daysToTarget: max(0, daysFromToday ?? 0),
                              targetDate: targetDate, targetDay: targetDay,
                              plateauDay: plateau, optimalSlaughterDay: optimal,
                              marginalCostNow: marginalNow, marginalCostSeries: series,
                              note: note)
    }
}
