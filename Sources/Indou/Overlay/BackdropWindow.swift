import AppKit

/// A transparent, click-catching window that spans every display just below the
/// switcher panel. Any click that lands on it is, by definition, outside the
/// switcher — so it dismisses the session. More reliable than a global event
/// monitor (which can miss same-display clicks).
@MainActor
final class BackdropWindow: NSPanel {
    var onClick: (() -> Void)?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue - 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        animationBehavior = .none

        let view = BackdropView()
        view.onClick = { [weak self] in self?.onClick?() }
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func present() {
        let union = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        setFrame(union.isNull ? (NSScreen.main?.frame ?? .zero) : union, display: false)
        orderFrontRegardless()
    }

    func dismiss() {
        orderOut(nil)
    }
}

private final class BackdropView: NSView {
    var onClick: (() -> Void)?
    override func mouseDown(with event: NSEvent) { onClick?() }
    override func rightMouseDown(with event: NSEvent) { onClick?() }
    override func otherMouseDown(with event: NSEvent) { onClick?() }
}
