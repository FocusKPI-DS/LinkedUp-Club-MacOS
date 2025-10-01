import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    // Set white background immediately to prevent black screen
    self.backgroundColor = NSColor.white
    self.isOpaque = true
    
    let flutterViewController = FlutterViewController.init()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Enable smooth scrolling and trackpad gestures
    self.acceptsMouseMovedEvents = true
    
    super.awakeFromNib()
  }

  
  override func scrollWheel(with event: NSEvent) {
    // Enable smooth scrolling with trackpad
    super.scrollWheel(with: event)
  }
}
