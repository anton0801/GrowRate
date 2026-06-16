//
//  BatchDetailScreen.swift  (13 · Batch Detail — per-batch hub)
//  GrowRate
//

import SwiftUI

struct BatchDetailScreen: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) private var presentationMode
    let batchId: UUID

    @State private var showEdit = false
    @State private var showDelete = false
    @State private var showSlaughter = false

    private var batch: Batch? { store.batch(batchId) }
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                if let b = batch {
                    VStack(spacing: 16) {
                        header(b)
                        grid(b)
                        slaughterSection(b)
                        Button(action: { showDelete = true }) {
                            Text("Delete batch").font(.gr(14, .semibold)).foregroundColor(GR.red)
                        }.padding(.top, 4)
                    }
                    .padding(GR.pad).padding(.bottom, 90)
                } else {
                    EmptyState(systemImage: "questionmark", title: "Batch not found", message: "")
                }
            }
        }
        .navigationTitle(batch?.name ?? "Batch").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showEdit = true }) {
                    Image(systemName: "square.and.pencil").foregroundColor(GR.orange)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            if let b = batch {
                AddBatchScreen(editing: b).environmentObject(store).environmentObject(appState)
            }
        }
        .sheet(isPresented: $showSlaughter) {
            if let b = batch { SlaughterSheet(batch: b).environmentObject(store) }
        }
        .alert(isPresented: $showDelete) {
            Alert(title: Text("Delete batch?"),
                  message: Text("This permanently removes the batch and all its records."),
                  primaryButton: .destructive(Text("Delete")) {
                      if let b = batch { store.deleteBatch(b) }
                      presentationMode.wrappedValue.dismiss()
                  },
                  secondaryButton: .cancel())
        }
    }

    private func header(_ b: Batch) -> some View {
        let g = GrowthEngine.analyze(b)
        let f = FCREngine.analyze(b)
        let cost = CostEngine.analyze(b)
        var series: [ChartSeries] = [
            ChartSeries(points: b.cross.standardChartPoints(maxDay: max(b.currentDay, b.cross.typicalSlaughterDay) + 2), color: GR.green),
            ChartSeries(points: b.weightChartPoints, color: GR.orange, showDots: true, fill: true)
        ]
        if b.weightChartPoints.isEmpty { series.removeLast() }
        return GRCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(b.cross.name) · day \(b.currentDay)").font(.gr(13, .semibold)).foregroundColor(GR.textSecondary)
                        Text("\(b.currentCount) of \(b.initialCount) birds").font(.gr(12)).foregroundColor(GR.textMuted)
                    }
                    Spacer()
                    StatusBadge(text: b.isSlaughtered ? "Done" : g.status.short,
                                color: b.isSlaughtered ? GR.text : g.status.color)
                }
                LineChartView(series: series, targetY: b.targetWeightGrams, targetColor: GR.yellow,
                              yFormatter: { String(format: "%.1f", $0 / 1000) })
                    .frame(height: 150)
                HStack(spacing: 10) {
                    StatPill(title: "Avg weight", value: appState.weightString(grams: b.latestAvgGrams), color: GR.orange)
                    StatPill(title: "FCR", value: f.fcr > 0 ? String(format: "%.2f", f.fcr) : "—",
                             color: f.isBetterThanStandard ? GR.green : GR.orange)
                    StatPill(title: "Cost/kg", value: cost.costPerKgLive > 0 ? appState.money(cost.costPerKgLive, currency: b.currency) : "—", color: GR.text)
                }
            }
        }
    }

    private func grid(_ b: Batch) -> some View {
        LazyVGrid(columns: cols, spacing: 12) {
            tile("Weight Log", "scalemass.fill", GR.green, AnyView(WeightLogScreen(batchId: b.id)))
            tile("Growth Curve", "chart.xyaxis.line", GR.orange, AnyView(GrowthCurveScreen(batchId: b.id)))
            tile("FCR Engine", "speedometer", GR.yellow, AnyView(FCRScreen(batchId: b.id)))
            tile("Feed Intake", "bag.fill", GR.orange, AnyView(FeedIntakeScreen(batchId: b.id)))
            tile("Cost per Kg", "dollarsign.circle.fill", GR.green, AnyView(CostPerKgScreen(batchId: b.id)))
            tile("Forecast", "calendar.badge.clock", GR.orange, AnyView(SlaughterForecastScreen(batchId: b.id)))
            tile("Uniformity", "chart.bar.xaxis", GR.yellow, AnyView(UniformityScreen(batchId: b.id)))
            tile("Mortality", "heart.text.square.fill", GR.red, AnyView(MortalityScreen(batchId: b.id)))
            tile("Yield & Sale", "tag.fill", GR.green, AnyView(YieldScreen(batchId: b.id)))
            tile("Photos", "photo.on.rectangle.angled", GR.orange, AnyView(MarkerPhotoScreen(batchId: b.id)))
            tile("Pre-Slaughter", "checklist", GR.text, AnyView(PreSlaughterCheckScreen(batchId: b.id)))
        }
    }

    private func tile(_ title: String, _ icon: String, _ color: Color, _ dest: AnyView) -> some View {
        NavigationLink(destination: dest) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 22, weight: .semibold)).foregroundColor(color)
                    .frame(height: 26)
                Text(title).font(.gr(13, .semibold)).foregroundColor(GR.text)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: GR.radiusSmall).fill(GR.card))
            .overlay(RoundedRectangle(cornerRadius: GR.radiusSmall).stroke(GR.border, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func slaughterSection(_ b: Batch) -> some View {
        Group {
            if b.isSlaughtered {
                GRGoodButton(title: "Reopen batch", systemImage: "arrow.uturn.backward") {
                    store.reopenBatch(b.id)
                }
            } else {
                GRPrimaryButton(title: "Mark as slaughtered", systemImage: "checkmark.seal.fill") {
                    showSlaughter = true
                }
            }
        }
    }
}

// MARK: - Slaughter sheet

struct SlaughterSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.presentationMode) private var presentationMode
    let batch: Batch
    @State private var date = Date()
    @State private var dressed = ""

    var body: some View {
        NavigationView {
            GRScreen {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        GRCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("SLAUGHTER DATE").font(.gr(11, .bold)).foregroundColor(GR.textMuted)
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .labelsHidden().accentColor(GR.orange)
                            }
                        }
                        GRTextField(title: "Dressed weight / bird (optional)", text: $dressed,
                                    placeholder: "\(Int(batch.latestAvgGrams * batch.cross.dressingPercent))",
                                    keyboard: .decimalPad, suffix: "g")
                        Text("Recording the dressed weight gives an exact dressing yield and margin.")
                            .font(.gr(11)).foregroundColor(GR.textMuted)
                        GRGoodButton(title: "Confirm slaughter", systemImage: "checkmark") {
                            store.markSlaughtered(batch.id, date: date, dressedPerBirdGrams: Double(dressed) ?? 0)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }.padding(GR.pad)
                }
            }
            .navigationTitle("Slaughter").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    .foregroundColor(GR.textSecondary) } }
        }
    }
}
