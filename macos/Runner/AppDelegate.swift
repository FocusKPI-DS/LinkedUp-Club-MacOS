import Cocoa
import FlutterMacOS
import AVFoundation
import UserNotifications
import FirebaseMessaging
import FirebaseCore
import GoogleSignIn

// MARK: - Camera Delegate for ImagePickerMacOS
class CameraDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
  var completionHandler: ((URL?, Error?) -> Void)?
  
  func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
    completionHandler?(outputFileURL, error)
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  private var cameraDelegate: CameraDelegate?
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  // MARK: - Force Release All Camera Sessions
  // This is a workaround for camera_macos package not properly releasing camera resources
  private func forceReleaseAllCameras() {
    print("🔴 [Camera Cleanup] Force releasing all camera sessions...")
    
    // Get all available video devices
    let discoverySession = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
      mediaType: .video,
      position: .unspecified
    )
    
    // Try to release any active camera sessions
    for device in discoverySession.devices {
      if device.isConnected {
        print("📷 [Camera Cleanup] Found connected device: \(device.localizedName)")
        // Attempt to unlock the device if it's locked
        do {
          try device.lockForConfiguration()
          device.unlockForConfiguration()
          print("✅ [Camera Cleanup] Unlocked device: \(device.localizedName)")
        } catch {
          print("⚠️ [Camera Cleanup] Could not unlock device \(device.localizedName): \(error.localizedDescription)")
        }
      }
    }
    
    print("✅ [Camera Cleanup] Camera release attempt completed")
  }
  
  override func applicationWillTerminate(_ notification: Notification) {
    print("🛑 [AppDelegate] applicationWillTerminate - forcing camera release")
    forceReleaseAllCameras()
  }
  
  override func applicationWillResignActive(_ notification: Notification) {
    // Release cameras when app loses focus (optional, but helps)
    // Uncomment if needed:
    // forceReleaseAllCameras()
  }
  
  // MARK: - Camera Permission & Cleanup Method Channel (DEDICATED - no conflicts)
  private func setupCameraChannels() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self,
            let controller = NSApplication.shared.windows.first?.contentViewController as? FlutterViewController else {
        print("⚠️ [Camera] Could not get FlutterViewController, will retry in 0.5s...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          self?.setupCameraChannels()
        }
        return
      }
      
      let messenger = controller.engine.binaryMessenger
      
      // ── 1. Dedicated camera permission channel (does NOT conflict with permission_handler) ──
      let cameraChannel = FlutterMethodChannel(
        name: "com.focuskpi.linkedup/camera_permission",
        binaryMessenger: messenger
      )
      
      cameraChannel.setMethodCallHandler { [weak self] (call, result) in
        guard let self = self else {
          result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate deallocated", details: nil))
          return
        }
        
        switch call.method {
          
        case "checkStatus":
          // Returns raw AVAuthorizationStatus: 0=notDetermined, 1=restricted, 2=denied, 3=authorized
          let status = AVCaptureDevice.authorizationStatus(for: .video)
          print("📷 [Camera] checkStatus → \(status.rawValue) (\(self.statusName(status)))")
          result(status.rawValue)
          
        case "requestAccess":
          // Calls AVCaptureDevice.requestAccess — this is what shows the macOS system dialog
          let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
          print("📷 [Camera] requestAccess called (current status: \(self.statusName(currentStatus)))")
          
          AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
              let newStatus = AVCaptureDevice.authorizationStatus(for: .video)
              print(granted
                ? "✅ [Camera] System granted camera access! (status: \(self.statusName(newStatus)))"
                : "❌ [Camera] System denied camera access (status: \(self.statusName(newStatus)))")
              // Return: {"granted": true/false, "status": rawValue}
              result(["granted": granted, "status": newStatus.rawValue])
            }
          }
          
        case "openSettings":
          // Open macOS System Settings → Privacy & Security → Camera (like Slack / WhatsApp)
          print("🔧 [Camera] Opening System Settings > Privacy > Camera...")
          self.openCameraSystemSettings()
          result(true)
          
        case "releaseCameras":
          self.forceReleaseAllCameras()
          result(true)
          
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      
      // ── 2. Camera cleanup channel (kept for dispose calls) ──
      let cleanupChannel = FlutterMethodChannel(
        name: "com.focuskpi.linkedup/camera_cleanup",
        binaryMessenger: messenger
      )
      
      cleanupChannel.setMethodCallHandler { [weak self] (call, result) in
        guard let self = self else {
          result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate deallocated", details: nil))
          return
        }
        switch call.method {
        case "release":
          self.forceReleaseAllCameras()
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      
      print("✅ [Camera] Dedicated permission channel ready: com.focuskpi.linkedup/camera_permission")
      print("✅ [Camera] Cleanup channel ready: com.focuskpi.linkedup/camera_cleanup")
    }
  }
  
  private func statusName(_ status: AVAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .restricted:    return "restricted"
    case .denied:        return "denied"
    case .authorized:    return "authorized"
    @unknown default:    return "unknown(\(status.rawValue))"
    }
  }
  
  // MARK: - Open System Preferences > Camera (like Slack / WhatsApp)
  private func openCameraSystemSettings() {
    // This URL scheme works on macOS 12+ (Monterey through Sequoia)
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
      NSWorkspace.shared.open(url)
    }
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
    print("🚀 [AppDelegate] applicationDidFinishLaunching started")
    
    // Configure dedicated camera permission + cleanup channels
    self.setupCameraChannels()
    
    // Configure Google Sign-In
    self.configureGoogleSignIn()
    
    // Initialize Firebase
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
      print("✅ [AppDelegate] FirebaseApp.configure() completed")
    } else {
      print("✅ [AppDelegate] FirebaseApp already configured")
    }
    
    // Set notification delegate
    UNUserNotificationCenter.current().delegate = self
    
    // Request registration immediately to ensure we get a token (if authorized)
    DispatchQueue.main.async {
      print("🚀 [AppDelegate] Calling registerForRemoteNotifications (proactive)")
      NSApplication.shared.registerForRemoteNotifications()
    }
    
    // Check permissions and request if needed
    print("🚀 [AppDelegate] Checking notification settings...")
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      print("📱 [AppDelegate] Notification settings status: \(settings.authorizationStatus.rawValue)")
      
      switch settings.authorizationStatus {
      case .authorized, .provisional:
        print("✅ [AppDelegate] Notification permission already authorized")
        DispatchQueue.main.async {
          NSApplication.shared.registerForRemoteNotifications()
        }
      case .notDetermined:
        print("📱 [AppDelegate] Requesting notification permission...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
          if let error = error {
            print("❌ [AppDelegate] Notification permission error: \(error.localizedDescription)")
            return
          }
          
          if granted {
            print("✅ [AppDelegate] Notification permission granted")
            DispatchQueue.main.async {
              NSApplication.shared.registerForRemoteNotifications()
            }
          } else {
            print("❌ [AppDelegate] Notification permission denied")
          }
        }
      case .denied:
        print("❌ [AppDelegate] Notification permission denied by user")
      @unknown default:
        print("⚠️ [AppDelegate] Unknown notification authorization status")
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
    if #available(macOS 11.0, *) {
      completionHandler([.banner, .badge, .sound])
    } else {
      completionHandler([.alert, .badge, .sound])
    }
  }
  
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    // Handle notification tap
    print("📱 Notification tapped: \(response.notification.request.content.userInfo)")
    completionHandler()
  }
}