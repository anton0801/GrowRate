//
//  GrowthCurveScreen.swift  (04 · Growth Curve)
//  GrowRate
//

import SwiftUI

struct GrowthCurveScreen: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    let batchId: UUID

    private var batch: Batch? { store.batch(batchId) }

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                if let b = batch {
                    VStack(spacing: 16) {
                        chartCard(b)
                        statusCard(b)
                        deviationTable(b)
                    }
                    .padding(GR.pad)
                    .padding(.bottom, 90)
                } else {
                    EmptyState(systemImage: "questionmark", title: "Batch not found", message: "")
                }
            }
        }
        .navigationTitle("Growth Curve").navigationBarTitleDisplayMode(.inline)
    }

    private func maxDay(_ b: Batch) -> Int {
        let f = ForecastEngine.analyze(b)
        return max(b.currentDay, b.latestDay ?? 0, f.targetDay ?? 0, b.cross.typicalSlaughterDay) + 3
    }

    private func chartCard(_ b: Batch) -> some View {
        let f = ForecastEngine.analyze(b)
        let md = maxDay(b)
        var series: [ChartSeries] = []
        series.append(ChartSeries(points: b.cross.standardChartPoints(maxDay: md),
                                   color: GR.green))
        series.append(ChartSeries(points: b.weightChartPoints, color: GR.orange,
                                   showDots: true, fill: true))
        if f.hasProjection, !f.alreadyReached, let td = f.targetDay,
           let last = b.sortedWeights.last {
            series.append(ChartSeries(points: [
                ChartPoint(x: Double(b.day(for: last.date)), y: last.avgWeightGrams),
                ChartPoint(x: Double(td), y: b.targetWeightGrams)
            ], color: GR.orangeActive, dashed: true))
        }

        return GRCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Weight vs \(b.cross.name)", systemImage: "chart.xyaxis.line")
                LineChartView(series: series, targetY: b.targetWeightGrams, targetColor: GR.yellow,
                              yFormatter: { String(format: "%.1f", $0 / 1000) })
                    .frame(height: 220)
                ChartLegend(items: [("Standard", GR.green, false),
                                    ("Your flock", GR.orange, false),
                                    ("Projection", GR.orangeActive, true),
                                    ("Target", GR.yellow, true)])
                Text("Y axis in kg · X axis in days on feed")
                    .font(.gr(10)).foregroundColor(GR.textMuted)
            }
        }
    }

    private func statusCard(_ b: Batch) -> some View {
        let g = GrowthEngine.analyze(b)
        return GRCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: g.status.icon).font(.system(size: 26)).foregroundColor(g.status.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(g.status.title).font(.gr(17, .bold)).foregroundColor(GR.text)
                        if g.hasData {
                            Text("Day \(g.latestDay): \(Int(g.latestAvgGrams)) g vs standard \(Int(g.standardGrams)) g")
                                .font(.gr(12)).foregroundColor(GR.textSecondary)
                        } else {
                            Text("Log a weighing to compare with the standard.")
                                .font(.gr(12)).foregroundColor(GR.textSecondary)
                        }
                    }
                    Spacer()
                }
                if g.hasData {
                    HStack(spacing: 10) {
                        StatPill(title: "Gain/day (recent)", value: "\(Int(g.adgRecent)) g", color: GR.orange)
                        StatPill(title: "Gain/day (overall)", value: "\(Int(g.adgOverall)) g", color: GR.text)
                        StatPill(title: "Deviation",
                                 value: String(format: "%+.0f%%", g.deviationPercent * 100),
                                 color: g.status.color)
                    }
                }
            }
        }
    }

    private func deviationTable(_ b: Batch) -> some View {
        GRCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Per-weighing detail", systemImage: "tablecells")
                if b.sortedWeights.isEmpty {
                    Text("No weighings yet.").font(.gr(13)).foregroundColor(GR.textMuted)
                } else {
                    ForEach(b.sortedWeights.reversed()) { w in
                        let day = b.day(for: w.date)
                        let std = b.cross.standardWeight(day: day)
                        let dev = w.avgWeightGrams - std
                        HStack {
                            Text("Day \(day)").font(.gr(13, .semibold)).foregroundColor(GR.text)
                                .frame(width: 60, alignment: .leading)
                            Text("\(Int(w.avgWeightGrams)) g").font(.gr(13)).foregroundColor(GR.orange)
                            Spacer()
                            Text("std \(Int(std)) g").font(.gr(12)).foregroundColor(GR.textMuted)
                            Text(String(format: "%+.0f", dev)).font(.gr(13, .bold))
                                .foregroundColor(dev >= 0 ? GR.green : GR.yellow)
                                .frame(width: 54, alignment: .trailing)
                        }
                        if w.id != b.sortedWeights.first?.id {
                            Divider().background(GR.divider)
                        }
                    }
                }
            }
        }
    }
}
