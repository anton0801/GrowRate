//
//  Enums.swift
//  GrowRate
//

import SwiftUI

// MARK: - Breed / cross type

enum CrossType: String, Codable, CaseIterable, Identifiable {
    case fastBroiler, slowHeritage, dualPurpose, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fastBroiler: return "Fast broiler"
        case .slowHeritage: return "Slow / heritage"
        case .dualPurpose: return "Dual purpose"
        case .custom: return "Custom"
        }
    }
    var subtitle: String {
        switch self {
        case .fastBroiler: return "Ross / Cobb — quick to slaughter weight"
        case .slowHeritage: return "Slower, hardier, leaner growth"
        case .dualPurpose: return "Meat + eggs, moderate growth"
        case .custom: return "Define your own target curve"
        }
    }
    var icon: String {
        switch self {
        case .fastBroiler: return "hare.fill"
        case .slowHeritage: return "tortoise.fill"
        case .dualPurpose: return "circle.grid.2x2.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
}

// MARK: - Weight unit (storage is always grams)

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case gram, kilogram, pound
    var id: String { rawValue }
    var title: String {
        switch self {
        case .gram: return "Grams (g)"
        case .kilogram: return "Kilograms (kg)"
        case .pound: return "Pounds (lb)"
        }
    }
    var short: String {
        switch self {
        case .gram: return "g"
        case .kilogram: return "kg"
        case .pound: return "lb"
        }
    }
    /// Convert grams to this unit's numeric value.
    func value(fromGrams g: Double) -> Double {
        switch self {
        case .gram: return g
        case .kilogram: return g / 1000
        case .pound: return g / 453.59237
        }
    }
    /// Convert a value in this unit back to grams.
    func grams(fromValue v: Double) -> Double {
        switch self {
        case .gram: return v
        case .kilogram: return v * 1000
        case .pound: return v * 453.59237
        }
    }
    func format(grams g: Double) -> String {
        let v = value(fromGrams: g)
        switch self {
        case .gram: return String(format: "%.0f %@", v, short)
        default: return String(format: "%.2f %@", v, short)
        }
    }
}

// MARK: - Feed phase

enum FeedPhase: String, Codable, CaseIterable, Identifiable {
    case starter, grower, finisher
    var id: String { rawValue }
    var title: String {
        switch self {
        case .starter: return "Starter"
        case .grower: return "Grower"
        case .finisher: return "Finisher"
        }
    }
    var color: Color {
        switch self {
        case .starter: return GR.yellow
        case .grower: return GR.orange
        case .finisher: return GR.green
        }
    }
    var icon: String {
        switch self {
        case .starter: return "leaf.fill"
        case .grower: return "flame.fill"
        case .finisher: return "checkmark.seal.fill"
        }
    }
}

// MARK: - Mortality type

enum MortalityType: String, Codable, CaseIterable, Identifiable {
    case death, cull
    var id: String { rawValue }
    var title: String {
        switch self {
        case .death: return "Mortality"
        case .cull: return "Cull"
        }
    }
    var icon: String {
        switch self {
        case .death: return "xmark.circle.fill"
        case .cull: return "scissors"
        }
    }
}

// MARK: - Growth status vs standard

enum GrowthStatus {
    case ahead, onTrack, behind, noData
    var title: String {
        switch self {
        case .ahead: return "Ahead of standard"
        case .onTrack: return "On track"
        case .behind: return "Behind standard"
        case .noData: return "No data yet"
        }
    }
    var short: String {
        switch self {
        case .ahead: return "Ahead"
        case .onTrack: return "On track"
        case .behind: return "Behind"
        case .noData: return "—"
        }
    }
    var color: Color {
        switch self {
        case .ahead: return GR.green
        case .onTrack: return GR.green
        case .behind: return GR.yellow
        case .noData: return GR.textMuted
        }
    }
    var icon: String {
        switch self {
        case .ahead: return "arrow.up.right.circle.fill"
        case .onTrack: return "checkmark.circle.fill"
        case .behind: return "exclamationmark.triangle.fill"
        case .noData: return "questionmark.circle"
        }
    }
}

// MARK: - Theme mode

enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case light, dark, system
    var id: String { rawValue }
    var title: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}
