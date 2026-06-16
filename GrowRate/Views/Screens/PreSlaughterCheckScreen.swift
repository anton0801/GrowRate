//
//  PreSlaughterCheckScreen.swift  (14 · Pre-Slaughter Check)
//  GrowRate
//

import SwiftUI

struct PreSlaughterCheckScreen: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    let batchId: UUID

    @State private var checks: [Bool] = [false, false, false, false]

    private var batch: Batch? { store.batch(batchId) }
    private let items: [(String, String, String)] = [
        ("Feed withdrawal started", "Stop feed 8–12 h before slaughter so crops/guts empty (keeps carcass clean).", "clock.badge.exclamationmark"),
        ("Water still available", "Keep water during the fasting window to avoid dehydration and weight loss.", "drop.fill"),
        ("Transport / processing booked", "Crates, vehicle and processing slot organised for the day.", "box.truck.fill"),
        ("Buyer / market confirmed", "Know where the meat goes before you catch the birds.", "person.2.fill")
    ]

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                if let b = batch {
                    VStack(spacing: 16) {
                        gate(b)
                        weightCard(b)
                        ForEach(items.indices, id: \.self) { i in checkRow(i) }
                    }
                    .padding(GR.pad).padding(.bottom, 90)
                } else {
                    EmptyState(systemImage: "questionmark", title: "Batch not found", message: "")
                }
            }
        }
        .navigationTitle("Pre-Slaughter Check").navigationBarTitleDisplayMode(.inline)
    }

    private func weightReached(_ b: Batch) -> Bool { b.latestAvgGrams >= b.targetWeightGrams }

    private func gate(_ b: Batch) -> some View {
        let ready = weightReached(b) && checks.allSatisfy { $0 }
        return GRCard {
            VStack(spacing: 8) {
                Image(systemName: ready ? "checkmark.seal.fill" : "hourglass")
                    .font(.system(size: 34)).foregroundColor(ready ? GR.green : GR.yellow)
                Text(ready ? "Ready to slaughter" : "Not ready yet")
                    .font(.gr(20, .bold)).foregroundColor(ready ? GR.green : GR.text)
                Text(ready ? "Weight target met and all checks complete."
                     : "Complete the checklist below before catching the birds.")
                    .font(.gr(12)).foregroundColor(GR.textSecondary).multilineTextAlignment(.center)
            }
        }
    }

    private func weightCard(_ b: Batch) -> some View {
        let reached = weightReached(b)
        return GRCard {
            HStack(spacing: 12) {
                Image(systemName: reached ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24)).foregroundColor(reached ? GR.green : GR.textMuted)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Target weight reached").font(.gr(15, .bold)).foregroundColor(GR.text)
                    Text("\(appState.weightString(grams: b.latestAvgGrams)) of \(appState.weightString(grams: b.targetWeightGrams))")
                        .font(.gr(12)).foregroundColor(GR.textSecondary)
                }
                Spacer()
                StatusBadge(text: reached ? "Met" : "Below", color: reached ? GR.green : GR.yellow)
            }
        }
    }

    private func checkRow(_ i: Int) -> some View {
        Button(action: { withAnimation(GR.spring) { checks[i].toggle() } }) {
            HStack(spacing: 12) {
                Image(systemName: checks[i] ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24)).foregroundColor(checks[i] ? GR.green : GR.textMuted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(items[i].0).font(.gr(15, .bold)).foregroundColor(GR.text)
                    Text(items[i].1).font(.gr(12)).foregroundColor(GR.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: items[i].2).font(.system(size: 16)).foregroundColor(GR.orangeHi)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: GR.radiusSmall).fill(GR.card))
            .overlay(RoundedRectangle(cornerRadius: GR.radiusSmall)
                        .stroke(checks[i] ? GR.green : GR.border, lineWidth: checks[i] ? 2 : 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
