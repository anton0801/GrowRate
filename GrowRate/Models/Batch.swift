//
//  Batch.swift
//  GrowRate
//
//  Core data model: a fattening batch and its logged sub-records.
//  All weights stored in GRAMS, all money in the batch currency, feed in KG.
//

import Foundation

// MARK: - Sub-records

struct WeightEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var avgWeightGrams: Double
    var sampleSize: Int
    var individualWeights: [Double] = []   // grams; optional, enables uniformity stats
    var notes: String = ""
}

struct FeedEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var amountKg: Double
    var phase: FeedPhase
    var notes: String = ""
}

struct MortalityEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var count: Int
    var type: MortalityType
    var cause: String = ""
    var notes: String = ""
}

struct PhotoMarker: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var fileName: String       // stored in Documents/photos
    var caption: String = ""
}

// MARK: - Batch

struct Batch: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var crossId: String
    var placementDate: Date
    var initialCount: Int
    var initialAvgWeightGrams: Double = 42      // day-0 chick weight
    var targetWeightGrams: Double
    var currency: String = "$"

    // Economics inputs
    var feedPricePerKg: Double                  // cost of feed
    var chickPricePerHead: Double = 0
    var otherCostsTotal: Double = 0             // bedding, vet, energy, etc.
    var marketPricePerKgLive: Double = 0        // live sale value (drives "stop feeding" point)
    var salePricePerKgDressed: Double = 0       // dressed sale price (drives yield revenue)

    // Status
    var isSlaughtered: Bool = false
    var slaughterDate: Date? = nil
    var actualDressedWeightPerBirdGrams: Double = 0  // measured at slaughter (optional)

    var notes: String = ""

    // Logs
    var weights: [WeightEntry] = []
    var feed: [FeedEntry] = []
    var mortality: [MortalityEntry] = []
    var photos: [PhotoMarker] = []

    // MARK: Derived (pure)

    var cross: CrossPreset { CrossPreset.builtIn(id: crossId) }

    var sortedWeights: [WeightEntry] { weights.sorted { $0.date < $1.date } }
    var sortedFeed: [FeedEntry] { feed.sorted { $0.date < $1.date } }
    var sortedMortality: [MortalityEntry] { mortality.sorted { $0.date < $1.date } }

    var deathsTotal: Int { mortality.filter { $0.type == .death }.reduce(0) { $0 + $1.count } }
    var cullsTotal: Int { mortality.filter { $0.type == .cull }.reduce(0) { $0 + $1.count } }
    var lossTotal: Int { mortality.reduce(0) { $0 + $1.count } }
    var currentCount: Int { max(0, initialCount - lossTotal) }

    var mortalityRate: Double {
        initialCount > 0 ? Double(lossTotal) / Double(initialCount) : 0
    }

    var latestWeight: WeightEntry? { sortedWeights.last }
    var latestAvgGrams: Double { latestWeight?.avgWeightGrams ?? initialAvgWeightGrams }

    var cumulativeFeedKg: Double { feed.reduce(0) { $0 + $1.amountKg } }

    /// Day on feed for a given date (day 0 = placement date).
    func day(for date: Date) -> Int {
        let cal = Calendar.current
        let a = cal.startOfDay(for: placementDate)
        let b = cal.startOfDay(for: date)
        return max(0, cal.dateComponents([.day], from: a, to: b).day ?? 0)
    }

    /// Current day on feed (today vs placement, or slaughter day if finished).
    var currentDay: Int { day(for: slaughterDate ?? Date()) }

    /// Latest measured day on feed.
    var latestDay: Int? {
        guard let w = latestWeight else { return nil }
        return day(for: w.date)
    }

    var currentPhase: FeedPhase { cross.phase(forDay: currentDay) }

    /// Growth-curve chart points from logged weights.
    var weightChartPoints: [ChartPoint] {
        sortedWeights.map { ChartPoint(x: Double(day(for: $0.date)), y: $0.avgWeightGrams) }
    }
}
