//
//  SettingsScreen.swift  (18 · Settings) + cross presets reference
//  GrowRate
//

import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: DataStore

    @State private var shareItems: [Any] = []
    @State private var showShare = false
    @State private var showClear = false

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    appearance
                    unitsCurrency
                    defaults
                    NavigationLink(destination: RemindersScreen()) {
                        linkRow("Reminders", "bell.fill", "Weigh, feed-phase & slaughter alerts")
                    }.buttonStyle(PlainButtonStyle())
                    NavigationLink(destination: CrossPresetsView()) {
                        linkRow("Cross presets", "list.star", "Reference growth standards")
                    }.buttonStyle(PlainButtonStyle())
                    dataCard
                    about
                }
                .padding(GR.pad).padding(.bottom, 90)
            }
        }
        .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) { ShareSheet(items: shareItems) }
        .alert(isPresented: $showClear) {
            Alert(title: Text("Delete all data?"),
                  message: Text("Removes every batch and record. This cannot be undone."),
                  primaryButton: .destructive(Text("Delete all")) {
                      let all = store.batches; all.forEach { store.deleteBatch($0) }
                  },
                  secondaryButton: .cancel())
        }
    }

    private var appearance: some View {
        GRCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Appearance", systemImage: "paintbrush.fill")
                Picker("", selection: $appState.themeMode) {
                    ForEach(ThemeMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
    }

    private var unitsCurrency: some View {
        GRCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Units & currency", systemImage: "ruler.fill")
                Text("WEIGHT UNIT").font(.gr(11, .bold)).foregroundColor(GR.textMuted)
                Picker("", selection: $appState.weightUnit) {
                    ForEach(WeightUnit.allCases) { Text($0.short).tag($0) }
                }
                .pickerStyle(SegmentedPickerStyle())
                Text("CURRENCY").font(.gr(11, .bold)).foregroundColor(GR.textMuted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AppState.commonCurrencies, id: \.self) { c in
                            GRChip(title: c, isSelected: appState.currencyCode == c) {
                                appState.currencyCode = c
                            }
                        }
                    }
                }
            }
        }
    }

    private var defaults: some View {
        GRCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "New-batch defaults", systemImage: "slider.horizontal.3")
                Text("DEFAULT CROSS").font(.gr(11, .bold)).foregroundColor(GR.textMuted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CrossPreset.builtIns) { p in
                            GRChip(title: p.name, isSelected: appState.defaultCrossId == p.id) {
                                appState.defaultCrossId = p.id
                            }
                        }
                    }
                }
                HStack {
                    Text("DEFAULT TARGET").font(.gr(11, .bold)).foregroundColor(GR.textMuted)
                    Spacer()
                    Text(String(format: "%.2f kg", appState.defaultTargetGrams / 1000))
                        .font(.gr(15, .heavy)).foregroundColor(GR.green)
                }
                Slider(value: $appState.defaultTargetGrams, in: 1000...4500, step: 50).accentColor(GR.orange)
            }
        }
    }

    private var dataCard: some View {
        GRCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Data", systemImage: "externaldrive.fill")
                GRSecondaryButton(title: "Backup / export data", systemImage: "square.and.arrow.up") {
                    if let url = backupURL() { shareItems = [url]; showShare = true }
                }
                Button(action: { showClear = true }) {
                    Text("Delete all data").font(.gr(14, .semibold)).foregroundColor(GR.red)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
            }
        }
    }

    private var about: some View {
        VStack(spacing: 4) {
            Image(systemName: "scalemass.fill").font(.system(size: 24)).foregroundColor(GR.orange)
            Text("Grow Rate").font(.gr(16, .bold)).foregroundColor(GR.text)
            Text("Weigh it, feed it, profit.").font(.gr(12)).foregroundColor(GR.textSecondary)
            Text("v1.0 · local & private").font(.gr(11)).foregroundColor(GR.textMuted)
        }
        .frame(maxWidth: .infinity).padding(.top, 8)
    }

    private func linkRow(_ title: String, _ icon: String, _ sub: String) -> some View {
        GRCard {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 18)).foregroundColor(GR.orange).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.gr(15, .bold)).foregroundColor(GR.text)
                    Text(sub).font(.gr(12)).foregroundColor(GR.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(GR.textMuted)
            }
        }
    }

    private func backupURL() -> URL? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(store.batches) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("GrowRate-backup.json")
        do { try data.write(to: url); return url } catch { return nil }
    }
}

// MARK: - Cross presets reference

struct CrossPresetsView: View {
    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    ForEach(CrossPreset.builtIns) { p in
                        GRCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: p.type.icon).foregroundColor(GR.orange)
                                    Text(p.name).font(.gr(16, .bold)).foregroundColor(GR.text)
                                    Spacer()
                                    StatusBadge(text: p.type.title, color: GR.green)
                                }
                                LineChartView(series: [ChartSeries(
                                    points: p.standardChartPoints(maxDay: p.typicalSlaughterDay + 7),
                                    color: GR.green, fill: true)],
                                    yFormatter: { String(format: "%.1f", $0 / 1000) })
                                    .frame(height: 110)
                                HStack(spacing: 10) {
                                    StatPill(title: "Dressing", value: String(format: "%.0f%%", p.dressingPercent * 100), color: GR.green)
                                    StatPill(title: "Typical target", value: String(format: "%.1f kg", p.typicalTargetGrams / 1000), color: GR.orange)
                                    StatPill(title: "~ Day", value: "\(p.typicalSlaughterDay)", color: GR.text)
                                }
                            }
                        }
                    }
                }
                .padding(GR.pad).padding(.bottom, 90)
            }
        }
        .navigationTitle("Cross Presets").navigationBarTitleDisplayMode(.inline)
    }
}
