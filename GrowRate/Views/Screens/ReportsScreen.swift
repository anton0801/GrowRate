//
//  ReportsScreen.swift  (15 · Reports) + report detail + export helpers
//  GrowRate
//

import SwiftUI
import UIKit

struct ReportsScreen: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    NavigationLink(destination: HistoryScreen()) {
                        GRCard {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath").font(.system(size: 20)).foregroundColor(GR.orange).frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Activity history").font(.gr(15, .bold)).foregroundColor(GR.text)
                                    Text("Every placement, weighing, feed phase & loss").font(.gr(12)).foregroundColor(GR.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(GR.textMuted)
                            }
                        }
                    }.buttonStyle(PlainButtonStyle())

                    if store.batches.isEmpty {
                        EmptyState(systemImage: "doc.text", title: "No reports yet",
                                   message: "Add a batch to generate growth, FCR, cost and margin reports.")
                    } else {
                        SectionHeader(title: "Batch reports", systemImage: "doc.text.fill")
                        ForEach(store.batches) { b in
                            NavigationLink(destination: ReportDetailScreen(batchId: b.id)) {
                                reportRow(b)
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(GR.pad).padding(.bottom, 90)
            }
        }
        .navigationTitle("Reports").navigationBarTitleDisplayMode(.inline)
    }

    private func reportRow(_ b: Batch) -> some View {
        let fcr = FCREngine.analyze(b)
        let cost = CostEngine.analyze(b)
        return GRCard {
            HStack(spacing: 12) {
                Image(systemName: b.isSlaughtered ? "checkmark.seal.fill" : "leaf.fill")
                    .font(.system(size: 20)).foregroundColor(b.isSlaughtered ? GR.green : GR.orange).frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(b.name).font(.gr(16, .bold)).foregroundColor(GR.text)
                    Text("FCR \(fcr.fcr > 0 ? String(format: "%.2f", fcr.fcr) : "—") · cost \(appState.money(cost.totalCost, currency: b.currency))")
                        .font(.gr(12)).foregroundColor(GR.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(GR.textMuted)
            }
        }
    }
}

// MARK: - Report detail

struct ReportDetailScreen: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    let batchId: UUID

    @State private var shareItems: [Any] = []
    @State private var showShare = false

    private var batch: Batch? { store.batch(batchId) }

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                if let b = batch {
                    let g = GrowthEngine.analyze(b)
                    let fcr = FCREngine.analyze(b)
                    let cost = CostEngine.analyze(b)
                    let yield = YieldEngine.analyze(b)
                    VStack(spacing: 16) {
                        GRCard {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeader(title: "Growth", systemImage: "chart.xyaxis.line")
                                line("Day on feed", "\(b.currentDay)")
                                line("Average weight", appState.weightString(grams: b.latestAvgGrams))
                                line("Gain / day", g.hasData ? "\(Int(g.adgRecent)) g" : "—")
                                line("Status", g.status.title)
                            }
                        }
                        GRCard {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeader(title: "Feed & FCR", systemImage: "speedometer")
                                line("Total feed", String(format: "%.0f kg", fcr.feedKg))
                                line("FCR", fcr.fcr > 0 ? String(format: "%.2f", fcr.fcr) : "—")
                                line("Standard FCR", String(format: "%.2f", fcr.standardFCR))
                            }
                        }
                        GRCard {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeader(title: "Economics", systemImage: "dollarsign.circle.fill")
                                line("Total cost", appState.money(cost.totalCost, currency: b.currency))
                                line("Cost / kg live", appState.money(cost.costPerKgLive, currency: b.currency))
                                line("Cost / kg dressed", appState.money(cost.costPerKgDressed, currency: b.currency))
                                line("Dressing yield", String(format: "%.0f%%", yield.dressingPercent * 100))
                                if yield.hasPrice {
                                    line("Revenue", appState.money(yield.revenue, currency: b.currency))
                                    line("Margin", appState.money(yield.margin, currency: b.currency))
                                }
                            }
                        }
                        GRPrimaryButton(title: "Export PDF", systemImage: "doc.richtext") {
                            if let url = ReportExport.pdf(b, appState: appState) { present([url]) }
                        }
                        GRSecondaryButton(title: "Export CSV", systemImage: "tablecells") {
                            if let url = ReportExport.csv(b, store: store) { present([url]) }
                        }
                    }
                    .padding(GR.pad).padding(.bottom, 90)
                } else {
                    EmptyState(systemImage: "questionmark", title: "Batch not found", message: "")
                }
            }
        }
        .navigationTitle("Report").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) { ShareSheet(items: shareItems) }
    }

    private func line(_ l: String, _ v: String) -> some View {
        HStack {
            Text(l).font(.gr(13)).foregroundColor(GR.textSecondary)
            Spacer()
            Text(v).font(.gr(14, .bold)).foregroundColor(GR.text)
        }
    }

    private func present(_ items: [Any]) { shareItems = items; showShare = true }
}

// MARK: - Export helpers

enum ReportExport {
    static func csv(_ b: Batch, store: DataStore) -> URL? {
        let text = store.csv(for: b)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GrowRate-\(safe(b.name)).csv")
        do { try text.write(to: url, atomically: true, encoding: .utf8); return url }
        catch { return nil }
    }

    static func pdf(_ b: Batch, appState: AppState) -> URL? {
        let g = GrowthEngine.analyze(b)
        let fcr = FCREngine.analyze(b)
        let cost = CostEngine.analyze(b)
        let yield = YieldEngine.analyze(b)
        let df = DateFormatter(); df.dateStyle = .medium

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GrowRate-\(safe(b.name)).pdf")

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .heavy),
            .foregroundColor: UIColor.white]
        let headAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .bold),
            .foregroundColor: UIColor(red: 0.93, green: 0.48, blue: 0.13, alpha: 1)]
        let keyAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.darkGray]
        let valAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.black]

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                let c = ctx.cgContext
                // header band
                c.setFillColor(UIColor(red: 0.93, green: 0.48, blue: 0.13, alpha: 1).cgColor)
                c.fill(CGRect(x: 0, y: 0, width: 595, height: 80))
                "Grow Rate — Batch Report".draw(at: CGPoint(x: 40, y: 28), withAttributes: titleAttr)

                var y: CGFloat = 110
                func section(_ s: String) {
                    s.draw(at: CGPoint(x: 40, y: y), withAttributes: headAttr); y += 24
                }
                func row(_ k: String, _ v: String) {
                    k.draw(at: CGPoint(x: 48, y: y), withAttributes: keyAttr)
                    v.draw(at: CGPoint(x: 360, y: y), withAttributes: valAttr); y += 20
                }

                section(b.name)
                row("Cross / breed", b.cross.name)
                row("Placed", df.string(from: b.placementDate))
                row("Head placed / alive", "\(b.initialCount) / \(b.currentCount)")
                row("Day on feed", "\(b.currentDay)")
                y += 8
                section("Growth")
                row("Average weight", appState.weightString(grams: b.latestAvgGrams))
                row("Target weight", appState.weightString(grams: b.targetWeightGrams))
                row("Gain per day", g.hasData ? "\(Int(g.adgRecent)) g" : "—")
                row("Status vs standard", g.status.title)
                y += 8
                section("Feed & FCR")
                row("Total feed", String(format: "%.0f kg", fcr.feedKg))
                row("FCR", fcr.fcr > 0 ? String(format: "%.2f", fcr.fcr) : "—")
                row("Standard FCR", String(format: "%.2f", fcr.standardFCR))
                y += 8
                section("Economics")
                row("Total cost", appState.money(cost.totalCost, currency: b.currency))
                row("Cost per kg live", appState.money(cost.costPerKgLive, currency: b.currency))
                row("Cost per kg dressed", appState.money(cost.costPerKgDressed, currency: b.currency))
                row("Dressing yield", String(format: "%.0f%%", yield.dressingPercent * 100))
                if yield.hasPrice {
                    row("Revenue", appState.money(yield.revenue, currency: b.currency))
                    row("Margin", appState.money(yield.margin, currency: b.currency))
                }

                let footer = "Generated by Grow Rate · \(df.string(from: Date()))"
                footer.draw(at: CGPoint(x: 40, y: 800), withAttributes: keyAttr)
            }
            return url
        } catch { return nil }
    }

    private static func safe(_ s: String) -> String {
        s.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "_")
    }
}
