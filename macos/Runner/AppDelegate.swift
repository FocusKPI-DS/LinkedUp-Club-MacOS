import Cocoa
import FlutterMacOS
import AVFoundation
import UserNotifications
import FirebaseMessaging
import FirebaseCore
import GoogleSignIn

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  // MARK: - Google Sign-In Configuration
  private func configureGoogleSignIn() {
    // Load GoogleService-Info.plist
    guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
          let plist = NSDictionary(contentsOfFile: path),
          let clientId = plist["CLIENT_ID"] as? String else {
      print("⚠️ Warning: Could not load GoogleService-Info.plist or CLIENT_ID")
      print("⚠️ Google Sign-In will not work properly without this configuration")
      return
    }
    
    // Only configure if not already configured (to avoid conflicts)
    if GIDSignIn.sharedInstance.configuration == nil {
      // Configure GIDSignIn with the client ID from GoogleService-Info.plist
      // This MUST be done before any Flutter code tries to use Google Sign-In
      let config = GIDConfiguration(clientID: clientId)
      GIDSignIn.sharedInstance.configuration = config
      print("✅ Google Sign-In configured for macOS")
      print("   Client ID: \(String(clientId.prefix(40)))...")
    } else {
      // Already configured, but verify it matches
      if let existingClientId = GIDSignIn.sharedInstance.configuration?.clientID,
         existingClientId == clientId {
        print("✅ Google Sign-In already configured correctly")
      } else {
        // Configuration exists but doesn't match - update it
        let config = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = config
        print("✅ Google Sign-In configuration updated")
      }
    }
    
    // Final verification
    if let configuredClientId = GIDSignIn.sharedInstance.configuration?.clientID {
      print("✅ Verified: GIDSignIn is configured with client ID: \(String(configuredClientId.prefix(40)))...")
    } else {
      print("❌ ERROR: GIDSignIn configuration verification failed!")
    }
  }
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Configure Google Sign-In BEFORE super call to ensure it's ready
    // This is critical for keychain access and OAuth flow on macOS
    self.configureGoogleSignIn()
    
    super.applicationDidFinishLaunching(notification)
    
    // Initialize Firebase
    FirebaseApp.configure()
    
    // Set notification delegate before requesting permissions
    UNUserNotificationCenter.current().delegate = self
    
    // Check current authorization status and register accordingly
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .authorized, .provisional:
        // Already authorized, register for remote notifications
        print("✅ Notification permission already authorized")
        DispatchQueue.main.async {
          NSApplication.shared.registerForRemoteNotifications()
        }
      case .notDetermined:
        // Request permission first
        print("📱 Requesting notification permission...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
          if let error = error {
            print("❌ Notification permission error: \(error.localizedDescription)")
            return
          }
          
          if granted {
            print("✅ Notification permission granted")
            DispatchQueue.main.async {
              NSApplication.shared.registerForRemoteNotifications()
            }
          } else {
            print("❌ Notification permission denied")
          }
        }
      case .denied:
        print("❌ Notification permission denied by user")
      @unknown default:
        print("⚠️ Unknown notification authorization status")
      }
    }
  }
  
  override func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("✅ APNS token received: \(token)")
    print("   Token length: \(deviceToken.count) bytes")
    
    // Set APNS token for Firebase Messaging - CRITICAL!
    Messaging.messaging().apnsToken = deviceToken
    
    // Verify the token was set correctly
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      // Check if APNS token is accessible in Firebase Messaging
      if let apnsToken = Messaging.messaging().apnsToken {
        let apnsTokenString = apnsToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("✅ Firebase Messaging confirms APNS token is set: \(String(apnsTokenString.prefix(20)))...")
      } else {
        print("❌ CRITICAL: Firebase Messaging APNS token is nil after setting!")
      }
      
      // Try to get FCM token
      Messaging.messaging().token { fcmToken, error in
        if let error = error {
          print("❌ Failed to retrieve FCM token: \(error.localizedDescription)")
        } else if let fcmToken = fcmToken {
          print("✅ FCM token retrieved successfully: \(String(fcmToken.prefix(30)))...")
        } else {
          print("⚠️ FCM token is nil - will retry...")
          // Retry after a longer delay
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            Messaging.messaging().token { retryToken, retryError in
              if let retryError = retryError {
                print("❌ FCM token retry failed: \(retryError.localizedDescription)")
              } else if let retryToken = retryToken {
                print("✅ FCM token retrieved on retry: \(String(retryToken.prefix(30)))...")
              } else {
                print("❌ FCM token still nil after retry")
              }
            }
          }
        }
      }
    }
  }
  
  override func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
  }
  
  // MARK: - URL Handling for Google Sign-In OAuth
  // This is critical for macOS to handle OAuth callbacks from Google Sign-In
  override func application(_ application: NSApplication, open urls: [URL]) {
    // Handle Google Sign-In OAuth callback
    for url in urls {
      if GIDSignIn.sharedInstance.handle(url) {
        print("✅ Google Sign-In OAuth callback handled: \(url)")
        return
      }
    }
    
    // Let Flutter handle other URLs
    super.application(application, open: urls)
  }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    // Show notification even when app is in foreground
    completionHandler([.alert, .badge, .sound])
  }
  
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    // Handle notification tap
    print("📱 Notification tapped: \(response.notification.request.content.userInfo)")
    completionHandler()
  }
}