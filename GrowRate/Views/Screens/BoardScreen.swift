//
//  BoardScreen.swift  (01 · Growth Board — main screen)
//  GrowRate
//

import SwiftUI

struct BoardScreen: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState

    @State private var showAddBatch = false
    @State private var goLogWeightID: UUID? = nil
    @State private var goFCRID: UUID? = nil

    private var active: [Batch] { store.activeBatches }
    private var firstActiveID: UUID? { active.first?.id }

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if store.batches.isEmpty {
                        EmptyState(systemImage: "chart.line.uptrend.xyaxis",
                                   title: "No batches yet",
                                   message: "Add your first batch of birds to start tracking growth, FCR and slaughter timing.")
                        GRPrimaryButton(title: "Add Batch", systemImage: "plus") { showAddBatch = true }
                            .padding(.horizontal, 4)
                    } else {
                        summaryCard
                        quickActions
                        ForEach(active) { b in
                            NavigationLink(destination: BatchDetailScreen(batchId: b.id)) {
                                BatchCard(batch: b)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        if !store.finishedBatches.isEmpty {
                            SectionHeader(title: "Finished", systemImage: "checkmark.seal.fill")
                                .padding(.top, 4)
                            ForEach(store.finishedBatches) { b in
                                NavigationLink(destination: BatchDetailScreen(batchId: b.id)) {
                                    BatchCard(batch: b)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    // Hidden navigation triggers for quick actions
                    navLinks
                }
                .padding(.horizontal, GR.pad)
                .padding(.top, 8)
                .padding(.bottom, 90)
            }
        }
        .navigationTitle("Growth Board").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddBatch = true }) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundColor(GR.orange)
                }
            }
        }
        .sheet(isPresented: $showAddBatch) {
            AddBatchScreen().environmentObject(store).environmentObject(appState)
        }
    }

    private var navLinks: some View {
        Group {
            NavigationLink(
                destination: goLogWeightID.map { WeightLogScreen(batchId: $0) },
                isActive: Binding(get: { goLogWeightID != nil },
                                  set: { if !$0 { goLogWeightID = nil } })
            ) { EmptyView() }.hidden()
            NavigationLink(
                destination: goFCRID.map { FCRScreen(batchId: $0) },
                isActive: Binding(get: { goFCRID != nil },
                                  set: { if !$0 { goFCRID = nil } })
            ) { EmptyView() }.hidden()
        }
    }

    private var summaryCard: some View {
        let totalBirds = active.reduce(0) { $0 + $1.currentCount }
        return GRCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Active flock").font(.gr(13, .semibold)).foregroundColor(GR.textSecondary)
                    Spacer()
                    Text("\(active.count) batch\(active.count == 1 ? "" : "es")")
                        .font(.gr(13, .bold)).foregroundColor(GR.orange)
                }
                HStack(spacing: 10) {
                    StatPill(title: "Birds", value: "\(totalBirds)", color: GR.orange, systemImage: "bird.fill")
                    StatPill(title: "Phase", value: active.first?.currentPhase.title ?? "—",
                             color: GR.green, systemImage: "leaf.fill")
                }
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            quickButton("Add Batch", "plus", GR.orange) { showAddBatch = true }
            quickButton("Log Weight", "scalemass.fill", GR.green) { goLogWeightID = firstActiveID }
            quickButton("FCR", "speedometer", GR.yellow) { goFCRID = firstActiveID }
        }
    }

    private func quickButton(_ title: String, _ icon: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundColor(color)
                Text(title).font(.gr(12, .semibold)).foregroundColor(GR.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: GR.radiusSmall).fill(GR.card))
            .overlay(RoundedRectangle(cornerRadius: GR.radiusSmall).stroke(GR.border, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(firstActiveID == nil && title != "Add Batch")
        .opacity((firstActiveID == nil && title != "Add Batch") ? 0.45 : 1)
    }
}

// MARK: - Batch card

struct BatchCard: View {
    @EnvironmentObject var appState: AppState
    let batch: Batch

    var body: some View {
        let g = GrowthEngine.analyze(batch)
        let fcr = FCREngine.analyze(batch)
        let cost = CostEngine.analyze(batch)
        let forecast = ForecastEngine.analyze(batch)
        let progress = batch.targetWeightGrams > 0 ? batch.latestAvgGrams / batch.targetWeightGrams : 0

        return GRCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(batch.name).font(.gr(18, .bold)).foregroundColor(GR.text)
                        Text("\(batch.cross.name) · day \(batch.currentDay) · \(batch.currentCount) birds")
                            .font(.gr(12)).foregroundColor(GR.textSecondary)
                    }
                    Spacer()
                    if batch.isSlaughtered {
                        StatusBadge(text: "Done", color: GR.text)
                    } else {
                        StatusBadge(text: g.status.short, color: g.status.color)
                    }
                }

                // progress to target
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(appState.weightString(grams: batch.latestAvgGrams))")
                            .font(.gr(13, .bold)).foregroundColor(GR.orange)
                        Spacer()
                        Text("target \(appState.weightString(grams: batch.targetWeightGrams))")
                            .font(.gr(11)).foregroundColor(GR.textMuted)
                    }
                    GRProgressBar(value: progress, color: progress >= 1 ? GR.green : GR.orange)
                }

                HStack(spacing: 8) {
                    miniStat("FCR", fcr.fcr > 0 ? String(format: "%.2f", fcr.fcr) : "—",
                             fcr.isBetterThanStandard ? GR.green : GR.orange)
                    miniStat("Gain/day", g.adgRecent > 0 ? "\(Int(g.adgRecent)) g" : "—", GR.text)
                    miniStat("Cost/kg", (batch.latestWeight != nil && cost.costPerKgLive > 0) ? appState.money(cost.costPerKgLive, currency: batch.currency) : "—", GR.text)
                }

                HStack(spacing: 6) {
                    Image(systemName: "calendar").font(.system(size: 12)).foregroundColor(GR.green)
                    Text(forecastText(forecast)).font(.gr(12, .semibold)).foregroundColor(GR.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(GR.textMuted)
                }
            }
        }
    }

    private func miniStat(_ t: String, _ v: String, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.gr(15, .heavy)).foregroundColor(c).lineLimit(1).minimumScaleFactor(0.6)
            Text(t).font(.gr(10, .semibold)).foregroundColor(GR.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(GR.bg2))
    }

    private func forecastText(_ f: ForecastResult) -> String {
        if batch.isSlaughtered { return "Slaughtered" }
        if f.alreadyReached { return "Target reached" }
        guard f.hasProjection, let date = f.targetDate else { return "Log a weight to forecast" }
        let df = DateFormatter(); df.dateFormat = "MMM d"
        return "Target ~\(df.string(from: date)) (day \(f.targetDay ?? 0))"
    }
}
