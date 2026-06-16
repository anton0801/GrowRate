//
//  ReminderManager.swift
//  GrowRate
//
//  Real local notifications: weigh-sample cadence, feed-phase switch,
//  target-weight approach, pre-slaughter feed withdrawal.
//

import SwiftUI
import UserNotifications

final class ReminderManager: ObservableObject {
    private let center = UNUserNotificationCenter.current()
    private let d = UserDefaults.standard

    @Published var authorized: Bool = false

    @Published var weighEnabled: Bool { didSet { d.set(weighEnabled, forKey: "rm_weigh") } }
    @Published var weighIntervalDays: Int { didSet { d.set(weighIntervalDays, forKey: "rm_weighDays") } }
    @Published var feedPhaseEnabled: Bool { didSet { d.set(feedPhaseEnabled, forKey: "rm_phase") } }
    @Published var targetEnabled: Bool { didSet { d.set(targetEnabled, forKey: "rm_target") } }
    @Published var targetLeadDays: Int { didSet { d.set(targetLeadDays, forKey: "rm_targetLead") } }
    @Published var withdrawalEnabled: Bool { didSet { d.set(withdrawalEnabled, forKey: "rm_withdraw") } }
    @Published var reminderHour: Int { didSet { d.set(reminderHour, forKey: "rm_hour") } }

    init() {
        weighEnabled = d.object(forKey: "rm_weigh") as? Bool ?? false
        weighIntervalDays = d.object(forKey: "rm_weighDays") as? Int ?? 3
        feedPhaseEnabled = d.object(forKey: "rm_phase") as? Bool ?? false
        targetEnabled = d.object(forKey: "rm_target") as? Bool ?? false
        targetLeadDays = d.object(forKey: "rm_targetLead") as? Int ?? 3
        withdrawalEnabled = d.object(forKey: "rm_withdraw") as? Bool ?? false
        reminderHour = d.object(forKey: "rm_hour") as? Int ?? 8
        refreshAuthStatus()
    }

    func refreshAuthStatus() {
        center.getNotificationSettings { s in
            DispatchQueue.main.async {
                self.authorized = (s.authorizationStatus == .authorized
                                   || s.authorizationStatus == .provisional)
            }
        }
    }

    func requestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.authorized = granted
                completion?(granted)
            }
        }
    }

    func cancelAll() { center.removeAllPendingNotificationRequests() }

    // MARK: Scheduling

    func reschedule(batches: [Batch]) {
        cancelAll()
        guard authorized else { return }

        if weighEnabled {
            addInterval(id: "weigh",
                        title: "Time to weigh a sample",
                        body: "Weigh a representative sample to keep the growth curve accurate.",
                        days: max(1, weighIntervalDays))
        }

        let active = batches.filter { !$0.isSlaughtered }
        for b in active {
            if feedPhaseEnabled {
                for (day, phaseName) in [(b.cross.starterEndDay + 1, "Grower"),
                                         (b.cross.growerEndDay + 1, "Finisher")] {
                    if let date = dateForDay(day, batch: b) {
                        addCalendar(id: "phase-\(b.id)-\(day)",
                                    title: "Switch feed: \(b.name)",
                                    body: "Day \(day) — move \(b.name) onto \(phaseName) feed.",
                                    date: date)
                    }
                }
            }

            let forecast = ForecastEngine.analyze(b)
            if targetEnabled, let td = forecast.targetDate,
               let lead = Calendar.current.date(byAdding: .day, value: -targetLeadDays, to: td) {
                addCalendar(id: "target-\(b.id)",
                            title: "Approaching target: \(b.name)",
                            body: "\(b.name) is about \(targetLeadDays) days from target weight. Plan slaughter & sale.",
                            date: lead)
            }
            if withdrawalEnabled, let td = forecast.targetDate,
               let wd = Calendar.current.date(byAdding: .day, value: -1, to: td) {
                addCalendar(id: "withdraw-\(b.id)",
                            title: "Feed withdrawal: \(b.name)",
                            body: "Start the pre-slaughter fasting window (keep water available).",
                            date: wd)
            }
        }
    }

    // MARK: Builders

    private func content(_ title: String, _ body: String) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = .default
        return c
    }

    private func addInterval(id: String, title: String, body: String, days: Int) {
        let interval = max(60, TimeInterval(days * 86_400))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content(title, body), trigger: trigger))
    }

    private func addCalendar(id: String, title: String, body: String, date: Date) {
        guard date > Date() else { return }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = reminderHour
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content(title, body), trigger: trigger))
    }

    private func dateForDay(_ day: Int, batch: Batch) -> Date? {
        Calendar.current.date(byAdding: .day, value: day, to: batch.placementDate)
    }
}
