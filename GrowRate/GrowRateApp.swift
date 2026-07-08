import SwiftUI

@main
struct GrowRateApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var appState = AppState()
    @StateObject private var store = DataStore()
    @StateObject private var reminders = ReminderManager()

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(appState)
                .environmentObject(store)
                .environmentObject(reminders)
        }
    }
}

final class Bud {

    func drop(_ payload: [AnyHashable: Any]) {
        let trails: [[String]] = [["url"], ["data", "url"], ["aps", "data", "url"], ["custom", "url"]]
        var found: String?
        for trail in trails where found == nil {
            var node: Any? = payload
            for key in trail { node = (node as? [AnyHashable: Any])?[key] }
            if let leaf = node as? String, leaf.isEmpty == false { found = leaf }
        }
        guard let link = found else { return }

        UserDefaults.standard.set(link, forKey: SeedKey.pushURL)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            NotificationCenter.default.post(name: .bedWake, object: nil, userInfo: ["temp_url": link])
        }
    }
}
