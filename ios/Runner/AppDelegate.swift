import UIKit
import Flutter
import GoogleMaps
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Google Maps API Key - Info.plist içinden oku
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
           !apiKey.isEmpty,
           apiKey != "BURAYA_GOOGLE_MAPS_API_KEY" {
            GMSServices.provideAPIKey(apiKey)
            print("Google Maps API Key loaded successfully")
        } else {
            // Fallback: Hardcoded key (Info.plist'te yoksa)
            GMSServices.provideAPIKey("AIzaSyBpgppKBVULdvG8yHq8F57TljP9PpXTvCM")
            print("WARNING: GMSApiKey not found or placeholder value is still being used in Info.plist")
        }

        // Firebase başlat
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("Firebase configured successfully")
        }

        // Ses oturumu - arka plan / ön plan ses için
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            print("Audio session configured successfully")
        } catch {
            print("Audio session configuration failed: \(error.localizedDescription)")
        }

        // Bildirim delegate ve izinler
        // FIX: Güvenli delegate ataması - class zaten UNUserNotificationCenterDelegate implement ediyor
        // Unsafe optional cast (as?) kaldırıldı - bu crash'e yol açıyordu
        if #available(iOS 10.0, *) {
            let center = UNUserNotificationCenter.current()
            // Güvenli atama: class zaten UNUserNotificationCenterDelegate protokolünü implement ediyor
            center.delegate = self

            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            center.requestAuthorization(options: options) { granted, error in
                if let error = error {
                    print("Notification permission error: \(error.localizedDescription)")
                } else {
                    print("Notification permission granted: \(granted)")
                }
            }
        }

        application.registerForRemoteNotifications()
        Messaging.messaging().delegate = self

        GeneratedPluginRegistrant.register(with: self)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // APNs token alındığında Firebase Messaging'e aktar
    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    // APNs kayıt hatası
    override func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
        super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    // Firebase FCM token geldiğinde
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(fcmToken ?? "nil")")
    }

    // Uygulama açıkken bildirim göster
    @available(iOS 10.0, *)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    // Bildirime tıklanınca
    @available(iOS 10.0, *)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
