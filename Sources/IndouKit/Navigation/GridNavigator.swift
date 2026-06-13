import Foundation

public enum GridDirection: Sendable {
    case up, down, left, right
}

/// Pure index math for moving a cursor across a row-major grid of `count` cells
/// laid out in `columns` columns. Tab / Shift-Tab cycle linearly (wrapping);
/// arrow keys move in 2D and clamp at the edges. Stateless and fully testable.
public enum GridNavigator {
    /// Linear next (Tab). Wraps from last to first.
    public static func next(from index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (index + 1) % count
    }

    /// Linear previous (Shift-Tab). Wraps from first to last.
    public static func previous(from index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (index - 1 + count) % count
    }

    /// 2D arrow movement. Clamps at the grid edges (no wraparound) and never
    /// lands on an empty trailing cell of a partial last row.
    public static func move(from index: Int, _ direction: GridDirection, columns: Int, count: Int) -> Int {
        guard count > 0, columns > 0 else { return 0 }
        let clamped = min(max(index, 0), count - 1)
        let row = clamped / columns
        let col = clamped % columns

        switch direction {
        case .left:
            return col > 0 ? clamped - 1 : clamped
        case .right:
            return (col < columns - 1 && clamped + 1 < count) ? clamped + 1 : clamped
        case .up:
            return row > 0 ? clamped - columns : clamped
        case .down:
            let candidate = clamped + columns
            return candidate < count ? candidate : clamped
        }
    }
}
