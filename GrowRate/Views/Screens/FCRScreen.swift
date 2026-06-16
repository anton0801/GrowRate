//
//  FCRScreen.swift  (05 · FCR Engine) + FCR tab overview
//  GrowRate
//

import SwiftUI

// MARK: - FCR tab overview (batch list)

struct FCROverviewScreen: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    explainer
                    if store.activeBatches.isEmpty {
                        EmptyState(systemImage: "speedometer", title: "No active batches",
                                   message: "Add a batch and log feed + weights to compute feed conversion.")
                    } else {
                        ForEach(store.activeBatches) { b in
                            NavigationLink(destination: FCRScreen(batchId: b.id)) {
                                fcrRow(b)
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(GR.pad).padding(.bottom, 90)
            }
        }
        .navigationTitle("FCR Engine").navigationBarTitleDisplayMode(.inline)
    }

    private var explainer: some View {
        GRCard {
            HStack(spacing: 12) {
                Image(systemName: "speedometer").font(.system(size: 24)).foregroundColor(GR.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Feed conversion ratio").font(.gr(15, .bold)).foregroundColor(GR.text)
                    Text("FCR = feed eaten ÷ live-weight gain. Lower is better — and cheaper.")
                        .font(.gr(12)).foregroundColor(GR.textSecondary)
                }
            }
        }
    }

    private func fcrRow(_ b: Batch) -> some View {
        let r = FCREngine.analyze(b)
        return GRCard {
            HStack(spacing: 14) {
                VStack(spacing: 0) {
                    Text(r.fcr > 0 ? String(format: "%.2f", r.fcr) : "—")
                        .font(.gr(22, .heavy)).foregroundColor(r.isBetterThanStandard ? GR.green : GR.orange)
                    Text("FCR").font(.gr(10, .semibold)).foregroundColor(GR.textMuted)
                }.frame(width: 60)
                VStack(alignment: .leading, spacing: 2) {
                    Text(b.name).font(.gr(16, .bold)).foregroundColor(GR.text)
                    Text("\(String(format: "%.0f", r.feedKg)) kg feed · standard \(String(format: "%.2f", r.standardFCR))")
                        .font(.gr(12)).foregroundColor(GR.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(GR.textMuted)
            }
        }
    }
}

// MARK: - FCR detail

struct FCRScreen: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    let batchId: UUID

    private var batch: Batch? { store.batch(batchId) }

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                if let b = batch {
                    VStack(spacing: 16) {
                        headline(b)
                        phaseCard(b)
                        if FCREngine.analyze(b).intervalFCRs.count >= 2 { trendCard(b) }
                        links(b)
                    }
                    .padding(GR.pad).padding(.bottom, 90)
                } else {
                    EmptyState(systemImage: "questionmark", title: "Batch not found", message: "")
                }
            }
        }
        .navigationTitle("FCR · \(batch?.name ?? "")").navigationBarTitleDisplayMode(.inline)
    }

    private func headline(_ b: Batch) -> some View {
        let r = FCREngine.analyze(b)
        return GRCard {
            VStack(spacing: 14) {
                Text(r.fcr > 0 ? String(format: "%.2f", r.fcr) : "—")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundColor(r.isBetterThanStandard ? GR.green : GR.orange)
                Text(r.fcr > 0 ? "kg feed per kg of live gain" : "Log feed and weight to compute FCR")
                    .font(.gr(13, .semibold)).foregroundColor(GR.textSecondary)
                if r.fcr > 0 {
                    HStack(spacing: 8) {
                        StatusBadge(text: r.isBetterThanStandard ? "Better than standard" : "Above standard",
                                    color: r.isBetterThanStandard ? GR.green : GR.yellow)
                        StatusBadge(text: String(format: "%@%.2f vs std", r.deltaVsStandard <= 0 ? "" : "+", r.deltaVsStandard),
                                    color: GR.textSecondary)
                    }
                }
                HStack(spacing: 10) {
                    StatPill(title: "Feed eaten", value: String(format: "%.0f kg", r.feedKg), color: GR.orange, systemImage: "bag.fill")
                    StatPill(title: "Live gain", value: String(format: "%.0f kg", r.gainKg), color: GR.green, systemImage: "arrow.up.right")
                    StatPill(title: "Std FCR", value: String(format: "%.2f", r.standardFCR), color: GR.text)
                }
            }
        }
    }

    private func phaseCard(_ b: Batch) -> some View {
        let r = FCREngine.analyze(b)
        return GRCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Feed by phase", systemImage: "chart.bar.fill")
                ForEach(r.phaseFeed) { pf in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: pf.phase.icon).foregroundColor(pf.phase.color).font(.system(size: 12))
                            Text(pf.phase.title).font(.gr(13, .semibold)).foregroundColor(GR.text)
                            Spacer()
                            Text(String(format: "%.1f kg (%.0f%%)", pf.kg, pf.percent * 100))
                                .font(.gr(12, .semibold)).foregroundColor(GR.textSecondary)
                        }
                        GRProgressBar(value: pf.percent, color: pf.phase.color, height: 8)
                    }
                }
            }
        }
    }

    private func trendCard(_ b: Batch) -> some View {
        let r = FCREngine.analyze(b)
        let pts = r.intervalFCRs.map { ChartPoint(x: Double($0.day), y: $0.fcr) }
        return GRCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Efficiency trend", systemImage: "waveform.path.ecg")
                LineChartView(series: [ChartSeries(points: pts, color: GR.orange, showDots: true, fill: true)],
                              targetY: r.standardFCR, targetColor: GR.green,
                              yFormatter: { String(format: "%.1f", $0) })
                    .frame(height: 160)
                ChartLegend(items: [("Interval FCR", GR.orange, false), ("Standard FCR", GR.green, true)])
                Text("Rising bars mean each extra kilo of gain is getting more expensive in feed.")
                    .font(.gr(11)).foregroundColor(GR.textMuted)
            }
        }
    }

    private func links(_ b: Batch) -> some View {
        VStack(spacing: 10) {
            NavigationLink(destination: FeedIntakeScreen(batchId: b.id)) {
                linkRow("Feed Intake", "bag.fill", "Daily feed, phases & remaining stock")
            }.buttonStyle(PlainButtonStyle())
            NavigationLink(destination: CostPerKgScreen(batchId: b.id)) {
                linkRow("Cost per Kg", "dollarsign.circle.fill", "Live & dressed cost breakdown")
            }.buttonStyle(PlainButtonStyle())
        }
    }

    private func linkRow(_ title: String, _ icon: String, _ sub: String) -> some View {
        GRCard {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(GR.orange).frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.gr(15, .bold)).foregroundColor(GR.text)
                    Text(sub).font(.gr(12)).foregroundColor(GR.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(GR.textMuted)
            }
        }
    }
}
