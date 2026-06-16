//
//  HistoryScreen.swift  (16 · History)
//  GrowRate
//

import SwiftUI

struct HistoryScreen: View {
    @EnvironmentObject var store: DataStore

    enum Filter: String, CaseIterable { case all = "All", weighed = "Weighed", feed = "Feed", losses = "Losses" }
    @State private var filter: Filter = .all

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    HStack(spacing: 8) {
                        ForEach(Filter.allCases, id: \.self) { f in
                            GRChip(title: f.rawValue, isSelected: filter == f) { filter = f }
                        }
                        Spacer()
                    }

                    let events = filtered()
                    if events.isEmpty {
                        EmptyState(systemImage: "clock", title: "No activity yet",
                                   message: "Placements, weighings, feed phases and losses appear here as a timeline.")
                    } else {
                        ForEach(events) { e in row(e) }
                    }
                }
                .padding(GR.pad).padding(.bottom, 90)
            }
        }
        .navigationTitle("History").navigationBarTitleDisplayMode(.inline)
    }

    private func filtered() -> [HistoryEvent] {
        let all = store.globalHistory()
        switch filter {
        case .all: return all
        case .weighed: return all.filter { $0.kind == .weighed }
        case .feed: return all.filter { $0.kind == .feed }
        case .losses: return all.filter { $0.kind == .mortality }
        }
    }

    private func row(_ e: HistoryEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: e.icon).font(.system(size: 16)).foregroundColor(e.color)
                .frame(width: 38, height: 38)
                .background(Circle().fill(e.color.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(e.title).font(.gr(15, .bold)).foregroundColor(GR.text)
                Text("\(e.batchName) · \(e.detail)").font(.gr(12)).foregroundColor(GR.textSecondary)
            }
            Spacer()
            Text(shortDate(e.date)).font(.gr(11, .semibold)).foregroundColor(GR.textMuted)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: GR.radiusSmall).fill(GR.card))
        .overlay(RoundedRectangle(cornerRadius: GR.radiusSmall).stroke(GR.border, lineWidth: 1))
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d)
    }
}
