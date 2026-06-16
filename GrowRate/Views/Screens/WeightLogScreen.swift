//
//  WeightLogScreen.swift  (03 · Weight Log)
//  GrowRate
//

import SwiftUI

struct WeightLogScreen: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    let batchId: UUID
    @State private var showAdd = false

    private var batch: Batch? { store.batch(batchId) }

    var body: some View {
        GRScreen {
            if let b = batch {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        headerCard(b)
                        GRPrimaryButton(title: "Log a weighing", systemImage: "plus") { showAdd = true }

                        if b.weights.isEmpty {
                            EmptyState(systemImage: "scalemass",
                                       title: "No weighings",
                                       message: "Weigh a representative sample and log the average. Each point lands on the growth curve.")
                        } else {
                            SectionHeader(title: "Weighings", systemImage: "list.bullet")
                            ForEach(b.sortedWeights.reversed()) { w in
                                weightRow(b, w)
                            }
                        }
                    }
                    .padding(GR.pad)
                    .padding(.bottom, 90)
                }
            } else {
                EmptyState(systemImage: "questionmark", title: "Batch not found", message: "")
            }
        }
        .navigationTitle("Weight Log").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) {
            AddWeightSheet(batchId: batchId).environmentObject(store).environmentObject(appState)
        }
    }

    private func headerCard(_ b: Batch) -> some View {
        let g = GrowthEngine.analyze(b)
        return GRCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.name).font(.gr(16, .bold)).foregroundColor(GR.text)
                        Text("Day \(b.currentDay) · \(b.cross.name)")
                            .font(.gr(12)).foregroundColor(GR.textSecondary)
                    }
                    Spacer()
                    StatusBadge(text: g.status.short, color: g.status.color)
                }
                HStack(spacing: 10) {
                    StatPill(title: "Current avg", value: appState.weightString(grams: b.latestAvgGrams),
                             color: GR.orange, systemImage: "scalemass.fill")
                    StatPill(title: "vs standard",
                             value: g.hasData ? String(format: "%+.0f g", g.deviationGrams) : "—",
                             color: g.status.color, systemImage: "arrow.up.arrow.down")
                }
            }
        }
    }

    private func weightRow(_ b: Batch, _ w: WeightEntry) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text("\(b.day(for: w.date))").font(.gr(18, .heavy)).foregroundColor(GR.orange)
                Text("day").font(.gr(9, .semibold)).foregroundColor(GR.textMuted)
            }
            .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.weightString(grams: w.avgWeightGrams))
                    .font(.gr(16, .bold)).foregroundColor(GR.text)
                Text("\(shortDate(w.date)) · sample \(w.sampleSize)\(w.individualWeights.isEmpty ? "" : " · CV data")")
                    .font(.gr(11)).foregroundColor(GR.textSecondary)
                if !w.notes.isEmpty {
                    Text(w.notes).font(.gr(11)).foregroundColor(GR.textMuted).lineLimit(2)
                }
            }
            Spacer()
            Button(action: { store.deleteWeight(w, from: b.id) }) {
                Image(systemName: "trash").font(.system(size: 14)).foregroundColor(GR.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: GR.radiusSmall).fill(GR.card))
        .overlay(RoundedRectangle(cornerRadius: GR.radiusSmall).stroke(GR.border, lineWidth: 1))
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d)
    }
}

// MARK: - Add weighing sheet

struct AddWeightSheet: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) private var presentationMode
    let batchId: UUID

    enum Mode: String, CaseIterable { case average = "Average", individual = "Sample weights" }
    @State private var mode: Mode = .average
    @State private var date = Date()
    @State private var avgWeight = ""
    @State private var sampleSize = "10"
    @State private var notes = ""
    @State private var individuals: [String] = ["", "", ""]

    private var unit: WeightUnit { appState.weightUnit }

    var body: some View {
        NavigationView {
            GRScreen {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        Picker("", selection: $mode) {
                            ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(SegmentedPickerStyle())

                        GRCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("DATE").font(.gr(11, .bold)).foregroundColor(GR.textMuted)
                                DatePicker("", selection: $date, in: ...Date(),
                                           displayedComponents: .date)
                                    .labelsHidden().accentColor(GR.orange)
                            }
                        }

                        if mode == .average {
                            GRTextField(title: "Average weight", text: $avgWeight,
                                        placeholder: "0", keyboard: .decimalPad, suffix: unit.short)
                            GRTextField(title: "Sample size (birds)", text: $sampleSize,
                                        placeholder: "10", keyboard: .numberPad)
                        } else {
                            individualSection
                        }

                        GRTextField(title: "Notes", text: $notes, placeholder: "Optional")

                        GRPrimaryButton(title: "Save weighing", systemImage: "checkmark") { save() }
                    }
                    .padding(GR.pad)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Log Weighing").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(GR.textSecondary) } }
        }
    }

    private var individualSection: some View {
        let vals = individuals.compactMap { Double($0) }.filter { $0 > 0 }
        let avgG = vals.isEmpty ? 0 : vals.map { unit.grams(fromValue: $0) }.reduce(0, +) / Double(vals.count)
        return VStack(alignment: .leading, spacing: 10) {
            Text("INDIVIDUAL WEIGHTS (\(unit.short))").font(.gr(11, .bold)).foregroundColor(GR.textMuted)
            ForEach(individuals.indices, id: \.self) { i in
                HStack {
                    TextField("0", text: $individuals[i])
                        .keyboardType(.decimalPad)
                        .font(.gr(15, .semibold))
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(GR.bg2))
                    if individuals.count > 1 {
                        Button(action: { individuals.remove(at: i) }) {
                            Image(systemName: "minus.circle.fill").foregroundColor(GR.red)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
            }
            Button(action: { individuals.append("") }) {
                Label("Add bird", systemImage: "plus").font(.gr(13, .semibold)).foregroundColor(GR.orange)
            }
            GRCard {
                HStack {
                    Text("Computed average").font(.gr(13, .semibold)).foregroundColor(GR.textSecondary)
                    Spacer()
                    Text(appState.weightString(grams: avgG)).font(.gr(16, .heavy)).foregroundColor(GR.green)
                }
            }
            Text("Sample of \(vals.count) bird(s) · enables uniformity stats.")
                .font(.gr(11)).foregroundColor(GR.textMuted)
        }
    }

    private func save() {
        var entry: WeightEntry
        if mode == .individual {
            let vals = individuals.compactMap { Double($0) }.filter { $0 > 0 }
                .map { unit.grams(fromValue: $0) }
            guard !vals.isEmpty else { dismiss(); return }
            let avg = vals.reduce(0, +) / Double(vals.count)
            entry = WeightEntry(date: date, avgWeightGrams: avg, sampleSize: vals.count,
                                individualWeights: vals, notes: notes)
        } else {
            let v = Double(avgWeight) ?? 0
            guard v > 0 else { dismiss(); return }
            entry = WeightEntry(date: date, avgWeightGrams: unit.grams(fromValue: v),
                                sampleSize: Int(sampleSize) ?? 1, notes: notes)
        }
        store.addWeight(entry, to: batchId)
        dismiss()
    }

    private func dismiss() { presentationMode.wrappedValue.dismiss() }
}
