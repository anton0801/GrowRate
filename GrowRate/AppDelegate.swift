import UIKit
import FirebaseCore
import FirebaseMessaging
import AppTrackingTransparency
import UserNotifications
import AppsFlyerLib

enum Seed {
    static let appCode = "6783496215"
    static let sensorKey = "Mt67E7Hm5ggv7bEyMJrG6W"
    static let suiteBed = "group.growrate.bed"
    static let cookieBed = "growrate_bed"
    static let canopyEndpoint = "https://growratte.com/config.php"
    static let logFile = "gr_sprout_log.dat"
    static let bedVault = "GrowRateBed"
    static let cipher = Array("growratebed".utf8)
}

extension AppDelegate: AppsFlyerLibDelegate, DeepLinkDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        graft.takeSap(conversionInfo)
    }

    func onConversionDataFail(_ error: Error) {
    }

    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard case .found = result.status, let deepLink = result.deepLink else { return }
        graft.takeRoots(deepLink.clickEvent)
    }
}

final class AppDelegate: UIResponder, UIApplicationDelegate {

    private let graft = Graft()
    private let bud = Bud()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        wire(application)
        (launchOptions?[.remoteNotification] as? [AnyHashable: Any]).map(bud.drop)
        NotificationCenter.default.addObserver(self, selector: #selector(awake), name: UIApplication.didBecomeActiveNotification, object: nil)
        return true
    }

    private func wire(_ application: UIApplication) {
        FirebaseApp.configure()

        let af = AppsFlyerLib.shared()
        af.appsFlyerDevKey = Seed.sensorKey
        af.appleAppID = Seed.appCode
        af.delegate = self
        af.deepLinkDelegate = self
        af.isDebug = false

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    @objc private func awake() {
        guard #available(iOS 14, *) else { return AppsFlyerLib.shared().start() }
        AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
        ATTrackingManager.requestTrackingAuthorization { status in
            DispatchQueue.main.async {
                AppsFlyerLib.shared().start()
                UserDefaults.standard.set(status.rawValue, forKey: SeedKey.attStatus)
            }
        }
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        messaging.token { token, error in
            guard error == nil, let token = token else { return }
            UserDefaults.standard.set(token, forKey: SeedKey.fcm)
            UserDefaults.standard.set(token, forKey: SeedKey.push)
            UserDefaults(suiteName: Seed.suiteBed)?.set(token, forKey: SeedKey.sharedFcm)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        bud.drop(notification.request.content.userInfo)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        bud.drop(response.notification.request.content.userInfo)
        completionHandler()
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        bud.drop(userInfo)
        completionHandler(.newData)
    }
}
