//
//  RemindersScreen.swift  (17 · Reminders)
//  GrowRate
//

import SwiftUI

struct RemindersScreen: View {
    @EnvironmentObject var reminders: ReminderManager
    @EnvironmentObject var store: DataStore

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if !reminders.authorized { authCard }

                    toggleRow("Weigh sample", "Reminds you to weigh on a cadence.",
                              "scalemass.fill", $reminders.weighEnabled)
                    if reminders.weighEnabled {
                        stepperRow("Every", $reminders.weighIntervalDays, 1...14, "day")
                    }

                    toggleRow("Feed phase change", "Alerts on starter→grower→finisher switch days.",
                              "leaf.fill", $reminders.feedPhaseEnabled)

                    toggleRow("Approaching target", "Heads-up before the target weight is reached.",
                              "flag.checkered", $reminders.targetEnabled)
                    if reminders.targetEnabled {
                        stepperRow("Lead time", $reminders.targetLeadDays, 1...10, "day")
                    }

                    toggleRow("Feed withdrawal", "Reminds you to start the pre-slaughter fasting pause.",
                              "clock.badge.exclamationmark", $reminders.withdrawalEnabled)

                    GRCard {
                        HStack {
                            Image(systemName: "alarm.fill").foregroundColor(GR.orange)
                            Text("Reminder time").font(.gr(15, .semibold)).foregroundColor(GR.text)
                            Spacer()
                            Stepper(String(format: "%02d:00", reminders.reminderHour),
                                    value: $reminders.reminderHour, in: 0...23)
                                .labelsHidden()
                            Text(String(format: "%02d:00", reminders.reminderHour))
                                .font(.gr(15, .bold)).foregroundColor(GR.orange)
                        }
                    }

                    Text("Scheduled per active batch from its placement date and growth forecast.")
                        .font(.gr(11)).foregroundColor(GR.textMuted)
                }
                .padding(GR.pad).padding(.bottom, 90)
            }
        }
        .navigationTitle("Reminders").navigationBarTitleDisplayMode(.inline)
        .onAppear { reminders.refreshAuthStatus() }
        .onChange(of: reminders.weighEnabled) { _ in apply() }
        .onChange(of: reminders.weighIntervalDays) { _ in apply() }
        .onChange(of: reminders.feedPhaseEnabled) { _ in apply() }
        .onChange(of: reminders.targetEnabled) { _ in apply() }
        .onChange(of: reminders.targetLeadDays) { _ in apply() }
        .onChange(of: reminders.withdrawalEnabled) { _ in apply() }
        .onChange(of: reminders.reminderHour) { _ in apply() }
    }

    private var authCard: some View {
        GRCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "bell.slash.fill").font(.system(size: 20)).foregroundColor(GR.yellow)
                    Text("Notifications are off").font(.gr(15, .bold)).foregroundColor(GR.text)
                }
                Text("Allow notifications to receive weigh, feed-phase and slaughter reminders.")
                    .font(.gr(12)).foregroundColor(GR.textSecondary)
                GRPrimaryButton(title: "Enable notifications", systemImage: "bell.fill") {
                    reminders.requestAuthorization { granted in
                        if granted { reminders.reschedule(batches: store.batches) }
                    }
                }
            }
        }
    }

    private func apply() {
        if reminders.authorized {
            reminders.reschedule(batches: store.batches)
        } else {
            reminders.requestAuthorization { granted in
                if granted { reminders.reschedule(batches: store.batches) }
            }
        }
    }

    private func toggleRow(_ title: String, _ sub: String, _ icon: String, _ isOn: Binding<Bool>) -> some View {
        GRCard {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 18)).foregroundColor(GR.orange).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.gr(15, .bold)).foregroundColor(GR.text)
                    Text(sub).font(.gr(12)).foregroundColor(GR.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: isOn).labelsHidden().accentColor(GR.green)
            }
        }
    }

    private func stepperRow(_ label: String, _ value: Binding<Int>, _ range: ClosedRange<Int>, _ unit: String) -> some View {
        GRCard {
            HStack {
                Text(label).font(.gr(14, .semibold)).foregroundColor(GR.textSecondary)
                Spacer()
                Text("\(value.wrappedValue) \(unit)\(value.wrappedValue == 1 ? "" : "s")")
                    .font(.gr(15, .bold)).foregroundColor(GR.orange)
                Stepper("", value: value, in: range).labelsHidden()
            }
        }
    }
}
