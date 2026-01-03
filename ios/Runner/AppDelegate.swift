import UIKit
import Flutter
import UserNotifications
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    UNUserNotificationCenter.current().delegate = self
    
    // Set up Firebase Messaging delegate
    Messaging.messaging().delegate = self
    
    // Set up method channel to allow Flutter to trigger registration
    // Use a delayed setup to ensure window is ready, but also set up immediately if possible
    if let controller = window?.rootViewController as? FlutterViewController {
      let notificationChannel = FlutterMethodChannel(
        name: "com.linkedup.notifications",
        binaryMessenger: controller.binaryMessenger
      )
      
      notificationChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "registerForRemoteNotifications" {
          DispatchQueue.main.async {
            application.registerForRemoteNotifications()
            result(true)
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    } else {
      // Fallback: set up asynchronously if window isn't ready
      DispatchQueue.main.async { [weak self] in
        guard let self = self,
              let controller = self.window?.rootViewController as? FlutterViewController else {
          return
        }
        
        let notificationChannel = FlutterMethodChannel(
          name: "com.linkedup.notifications",
          binaryMessenger: controller.binaryMessenger
        )
        
        notificationChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
          if call.method == "registerForRemoteNotifications" {
            DispatchQueue.main.async {
              application.registerForRemoteNotifications()
              result(true)
            }
          } else {
            result(FlutterMethodNotImplemented)
          }
        }
      }
    }
    
    // Check permission and register for remote notifications
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
        DispatchQueue.main.async {
          application.registerForRemoteNotifications()
        }
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("✅ iOS: APNS token received: \(String(token.prefix(20)))...")
    Messaging.messaging().apnsToken = deviceToken
    print("✅ iOS: APNS token set in Firebase Messaging")
  }
  
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ iOS: Failed to register for remote notifications: \(error.localizedDescription)")
  }
  
  override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo
    print("🔔 iOS: Notification received in foreground")
    print("   Title: \(notification.request.content.title)")
    print("   Body: \(notification.request.content.body)")
    print("   UserInfo: \(userInfo)")
    
    // For iOS 17+, ensure we show notifications even in foreground
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .badge, .sound, .list])
    } else {
      completionHandler([.alert, .badge, .sound])
    }
  }
  
  override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    print("📱 iOS: Notification tapped")
    print("   Title: \(response.notification.request.content.title)")
    print("   UserInfo: \(userInfo)")
    completionHandler()
  }
  
  // MARK: - MessagingDelegate
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("🔄 iOS: FCM token received: \(fcmToken?.prefix(20) ?? "nil")...")
    if let fcmToken = fcmToken {
      print("✅ iOS: FCM token available for notifications")
    }
  }
}
