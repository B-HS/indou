import AppKit
import ApplicationServices
import CoreGraphics
import os

private let focusLog = Logger(subsystem: "com.hyunseokbyun.indou", category: "focus")

/// Brings a specific window to the front. macOS 14+ made `NSRunningApplication.activate`
/// cooperative, so from a background/accessory app it cannot reliably raise one
/// particular window. We therefore stack three mechanisms (best-effort, in order):
///  1. private SLPS (`_SLPSSetFrontProcessWithOptions` + two `SLPSPostEventRecordTo`
///     "make key" records — the AltTab technique) when enabled,
///  2. AX: set the app `kAXFrontmost` + the window `kAXRaise`,
///  3. public `NSRunningApplication.activate()` as a final nudge.
public enum PreciseFocus {
    private static let kCPSUserGenerated: UInt32 = 0x200
    private static let axMessagingTimeoutSeconds: Float = 0.5

    @MainActor
    public static func focus(windowID: CGWindowID, pid: pid_t, axWindow: AXUIElement?, usePrivate: Bool) {
        let didPrivate = usePrivate && privateFocus(windowID: windowID)

        let raised: Bool
        if didPrivate {
            raised = raise(axWindow)
        } else {
            let appElement = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(appElement, axMessagingTimeoutSeconds)
            AXUIElementSetAttributeValue(appElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            raised = raise(axWindow)
            NSRunningApplication(processIdentifier: pid)?.activate()
        }

        focusLog.info("focus wid=\(windowID) pid=\(pid) didPrivate=\(didPrivate) raised=\(raised)")
    }

    private static func raise(_ axWindow: AXUIElement?) -> Bool {
        guard let axWindow else { return false }
        AXUIElementSetMessagingTimeout(axWindow, axMessagingTimeoutSeconds)
        return AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString) == .success
    }

    /// Private success means the full front + make-key sequence landed: both the
    /// front switch and each make-key post returned `.success`. A missing post
    /// symbol is not a success either — that degrades to the public fallback.
    private static func privateFocus(windowID: CGWindowID) -> Bool {
        let symbols = SkyLightSymbols.shared
        guard let setFront = symbols.setFrontProcessWithOptions, let post = symbols.postEventRecordTo else { return false }
        guard var psn = processSerialNumber(forWindow: windowID) else { return false }

        return withUnsafePointer(to: &psn) { psnPtr -> Bool in
            let raw = UnsafeRawPointer(psnPtr)
            guard setFront(raw, windowID, kCPSUserGenerated) == .success else { return false }
            return postMakeKey(windowID: windowID, psn: raw, post: post)
        }
    }

    /// Replicates AltTab's `makeKeyWindow`: a 0xf8-byte event record with the
    /// window id at 0x3c and 16 bytes of 0xff at 0x20, posted twice (mode 0x02
    /// then 0x01). Bubbles up whether both posts succeeded.
    private static func postMakeKey(windowID: CGWindowID, psn: UnsafeRawPointer, post: PostEventRecordFn) -> Bool {
        var bytes = [UInt8](repeating: 0, count: 0xF8)
        bytes[0x04] = 0xF8
        bytes[0x08] = 0x01
        bytes[0x3A] = 0x10
        bytes[0x3C] = UInt8(windowID & 0xFF)
        bytes[0x3D] = UInt8((windowID >> 8) & 0xFF)
        bytes[0x3E] = UInt8((windowID >> 16) & 0xFF)
        bytes[0x3F] = UInt8((windowID >> 24) & 0xFF)
        for i in 0x20 ..< 0x30 { bytes[i] = 0xFF }

        bytes[0x08] = 0x02
        let secondPostSucceeded = bytes.withUnsafeMutableBytes { post(psn, $0.baseAddress!) } == .success
        bytes[0x08] = 0x01
        let firstPostSucceeded = bytes.withUnsafeMutableBytes { post(psn, $0.baseAddress!) } == .success
        return secondPostSucceeded && firstPostSucceeded
    }

    /// Derive a window's owning process PSN via the window server: the main
    /// connection → window's owner connection (`SLSGetWindowOwner`) → that
    /// connection's PSN (`SLSGetConnectionPSN`). Replaces the removed
    /// `GetProcessForPID` on macOS 26.
    private static func processSerialNumber(forWindow windowID: CGWindowID) -> ProcessSerialNumber? {
        let symbols = SkyLightSymbols.shared
        guard let getOwner = symbols.getWindowOwner, let getPSN = symbols.getConnectionPSN else { return nil }
        let cid = symbols.connectionID
        var ownerCID: Int32 = 0
        guard getOwner(cid, windowID, &ownerCID) == .success, ownerCID != 0 else { return nil }
        var psn = ProcessSerialNumber()
        guard getPSN(ownerCID, &psn) == .success else { return nil }
        return psn
    }
}
