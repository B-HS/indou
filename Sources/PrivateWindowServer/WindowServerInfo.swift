import ApplicationServices
import CoreGraphics

// `_AXUIElementGetWindow` is a private HIServices symbol that is NOT exported for
// `dlsym` but resolves at link time (ApplicationServices is linked). It maps an
// Accessibility window element to its CGWindowID — essential for attaching the
// live AX element (for raise/close actions) to each enumerated window.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Small private-API helpers used while enumerating windows: mapping an
/// Accessibility element to its CGWindowID, and reading a window's level.
public enum WindowServerInfo {
    public static func windowID(for axWindow: AXUIElement) -> CGWindowID? {
        var wid: CGWindowID = 0
        return _AXUIElementGetWindow(axWindow, &wid) == .success ? wid : nil
    }

    public static func windowLevel(_ windowID: CGWindowID) -> Int? {
        let symbols = SkyLightSymbols.shared
        guard let fn = symbols.getWindowLevel else { return nil }
        var level: Int32 = 0
        return fn(symbols.connectionID, windowID, &level) == .success ? Int(level) : nil
    }
}
