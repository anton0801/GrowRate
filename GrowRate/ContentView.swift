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
            if !appState.hasCompletedOnboarding {
                OnboardingView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(appState.themeMode.colorScheme)
        .accentColor(GR.orange)
    }
}


final class Graft {

    private var sap: [AnyHashable: Any] = [:]
    private var roots: [AnyHashable: Any] = [:]
    private var pending: DispatchWorkItem?

    func takeSap(_ data: [AnyHashable: Any]) {
        sap = data
        arm()
        if roots.isEmpty == false { fuse() }
    }

    func takeRoots(_ data: [AnyHashable: Any]) {
        guard UserDefaults.standard.bool(forKey: SeedKey.primed) == false else { return }
        roots = data
        NotificationCenter.default.post(name: .rootsIn, object: nil, userInfo: ["deeplinksData": data])
        pending?.cancel()
        pending = nil
        if sap.isEmpty == false { fuse() }
    }

    private func arm() {
        pending?.cancel()
        let job = DispatchWorkItem { [weak self] in self?.fuse() }
        pending = job
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: job)
    }

    private func fuse() {
        pending?.cancel()
        pending = nil
        var merged = sap
        roots.forEach { pair in
            let key = "deep_\(pair.key)"
            if merged[key] == nil { merged[key] = pair.value }
        }
        NotificationCenter.default.post(name: .sapIn, object: nil, userInfo: ["conversionData": merged])
    }
}
