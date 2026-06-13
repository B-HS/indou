import AppKit
import CoreGraphics
import IndouKit

/// A global keyboard event tap that drives the whole switcher interaction:
/// detecting the trigger combo, cycling while the modifier is held, and
/// committing on release. While a session is active it swallows key events so
/// they never leak to the focused app. Self-heals if the system disables the tap.
@MainActor
final class EventTapController {
    /// Return `true` to swallow the key event.
    var onKeyDown: ((_ modifiers: ModifierFlags, _ keyCode: UInt16) -> Bool)?
    /// Called on every modifier change while running.
    var onFlagsChanged: ((_ modifiers: ModifierFlags) -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    func start() {
        guard tap == nil else { return }
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.callback,
            userInfo: refcon
        ) else {
            Log.hotkey.error("CGEvent.tapCreate failed (Accessibility permission?)")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        runLoopSource = source
        Log.hotkey.info("event tap started")
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        self.tap = nil
        runLoopSource = nil
    }

    fileprivate func reenable() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            Log.hotkey.info("event tap re-enabled after disable")
        }
    }

    // The tap is attached to the main run loop, so the callback fires on the main
    // thread. We read the (non-Sendable) CGEvent in this nonisolated context and
    // hop into MainActor with only Sendable primitives.
    private nonisolated static let callback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let controller = Unmanaged<EventTapController>.fromOpaque(refcon).takeUnretainedValue()

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            MainActor.assumeIsolated { controller.reenable() }
            return Unmanaged.passUnretained(event)

        case .flagsChanged:
            let modifiers = UInt(event.flags.rawValue)
            MainActor.assumeIsolated { controller.onFlagsChanged?(ModifierFlags(rawValue: modifiers)) }
            return Unmanaged.passUnretained(event)

        case .keyDown:
            let modifiers = UInt(event.flags.rawValue)
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let swallow = MainActor.assumeIsolated { controller.onKeyDown?(ModifierFlags(rawValue: modifiers), keyCode) ?? false }
            return swallow ? nil : Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
