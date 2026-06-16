//
//  AppState.swift
//  GrowRate
//
//  App-wide preferences (theme, units, currency) persisted to UserDefaults,
//  plus the transient onboarding draft used to seed the first batch.
//

import SwiftUI

final class AppState: ObservableObject {
    private let d = UserDefaults.standard

    @Published var hasCompletedOnboarding: Bool {
        didSet { d.set(hasCompletedOnboarding, forKey: "gr_onboarded") }
    }
    @Published var themeMode: ThemeMode {
        didSet { d.set(themeMode.rawValue, forKey: "gr_theme") }
    }
    @Published var weightUnit: WeightUnit {
        didSet { d.set(weightUnit.rawValue, forKey: "gr_unit") }
    }
    @Published var currencyCode: String {
        didSet { d.set(currencyCode, forKey: "gr_currency") }
    }
    @Published var defaultCrossId: String {
        didSet { d.set(defaultCrossId, forKey: "gr_cross") }
    }
    @Published var defaultTargetGrams: Double {
        didSet { d.set(defaultTargetGrams, forKey: "gr_target") }
    }

    // Onboarding draft (transient)
    @Published var draftCrossId: String = CrossPreset.ross308.id
    @Published var draftPlacementDate: Date = Date()
    @Published var draftHeadCount: Int = 100
    @Published var draftTargetGrams: Double = 2500
    @Published var draftFeedPrice: Double = 0.55
    @Published var draftCurrency: String = "$"

    init() {
        hasCompletedOnboarding = d.bool(forKey: "gr_onboarded")
        themeMode = ThemeMode(rawValue: d.string(forKey: "gr_theme") ?? "") ?? .light
        weightUnit = WeightUnit(rawValue: d.string(forKey: "gr_unit") ?? "") ?? .gram
        currencyCode = d.string(forKey: "gr_currency") ?? "$"
        defaultCrossId = d.string(forKey: "gr_cross") ?? CrossPreset.ross308.id
        let t = d.double(forKey: "gr_target")
        defaultTargetGrams = t > 0 ? t : 2500
    }

    // MARK: Formatting helpers

    func weightString(grams: Double) -> String {
        weightUnit.format(grams: grams)
    }

    private static let moneyFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = " "
        return nf
    }()

    func money(_ value: Double, currency: String? = nil) -> String {
        let sym = currency ?? currencyCode
        let decimals = abs(value) >= 1000 ? 0 : 2
        let nf = AppState.moneyFormatter
        nf.minimumFractionDigits = decimals
        nf.maximumFractionDigits = decimals
        let s = nf.string(from: NSNumber(value: value)) ?? String(format: "%.\(decimals)f", value)
        return sym + s
    }

    static let commonCurrencies = ["$", "€", "£", "₽", "₴", "zł", "₸", "Kč", "₹", "R$"]
}
