//
//  UniformityScreen.swift  (09 · Uniformity)
//  GrowRate
//

import SwiftUI

struct UniformityScreen: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    let batchId: UUID

    private var batch: Batch? { store.batch(batchId) }

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                if let b = batch {
                    let r = UniformityEngine.analyze(b)
                    VStack(spacing: 16) {
                        if r.hasData {
                            headline(r)
                            stats(b, r)
                            distribution(b, r)
                        } else {
                            EmptyState(systemImage: "chart.bar.xaxis",
                                       title: "No sample weights",
                                       message: "Log a weighing using “Sample weights” mode to measure flock uniformity (CV%).")
                            NavigationLink(destination: WeightLogScreen(batchId: b.id)) {
                                GRSecondaryButton(title: "Go to Weight Log", systemImage: "scalemass.fill") {}
                                    .allowsHitTesting(false)
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(GR.pad).padding(.bottom, 90)
                } else {
                    EmptyState(systemImage: "questionmark", title: "Batch not found", message: "")
                }
            }
        }
        .navigationTitle("Uniformity").navigationBarTitleDisplayMode(.inline)
    }

    private func headline(_ r: UniformityResult) -> some View {
        GRCard {
            VStack(spacing: 10) {
                Text(String(format: "%.1f%%", r.cvPercent))
                    .font(.system(size: 50, weight: .heavy, design: .rounded)).foregroundColor(r.ratingColor)
                Text("Coefficient of variation").font(.gr(13, .semibold)).foregroundColor(GR.textSecondary)
                StatusBadge(text: r.rating, color: r.ratingColor)
                Text("Lower CV = a more even flock that finishes together.")
                    .font(.gr(11)).foregroundColor(GR.textMuted).multilineTextAlignment(.center)
            }
        }
    }

    private func stats(_ b: Batch, _ r: UniformityResult) -> some View {
        GRCard {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    StatPill(title: "In target ±10%", value: String(format: "%.0f%%", r.percentInTargetBand * 100), color: GR.green)
                    StatPill(title: "Sample", value: "\(r.count)", color: GR.text)
                }
                HStack(spacing: 10) {
                    StatPill(title: "Leaders", value: "\(r.leaders)", color: GR.orange, systemImage: "arrow.up")
                    StatPill(title: "Laggards", value: "\(r.laggards)", color: GR.yellow, systemImage: "arrow.down")
                    StatPill(title: "Mean", value: appState.weightString(grams: r.mean), color: GR.text)
                }
            }
        }
    }

    private func distribution(_ b: Batch, _ r: UniformityResult) -> some View {
        let maxW = r.maxW > 0 ? r.maxW : 1
        return GRCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Sorted sample", systemImage: "arrow.up.arrow.down")
                ForEach(r.sortedWeights.indices, id: \.self) { i in
                    let w = r.sortedWeights[i]
                    let color: Color = w > r.mean * 1.10 ? GR.orange : (w < r.mean * 0.90 ? GR.yellow : GR.green)
                    HStack(spacing: 8) {
                        Text("#\(i + 1)").font(.gr(11, .semibold)).foregroundColor(GR.textMuted).frame(width: 28, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(GR.bg2)
                                Capsule().fill(color).frame(width: CGFloat(w / maxW) * geo.size.width)
                            }
                        }
                        .frame(height: 14)
                        Text(appState.weightString(grams: w)).font(.gr(11, .bold)).foregroundColor(GR.text)
                            .frame(width: 64, alignment: .trailing)
                    }
                }
            }
        }
    }
}
