//
//  GrowRateApp.swift
//  GrowRate
//
//  Broiler fattening economics tracker.
//

import SwiftUI

@main
struct GrowRateApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var store = DataStore()
    @StateObject private var reminders = ReminderManager()

    var body: some Scene {
        WindowGroup {
            RootFlowView()
                .environmentObject(appState)
                .environmentObject(store)
                .environmentObject(reminders)
                .preferredColorScheme(appState.themeMode.colorScheme)
                .accentColor(GR.orange)
        }
    }
}
