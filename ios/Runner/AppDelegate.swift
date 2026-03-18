import UIKit
import Flutter
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps API Key
    GMSServices.provideAPIKey("AIzaSyBpgppKBVULdvG8yHq8F57TljP9PpXTvCM")
    
    // FlutterAppDelegate zaten UNUserNotificationCenterDelegate'i implement ediyor
    // Delegate ataması Flutter tarafından otomatik yapılıyor, manuel atama gerekmiyor
    // Eğer custom notification handling gerekiyorsa, Flutter plugin'leri kullanılmalı
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
