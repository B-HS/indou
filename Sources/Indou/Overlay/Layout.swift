import CoreGraphics
import IndouKit

/// Computes cell size, column count, and overall panel size for a given window
/// count and appearance size, fitting within the target screen.
enum Layout {
    static let spacing: CGFloat = 12
    static let padding: CGFloat = 16

    static func cellSize(for size: AppearanceSize, manualHeight: Int = 160) -> CGSize {
        switch size {
        case .small: return CGSize(width: 170, height: 120)
        case .medium: return CGSize(width: 220, height: 152)
        case .large: return CGSize(width: 300, height: 200)
        case .auto: return CGSize(width: 240, height: 164)
        case .manual:
            let h = CGFloat(min(max(80, manualHeight), 600))
            return CGSize(width: (h * 1.45).rounded(), height: h)
        }
    }

    static func compute(count: Int, size: AppearanceSize, preferredColumns: Int, manualHeight: Int, visible: CGRect) -> (cell: CGSize, columns: Int, panel: CGSize) {
        let cell = cellSize(for: size, manualHeight: manualHeight)
        let count = max(1, count)
        let maxByWidth = max(1, Int((visible.width * 0.86 - padding * 2) / (cell.width + spacing)))

        let columns: Int
        if preferredColumns > 0 {
            columns = min(preferredColumns, count)
        } else {
            let ideal = max(1, Int(ceil(Double(count).squareRoot() * 1.7)))
            columns = max(1, min(min(maxByWidth, count), ideal))
        }

        let rows = Int(ceil(Double(count) / Double(columns)))
        // n cells have (n-1) inter-cell gaps, plus the outer padding on both sides.
        let width = CGFloat(columns) * cell.width + CGFloat(max(0, columns - 1)) * spacing + padding * 2
        let heightRaw = CGFloat(rows) * cell.height + CGFloat(max(0, rows - 1)) * spacing + padding * 2
        let height = min(heightRaw, visible.height * 0.85)
        return (cell, columns, CGSize(width: width, height: height))
    }
}
