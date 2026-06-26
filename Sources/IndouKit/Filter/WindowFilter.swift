import CoreGraphics
import Foundation

/// The per-profile rules that decide which collected windows are shown, and in
/// what order. Persisted as part of a `ShortcutProfile`.
public struct WindowFilterCriteria: Codable, Sendable, Equatable {
    public var appsToShow: AppsToShow
    public var spacesToShow: SpacesToShow
    public var screensToShow: ScreensToShow

    public var minimized: ShowHow
    public var hidden: ShowHow
    public var fullscreen: ShowHow

    public var groupTabs: GroupTabs
    public var windowOrder: WindowOrder

    public var minWidth: CGFloat
    public var minHeight: CGFloat

    public init(
        appsToShow: AppsToShow = .all,
        spacesToShow: SpacesToShow = .all,
        screensToShow: ScreensToShow = .all,
        minimized: ShowHow = .show,
        hidden: ShowHow = .show,
        fullscreen: ShowHow = .show,
        groupTabs: GroupTabs = .combined,
        windowOrder: WindowOrder = .recentlyFocused,
        minWidth: CGFloat = 0,
        minHeight: CGFloat = 0
    ) {
        self.appsToShow = appsToShow
        self.spacesToShow = spacesToShow
        self.screensToShow = screensToShow
        self.minimized = minimized
        self.hidden = hidden
        self.fullscreen = fullscreen
        self.groupTabs = groupTabs
        self.windowOrder = windowOrder
        self.minWidth = minWidth
        self.minHeight = minHeight
    }
}

/// Runtime facts the resolver needs that are not part of the persisted criteria.
public struct FilterContext: Sendable {
    public var activeAppPID: pid_t?
    public var visibleSpaceIDs: Set<SpaceID>
    public var switcherDisplayID: DisplayID?

    public init(activeAppPID: pid_t? = nil, visibleSpaceIDs: Set<SpaceID> = [], switcherDisplayID: DisplayID? = nil) {
        self.activeAppPID = activeAppPID
        self.visibleSpaceIDs = visibleSpaceIDs
        self.switcherDisplayID = switcherDisplayID
    }
}

/// Applies a `WindowFilterCriteria` (+ exceptions + runtime context) to a raw
/// window list and produces the ordered list the switcher shows. Pure: same
/// inputs always yield the same output, so it is unit-tested in isolation.
public struct WindowFilterResolver: Sendable {
    public init() {}

    public func resolve(
        windows: [WindowState],
        criteria: WindowFilterCriteria,
        context: FilterContext = .init(),
        matcher: ExceptionMatcher = .init()
    ) -> [WindowState] {
        // Count only open (non-minimized, non-hidden) windows per app so the
        // `.whenNoOpenWindow` exception can hide apps whose windows are all minimized.
        let appOpenWindowCounts = Dictionary(grouping: windows.filter { !$0.isMinimized && !$0.isHidden }, by: \.pid).mapValues(\.count)

        var head: [WindowState] = []
        var tail: [WindowState] = []
        var appEntries: [WindowState] = []

        for window in windows {
            guard passesSize(window, criteria) else { continue }
            guard passesApps(window, criteria, context) else { continue }
            guard passesSpaces(window, criteria, context) else { continue }
            guard passesScreens(window, criteria, context) else { continue }
            if matcher.shouldHide(window, appWindowCount: appOpenWindowCounts[window.pid] ?? 0) { continue }
            if criteria.groupTabs == .combined, window.kind == .tab { continue }

            // Background-app stand-ins always sort after every real window.
            if window.isAppEntry {
                appEntries.append(window)
                continue
            }

            switch categoryDisposition(window, criteria) {
            case .exclude: continue
            case .head: head.append(window)
            case .tail: tail.append(window)
            }
        }

        return sorted(head, by: criteria.windowOrder)
            + sorted(tail, by: criteria.windowOrder)
            + sorted(appEntries, by: .alphabetical)
    }

    // MARK: - Predicates

    private func passesSize(_ w: WindowState, _ c: WindowFilterCriteria) -> Bool {
        // Minimized / off-screen windows often report a zero frame; don't size-gate those.
        if w.isMinimized || w.frame == .zero { return true }
        return w.frame.width >= c.minWidth && w.frame.height >= c.minHeight
    }

    private func passesApps(_ w: WindowState, _ c: WindowFilterCriteria, _ ctx: FilterContext) -> Bool {
        switch c.appsToShow {
        case .all: return true
        case .active: return w.pid == ctx.activeAppPID
        case .nonActive: return w.pid != ctx.activeAppPID
        }
    }

    private func passesSpaces(_ w: WindowState, _ c: WindowFilterCriteria, _ ctx: FilterContext) -> Bool {
        if w.isOnAllSpaces { return true }
        // No space data available → don't filter on it (best-effort degradation).
        if w.spaceIDs.isEmpty || ctx.visibleSpaceIDs.isEmpty { return true }
        let onVisible = !ctx.visibleSpaceIDs.isDisjoint(with: Set(w.spaceIDs))
        switch c.spacesToShow {
        case .all: return true
        case .visible: return onVisible
        case .nonVisible: return !onVisible
        }
    }

    private func passesScreens(_ w: WindowState, _ c: WindowFilterCriteria, _ ctx: FilterContext) -> Bool {
        switch c.screensToShow {
        case .all: return true
        case .showingSwitcher:
            guard let target = ctx.switcherDisplayID else { return true }
            guard let display = w.displayID else { return true }
            return display == target
        }
    }

    private enum Disposition { case exclude, head, tail }

    private func categoryDisposition(_ w: WindowState, _ c: WindowFilterCriteria) -> Disposition {
        func apply(_ how: ShowHow) -> Disposition {
            switch how {
            case .show: return .head
            case .hide: return .exclude
            case .showAtTheEnd: return .tail
            }
        }
        if w.isMinimized { return apply(c.minimized) }
        if w.isHidden { return apply(c.hidden) }
        if w.isFullscreen { return apply(c.fullscreen) }
        return .head
    }

    // MARK: - Ordering

    private func sorted(_ windows: [WindowState], by order: WindowOrder) -> [WindowState] {
        switch order {
        case .recentlyFocused:
            return windows.sorted { $0.lastFocusOrder > $1.lastFocusOrder }
        case .recentlyCreated:
            return windows.sorted { $0.creationOrder > $1.creationOrder }
        case .alphabetical:
            return windows.sorted { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
        case .space:
            return windows.sorted {
                let a = $0.spaceIDs.first ?? Int.max
                let b = $1.spaceIDs.first ?? Int.max
                if a != b { return a < b }
                return $0.lastFocusOrder > $1.lastFocusOrder
            }
        }
    }
}
