import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required by firebase_messaging 17: Apple needs the notification-center
    // delegate configured before application:didFinishLaunching returns.
    // Without this, foreground/background push delivery on iOS is unreliable.
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
