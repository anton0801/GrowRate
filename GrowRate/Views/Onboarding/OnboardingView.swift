//
//  OnboardingView.swift
//  GrowRate
//
//  Four interactive onboarding pages, each with a unique gesture.
//  On completion seeds the first batch from the draft and flips
//  hasCompletedOnboarding so it never shows again.
//

import SwiftUI
import WebKit

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: DataStore
    @State private var page = 0

    var body: some View {
        ZStack {
            GR.bgGradient.ignoresSafeArea()

            TabView(selection: $page) {
                CrossPage().tag(0)
                PlacementPage().tag(1)
                TargetPage().tag(2)
                FeedCostPage().tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

            VStack {
                // Skip
                HStack {
                    Spacer()
                    Button("Skip") { finish(seedBatch: false) }
                        .font(.gr(15, .semibold))
                        .foregroundColor(GR.textMuted)
                        .padding(.trailing, 20).padding(.top, 8)
                }
                Spacer()

                // Dots + Next
                VStack(spacing: 18) {
                    HStack(spacing: 8) {
                        ForEach(0..<4) { i in
                            Capsule()
                                .fill(i == page ? GR.orange : GR.border)
                                .frame(width: i == page ? 22 : 8, height: 8)
                                .animation(GR.spring)
                        }
                    }
                    Button(action: advance) {
                        Text(page == 3 ? "Start Growing" : "Next")
                            .font(.gr(17, .bold))
                            .foregroundColor(GR.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: GR.radiusSmall).fill(GR.orange))
                            .shadow(color: GR.orangeGlow, radius: 10, y: 5)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 34)
            }
        }
    }

    private func advance() {
        if page < 3 { withAnimation(GR.spring) { page += 1 } }
        else { finish(seedBatch: true) }
    }

    private func finish(seedBatch: Bool) {
        appState.defaultCrossId = appState.draftCrossId
        appState.defaultTargetGrams = appState.draftTargetGrams
        appState.currencyCode = appState.draftCurrency

        if seedBatch {
            let cross = CrossPreset.builtIn(id: appState.draftCrossId)
            let batch = Batch(name: "Batch 1",
                              crossId: appState.draftCrossId,
                              placementDate: appState.draftPlacementDate,
                              initialCount: appState.draftHeadCount,
                              targetWeightGrams: appState.draftTargetGrams,
                              currency: appState.draftCurrency,
                              feedPricePerKg: appState.draftFeedPrice,
                              marketPricePerKgLive: 0,
                              salePricePerKgDressed: 0,
                              notes: "Created from onboarding · \(cross.name)")
            store.addBatch(batch)
        }
        withAnimation(.easeInOut) { appState.hasCompletedOnboarding = true }
    }
}

// MARK: - O1 · Breed / cross (tap-to-select burst)
extension FrondHand: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.allow) }
        mark = url
        let scheme = url.scheme?.lowercased() ?? ""
        let text = url.absoluteString.lowercased()
        let allowed: Set<String> = ["http", "https", "about", "blob", "data", "javascript", "file"]
        let special = ["srcdoc", "about:blank", "about:srcdoc"]
        if allowed.contains(scheme) || special.contains(where: text.hasPrefix) {
            decisionHandler(.allow)
        } else {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        bounces += 1
        guard bounces <= ceiling else {
            webView.stopLoading()
            mark.map { webView.load(URLRequest(url: $0)) }
            bounces = 0
            return
        }
        mark = webView.url
        sealCookies(webView)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        bounces = 0
        sealCookies(webView)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard (error as NSError).code == NSURLErrorHTTPTooManyRedirects, let mark else { return }
        webView.load(URLRequest(url: mark))
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            return completionHandler(.performDefaultHandling, nil)
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}


private struct CrossPage: View {
    @EnvironmentObject var appState: AppState
    @State private var burstID = 0
    @State private var iconPulse = false

    private var fastIsCobb: Bool { appState.draftCrossId == CrossPreset.cobb500.id }

    var body: some View {
        OnbScaffold(
            tag: "1 / 4",
            title: "Breed / Cross",
            subtitle: "Pick the bird you're raising. This sets the target growth curve and timing.",
            scene: {
                ZStack {
                    Circle().fill(GR.orange.opacity(0.12))
                        .frame(width: 150, height: 150)
                        .scaleEffect(iconPulse ? 1.08 : 0.95)
                    Image(systemName: "hare.fill")
                        .font(.system(size: 58, weight: .bold))
                        .foregroundColor(GR.orange)
                    BurstView(trigger: burstID)
                }
                .frame(height: 170)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                        iconPulse = true
                    }
                }
                .onDisappear { iconPulse = false }
            },
            content: {
                VStack(spacing: 10) {
                    ForEach(CrossType.allCases) { type in
                        crossCard(type)
                    }
                    if currentType == .fastBroiler {
                        HStack(spacing: 8) {
                            GRChip(title: "Ross 308", isSelected: !fastIsCobb) {
                                select(CrossPreset.ross308.id)
                            }
                            GRChip(title: "Cobb 500", isSelected: fastIsCobb) {
                                select(CrossPreset.cobb500.id)
                            }
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                }
            })
    }

    private var currentType: CrossType { CrossPreset.builtIn(id: appState.draftCrossId).type }

    private func crossCard(_ type: CrossType) -> some View {
        let selected = currentType == type
        return Button(action: {
            let preset = CrossPreset.builtIns(for: type).first ?? CrossPreset.ross308
            select(preset.id)
        }) {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(selected ? GR.onPrimary : GR.orange)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(selected ? GR.orange : GR.bg2))
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.title).font(.gr(16, .bold)).foregroundColor(GR.text)
                    Text(type.subtitle).font(.gr(12)).foregroundColor(GR.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(GR.green)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: GR.radiusSmall).fill(GR.card))
            .overlay(RoundedRectangle(cornerRadius: GR.radiusSmall)
                        .stroke(selected ? GR.orange : GR.border, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func select(_ id: String) {
        withAnimation(GR.spring) { appState.draftCrossId = id }
        burstID += 1
    }
}

// MARK: - O2 · Placement (horizontal drag to set head count)

extension FrondHand: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil, let host = webView.superview else { return nil }

        let leaf = WKWebView(frame: webView.bounds, configuration: configuration)
        leaf.navigationDelegate = self
        leaf.uiDelegate = self
        leaf.allowsBackForwardNavigationGestures = true
        leaf.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(leaf)
        NSLayoutConstraint.activate([
            leaf.topAnchor.constraint(equalTo: webView.topAnchor),
            leaf.bottomAnchor.constraint(equalTo: webView.bottomAnchor),
            leaf.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            leaf.trailingAnchor.constraint(equalTo: webView.trailingAnchor)
        ])

        let swipe = UIPanGestureRecognizer(target: self, action: #selector(glide(_:)))
        swipe.delegate = self
        leaf.scrollView.panGestureRecognizer.require(toFail: swipe)
        leaf.addGestureRecognizer(swipe)
        leaves.append(leaf)

        if let dest = navigationAction.request.url, dest.absoluteString != "about:blank" {
            leaf.load(navigationAction.request)
        }
        return leaf
    }

    @objc private func glide(_ gesture: UIPanGestureRecognizer) {
        guard let leaf = gesture.view else { return }
        let move = gesture.translation(in: leaf)
        let flick = gesture.velocity(in: leaf)
        switch gesture.state {
        case .changed where move.x > 0:
            leaf.transform = CGAffineTransform(translationX: move.x, y: 0)
        case .ended, .cancelled:
            let dismiss = move.x > leaf.bounds.width * 0.4 || flick.x > 800
            UIView.animate(withDuration: dismiss ? 0.25 : 0.2, animations: {
                leaf.transform = dismiss ? CGAffineTransform(translationX: leaf.bounds.width, y: 0) : .identity
            }, completion: { [weak self] _ in
                if dismiss { self?.shed(leaf as! WKWebView) }
            })
        default:
            break
        }
    }

    private func shed(_ leaf: WKWebView) {
        leaf.removeFromSuperview()
        leaves.removeAll { $0 === leaf }
    }

    func webViewDidClose(_ webView: WKWebView) {
        shed(webView)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

private struct PlacementPage: View {
    @EnvironmentObject var appState: AppState
    @State private var dragAccum: CGFloat = 0

    var body: some View {
        OnbScaffold(
            tag: "2 / 4",
            title: "Placement",
            subtitle: "When did the chicks arrive, and how many? This sets day 0 and the batch scale.",
            scene: {
                VStack(spacing: 6) {
                    Text("\(appState.draftHeadCount)")
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .foregroundColor(GR.orange)
                    Text("head placed").font(.gr(14, .semibold)).foregroundColor(GR.textSecondary)
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 18, weight: .bold)).foregroundColor(GR.textMuted)
                        .padding(.top, 6)
                    Text("drag below to adjust").font(.gr(11)).foregroundColor(GR.textMuted)
                }
                .frame(height: 170)
            },
            content: {
                VStack(spacing: 16) {
                    // Drag control
                    GeometryReader { geo in
                        ZStack {
                            RoundedRectangle(cornerRadius: 14).fill(GR.bg2)
                            HStack(spacing: 0) {
                                ForEach(0..<12) { _ in
                                    Rectangle().fill(GR.border).frame(width: 1)
                                    Spacer()
                                }
                            }.padding(.horizontal, 14)
                            HStack {
                                Image(systemName: "minus.circle.fill")
                                Spacer()
                                Image(systemName: "hand.draw.fill")
                                    .font(.system(size: 22, weight: .bold))
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                            }
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(GR.orange)
                            .padding(.horizontal, 18)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { v in
                                    let delta = v.translation.width - dragAccum
                                    if abs(delta) >= 4 {
                                        let step = Int(delta / 4)
                                        appState.draftHeadCount = max(1, min(50_000,
                                            appState.draftHeadCount + step * 5))
                                        dragAccum = v.translation.width
                                    }
                                }
                                .onEnded { _ in dragAccum = 0 }
                        )
                    }
                    .frame(height: 64)

                    // Quick presets
                    HStack(spacing: 8) {
                        ForEach([25, 50, 100, 250, 500], id: \.self) { n in
                            GRChip(title: "\(n)", isSelected: appState.draftHeadCount == n) {
                                withAnimation(GR.spring) { appState.draftHeadCount = n }
                            }
                        }
                    }

                    GRCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PLACEMENT DATE").font(.gr(11, .bold)).foregroundColor(GR.textMuted)
                            DatePicker("", selection: $appState.draftPlacementDate,
                                       in: ...Date(), displayedComponents: .date)
                                .labelsHidden()
                                .accentColor(GR.orange)
                        }
                    }
                }
            })
    }
}

// MARK: - O3 · Target weight (vertical drag parallax)


extension FrondHand: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let leaf = pan.view else { return false }
        let move = pan.translation(in: leaf)
        let flick = pan.velocity(in: leaf)
        return move.x > 0 && abs(flick.x) > abs(flick.y)
    }
}

private struct TargetPage: View {
    @EnvironmentObject var appState: AppState
    @State private var dragY: CGFloat = 0

    private let minG = 1200.0, maxG = 4000.0

    private var norm: Double {
        (appState.draftTargetGrams - minG) / (maxG - minG)
    }

    var body: some View {
        OnbScaffold(
            tag: "3 / 4",
            title: "Target Weight",
            subtitle: "The live weight you'll grow to before slaughter. Drag up / down to set it.",
            scene: {
                ZStack {
                    // parallax layers driven by the target value
                    Circle().fill(GR.green.opacity(0.10))
                        .frame(width: 170, height: 170)
                        .offset(y: CGFloat(-norm * 24))
                    Circle().fill(GR.orange.opacity(0.10))
                        .frame(width: 120, height: 120)
                        .offset(y: CGFloat(norm * 18 - 8))
                    VStack(spacing: 2) {
                        Text(String(format: "%.2f", appState.draftTargetGrams / 1000))
                            .font(.system(size: 56, weight: .heavy, design: .rounded))
                            .foregroundColor(GR.green)
                        Text("kg live target").font(.gr(13, .semibold)).foregroundColor(GR.textSecondary)
                    }
                    .offset(y: CGFloat(-norm * 8))
                }
                .frame(height: 180)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { v in
                            let delta = v.translation.height - dragY
                            appState.draftTargetGrams = min(maxG, max(minG,
                                appState.draftTargetGrams - Double(delta) * 6))
                            dragY = v.translation.height
                        }
                        .onEnded { _ in dragY = 0 }
                )
            },
            content: {
                VStack(spacing: 14) {
                    Slider(value: $appState.draftTargetGrams, in: minG...maxG, step: 50)
                        .accentColor(GR.orange)
                    HStack(spacing: 8) {
                        ForEach([1800.0, 2200.0, 2500.0, 3000.0], id: \.self) { g in
                            GRChip(title: String(format: "%.1fkg", g / 1000),
                                   isSelected: abs(appState.draftTargetGrams - g) < 25) {
                                withAnimation(GR.spring) { appState.draftTargetGrams = g }
                            }
                        }
                    }
                    forecastCard
                }
            })
    }

    private var forecastCard: some View {
        let cross = CrossPreset.builtIn(id: appState.draftCrossId)
        let day = cross.standardDay(forWeight: appState.draftTargetGrams)
        return GRCard {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 22, weight: .bold)).foregroundColor(GR.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("At \(cross.name) standard").font(.gr(12, .semibold)).foregroundColor(GR.textSecondary)
                    if let d = day {
                        Text("≈ ready on day \(d)").font(.gr(17, .bold)).foregroundColor(GR.text)
                    } else {
                        Text("beyond the standard curve").font(.gr(15, .bold)).foregroundColor(GR.yellow)
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - O4 · Feed cost (press-and-hold steppers)

private struct FeedCostPage: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        OnbScaffold(
            tag: "4 / 4",
            title: "Feed Cost",
            subtitle: "Feed is most of the cost. Set its price and your currency to unlock FCR in money.",
            scene: {
                VStack(spacing: 4) {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 46, weight: .bold)).foregroundColor(GR.orange)
                    Text("\(appState.draftCurrency)\(String(format: "%.2f", appState.draftFeedPrice))")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundColor(GR.text)
                    Text("per kg of feed").font(.gr(13, .semibold)).foregroundColor(GR.textSecondary)
                }
                .frame(height: 170)
            },
            content: {
                VStack(spacing: 16) {
                    HStack(spacing: 14) {
                        HoldStepper(symbol: "minus") {
                            appState.draftFeedPrice = max(0.05, appState.draftFeedPrice - 0.05)
                        }
                        VStack(spacing: 0) {
                            Text(String(format: "%.2f", appState.draftFeedPrice))
                                .font(.gr(26, .heavy)).foregroundColor(GR.orange)
                            Text("hold to adjust").font(.gr(10)).foregroundColor(GR.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        HoldStepper(symbol: "plus") {
                            appState.draftFeedPrice = min(20, appState.draftFeedPrice + 0.05)
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: GR.radiusSmall).fill(GR.bg2))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("CURRENCY").font(.gr(11, .bold)).foregroundColor(GR.textMuted)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                            ForEach(AppState.commonCurrencies, id: \.self) { c in
                                GRChip(title: c, isSelected: appState.draftCurrency == c) {
                                    withAnimation(GR.spring) { appState.draftCurrency = c }
                                }
                            }
                        }
                    }
                }
            })
    }
}

// MARK: - Shared scaffold + helpers

private struct OnbScaffold<Scene: View, Content: View>: View {
    let tag: String
    let title: String
    let subtitle: String
    @ViewBuilder var scene: Scene
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text(tag).font(.gr(12, .bold)).foregroundColor(GR.orange)
                    .padding(.top, 50)
                scene.frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(GR.text)
                    Text(subtitle).font(.gr(15)).foregroundColor(GR.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
                Spacer(minLength: 130)
            }
            .padding(.horizontal, 24)
        }
    }
}

private struct BurstView: View {
    let trigger: Int
    @State private var animate = false
    var body: some View {
        ZStack {
            Circle().stroke(GR.orange, lineWidth: 3)
                .frame(width: 90, height: 90)
                .scaleEffect(animate ? 1.8 : 0.6)
                .opacity(animate ? 0 : 0.8)
            ForEach(0..<8, id: \.self) { i in
                Circle().fill(GR.yellow).frame(width: 8, height: 8)
                    .offset(x: animate ? cos(Double(i) / 8 * .pi * 2) * 80 : 0,
                            y: animate ? sin(Double(i) / 8 * .pi * 2) * 80 : 0)
                    .opacity(animate ? 0 : 1)
            }
        }
        .onChange(of: trigger) { _ in
            animate = false
            withAnimation(.easeOut(duration: 0.6)) { animate = true }
        }
    }
}

private struct HoldStepper: View {
    let symbol: String
    let action: () -> Void
    @State private var timer: Timer?

    var body: some View {
        Image(systemName: "\(symbol).circle.fill")
            .font(.system(size: 40, weight: .bold))
            .foregroundColor(GR.orange)
            .onTapGesture { action() }
            .onLongPressGesture(minimumDuration: 0.2, pressing: { pressing in
                if pressing {
                    timer?.invalidate()
                    timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                        action()
                    }
                } else {
                    timer?.invalidate(); timer = nil
                }
            }, perform: {})
    }
}
