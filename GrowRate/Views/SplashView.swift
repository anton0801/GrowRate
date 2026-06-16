//
//  SplashView.swift
//  GrowRate
//
//  Thematic launch animation: warm beige stage, a chick on a scale, a rising
//  orange weight curve drawing itself, floating feed grains, and a spring
//  title entrance — then a designed scale-up/fade exit.
//

import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void

    // Animation state flags
    @State private var isVisible = true
    @State private var bgIn = false
    @State private var glowPulse = false
    @State private var curveProgress: CGFloat = 0
    @State private var grainsRising = false
    @State private var chickBob = false
    @State private var logoIn = false
    @State private var titleIn = false
    @State private var exitScale: CGFloat = 1
    @State private var exitOpacity: Double = 1

    private let grainCount = 7

    var body: some View {
        ZStack {
            // Layer 1 — background gradient + pulsing warm glow
            GR.bgGradient.ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [GR.orangeGlow, .clear]),
                           center: .center, startRadius: 10,
                           endRadius: glowPulse ? 360 : 240)
                .scaleEffect(bgIn ? 1 : 0.6)
                .opacity(bgIn ? 1 : 0)
                .ignoresSafeArea()

            // Layer 2 — thematic midground (curve + grains + chick on scale)
            ZStack {
                // rising weight curve being drawn
                SplashCurve()
                    .trim(from: 0, to: curveProgress)
                    .stroke(GR.orange,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                    .frame(width: 220, height: 130)
                    .offset(y: -10)

                // floating feed grains
                ForEach(0..<grainCount, id: \.self) { i in
                    Circle()
                        .fill(i % 2 == 0 ? GR.orangeHi : GR.yellow)
                        .frame(width: 7, height: 7)
                        .offset(x: CGFloat(i - grainCount / 2) * 26,
                                y: grainsRising ? -90 : 70)
                        .opacity(grainsRising ? 0 : 0.9)
                        .animation(Animation.easeIn(duration: 1.6)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.18),
                                   value: grainsRising)
                }

                // chick on a scale
                ChickOnScale()
                    .frame(width: 150, height: 150)
                    .offset(y: 70)
                    .scaleEffect(chickBob ? 1.04 : 0.97)
                    .offset(y: chickBob ? -4 : 2)
            }
            .frame(width: 260, height: 260)
            .scaleEffect(bgIn ? 1 : 0.8)
            .opacity(bgIn ? 1 : 0)
            .offset(y: -30)

            // Layer 3 — logo + title entrance
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(GR.green)
                    .padding(14)
                    .background(Circle().fill(GR.card))
                    .shadow(color: GR.greenGlow, radius: 12, x: 0, y: 6)
                    .scaleEffect(logoIn ? 1 : 0.2)
                    .opacity(logoIn ? 1 : 0)
                    .padding(.bottom, 4)
                Text("Grow Rate")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundColor(GR.text)
                    .opacity(titleIn ? 1 : 0)
                    .offset(y: titleIn ? 0 : 16)
                Text("Weigh it, feed it, profit.")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(GR.orangeActive)
                    .opacity(titleIn ? 1 : 0)
                    .offset(y: titleIn ? 0 : 12)
                    .padding(.bottom, 70)
            }
        }
        .scaleEffect(exitScale)
        .opacity(exitOpacity)
        .onAppear { startSequence() }
        .onDisappear { stopAll() }
    }

    // MARK: Animation control

    private func startSequence() {
        guard isVisible else { return }

        // Phase 1 (0–0.6s): background builds in
        withAnimation(.easeOut(duration: 0.6)) { bgIn = true }

        // Continuous loops
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
            chickBob = true
        }
        // Phase 2 (0.6–1.4s): curve draws (repeating)
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            curveProgress = 1
        }
        grainsRising = true

        // Phase 3 (1.4–2.2s): logo + title spring in
        withAnimation(GR.spring.delay(1.4)) { logoIn = true }
        withAnimation(GR.spring.delay(1.7)) { titleIn = true }

        // Phase 4 (2.3–2.7s): designed exit (single coordinator, ≤2 levels)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            guard isVisible else { return }
            withAnimation(.easeIn(duration: 0.4)) {
                exitScale = 1.25
                exitOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                onFinish()
            }
        }
    }

    private func stopAll() {
        isVisible = false
        bgIn = false
        glowPulse = false
        curveProgress = 0
        grainsRising = false
        chickBob = false
        logoIn = false
        titleIn = false
    }
}

// MARK: - Rising curve shape

private struct SplashCurve: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: 0, y: h * 0.92))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.55),
                   control1: CGPoint(x: w * 0.22, y: h * 0.9),
                   control2: CGPoint(x: w * 0.33, y: h * 0.62))
        p.addCurve(to: CGPoint(x: w, y: h * 0.06),
                   control1: CGPoint(x: w * 0.7, y: h * 0.48),
                   control2: CGPoint(x: w * 0.82, y: h * 0.16))
        return p
    }
}

// MARK: - Chick on a scale (shape-built, SF-Symbol-free)

private struct ChickOnScale: View {
    var body: some View {
        ZStack {
            // scale platform
            VStack(spacing: 0) {
                Spacer()
                RoundedRectangle(cornerRadius: 6)
                    .fill(GR.bg3)
                    .frame(width: 120, height: 14)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(GR.border, lineWidth: 1))
                RoundedRectangle(cornerRadius: 3)
                    .fill(GR.textMuted)
                    .frame(width: 10, height: 22)
                RoundedRectangle(cornerRadius: 4)
                    .fill(GR.bg3)
                    .frame(width: 70, height: 10)
            }
            .frame(height: 150, alignment: .bottom)

            // chick body + head
            ZStack {
                Circle().fill(GR.orangeHi).frame(width: 64, height: 56)
                    .offset(x: -6, y: 6)
                Circle().fill(GR.orangeHi).frame(width: 40, height: 40)
                    .offset(x: 20, y: -18)
                // beak
                Triangle().fill(GR.orange)
                    .frame(width: 16, height: 12)
                    .rotationEffect(.degrees(90))
                    .offset(x: 42, y: -18)
                // eye
                Circle().fill(GR.text).frame(width: 6, height: 6)
                    .offset(x: 26, y: -22)
            }
            .offset(y: -22)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
