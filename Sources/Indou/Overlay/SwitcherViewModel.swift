import AppKit
import IndouKit
import Observation

/// Batch actions offered from the right-click context menu.
enum ContextAction {
    case focus
    case close
    case minimize
    case quitApp
}

/// Observable state the switcher grid renders. The controller owns the logic and
/// mutates this; the view reports user intent (hover/click/marquee/menu) back via
/// the closures.
@MainActor
@Observable
final class SwitcherViewModel {
    var windows: [WindowState] = []
    var selectedIndex = 0
    var multiSelected: Set<WindowID> = []
    var columns = 5
    var cellSize = CGSize(width: 220, height: 150)

    var appearance = AppearanceSettings()
    var animationEnabled = true
    var multiSelectEnabled = false
    var searchQuery = ""

    @ObservationIgnored let thumbnails: ThumbnailStore

    @ObservationIgnored var onHover: ((Int) -> Void)?
    @ObservationIgnored var onClick: ((Int, _ additive: Bool) -> Void)?
    @ObservationIgnored var onCommit: (() -> Void)?
    @ObservationIgnored var onMarquee: ((Set<WindowID>) -> Void)?
    @ObservationIgnored var onContext: ((ContextAction, [WindowID]) -> Void)?
    @ObservationIgnored var onCloseWindow: ((WindowID) -> Void)?
    @ObservationIgnored var onMinimizeWindow: ((WindowID) -> Void)?
    @ObservationIgnored var onFullscreenWindow: ((WindowID) -> Void)?

    init(thumbnails: ThumbnailStore) {
        self.thumbnails = thumbnails
    }

    var selectedWindow: WindowState? {
        windows.indices.contains(selectedIndex) ? windows[selectedIndex] : nil
    }

    /// The target ids for a context action on `id`: the whole multi-selection if
    /// the clicked cell is part of it, otherwise just that cell.
    func contextTargets(for id: WindowID) -> [WindowID] {
        if multiSelected.contains(id) {
            return windows.map(\.id).filter { multiSelected.contains($0) }
        }
        return [id]
    }
}
