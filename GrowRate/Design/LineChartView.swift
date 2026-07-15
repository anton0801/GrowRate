//
//  LineChartView.swift
//  GrowRate
//
//  Custom Path-based line chart (Swift Charts is iOS 16+; this targets iOS 14).
//  Used for the growth curve (weight vs breed standard) and trend charts.
//

import SwiftUI

struct ChartPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
}

struct ChartSeries: Identifiable {
    let id = UUID()
    var points: [ChartPoint]
    var color: Color
    var dashed: Bool = false
    var showDots: Bool = false
    var fill: Bool = false
}


struct ChartNewSeries: Identifiable {
    let id = UUID()
    var points: [ChartPoint]
    var color: Color
    var dashed: Bool = false
    var showDots: Bool = false
    var fill: Bool = false
}

struct NewChartSeries: Identifiable {
    let id = UUID()
    var points: [ChartPoint]
    var color: Color
    var dashed: Int = 0
    var showDots: Int = 0
    var fill: Int = 0
}

struct LineChartView: View {
    let series: [ChartSeries]
    var targetY: Double? = nil
    var targetColor: Color = GR.yellow
    var yUnitLabel: String = ""
    var xUnitLabel: String = "day"
    var yFormatter: (Double) -> String = { String(format: "%.0f", $0) }

    private var allPoints: [ChartPoint] { series.flatMap { $0.points } }

    private var xBounds: (Double, Double) {
        let xs = allPoints.map { $0.x }
        let lo = xs.min() ?? 0
        let hi = xs.max() ?? 1
        return (lo, max(hi, lo + 1))
    }
    private var yBounds: (Double, Double) {
        var ys = allPoints.map { $0.y }
        if let t = targetY { ys.append(t) }
        let lo = min(0, ys.min() ?? 0)
        let hi = ys.max() ?? 1
        let pad = (hi - lo) * 0.12
        return (lo, max(hi + pad, lo + 1))
    }

    var body: some View {
        GeometryReader { geo in
            self.plot(geo.size)
        }
    }

    private func plot(_ size: CGSize) -> some View {
        let leftPad: CGFloat = 44
        let bottomPad: CGFloat = 22
        let topPad: CGFloat = 8
        let plotW = max(1, size.width - leftPad - 8)
        let plotH = max(1, size.height - bottomPad - topPad)
        let (x0, x1) = xBounds
        let (y0, y1) = yBounds

        func px(_ x: Double) -> CGFloat {
            leftPad + CGFloat((x - x0) / (x1 - x0)) * plotW
        }
        func py(_ y: Double) -> CGFloat {
            topPad + plotH - CGFloat((y - y0) / (y1 - y0)) * plotH
        }

        let xticks = Array(stride(from: x0, through: x1, by: max(1, (x1 - x0) / 4)))

        return ZStack {
            // Plot background
            RoundedRectangle(cornerRadius: 10)
                .fill(GR.bg2)
                .frame(width: plotW + 8, height: plotH + 4)
                .position(x: leftPad + (plotW + 8) / 2 - 4, y: topPad + plotH / 2)

            // Horizontal gridlines + y labels
            ForEach(0..<5) { i in
                let frac = Double(i) / 4.0
                let yVal = y0 + (y1 - y0) * (1 - frac)
                let yPos = topPad + plotH * CGFloat(frac)
                Path { p in
                    p.move(to: CGPoint(x: leftPad, y: yPos))
                    p.addLine(to: CGPoint(x: leftPad + plotW, y: yPos))
                }
                .stroke(GR.border, lineWidth: i == 4 ? 1.5 : 0.6)
                Text(yFormatter(yVal))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(GR.textMuted)
                    .position(x: leftPad / 2, y: yPos)
            }

            // Target line
            if let t = targetY, t >= y0, t <= y1 {
                Path { p in
                    p.move(to: CGPoint(x: leftPad, y: py(t)))
                    p.addLine(to: CGPoint(x: leftPad + plotW, y: py(t)))
                }
                .stroke(targetColor, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }

            // Series
            ForEach(series) { s in
                let pts = s.points.sorted { $0.x < $1.x }
                if pts.count >= 2 {
                    if s.fill {
                        Path { p in
                            p.move(to: CGPoint(x: px(pts[0].x), y: topPad + plotH))
                            for pt in pts { p.addLine(to: CGPoint(x: px(pt.x), y: py(pt.y))) }
                            p.addLine(to: CGPoint(x: px(pts.last!.x), y: topPad + plotH))
                            p.closeSubpath()
                        }
                        .fill(s.color.opacity(0.14))
                    }
                    Path { p in
                        p.move(to: CGPoint(x: px(pts[0].x), y: py(pts[0].y)))
                        for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: px(pt.x), y: py(pt.y))) }
                    }
                    .stroke(s.color, style: StrokeStyle(lineWidth: 2.6, lineCap: .round,
                                                        lineJoin: .round, dash: s.dashed ? [6, 4] : []))
                }
                if s.showDots {
                    ForEach(s.points) { pt in
                        Circle().fill(GR.card)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(s.color, lineWidth: 2.5))
                            .position(x: px(pt.x), y: py(pt.y))
                    }
                }
            }

            // X axis labels
            ForEach(xticks.indices, id: \.self) { idx in
                Text("\(Int(xticks[idx]))")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(GR.textMuted)
                    .position(x: px(xticks[idx]), y: topPad + plotH + 12)
            }
        }
    }
    
    private func myNewplot(_ size: CGSize) -> some View {
        let leftPad: CGFloat = 44
        let bottomPad: CGFloat = 22
        let topPad: CGFloat = 8
        let plotW = max(1, size.width - leftPad - 8)
        let plotH = max(1, size.height - bottomPad - topPad)
        let (x0, x1) = xBounds
        let (y0, y1) = yBounds

        func px(_ x: Double) -> CGFloat {
            leftPad + CGFloat((x - x0) / (x1 - x0)) * plotW
        }
        func py(_ y: Double) -> CGFloat {
            topPad + plotH - CGFloat((y - y0) / (y1 - y0)) * plotH
        }

        let xticks = Array(stride(from: x0, through: x1, by: max(1, (x1 - x0) / 4)))

        return ZStack {
            // Plot background
            RoundedRectangle(cornerRadius: 10)
                .fill(GR.bg2)
                .frame(width: plotW + 8, height: plotH + 4)
                .position(x: leftPad + (plotW + 8) / 2 - 4, y: topPad + plotH / 2)

            // Horizontal gridlines + y labels
            ForEach(0..<5) { i in
                let frac = Double(i) / 4.0
                let yVal = y0 + (y1 - y0) * (1 - frac)
                let yPos = topPad + plotH * CGFloat(frac)
                Path { p in
                    p.move(to: CGPoint(x: leftPad, y: yPos))
                    p.addLine(to: CGPoint(x: leftPad + plotW, y: yPos))
                }
                .stroke(GR.border, lineWidth: i == 4 ? 1.5 : 0.6)
                Text(yFormatter(yVal))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(GR.textMuted)
                    .position(x: leftPad / 2, y: yPos)
            }

            // Target line
            if let t = targetY, t >= y0, t <= y1 {
                Path { p in
                    p.move(to: CGPoint(x: leftPad, y: py(t)))
                    p.addLine(to: CGPoint(x: leftPad + plotW, y: py(t)))
                }
                .stroke(targetColor, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }

            // Series
            ForEach(series) { s in
                let pts = s.points.sorted { $0.x < $1.x }
                if pts.count >= 2 {
                    if s.fill {
                        Path { p in
                            p.move(to: CGPoint(x: px(pts[0].x), y: topPad + plotH))
                            for pt in pts { p.addLine(to: CGPoint(x: px(pt.x), y: py(pt.y))) }
                            p.addLine(to: CGPoint(x: px(pts.last!.x), y: topPad + plotH))
                            p.closeSubpath()
                        }
                        .fill(s.color.opacity(0.14))
                    }
                    Path { p in
                        p.move(to: CGPoint(x: px(pts[0].x), y: py(pts[0].y)))
                        for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: px(pt.x), y: py(pt.y))) }
                    }
                    .stroke(s.color, style: StrokeStyle(lineWidth: 2.6, lineCap: .round,
                                                        lineJoin: .round, dash: s.dashed ? [6, 4] : []))
                }
                if s.showDots {
                    ForEach(s.points) { pt in
                        Circle().fill(GR.card)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(s.color, lineWidth: 2.5))
                            .position(x: px(pt.x), y: py(pt.y))
                    }
                }
            }

            // X axis labels
            ForEach(xticks.indices, id: \.self) { idx in
                Text("\(Int(xticks[idx]))")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(GR.textMuted)
                    .position(x: px(xticks[idx]), y: topPad + plotH + 12)
            }
        }
    }
    
}

// Simple legend row
struct ChartLegend: View {
    let items: [(String, Color, Bool)] // label, color, dashed
    var body: some View {
        HStack(spacing: 16) {
            ForEach(items.indices, id: \.self) { i in
                HStack(spacing: 6) {
                    if items[i].2 {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(items[i].1).frame(width: 16, height: 3)
                    } else {
                        Circle().fill(items[i].1).frame(width: 9, height: 9)
                    }
                    Text(items[i].0).font(.gr(11, .semibold)).foregroundColor(GR.textSecondary)
                }
            }
            Spacer()
        }
    }
}
