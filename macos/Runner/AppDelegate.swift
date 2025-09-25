import Cocoa
import FlutterMacOS
import AVFoundation
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    
    // Set window background to white immediately to prevent black screen
    if let window = NSApplication.shared.windows.first {
      window.backgroundColor = NSColor.white
      window.isOpaque = true
    }
    
    // Register for remote notifications
    NSApplication.shared.registerForRemoteNotifications()
    
    // Set up camera permission method channel
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let cameraChannel = FlutterMethodChannel(
        name: "com.linkedup.camera_permission",
        binaryMessenger: controller.engine.binaryMessenger
      )
      
      cameraChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "requestCameraPermission":
          self.requestCameraPermission(result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
  
  private func requestCameraPermission(result: @escaping FlutterResult) {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    
    switch status {
    case .authorized:
      result(true)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async {
          result(granted)
        }
      }
    case .denied, .restricted:
      result(false)
    @unknown default:
      result(false)
    }
  }
  
  // Handle APNS token registration
  override func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("Successfully registered for remote notifications with token: \(deviceToken)")
    // Firebase will automatically handle this token
  }
  
  override func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for remote notifications: \(error)")
  }
}
