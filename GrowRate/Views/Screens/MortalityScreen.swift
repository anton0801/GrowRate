//
//  MortalityScreen.swift  (10 · Mortality & Cull)
//  GrowRate
//

import SwiftUI

struct MortalityScreen: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    let batchId: UUID
    @State private var showAdd = false

    private var batch: Batch? { store.batch(batchId) }

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                if let b = batch {
                    VStack(spacing: 16) {
                        summary(b)
                        GRPrimaryButton(title: "Record loss", systemImage: "plus") { showAdd = true }
                        if b.mortality.isEmpty {
                            EmptyState(systemImage: "heart.text.square",
                                       title: "No losses recorded",
                                       message: "Log mortality and culls with a cause. The economics recalculate on the remaining birds.")
                        } else {
                            SectionHeader(title: "Records", systemImage: "list.bullet")
                            ForEach(b.sortedMortality.reversed()) { m in row(b, m) }
                        }
                    }
                    .padding(GR.pad).padding(.bottom, 90)
                } else {
                    EmptyState(systemImage: "questionmark", title: "Batch not found", message: "")
                }
            }
        }
        .navigationTitle("Mortality & Cull").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) {
            AddMortalitySheet(batchId: batchId).environmentObject(store)
        }
    }

    private func summary(_ b: Batch) -> some View {
        let cost = CostEngine.analyze(b)
        return GRCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    StatPill(title: "Placed", value: "\(b.initialCount)", color: GR.text)
                    StatPill(title: "Alive now", value: "\(b.currentCount)", color: GR.green)
                    StatPill(title: "Loss rate", value: String(format: "%.1f%%", b.mortalityRate * 100),
                             color: b.mortalityRate > 0.05 ? GR.red : GR.yellow)
                }
                HStack(spacing: 10) {
                    StatPill(title: "Deaths", value: "\(b.deathsTotal)", color: GR.red, systemImage: "xmark.circle.fill")
                    StatPill(title: "Culls", value: "\(b.cullsTotal)", color: GR.yellow, systemImage: "scissors")
                    StatPill(title: "Cost / bird", value: appState.money(cost.costPerBird, currency: b.currency), color: GR.orange)
                }
                Text("Fewer birds spread the same cost over less meat — cost per bird rises with every loss.")
                    .font(.gr(11)).foregroundColor(GR.textMuted)
            }
        }
    }

    private func row(_ b: Batch, _ m: MortalityEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: m.type.icon).font(.system(size: 16))
                .foregroundColor(m.type == .death ? GR.red : GR.yellow)
                .frame(width: 36, height: 36)
                .background(Circle().fill((m.type == .death ? GR.red : GR.yellow).opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(m.type.title) ×\(m.count)").font(.gr(15, .bold)).foregroundColor(GR.text)
                Text("\(shortDate(m.date))\(m.cause.isEmpty ? "" : " · \(m.cause)")")
                    .font(.gr(12)).foregroundColor(GR.textSecondary)
            }
            Spacer()
            Button(action: { store.deleteMortality(m, from: b.id) }) {
                Image(systemName: "trash").font(.system(size: 14)).foregroundColor(GR.red)
            }.buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: GR.radiusSmall).fill(GR.card))
        .overlay(RoundedRectangle(cornerRadius: GR.radiusSmall).stroke(GR.border, lineWidth: 1))
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d)
    }
}

struct AddMortalitySheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.presentationMode) private var presentationMode
    let batchId: UUID
    @State private var date = Date()
    @State private var count = "1"
    @State private var type: MortalityType = .death
    @State private var cause = ""

    var body: some View {
        NavigationView {
            GRScreen {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TYPE").font(.gr(11, .bold)).foregroundColor(GR.textMuted)
                            HStack(spacing: 8) {
                                ForEach(MortalityType.allCases) { t in
                                    GRChip(title: t.title, isSelected: type == t) { type = t }
                                }
                            }
                        }
                        GRCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("DATE").font(.gr(11, .bold)).foregroundColor(GR.textMuted)
                                DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                                    .labelsHidden().accentColor(GR.orange)
                            }
                        }
                        GRTextField(title: "Count", text: $count, placeholder: "1", keyboard: .numberPad)
                        GRTextField(title: "Cause", text: $cause, placeholder: "e.g. heat, leg issue, predator")
                        GRPrimaryButton(title: "Save record", systemImage: "checkmark") { save() }
                    }
                    .padding(GR.pad).padding(.bottom, 30)
                }
            }
            .navigationTitle("Record Loss").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(GR.textSecondary) } }
        }
    }

    private func save() {
        let n = Int(count) ?? 0
        guard n > 0 else { dismiss(); return }
        store.addMortality(MortalityEntry(date: date, count: n, type: type, cause: cause), to: batchId)
        dismiss()
    }
    private func dismiss() { presentationMode.wrappedValue.dismiss() }
}
