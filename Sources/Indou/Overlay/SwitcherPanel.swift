import AppKit
import SwiftUI

/// The floating overlay window. A non-activating panel so it never steals focus
/// (keyboard arrives via the global event tap); shown above everything including
/// fullscreen apps, on all Spaces. Alpha is pre-staged to avoid flicker.
@MainActor
final class SwitcherPanel: NSPanel {
    private let hostingView: NSHostingView<SwitcherView>

    init(model: SwitcherViewModel) {
        hostingView = NSHostingView(rootView: SwitcherView(model: model))

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        animationBehavior = .none
        acceptsMouseMovedEvents = true
        isMovable = false

        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.frame = contentLayoutRect
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
        alphaValue = 0
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func present(on screen: NSScreen, size: CGSize) {
        let visible = screen.visibleFrame
        let clamped = CGSize(width: min(size.width, visible.width - 40), height: min(size.height, visible.height - 40))
        let origin = CGPoint(
            x: visible.midX - clamped.width / 2,
            y: visible.midY - clamped.height / 2
        )
        setFrame(CGRect(origin: origin, size: clamped), display: true)
        orderFrontRegardless()
        alphaValue = 1
    }

    func dismiss() {
        alphaValue = 0
        orderOut(nil)
    }
}
