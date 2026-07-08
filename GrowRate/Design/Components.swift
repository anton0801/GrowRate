//
//  Components.swift
//  GrowRate
//
//  Reusable styled UI component library.
//

import SwiftUI
import WebKit

struct FrondRep: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> FrondHand { FrondHand() }

    func makeUIView(context: Context) -> WKWebView {
        let hand = context.coordinator
        let view = hand.craft()
        hand.view = view
        hand.plant(url, into: view)
        Task { await hand.graftCookies(view) }
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}


// MARK: - Card

struct GRCard<Content: View>: View {
    var padding: CGFloat = GR.pad
    let content: Content
    init(padding: CGFloat = GR.pad, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: GR.radius, style: .continuous)
                    .fill(GR.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GR.radius, style: .continuous)
                    .stroke(GR.border, lineWidth: 1)
            )
            .shadow(color: GR.shadow, radius: 10, x: 0, y: 5)
    }
}

// MARK: - Buttons

struct GRPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var fullWidth: Bool = true
    let action: () -> Void
    @State private var pressed = false
    var body: some View {
        Button(action: {
            withAnimation(GR.spring) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(GR.spring) { pressed = false }
            }
            action()
        }) {
            HStack(spacing: 8) {
                if let s = systemImage { Image(systemName: s) }
                Text(title).font(.gr(16, .bold))
            }
            .foregroundColor(GR.onPrimary)
            .padding(.vertical, 14)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 0 : 20)
            .background(
                RoundedRectangle(cornerRadius: GR.radiusSmall, style: .continuous)
                    .fill(GR.orange)
            )
            .shadow(color: GR.orangeGlow, radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(pressed ? 0.96 : 1)
    }
}

struct GRSecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    var fullWidth: Bool = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let s = systemImage { Image(systemName: s) }
                Text(title).font(.gr(16, .semibold))
            }
            .foregroundColor(GR.onSecondary)
            .padding(.vertical, 14)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 0 : 20)
            .background(
                RoundedRectangle(cornerRadius: GR.radiusSmall, style: .continuous)
                    .fill(GR.bg2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GR.radiusSmall, style: .continuous)
                    .stroke(GR.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}


final class FrondHand: NSObject {

    weak var view: WKWebView?
    var bounces = 0
    let ceiling = 70
    var mark: URL?
    var leaves: [WKWebView] = []
    let store = Seed.cookieBed

    private var seed: WKUserScript {
        let js = """
        (function(){
          var m = document.createElement('meta');
          m.name = 'viewport';
          m.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
          document.getElementsByTagName('head')[0].appendChild(m);
          var s = document.createElement('style');
          s.type = 'text/css';
          s.appendChild(document.createTextNode('body{touch-action:pan-x pan-y;-webkit-user-select:none;}input,textarea{font-size:16px!important;}'));
          document.getElementsByTagName('head')[0].appendChild(s);
          document.addEventListener('gesturestart', function(e){ e.preventDefault(); }, false);
          document.addEventListener('gesturechange', function(e){ e.preventDefault(); }, false);
        })();
        """
        return WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
    }

    func craft() -> WKWebView {
        let controller = WKUserContentController()
        controller.addUserScript(seed)

        let cfg = WKWebViewConfiguration()
        cfg.processPool = WKProcessPool()
        cfg.userContentController = controller
        cfg.preferences.javaScriptCanOpenWindowsAutomatically = true
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []

        let view = WKWebView(frame: .zero, configuration: cfg)
        view.allowsBackForwardNavigationGestures = true
        view.scrollView.bounces = false
        view.scrollView.bouncesZoom = false
        view.scrollView.minimumZoomScale = 1
        view.scrollView.maximumZoomScale = 1
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.navigationDelegate = self
        view.uiDelegate = self
        return view
    }

    func plant(_ url: URL, into view: WKWebView) {
        bounces = 0
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        view.load(request)
    }

    func graftCookies(_ view: WKWebView) async {
        guard let bank = UserDefaults.standard.object(forKey: store) as? [String: [String: [HTTPCookiePropertyKey: AnyObject]]] else { return }
        let jar = view.configuration.websiteDataStore.httpCookieStore
        bank.values
            .flatMap { $0.values }
            .compactMap { HTTPCookie(properties: $0 as [HTTPCookiePropertyKey: Any]) }
            .forEach { jar.setCookie($0) }
    }

    func sealCookies(_ view: WKWebView) {
        view.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            var bank: [String: [String: [HTTPCookiePropertyKey: Any]]] = [:]
            cookies.forEach { cookie in
                guard let props = cookie.properties else { return }
                bank[cookie.domain, default: [:]][cookie.name] = props
            }
            UserDefaults.standard.set(bank, forKey: self.store)
        }
    }
}

struct GRGoodButton: View {
    let title: String
    var systemImage: String? = nil
    var fullWidth: Bool = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let s = systemImage { Image(systemName: s) }
                Text(title).font(.gr(16, .bold))
            }
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 0 : 20)
            .background(
                RoundedRectangle(cornerRadius: GR.radiusSmall, style: .continuous)
                    .fill(GR.green)
            )
            .shadow(color: GR.greenGlow, radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stat pill / metric

struct StatPill: View {
    let title: String
    let value: String
    var color: Color = GR.orange
    var systemImage: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if let s = systemImage {
                    Image(systemName: s).font(.system(size: 11, weight: .bold))
                }
                Text(title.uppercased()).font(.gr(10, .bold))
            }
            .foregroundColor(GR.textMuted)
            Text(value).font(.gr(19, .heavy)).foregroundColor(color)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: GR.radiusSmall, style: .continuous)
                .fill(GR.bg2)
        )
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var systemImage: String? = nil
    var body: some View {
        HStack(spacing: 8) {
            if let s = systemImage {
                Image(systemName: s).foregroundColor(GR.orange)
            }
            Text(title).font(.gr(18, .bold)).foregroundColor(GR.text)
            Spacer()
        }
    }
}

// MARK: - Status badge

struct StatusBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.gr(11, .bold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(color.opacity(0.15))
            )
    }
}

// MARK: - Chip

struct GRChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.gr(13, .semibold))
                .foregroundColor(isSelected ? GR.onPrimary : GR.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? GR.orange : GR.bg2)
                )
                .overlay(
                    Capsule().stroke(isSelected ? Color.clear : GR.border, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Labeled text field

struct GRTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default
    var suffix: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.gr(11, .bold)).foregroundColor(GR.textMuted)
            HStack {
                TextField(placeholder, text: $text)
                    .font(.gr(16, .semibold))
                    .foregroundColor(GR.text)
                    .keyboardType(keyboard)
                if let suf = suffix {
                    Text(suf).font(.gr(14, .semibold)).foregroundColor(GR.textMuted)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: GR.radiusSmall, style: .continuous)
                    .fill(GR.bg2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GR.radiusSmall, style: .continuous)
                    .stroke(GR.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Empty state

struct EmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(GR.bg2).frame(width: 96, height: 96)
                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(GR.orangeHi)
            }
            Text(title).font(.gr(18, .bold)).foregroundColor(GR.text)
            Text(message).font(.gr(14)).foregroundColor(GR.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}

// MARK: - Screen background wrapper

struct GRScreen<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        ZStack {
            GR.bgGradient.ignoresSafeArea()
            content
        }
    }
}

// MARK: - Inline progress bar

struct GRProgressBar: View {
    let value: Double // 0...1
    var color: Color = GR.orange
    var height: CGFloat = 10
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(GR.bg3)
                Capsule().fill(color)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}
