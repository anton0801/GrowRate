//
//  ContentView.swift
//  GrowRate
//
//  Root flow coordinator: Splash -> Onboarding (first launch) -> Main.
//

import SwiftUI

struct RootFlowView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView(onFinish: {
                    withAnimation(.easeInOut(duration: 0.45)) { showSplash = false }
                })
                .transition(.opacity)
            } else if !appState.hasCompletedOnboarding {
                OnboardingView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
    }
}
