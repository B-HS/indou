import Testing
@testable import IndouKit

@Suite("WindowFilterResolver")
struct WindowFilterTests {
    private func sample() -> [WindowState] {
        [
            WindowState(id: 1, title: "A", appName: "Finder", pid: 100, spaceIDs: [1], displayID: 1, lastFocusOrder: 5),
            WindowState(id: 2, title: "B", appName: "Safari", pid: 200, spaceIDs: [1], displayID: 1, lastFocusOrder: 4),
            WindowState(id: 3, title: "C", appName: "Notes", pid: 300, isMinimized: true, spaceIDs: [2], displayID: 1, lastFocusOrder: 3),
            WindowState(id: 4, title: "D", appName: "Mail", pid: 400, spaceIDs: [2], displayID: 2, lastFocusOrder: 2),
        ]
    }

    @Test("appsToShow=active 는 활성 앱만")
    func appsActive() {
        let c = WindowFilterCriteria(appsToShow: .active)
        let ctx = FilterContext(activeAppPID: 200)
        let r = WindowFilterResolver().resolve(windows: sample(), criteria: c, context: ctx)
        #expect(r.map(\.id) == [2])
    }

    @Test("appsToShow=nonActive 는 활성 앱 제외")
    func appsNonActive() {
        let c = WindowFilterCriteria(appsToShow: .nonActive)
        let ctx = FilterContext(activeAppPID: 200)
        let r = WindowFilterResolver().resolve(windows: sample(), criteria: c, context: ctx)
        #expect(!r.map(\.id).contains(2))
        #expect(r.count == 3)
    }

    @Test("minimized=hide 는 최소화 윈도우 제외")
    func minimizedHide() {
        let c = WindowFilterCriteria(minimized: .hide)
        let r = WindowFilterResolver().resolve(windows: sample(), criteria: c)
        #expect(!r.map(\.id).contains(3))
    }

    @Test("minimized=showAtTheEnd 는 끝으로")
    func minimizedAtEnd() {
        let c = WindowFilterCriteria(minimized: .showAtTheEnd, windowOrder: .recentlyFocused)
        let r = WindowFilterResolver().resolve(windows: sample(), criteria: c)
        #expect(r.last?.id == 3)
    }

    @Test("spacesToShow=visible 는 보이는 Space만")
    func spacesVisible() {
        let c = WindowFilterCriteria(spacesToShow: .visible)
        let ctx = FilterContext(visibleSpaceIDs: [1])
        let r = WindowFilterResolver().resolve(windows: sample(), criteria: c, context: ctx)
        #expect(Set(r.map(\.id)) == [1, 2])
    }

    @Test("screensToShow=showingSwitcher 는 해당 디스플레이만")
    func screensSwitcher() {
        let c = WindowFilterCriteria(screensToShow: .showingSwitcher)
        let ctx = FilterContext(switcherDisplayID: 2)
        let r = WindowFilterResolver().resolve(windows: sample(), criteria: c, context: ctx)
        #expect(r.map(\.id) == [4])
    }

    @Test("alphabetical 정렬")
    func alphabetical() {
        let c = WindowFilterCriteria(windowOrder: .alphabetical)
        let r = WindowFilterResolver().resolve(windows: sample(), criteria: c)
        #expect(r.map(\.title) == ["A", "B", "C", "D"])
    }

    @Test("recentlyFocused 정렬 (lastFocusOrder 내림차순)")
    func mru() {
        let c = WindowFilterCriteria(windowOrder: .recentlyFocused)
        let r = WindowFilterResolver().resolve(windows: sample(), criteria: c)
        #expect(r.map(\.id) == [1, 2, 3, 4])
    }

    @Test("앱 엔트리는 MRU 가 높아도 항상 맨 뒤")
    func appEntriesAlwaysLast() {
        let windows = [
            WindowState(id: 100, appName: "Background", pid: 99, isAppEntry: true, lastFocusOrder: 999),
            WindowState(id: 1, appName: "Real A", pid: 1, lastFocusOrder: 1),
            WindowState(id: 2, appName: "Real B", pid: 2, lastFocusOrder: 2),
        ]
        let r = WindowFilterResolver().resolve(windows: windows, criteria: WindowFilterCriteria(windowOrder: .recentlyFocused))
        // 실제 창이 MRU 순으로 먼저, 앱 엔트리는 lastFocusOrder 999 라도 맨 뒤
        #expect(r.map(\.id) == [2, 1, 100])
    }
}

@Suite("ExceptionMatcher blacklist")
struct ExceptionMatcherTests {
    @Test("hide=always 는 항상 숨김")
    func hideAlways() {
        let m = ExceptionMatcher(rules: [ExceptionRule(bundleIDPrefix: "com.apple.Safari", hide: .always)])
        let w = WindowState(id: 1, appBundleID: "com.apple.Safari")
        #expect(m.shouldHide(w, appWindowCount: 3))
    }

    @Test("hide=whenTitleMatches 는 타이틀 포함 시만")
    func hideWhenTitle() {
        let m = ExceptionMatcher(rules: [ExceptionRule(bundleIDPrefix: "com.x", titleContains: "Secret", hide: .whenTitleMatches)])
        #expect(m.shouldHide(WindowState(id: 1, title: "My Secret Doc", appBundleID: "com.x.app"), appWindowCount: 1))
        #expect(!m.shouldHide(WindowState(id: 2, title: "Public", appBundleID: "com.x.app"), appWindowCount: 1))
    }

    @Test("ignoreShortcut=whenFullscreen")
    func ignoreWhenFullscreen() {
        let m = ExceptionMatcher(rules: [ExceptionRule(bundleIDPrefix: "com.game", ignoreShortcut: .whenFullscreen)])
        #expect(m.shouldIgnoreShortcut(bundleID: "com.game.x", isFullscreen: true))
        #expect(!m.shouldIgnoreShortcut(bundleID: "com.game.x", isFullscreen: false))
    }

    @Test("hide=whenNoOpenWindow: 모든 창이 최소화면 숨김")
    func hideWhenNoOpenWindow() {
        let m = ExceptionMatcher(rules: [ExceptionRule(bundleIDPrefix: "com.ghost", hide: .whenNoOpenWindow)])
        let windows = [
            WindowState(id: 1, appName: "Ghost", appBundleID: "com.ghost.app", pid: 10, isMinimized: true),
            WindowState(id: 2, appName: "Open", appBundleID: "com.open.app", pid: 20),
        ]
        let r = WindowFilterResolver().resolve(windows: windows, criteria: WindowFilterCriteria(), matcher: m)
        #expect(!r.map(\.id).contains(1))
        #expect(r.map(\.id).contains(2))
    }

    @Test("hide=whenNoOpenWindow: 열린 창이 있으면 유지")
    func keepWhenHasOpenWindow() {
        let m = ExceptionMatcher(rules: [ExceptionRule(bundleIDPrefix: "com.ghost", hide: .whenNoOpenWindow)])
        let windows = [
            WindowState(id: 1, appName: "Ghost", appBundleID: "com.ghost.app", pid: 10, isMinimized: true),
            WindowState(id: 3, appName: "Ghost", appBundleID: "com.ghost.app", pid: 10),
        ]
        let r = WindowFilterResolver().resolve(windows: windows, criteria: WindowFilterCriteria(), matcher: m)
        #expect(r.map(\.id).contains(1))
        #expect(r.map(\.id).contains(3))
    }
}
