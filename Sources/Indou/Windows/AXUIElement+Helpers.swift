import ApplicationServices
import CoreGraphics

/// Thin, non-throwing accessors over the C Accessibility API. Each returns `nil`
/// rather than an error so the enumerator can degrade per-attribute.
extension AXUIElement {
    func rawValue(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    func value<T>(_ attribute: String, as type: T.Type = T.self) -> T? {
        rawValue(attribute) as? T
    }

    func bool(_ attribute: String) -> Bool {
        (rawValue(attribute) as? Bool) ?? false
    }

    var axTitle: String? { value(kAXTitleAttribute as String) }
    var axRole: String? { value(kAXRoleAttribute as String) }
    var axSubrole: String? { value(kAXSubroleAttribute as String) }
    var axIsMinimized: Bool { bool(kAXMinimizedAttribute as String) }
    var axIsFullscreen: Bool { bool("AXFullScreen") }

    var axWindows: [AXUIElement]? {
        rawValue(kAXWindowsAttribute as String) as? [AXUIElement]
    }

    var axCloseButton: AXUIElement? {
        guard let ref = rawValue(kAXCloseButtonAttribute as String) else { return nil }
        return (ref as! AXUIElement)
    }

    var axPosition: CGPoint? {
        guard let ref = rawValue(kAXPositionAttribute as String) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(ref as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    var axSize: CGSize? {
        guard let ref = rawValue(kAXSizeAttribute as String) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(ref as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    @discardableResult
    func perform(_ action: String) -> Bool {
        AXUIElementPerformAction(self, action as CFString) == .success
    }

    @discardableResult
    func setValue(_ attribute: String, _ value: CFTypeRef) -> Bool {
        AXUIElementSetAttributeValue(self, attribute as CFString, value) == .success
    }

    func setMessagingTimeout(_ seconds: Float) {
        AXUIElementSetMessagingTimeout(self, seconds)
    }
}
