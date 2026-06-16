//
//  CostPerKgScreen.swift  (07 · Cost per Kg)
//  GrowRate
//

import SwiftUI

struct CostPerKgScreen: View {
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
                        breakdown(b)
                        details(b)
                    }
                    .padding(GR.pad).padding(.bottom, 90)
                } else {
                    EmptyState(systemImage: "questionmark", title: "Batch not found", message: "")
                }
            }
        }
        .navigationTitle("Cost per Kg").navigationBarTitleDisplayMode(.inline)
    }

    private func headline(_ b: Batch) -> some View {
        let c = CostEngine.analyze(b)
        return GRCard {
            HStack(spacing: 12) {
                costBlock("Live weight", c.costPerKgLive, GR.orange, b.currency)
                Rectangle().fill(GR.divider).frame(width: 1, height: 56)
                costBlock("Dressed weight", c.costPerKgDressed, GR.green, b.currency)
            }
        }
    }

    private func costBlock(_ title: String, _ value: Double, _ color: Color, _ cur: String) -> some View {
        VStack(spacing: 4) {
            Text(value > 0 ? appState.money(value, currency: cur) : "—")
                .font(.gr(26, .heavy)).foregroundColor(color)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(title).font(.gr(12, .semibold)).foregroundColor(GR.textSecondary)
            Text("per kg").font(.gr(10)).foregroundColor(GR.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func breakdown(_ b: Batch) -> some View {
        let c = CostEngine.analyze(b)
        let rows: [(String, Double, Color, String)] = [
            ("Feed", c.feedCost, GR.orange, "bag.fill"),
            ("Chicks", c.chickCost, GR.yellow, "bird.fill"),
            ("Other", c.otherCost, GR.textSecondary, "wrench.and.screwdriver.fill")
        ]
        return GRCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Cost breakdown", systemImage: "chart.pie.fill")
                ForEach(rows.indices, id: \.self) { i in
                    let r = rows[i]
                    let share = c.totalCost > 0 ? r.1 / c.totalCost : 0
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: r.3).font(.system(size: 12)).foregroundColor(r.2)
                            Text(r.0).font(.gr(13, .semibold)).foregroundColor(GR.text)
                            Spacer()
                            Text("\(appState.money(r.1, currency: b.currency)) · \(Int(share * 100))%")
                                .font(.gr(12, .semibold)).foregroundColor(GR.textSecondary)
                        }
                        GRProgressBar(value: share, color: r.2, height: 8)
                    }
                }
                Divider().background(GR.divider)
                HStack {
                    Text("Total cost").font(.gr(15, .bold)).foregroundColor(GR.text)
                    Spacer()
                    Text(appState.money(c.totalCost, currency: b.currency))
                        .font(.gr(18, .heavy)).foregroundColor(GR.orange)
                }
            }
        }
    }

    private func details(_ b: Batch) -> some View {
        let c = CostEngine.analyze(b)
        return GRCard {
            VStack(alignment: .leading, spacing: 10) {
                infoRow("Feed is", String(format: "%.0f%% of cost", c.feedCostShare * 100),
                        c.feedCostShare > 0.6 ? GR.orange : GR.green)
                infoRow("Live mass now", String(format: "%.0f kg", c.liveMassKg), GR.text)
                infoRow("Dressing yield", String(format: "%.0f%%", c.dressingPercent * 100), GR.green)
                infoRow("Cost per bird", appState.money(c.costPerBird, currency: b.currency), GR.text)
            }
        }
    }

    private func infoRow(_ l: String, _ v: String, _ c: Color) -> some View {
        HStack {
            Text(l).font(.gr(13)).foregroundColor(GR.textSecondary)
            Spacer()
            Text(v).font(.gr(14, .bold)).foregroundColor(c)
        }
    }
}
