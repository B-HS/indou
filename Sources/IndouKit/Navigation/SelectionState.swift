import Foundation

/// Tracks the switcher's cursor (single focused cell) plus an optional
/// multi-selection set used for the drag-marquee / right-click batch actions.
/// Index-based focus for keyboard nav, id-based multi-selection so it survives
/// list reordering between captures.
public struct SelectionState: Sendable, Equatable {
    public private(set) var focusedIndex: Int
    public private(set) var multiSelected: Set<WindowID>

    public init(focusedIndex: Int = 0, multiSelected: Set<WindowID> = []) {
        self.focusedIndex = focusedIndex
        self.multiSelected = multiSelected
    }

    public var hasMultiSelection: Bool { !multiSelected.isEmpty }

    public mutating func setFocus(_ index: Int) {
        focusedIndex = index
    }

    public func isMultiSelected(_ id: WindowID) -> Bool {
        multiSelected.contains(id)
    }

    public mutating func toggleMultiSelection(_ id: WindowID) {
        if multiSelected.contains(id) {
            multiSelected.remove(id)
        } else {
            multiSelected.insert(id)
        }
    }

    public mutating func setMultiSelection(_ ids: Set<WindowID>) {
        multiSelected = ids
    }

    public mutating func addMultiSelection(_ ids: some Sequence<WindowID>) {
        multiSelected.formUnion(ids)
    }

    public mutating func clearMultiSelection() {
        multiSelected.removeAll(keepingCapacity: true)
    }

    /// The set of windows a batch action should target: the explicit multi-selection
    /// if any, otherwise just the focused window (resolved against the current list).
    public func actionTargets(in windows: [WindowState]) -> [WindowID] {
        if !multiSelected.isEmpty {
            return windows.map(\.id).filter { multiSelected.contains($0) }
        }
        guard windows.indices.contains(focusedIndex) else { return [] }
        return [windows[focusedIndex].id]
    }
}
