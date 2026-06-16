//
//  YieldScreen.swift  (11 · Yield & Sale)
//  GrowRate
//

import SwiftUI

struct YieldScreen: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    let batchId: UUID

    @State private var priceStr = ""
    @State private var dressedStr = ""
    @State private var loaded = false

    private var batch: Batch? { store.batch(batchId) }

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                if let b = batch {
                    VStack(spacing: 16) {
                        marginCard(b)
                        revenueCard(b)
                        detailCard(b)
                        inputCard(b)
                    }
                    .padding(GR.pad).padding(.bottom, 90)
                } else {
                    EmptyState(systemImage: "questionmark", title: "Batch not found", message: "")
                }
            }
        }
        .navigationTitle("Yield & Sale").navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded, let b = batch else { return }
            priceStr = b.salePricePerKgDressed > 0 ? trim(b.salePricePerKgDressed) : ""
            dressedStr = b.actualDressedWeightPerBirdGrams > 0 ? trim(b.actualDressedWeightPerBirdGrams) : ""
            loaded = true
        }
    }

    private func marginCard(_ b: Batch) -> some View {
        let y = YieldEngine.analyze(b)
        return GRCard {
            VStack(spacing: 10) {
                Image(systemName: y.isProfit ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    .font(.system(size: 34)).foregroundColor(y.isProfit ? GR.green : GR.red)
                Text(y.hasPrice ? appState.money(y.margin, currency: b.currency) : "—")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(y.isProfit ? GR.green : GR.red)
                Text(y.hasPrice ? "Batch margin" : "Set a dressed sale price below").font(.gr(13, .semibold)).foregroundColor(GR.textSecondary)
                if y.hasPrice {
                    StatusBadge(text: y.isProfit ? "Profit · \(appState.money(y.marginPerBird, currency: b.currency))/bird"
                                : "Loss · \(appState.money(y.marginPerBird, currency: b.currency))/bird",
                                color: y.isProfit ? GR.green : GR.red)
                }
            }
        }
    }

    private func revenueCard(_ b: Batch) -> some View {
        let y = YieldEngine.analyze(b)
        let maxV = max(y.revenue, y.totalCost, 1)
        return GRCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Revenue vs cost", systemImage: "chart.bar.fill")
                bar("Revenue", y.revenue, GR.green, maxV, b.currency)
                bar("Cost", y.totalCost, GR.orange, maxV, b.currency)
            }
        }
    }

    private func bar(_ t: String, _ v: Double, _ c: Color, _ maxV: Double, _ cur: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(t).font(.gr(13, .semibold)).foregroundColor(GR.text)
                Spacer()
                Text(appState.money(v, currency: cur)).font(.gr(13, .bold)).foregroundColor(c)
            }
            GRProgressBar(value: v / maxV, color: c, height: 10)
        }
    }

    private func detailCard(_ b: Batch) -> some View {
        let y = YieldEngine.analyze(b)
        return GRCard {
            VStack(spacing: 10) {
                infoRow("Dressing yield", String(format: "%.0f%%", y.dressingPercent * 100), GR.green)
                infoRow("Dressed / bird", String(format: "%.2f kg", y.dressedPerBirdKg), GR.text)
                infoRow("Total dressed", String(format: "%.0f kg", y.totalDressedKg), GR.text)
                infoRow("Break-even price", y.totalDressedKg > 0 ? appState.money(y.breakEvenPriceDressed, currency: b.currency) + " / kg" : "—", GR.orange)
            }
        }
    }

    private func inputCard(_ b: Batch) -> some View {
        GRCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Sale inputs", systemImage: "tag.fill")
                GRTextField(title: "Dressed sale price / kg", text: $priceStr, placeholder: "0",
                            keyboard: .decimalPad, suffix: b.currency)
                GRTextField(title: "Actual dressed weight / bird (optional)", text: $dressedStr,
                            placeholder: "\(Int(b.latestAvgGrams * b.cross.dressingPercent))",
                            keyboard: .decimalPad, suffix: "g")
                GRPrimaryButton(title: "Apply", systemImage: "checkmark") { apply(b) }
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

    private func apply(_ b: Batch) {
        var copy = b
        copy.salePricePerKgDressed = Double(priceStr) ?? 0
        copy.actualDressedWeightPerBirdGrams = Double(dressedStr) ?? 0
        store.updateBatch(copy)
    }

    private func trim(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.2f", v)
    }
}
