//
//  SlaughterForecastScreen.swift  (08 · Slaughter Forecast) + Forecast tab overview
//  GrowRate
//

import SwiftUI

// MARK: - Forecast tab overview

struct ForecastOverviewScreen: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if store.activeBatches.isEmpty {
                        EmptyState(systemImage: "calendar.badge.clock", title: "No active batches",
                                   message: "Add a batch and log weights to forecast the slaughter date and the point where feeding stops paying.")
                    } else {
                        ForEach(store.activeBatches) { b in
                            NavigationLink(destination: SlaughterForecastScreen(batchId: b.id)) {
                                row(b)
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(GR.pad).padding(.bottom, 90)
            }
        }
        .navigationTitle("Slaughter Forecast").navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ b: Batch) -> some View {
        let f = ForecastEngine.analyze(b)
        let df = DateFormatter(); df.dateFormat = "MMM d"
        return GRCard {
            HStack(spacing: 14) {
                Image(systemName: "flag.checkered").font(.system(size: 22)).foregroundColor(GR.green).frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(b.name).font(.gr(16, .bold)).foregroundColor(GR.text)
                    if f.alreadyReached {
                        Text("Target reached — ready to slaughter").font(.gr(12, .semibold)).foregroundColor(GR.green)
                    } else if f.hasProjection, let d = f.targetDate {
                        Text("Target ~\(df.string(from: d)) · day \(f.targetDay ?? 0)")
                            .font(.gr(12)).foregroundColor(GR.textSecondary)
                    } else {
                        Text("Log a weighing to project").font(.gr(12)).foregroundColor(GR.textMuted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(GR.textMuted)
            }
        }
    }
}

// MARK: - Forecast detail

struct SlaughterForecastScreen: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    let batchId: UUID

    private var batch: Batch? { store.batch(batchId) }

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                if let b = batch {
                    VStack(spacing: 16) {
                        targetCard(b)
                        optimumCard(b)
                        marginalCard(b)
                        noteCard(b)
                    }
                    .padding(GR.pad).padding(.bottom, 90)
                } else {
                    EmptyState(systemImage: "questionmark", title: "Batch not found", message: "")
                }
            }
        }
        .navigationTitle("Forecast · \(batch?.name ?? "")").navigationBarTitleDisplayMode(.inline)
    }

    private func targetCard(_ b: Batch) -> some View {
        let f = ForecastEngine.analyze(b)
        let df = DateFormatter(); df.dateStyle = .medium
        return GRCard {
            VStack(spacing: 12) {
                Image(systemName: f.alreadyReached ? "checkmark.seal.fill" : "calendar.badge.clock")
                    .font(.system(size: 34)).foregroundColor(GR.green)
                if f.alreadyReached {
                    Text("Target reached").font(.gr(20, .bold)).foregroundColor(GR.text)
                    Text("\(b.name) hit \(appState.weightString(grams: b.targetWeightGrams)) — ready to slaughter.")
                        .font(.gr(13)).foregroundColor(GR.textSecondary).multilineTextAlignment(.center)
                } else if f.hasProjection, let d = f.targetDate {
                    Text(df.string(from: d)).font(.gr(22, .heavy)).foregroundColor(GR.orange)
                    Text("Projected target date").font(.gr(13, .semibold)).foregroundColor(GR.textSecondary)
                    HStack(spacing: 10) {
                        StatPill(title: "In", value: "\(f.daysToTarget ?? 0) days", color: GR.green)
                        StatPill(title: "Day on feed", value: "\(f.targetDay ?? 0)", color: GR.text)
                        StatPill(title: "Rate", value: "\(Int(f.adgUsed)) g/d", color: GR.orange)
                    }
                } else {
                    Text("Not enough data").font(.gr(18, .bold)).foregroundColor(GR.text)
                    Text(f.note).font(.gr(13)).foregroundColor(GR.textSecondary).multilineTextAlignment(.center)
                }
            }
        }
    }

    private func optimumCard(_ b: Batch) -> some View {
        let f = ForecastEngine.analyze(b)
        return GRCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "When to stop feeding", systemImage: "exclamationmark.triangle.fill")
                HStack(spacing: 10) {
                    StatPill(title: "Growth plateau", value: "day \(f.plateauDay)", color: GR.yellow, systemImage: "tortoise.fill")
                    if let opt = f.optimalSlaughterDay {
                        StatPill(title: "Profit optimum", value: "day \(opt)", color: GR.green, systemImage: "checkmark.seal.fill")
                    } else {
                        StatPill(title: "Profit optimum", value: "set price", color: GR.textMuted, systemImage: "tag")
                    }
                }
                if b.marketPricePerKgLive <= 0 {
                    Text("Add a live sale price (Edit batch) to compute the day feeding stops paying.")
                        .font(.gr(11)).foregroundColor(GR.textMuted)
                } else {
                    Text(String(format: "Marginal cost of gain now ≈ %@ / kg vs live price %@ / kg.",
                                appState.money(f.marginalCostNow, currency: b.currency),
                                appState.money(b.marketPricePerKgLive, currency: b.currency)))
                        .font(.gr(11)).foregroundColor(GR.textSecondary)
                }
            }
        }
    }

    private func marginalCard(_ b: Batch) -> some View {
        let f = ForecastEngine.analyze(b)
        return GRCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Marginal cost of gain", systemImage: "chart.xyaxis.line")
                LineChartView(series: [ChartSeries(points: f.marginalCostSeries, color: GR.orange, fill: true)],
                              targetY: b.marketPricePerKgLive > 0 ? b.marketPricePerKgLive : nil,
                              targetColor: GR.red,
                              yFormatter: { String(format: "%.1f", $0) })
                    .frame(height: 170)
                ChartLegend(items: b.marketPricePerKgLive > 0
                            ? [("Cost / kg gain", GR.orange, false), ("Live price", GR.red, true)]
                            : [("Cost / kg gain", GR.orange, false)])
                Text("Each later day, the same kilo of gain costs more feed. Where the orange line crosses the live price, extra feeding loses money.")
                    .font(.gr(11)).foregroundColor(GR.textMuted)
            }
        }
    }

    private func noteCard(_ b: Batch) -> some View {
        let f = ForecastEngine.analyze(b)
        return GRCard {
            HStack(spacing: 10) {
                Image(systemName: "lightbulb.fill").foregroundColor(GR.yellow)
                Text(f.note).font(.gr(13)).foregroundColor(GR.text)
                Spacer()
            }
        }
    }
}
