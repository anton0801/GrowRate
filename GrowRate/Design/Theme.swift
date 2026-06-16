//
//  Theme.swift
//  GrowRate
//
//  Design system: palette, gradients, typography, spacing.
//  Light, beige-orange dominant; green = efficiency / on-track.
//

import SwiftUI

// MARK: - Color from hex

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r, g, b, a: Double
        switch s.count {
        case 8: // RRGGBBAA
            r = Double((rgb & 0xFF000000) >> 24) / 255
            g = Double((rgb & 0x00FF0000) >> 16) / 255
            b = Double((rgb & 0x0000FF00) >> 8) / 255
            a = Double(rgb & 0x000000FF) / 255
        default: // RRGGBB
            r = Double((rgb & 0xFF0000) >> 16) / 255
            g = Double((rgb & 0x00FF00) >> 8) / 255
            b = Double(rgb & 0x0000FF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Palette

enum GR {
    /// Scheme-adaptive color: warm light palette by default, warm dark palette
    /// in dark mode. Accent colors stay constant across schemes.
    private static func dyn(_ light: String, _ dark: String) -> Color {
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }

    // Backgrounds
    static let bg = dyn("FBF5EA", "17140F")
    static let bg2 = dyn("F4E9D4", "201C15")
    static let bg3 = dyn("ECDFC3", "2A251C")

    // Cards
    static let card = dyn("FFFFFF", "26221A")
    static let cardHover = dyn("FBF5EA", "2E2920")
    static let border = dyn("E8DABC", "3B3528")
    static let divider = dyn("EFE3C8", "332E24")

    // Primary (orange — growth / meat)
    static let orange = Color(hex: "EE7B22")
    static let orangeActive = Color(hex: "CF6612")
    static let orangeHi = Color(hex: "F8A45A")

    // Second accent (green — efficiency / on-track)
    static let green = Color(hex: "4FB36B")
    static let greenHi = Color(hex: "7FD49A")

    // Third accent (yellow — attention / plateau)
    static let yellow = Color(hex: "F5B400")

    // Loss / mortality
    static let red = Color(hex: "E5484D")

    // Text
    static let text = dyn("3A2C10", "F3E9D6")
    static let textSecondary = dyn("6E5A2C", "C7B790")
    static let textMuted = dyn("A89464", "8C7E5A")

    // Button text
    static let onPrimary = Color(hex: "381B04")          // on orange — readable in both schemes
    static let onSecondary = dyn("4A3514", "ECDFC0")

    // Effects
    static let orangeGlow = Color(hex: "EE7B22").opacity(0.24)
    static let greenGlow = Color(hex: "4FB36B").opacity(0.20)
    static let shadow = Color(hex: "785A1E").opacity(0.10)

    // Gradients
    static var bgGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [bg, bg2]),
                       startPoint: .top, endPoint: .bottom)
    }
    static var orangeGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [orangeHi, orange]),
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var greenGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [greenHi, green]),
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Spacing
    static let pad: CGFloat = 16
    static let radius: CGFloat = 18
    static let radiusSmall: CGFloat = 12

    // Standard spring
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.7)
}

// MARK: - Typography (system rounded, weighted)

extension Font {
    static func gr(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static let grLargeTitle = Font.system(size: 30, weight: .heavy, design: .rounded)
    static let grTitle = Font.system(size: 22, weight: .bold, design: .rounded)
    static let grHeadline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let grBody = Font.system(size: 15, weight: .regular, design: .rounded)
    static let grCaption = Font.system(size: 12, weight: .medium, design: .rounded)
    static let grNumber = Font.system(size: 26, weight: .heavy, design: .rounded)
}
