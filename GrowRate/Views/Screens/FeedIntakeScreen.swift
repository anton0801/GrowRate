//
//  FeedIntakeScreen.swift  (06 · Feed Intake)
//  GrowRate
//

import SwiftUI

struct FeedIntakeScreen: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    let batchId: UUID
    @State private var showAdd = false
    @State private var stockOnHand = ""

    private var batch: Batch? { store.batch(batchId) }

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                if let b = batch {
                    VStack(spacing: 16) {
                        summary(b)
                        stockCard(b)
                        GRPrimaryButton(title: "Log feed", systemImage: "plus") { showAdd = true }
                        if b.feed.isEmpty {
                            EmptyState(systemImage: "bag", title: "No feed logged",
                                       message: "Record feed used so FCR and cost per kg stay accurate.")
                        } else {
                            SectionHeader(title: "Feed log", systemImage: "list.bullet")
                            ForEach(b.sortedFeed.reversed()) { f in feedRow(b, f) }
                        }
                    }
                    .padding(GR.pad).padding(.bottom, 90)
                } else {
                    EmptyState(systemImage: "questionmark", title: "Batch not found", message: "")
                }
            }
        }
        .navigationTitle("Feed Intake").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) {
            AddFeedSheet(batchId: batchId).environmentObject(store).environmentObject(appState)
        }
    }

    private func summary(_ b: Batch) -> some View {
        let dailyRate = b.currentDay > 0 ? b.cumulativeFeedKg / Double(b.currentDay) : 0
        let perBird = b.currentCount > 0 ? b.cumulativeFeedKg / Double(b.currentCount) : 0
        return GRCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Current phase: \(b.currentPhase.title)", systemImage: b.currentPhase.icon)
                HStack(spacing: 10) {
                    StatPill(title: "Total feed", value: String(format: "%.0f kg", b.cumulativeFeedKg), color: GR.orange, systemImage: "bag.fill")
                    StatPill(title: "Per day", value: String(format: "%.1f kg", dailyRate), color: GR.text)
                    StatPill(title: "Per bird", value: String(format: "%.2f kg", perBird), color: GR.green)
                }
            }
        }
    }

    private func stockCard(_ b: Batch) -> some View {
        let dailyRate = b.currentDay > 0 ? b.cumulativeFeedKg / Double(b.currentDay) : 0
        let stock = Double(stockOnHand) ?? 0
        let daysLeft = dailyRate > 0 ? stock / dailyRate : 0
        return GRCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Stock on hand", systemImage: "shippingbox.fill")
                GRTextField(title: "Feed in store", text: $stockOnHand, placeholder: "0",
                            keyboard: .decimalPad, suffix: "kg")
                if stock > 0 && dailyRate > 0 {
                    HStack {
                        Image(systemName: "clock.fill").foregroundColor(GR.green)
                        Text(String(format: "Lasts about %.0f day(s) at the current rate.", daysLeft))
                            .font(.gr(13, .semibold)).foregroundColor(GR.text)
                        Spacer()
                    }
                } else {
                    Text("Enter your stock to estimate how long it lasts.")
                        .font(.gr(11)).foregroundColor(GR.textMuted)
                }
            }
        }
    }

    private func feedRow(_ b: Batch, _ f: FeedEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: f.phase.icon).font(.system(size: 16)).foregroundColor(f.phase.color)
                .frame(width: 36, height: 36)
                .background(Circle().fill(f.phase.color.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.1f kg", f.amountKg)).font(.gr(16, .bold)).foregroundColor(GR.text)
                Text("\(f.phase.title) · \(shortDate(f.date))").font(.gr(12)).foregroundColor(GR.textSecondary)
            }
            Spacer()
            Button(action: { store.deleteFeed(f, from: b.id) }) {
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

struct AddFeedSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.presentationMode) private var presentationMode
    let batchId: UUID
    @State private var date = Date()
    @State private var amount = ""
    @State private var phase: FeedPhase = .starter
    @State private var notes = ""
    @State private var didSetPhase = false

    var body: some View {
        NavigationView {
            GRScreen {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        GRCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("DATE").font(.gr(11, .bold)).foregroundColor(GR.textMuted)
                                DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                                    .labelsHidden().accentColor(GR.orange)
                            }
                        }
                        GRTextField(title: "Amount", text: $amount, placeholder: "0",
                                    keyboard: .decimalPad, suffix: "kg")
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PHASE").font(.gr(11, .bold)).foregroundColor(GR.textMuted)
                            HStack(spacing: 8) {
                                ForEach(FeedPhase.allCases) { p in
                                    GRChip(title: p.title, isSelected: phase == p) { phase = p }
                                }
                            }
                        }
                        GRTextField(title: "Notes", text: $notes, placeholder: "Optional")
                        GRPrimaryButton(title: "Save feed", systemImage: "checkmark") { save() }
                    }
                    .padding(GR.pad).padding(.bottom, 30)
                }
            }
            .navigationTitle("Log Feed").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(GR.textSecondary) } }
        }
        .onAppear {
            if !didSetPhase, let b = store.batch(batchId) { phase = b.currentPhase; didSetPhase = true }
        }
    }

    private func save() {
        let v = Double(amount) ?? 0
        guard v > 0 else { dismiss(); return }
        store.addFeed(FeedEntry(date: date, amountKg: v, phase: phase, notes: notes), to: batchId)
        dismiss()
    }
    private func dismiss() { presentationMode.wrappedValue.dismiss() }
}
