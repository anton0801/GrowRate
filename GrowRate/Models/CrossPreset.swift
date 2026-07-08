//
//  CrossPreset.swift
//  GrowRate
//
//  Breed / cross growth standards. Each preset carries a day->weight target
//  curve, a cumulative-FCR target curve, dressing yield, and feed-phase
//  boundaries. These are the benchmarks the engines compare a batch against.
//

import Foundation

struct CrossPreset: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var type: CrossType
    var curve: [Int: Double]      // day on feed -> target live weight (grams)
    var fcrCurve: [Int: Double]   // day on feed -> target cumulative FCR
    var dressingPercent: Double   // dressed weight / live weight (0...1)
    var starterEndDay: Int        // last day of starter feed
    var growerEndDay: Int         // last day of grower feed
    var typicalTargetGrams: Double
    var typicalSlaughterDay: Int
    var isBuiltIn: Bool

    // MARK: Interpolation helpers

    private func interpolate(_ table: [Int: Double], _ day: Int) -> Double {
        guard !table.isEmpty else { return 0 }
        let keys = table.keys.sorted()
        if let exact = table[day] { return exact }
        if day <= keys.first! { return table[keys.first!]! }
        if day >= keys.last! {
            // linear extrapolation from last segment
            guard keys.count >= 2 else { return table[keys.last!]! }
            let k1 = keys[keys.count - 2], k2 = keys[keys.count - 1]
            let slope = (table[k2]! - table[k1]!) / Double(k2 - k1)
            return table[k2]! + slope * Double(day - k2)
        }
        var lo = keys.first!, hi = keys.last!
        for k in keys { if k <= day { lo = k }; if k >= day { hi = k; break } }
        if lo == hi { return table[lo]! }
        let f = Double(day - lo) / Double(hi - lo)
        return table[lo]! + (table[hi]! - table[lo]!) * f
    }

    func standardWeight(day: Int) -> Double { interpolate(curve, day) }
    func standardFCR(day: Int) -> Double { interpolate(fcrCurve, day) }

    func phase(forDay day: Int) -> FeedPhase {
        if day <= starterEndDay { return .starter }
        if day <= growerEndDay { return .grower }
        return .finisher
    }

    /// Day at which the standard curve first reaches a target weight.
    func standardDay(forWeight grams: Double) -> Int? {
        let maxDay = (curve.keys.max() ?? 70) + 30
        for d in 0...maxDay where standardWeight(day: d) >= grams { return d }
        return nil
    }

    func standardChartPoints(maxDay: Int) -> [ChartPoint] {
        stride(from: 0, through: maxDay, by: 1).map {
            ChartPoint(x: Double($0), y: standardWeight(day: $0))
        }
    }
}

// MARK: - Built-in presets

enum SeedKey {
    static let routeURL = "gr_route_url"
    static let routeMode = "gr_route_mode"
    static let primed = "gr_primed"
    static let pollenGranted = "gr_pollen_granted"
    static let pollenBarred = "gr_pollen_barred"
    static let pollenAt = "gr_pollen_at"
    static let pushURL = "temp_url"
    static let fcm = "fcm_token"
    static let push = "push_token"
    static let attStatus = "att_status"
    static let sharedFcm = "shared_fcm"
}

extension CrossPreset {
    static let ross308 = CrossPreset(
        id: "ross308", name: "Ross 308", type: .fastBroiler,
        curve: [0: 42, 7: 185, 10: 290, 14: 465, 17: 620, 21: 940, 24: 1180,
                28: 1550, 31: 1830, 35: 2250, 38: 2560, 42: 2950, 45: 3250, 49: 3700],
        fcrCurve: [7: 0.85, 14: 1.08, 21: 1.26, 28: 1.42, 35: 1.58, 42: 1.74, 49: 1.92],
        dressingPercent: 0.73, starterEndDay: 10, growerEndDay: 24,
        typicalTargetGrams: 2500, typicalSlaughterDay: 38, isBuiltIn: true)

    static let cobb500 = CrossPreset(
        id: "cobb500", name: "Cobb 500", type: .fastBroiler,
        curve: [0: 42, 7: 180, 10: 285, 14: 455, 17: 610, 21: 920, 24: 1160,
                28: 1520, 31: 1800, 35: 2200, 38: 2520, 42: 2880, 45: 3180, 49: 3600],
        fcrCurve: [7: 0.83, 14: 1.05, 21: 1.24, 28: 1.40, 35: 1.55, 42: 1.70, 49: 1.88],
        dressingPercent: 0.73, starterEndDay: 10, growerEndDay: 24,
        typicalTargetGrams: 2500, typicalSlaughterDay: 38, isBuiltIn: true)

    static let slowHeritage = CrossPreset(
        id: "slowHeritage", name: "Slow / heritage", type: .slowHeritage,
        curve: [0: 40, 7: 130, 14: 300, 21: 560, 28: 880, 35: 1250, 42: 1650,
                49: 2050, 56: 2450, 63: 2800, 70: 3100],
        fcrCurve: [14: 1.40, 28: 1.90, 42: 2.30, 56: 2.70, 63: 2.90, 70: 3.05],
        dressingPercent: 0.70, starterEndDay: 14, growerEndDay: 42,
        typicalTargetGrams: 2200, typicalSlaughterDay: 56, isBuiltIn: true)

    static let dualPurpose = CrossPreset(
        id: "dualPurpose", name: "Dual purpose", type: .dualPurpose,
        curve: [0: 40, 7: 120, 14: 280, 21: 500, 28: 780, 35: 1100, 42: 1450,
                49: 1780, 56: 2100, 63: 2400, 70: 2700, 84: 3200],
        fcrCurve: [14: 1.50, 28: 2.00, 42: 2.60, 56: 3.05, 70: 3.40, 84: 3.70],
        dressingPercent: 0.68, starterEndDay: 14, growerEndDay: 49,
        typicalTargetGrams: 2200, typicalSlaughterDay: 70, isBuiltIn: true)

    static let custom = CrossPreset(
        id: "custom", name: "Custom", type: .custom,
        curve: [0: 42, 7: 170, 14: 430, 21: 870, 28: 1430, 35: 2050, 42: 2700, 49: 3300],
        fcrCurve: [7: 0.90, 14: 1.15, 21: 1.35, 28: 1.55, 35: 1.72, 42: 1.90, 49: 2.05],
        dressingPercent: 0.72, starterEndDay: 12, growerEndDay: 28,
        typicalTargetGrams: 2400, typicalSlaughterDay: 40, isBuiltIn: true)

    static let builtIns: [CrossPreset] = [ross308, cobb500, slowHeritage, dualPurpose, custom]

    static func builtIn(id: String) -> CrossPreset {
        builtIns.first(where: { $0.id == id }) ?? ross308
    }

    static func builtIns(for type: CrossType) -> [CrossPreset] {
        builtIns.filter { $0.type == type }
    }
}
