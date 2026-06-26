import AppKit
import IndouKit
import PrivateWindowServer

/// Orchestrates the whole switcher: global key tap → session lifecycle →
/// enumerate + filter → overlay → navigate → commit/focus. Holds the live AX
/// elements and the MRU order; the pure decisions live in `IndouKit`.
@MainActor
final class SwitcherController {
    private let store: PreferenceStore
    private let enumerator = WindowEnumerator()
    private let thumbnails = ThumbnailStore()
    private let resolver = WindowFilterResolver()
    private let model: SwitcherViewModel
    private let panel: SwitcherPanel
    private let backdrop = BackdropWindow()
    private let eventTap = EventTapController()

    private var liveByID: [WindowID: LiveWindow] = [:]
    private var sessionActive = false
    private var persistent = false
    private var windowsLoaded = false
    private var pendingSteps = 0
    private var pendingCommit = false
    private var activeProfile: ShortcutProfile?

    private var sessionGeneration = 0

    private var orderCounter = 0
    private var appActivationOrder: [pid_t: Int] = [:]
    private var windowFocusOrder: [WindowID: Int] = [:]
    private var lastFocusedWindow: (id: WindowID, pid: pid_t)?
    private var activationObserver: NSObjectProtocol?

    init(store: PreferenceStore) {
        self.store = store
        model = SwitcherViewModel(thumbnails: thumbnails)
        panel = SwitcherPanel(model: model)
        backdrop.onClick = { [weak self] in self?.closeSession(commit: false) }
        wireModel()
        wireEventTap()
    }

    func start() {
        eventTap.start()
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                self.orderCounter += 1
                self.appActivationOrder[app.processIdentifier] = self.orderCounter
                // This activation fires right after commit() focuses a window; keep
                // that window ranked above its own app's siblings (which would
                // otherwise inherit the just-bumped per-app order).
                if let last = self.lastFocusedWindow, last.pid == app.processIdentifier {
                    self.orderCounter += 1
                    self.windowFocusOrder[last.id] = self.orderCounter
                }
            }
        }
        // The CGEventTap is invalidated/disabled across sleep, display reconfig,
        // and fast user switching — recreate it on those events so the hotkey
        // keeps working after wake.
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.closeSession(commit: false)
                    self?.restartEventTap()
                    self?.applyNativeCommandTab()
                    Log.hotkey.info("recovered event tap after system event")
                }
            }
        }
        applyNativeCommandTab()
    }

    var isEventTapRunning: Bool { eventTap.isRunning }
    func restartEventTap() { eventTap.stop(); eventTap.start() }

    /// While recording a shortcut in Settings, pass all keys through so the
    /// recorder field can capture them instead of triggering the switcher.
    var isRecordingShortcut = false

    // MARK: - Native ⌘Tab

    /// Apply the persisted "disable native ⌘Tab" setting (called on launch).
    func applyNativeCommandTab() {
        NativeHotkeyResolver.setNativeCommandTabEnabled(!store.settings.advanced.disableNativeCmdTab)
    }

    /// Live toggle from Settings: persist and apply immediately.
    func setDisableNativeCmdTab(_ disabled: Bool) {
        store.update { $0.advanced.disableNativeCmdTab = disabled }
        NativeHotkeyResolver.setNativeCommandTabEnabled(!disabled)
    }

    /// Re-enable the native switcher (call on quit so we never leave ⌘Tab off).
    func restoreNativeCommandTab() {
        if store.settings.advanced.disableNativeCmdTab {
            NativeHotkeyResolver.setNativeCommandTabEnabled(true)
        }
    }

    // MARK: - Event wiring

    private func wireEventTap() {
        eventTap.onKeyDown = { [weak self] modifiers, keyCode in
            self?.handleKeyDown(modifiers: modifiers, keyCode: keyCode) ?? false
        }
        eventTap.onFlagsChanged = { [weak self] modifiers in
            self?.handleFlagsChanged(modifiers)
        }
    }

    private func wireModel() {
        model.onHover = { [weak self] index in
            guard let self, self.store.settings.input.mouseHoverEnabled else { return }
            self.model.selectedIndex = index
        }
        model.onClick = { [weak self] index, additive in
            guard let self else { return }
            self.model.selectedIndex = index
            if additive {
                guard let id = self.model.selectedWindow?.id else { return }
                self.model.multiSelected.formSymmetricDifference([id])
            } else {
                self.commit()
            }
        }
        model.onCommit = { [weak self] in self?.commit() }
        model.onMarquee = { [weak self] ids in self?.model.multiSelected = ids }
        model.onContext = { [weak self] action, targets in self?.performContext(action, targets: targets) }
        model.onCloseWindow = { [weak self] id in self?.closeWindow(id) }
        model.onMinimizeWindow = { [weak self] id in self?.windowAction(id) { WindowActions.setMinimized($0, true) } }
        model.onFullscreenWindow = { [weak self] id in self?.windowAction(id) { WindowActions.toggleFullscreen($0) } }
    }

    // MARK: - Keyboard

    private func handleKeyDown(modifiers: ModifierFlags, keyCode: UInt16) -> Bool {
        if isRecordingShortcut { return false }
        if !sessionActive {
            guard let profile = ShortcutMatcher.firstMatch(in: store.settings.profiles, modifiers: modifiers, keyCode: keyCode) else {
                return false
            }
            if shouldYieldToNativeShortcut() { return false }
            openSession(profile: profile, reverse: ShortcutMatcher.isReverse(profile, modifiers: modifiers))
            return true
        }

        // Session is active — handle navigation / actions, swallow everything.
        guard let profile = activeProfile else { return true }

        if keyCode == profile.nextKey {
            advance(reverse: ShortcutMatcher.isReverse(profile, modifiers: modifiers))
            return true
        }

        switch keyCode {
        case KeyCode.escape:
            closeSession(commit: false)
        case KeyCode.return, KeyCode.enter:
            commit()
        case KeyCode.space:
            persistent.toggle()
        case KeyCode.arrowLeft where store.settings.input.arrowKeysEnabled:
            move(.left)
        case KeyCode.arrowRight where store.settings.input.arrowKeysEnabled:
            move(.right)
        case KeyCode.arrowUp where store.settings.input.arrowKeysEnabled:
            move(.up)
        case KeyCode.arrowDown where store.settings.input.arrowKeysEnabled:
            move(.down)
        case KeyCode.keyH where store.settings.input.vimKeysEnabled:
            move(.left)
        case KeyCode.keyL where store.settings.input.vimKeysEnabled:
            move(.right)
        case KeyCode.keyK where store.settings.input.vimKeysEnabled:
            move(.up)
        case KeyCode.keyJ where store.settings.input.vimKeysEnabled:
            move(.down)
        case KeyCode.w:
            actionOnSelected { WindowActions.close($0) }
        case KeyCode.m:
            actionOnSelected { WindowActions.toggleMinimized($0) }
        case KeyCode.f:
            actionOnSelected { WindowActions.toggleFullscreen($0) }
        case KeyCode.q:
            if let pid = model.selectedWindow?.pid { WindowActions.quitApp(pid: pid) }
            closeSession(commit: false)
        default:
            break
        }
        return true
    }

    private func handleFlagsChanged(_ modifiers: ModifierFlags) {
        guard sessionActive, !persistent, let profile = activeProfile else { return }
        if ShortcutMatcher.holdReleased(profile, currentModifiers: modifiers) {
            Log.hotkey.info("hold released → commit")
            commit()
        }
    }

    // MARK: - Session lifecycle

    private func openSession(profile: ShortcutProfile, reverse: Bool) {
        sessionActive = true
        persistent = false
        windowsLoaded = false
        pendingCommit = false
        // New session id so a still-pending reload Task from a prior session bails
        // instead of clobbering this one's results.
        sessionGeneration += 1
        let generation = sessionGeneration
        // Opening already advances one step, like the classic alt-tab tap: forward
        // pre-selects the previous window (index 1 after MRU sort), reverse the last
        // (index count-1). Subsequent Tab presses advance from there.
        pendingSteps = reverse ? -1 : 1
        activeProfile = profile
        // Drop the previous session's snapshot so a pre-load commit can never act on
        // a stale window / dead AX element, and so thumbnails are re-captured fresh.
        model.windows = []
        model.selectedIndex = 0
        liveByID = [:]
        model.multiSelected = []
        model.searchQuery = ""
        thumbnails.clear()

        Task { await loadWindows(for: profile, preserveSelection: false, generation: generation) }
    }

    private func loadWindows(for profile: ShortcutProfile, preserveSelection: Bool, generation: Int) async {
        await thumbnails.refreshContent()
        let live = await enumerator.enumerate()

        liveByID = Dictionary(live.map { ($0.state.id, $0) }, uniquingKeysWith: { a, _ in a })
        IconProvider.shared.prune(keeping: Set(live.map { $0.state.pid }))

        let ranked = live.map { applyOrder(to: $0.state) }
        let context = FilterContext(
            activeAppPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
            visibleSpaceIDs: store.settings.advanced.usePrivateSpaceAPIs ? SpaceQuery.visibleSpaceIDs() : [],
            switcherDisplayID: nil
        )
        let matcher = ExceptionMatcher(rules: store.settings.exceptions)
        let filtered = resolver.resolve(windows: ranked, criteria: profile.filter, context: context, matcher: matcher)

        // Bail if the session ended or a newer one started while we were awaiting.
        guard sessionActive, generation == sessionGeneration else { return }

        model.appearance = store.settings.appearance
        model.animationEnabled = store.settings.animation.enabled && !reduceMotionActive()
        model.windows = filtered
        windowsLoaded = true

        let count = filtered.count
        guard count > 0 else { closeSession(commit: false); return }
        if preserveSelection {
            model.selectedIndex = min(max(0, model.selectedIndex), count - 1)
        } else {
            model.selectedIndex = ((pendingSteps % count) + count) % count
        }

        // The modifier was released before the list was ready — focus the resolved
        // selection now instead of dropping the switch.
        if pendingCommit {
            pendingCommit = false
            commit()
            return
        }

        layoutAndPresent(count: count)
    }

    private func layoutAndPresent(count: Int) {
        let screen = resolveScreen()
        let (cell, columns, panelSize) = Layout.compute(
            count: count,
            size: store.settings.appearance.size,
            preferredColumns: store.settings.appearance.columns,
            manualHeight: store.settings.appearance.manualCellHeight,
            visible: screen.visibleFrame
        )
        model.cellSize = cell
        model.columns = columns
        backdrop.present()
        panel.present(on: screen, size: panelSize)
        thumbnails.requestThumbnails(
            for: model.windows.map(\.id),
            pointSize: CGSize(width: cell.width - DS.Spacing.md, height: cell.height - 44),
            scale: screen.backingScaleFactor
        )
    }

    private func advance(reverse: Bool) {
        guard windowsLoaded else { pendingSteps += reverse ? -1 : 1; return }
        let count = model.windows.count
        guard count > 0 else { return }
        model.selectedIndex = reverse
            ? GridNavigator.previous(from: model.selectedIndex, count: count)
            : GridNavigator.next(from: model.selectedIndex, count: count)
    }

    private func move(_ direction: GridDirection) {
        guard windowsLoaded else { return }
        model.selectedIndex = GridNavigator.move(
            from: model.selectedIndex,
            direction,
            columns: model.columns,
            count: model.windows.count
        )
    }

    private func commit() {
        // Released before the window list finished loading: defer the focus until
        // loadWindows resolves the selection, mirroring advance()'s pendingSteps
        // buffering, instead of dropping the switch.
        guard windowsLoaded else { pendingCommit = true; return }
        defer { closeSession(commit: true) }
        guard let selected = model.selectedWindow, let live = liveByID[selected.id] else {
            Log.windows.error("commit: no selected window (index=\(self.model.selectedIndex) count=\(self.model.windows.count))")
            return
        }
        Log.windows.info("commit focus '\(selected.title)' (\(selected.appName)) wid=\(selected.id)")
        orderCounter += 1
        windowFocusOrder[selected.id] = orderCounter
        lastFocusedWindow = (selected.id, selected.pid)
        WindowActions.focus(live, usePrivateFocus: store.settings.advanced.usePreciseFocus)
    }

    private func closeSession(commit _: Bool) {
        guard sessionActive else { return }
        sessionActive = false
        persistent = false
        windowsLoaded = false
        pendingCommit = false
        // Invalidate any reload Task still in flight for this session.
        sessionGeneration += 1
        panel.dismiss()
        backdrop.dismiss()
        model.multiSelected = []
    }

    // MARK: - Context (mouse) actions

    private func performContext(_ action: ContextAction, targets: [WindowID]) {
        let live = targets.compactMap { liveByID[$0] }
        switch action {
        case .focus:
            if let first = live.first { WindowActions.focus(first, usePrivateFocus: store.settings.advanced.usePreciseFocus) }
            closeSession(commit: true)
        case .close:
            WindowActions.closeAll(live)
            refreshAfterAction()
        case .minimize:
            WindowActions.minimizeAll(live)
            refreshAfterAction()
        case .quitApp:
            WindowActions.quitApps(live)
            refreshAfterAction()
        }
    }

    private func actionOnSelected(_ body: (LiveWindow) -> Void) {
        guard let selected = model.selectedWindow, let live = liveByID[selected.id] else { return }
        body(live)
        refreshAfterAction()
    }

    private func closeWindow(_ id: WindowID) {
        guard let live = liveByID[id] else { return }
        WindowActions.close(live)
        refreshAfterAction()
    }

    private func windowAction(_ id: WindowID, _ body: (LiveWindow) -> Void) {
        guard let live = liveByID[id] else { return }
        body(live)
        refreshAfterAction()
    }

    private func refreshAfterAction() {
        guard sessionActive, let profile = activeProfile else { return }
        // Re-enumerate after a short delay so the closed/minimized window is gone,
        // keeping the current cursor position.
        let generation = sessionGeneration
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            await loadWindows(for: profile, preserveSelection: true, generation: generation)
        }
    }

    // MARK: - Ordering / helpers

    private func applyOrder(to state: WindowState) -> WindowState {
        var s = state
        s.lastFocusOrder = windowFocusOrder[state.id] ?? appActivationOrder[state.pid] ?? 0
        return s
    }

    private func shouldYieldToNativeShortcut() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication else { return false }
        let matcher = ExceptionMatcher(rules: store.settings.exceptions)
        return matcher.shouldIgnoreShortcut(bundleID: front.bundleIdentifier, isFullscreen: false)
    }

    private func resolveScreen() -> NSScreen {
        switch store.settings.general.showOnScreen {
        case .includingMouse:
            let mouse = NSEvent.mouseLocation
            return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        case .active:
            return NSScreen.main ?? NSScreen.screens[0]
        case .includingMenubar:
            return NSScreen.screens.first ?? NSScreen.screens[0]
        }
    }

    private func reduceMotionActive() -> Bool {
        store.settings.animation.respectReduceMotion &&
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}
