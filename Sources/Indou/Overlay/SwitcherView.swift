import AppKit
import IndouKit
import SwiftUI

private struct CellFrameKey: PreferenceKey {
    static let defaultValue: [WindowID: CGRect] = [:]
    static func reduce(value: inout [WindowID: CGRect], nextValue: () -> [WindowID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, b in b })
    }
}

/// The switcher overlay grid. Renders cached thumbnails + app icons, draws the
/// keyboard selection ring, auto-scrolls to keep the selection visible, and
/// supports hover-select, click-commit, ⌘/⇧-click multi-select, drag-marquee,
/// per-cell close (red ×), and a right-click menu.
struct SwitcherView: View {
    @Bindable var model: SwitcherViewModel

    @State private var cellFrames: [WindowID: CGRect] = [:]
    @State private var marqueeRect: CGRect?

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(model.cellSize.width), spacing: DS.Spacing.md), count: max(1, model.columns))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: gridColumns, spacing: DS.Spacing.md) {
                    ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                        cell(index: index, window: window).id(window.id)
                    }
                }
                .padding(DS.Spacing.lg)
                .coordinateSpace(name: "grid")
                .overlay(alignment: .topLeading) { marqueeOverlay }
                .onPreferenceChange(CellFrameKey.self) { cellFrames = $0 }
                .simultaneousGesture(marqueeGesture)
            }
            .onChange(of: model.selectedIndex) { _, index in
                guard model.windows.indices.contains(index) else { return }
                let id = model.windows[index].id
                if model.animationEnabled {
                    withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo(id, anchor: .center) }
                } else {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func cell(index: Int, window: WindowState) -> some View {
        SwitcherCell(
            window: window,
            image: model.thumbnails.images[window.id],
            icon: IconProvider.shared.icon(for: window.pid),
            isSelected: index == model.selectedIndex,
            isMultiSelected: model.multiSelected.contains(window.id),
            appearance: model.appearance,
            cellSize: model.cellSize,
            animated: model.animationEnabled,
            onClose: { model.onCloseWindow?(window.id) }
        )
        .background(GeometryReader { geo in
            Color.clear.preference(key: CellFrameKey.self, value: [window.id: geo.frame(in: .named("grid"))])
        })
        .onHover { if $0 { model.onHover?(index) } }
        .onTapGesture {
            let additive = NSEvent.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.shift)
            model.onClick?(index, additive)
        }
        .contextMenu { contextMenu(for: window.id) }
    }

    @ViewBuilder
    private func contextMenu(for id: WindowID) -> some View {
        let targets = model.contextTargets(for: id)
        let label = targets.count > 1 ? "\(targets.count)" : ""
        Button("Focus") { model.onContext?(.focus, targets) }
        Divider()
        Button("Close \(label)") { model.onContext?(.close, targets) }
        Button("Minimize \(label)") { model.onContext?(.minimize, targets) }
        Button("Quit App \(label)") { model.onContext?(.quitApp, targets) }
    }

    @ViewBuilder
    private var marqueeOverlay: some View {
        if let rect = marqueeRect {
            Rectangle()
                .fill(Color.accentColor.opacity(0.15))
                .overlay(Rectangle().strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1))
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .allowsHitTesting(false)
        }
    }

    private var marqueeGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named("grid"))
            .onChanged { value in
                let rect = CGRect(
                    x: min(value.startLocation.x, value.location.x),
                    y: min(value.startLocation.y, value.location.y),
                    width: abs(value.location.x - value.startLocation.x),
                    height: abs(value.location.y - value.startLocation.y)
                )
                marqueeRect = rect
                let hit = cellFrames.filter { $0.value.intersects(rect) }.map(\.key)
                model.onMarquee?(Set(hit))
            }
            .onEnded { _ in marqueeRect = nil }
    }
}

/// One window cell: thumbnail (or icon placeholder) + app icon + title + status,
/// framed to an exact size so the grid padding stays symmetric. Shows a red ×
/// close button on hover.
private struct SwitcherCell: View {
    let window: WindowState
    let image: NSImage?
    let icon: NSImage?
    let isSelected: Bool
    let isMultiSelected: Bool
    let appearance: AppearanceSettings
    let cellSize: CGSize
    let animated: Bool
    let onClose: () -> Void

    @State private var hovering = false

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            thumbnail
            titleRow
        }
        .padding(DS.Spacing.sm)
        .frame(width: cellSize.width, height: cellSize.height)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.cell)
                .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.cell)
                .strokeBorder(borderColor, lineWidth: isSelected || isMultiSelected ? 2 : 0)
        )
        .overlay(alignment: .topLeading) { closeButton }
        .scaleEffect(isSelected && animated ? 1.03 : 1.0)
        .animation(animated ? .spring(response: 0.25, dampingFraction: 0.7) : nil, value: isSelected)
        .onHover { hovering = $0 }
    }

    private var borderColor: Color {
        if isMultiSelected { return .orange }
        if isSelected { return .accentColor }
        return .clear
    }

    @ViewBuilder
    private var closeButton: some View {
        if hovering {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Color.red, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(6)
            .help("Close window")
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.sm).fill(Color.black.opacity(0.18))
            if appearance.showThumbnails, let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            } else if let icon {
                Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit).frame(width: 56, height: 56)
            }
            statusBadges
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var statusBadges: some View {
        if appearance.showStatusIcons {
            VStack {
                HStack {
                    Spacer()
                    if window.isMinimized { badge("minus.circle.fill", .yellow) }
                    if window.isFullscreen { badge("arrow.up.left.and.arrow.down.right", .blue) }
                }
                Spacer()
            }
            .padding(6)
        }
    }

    private func badge(_ symbol: String, _ color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(3)
            .background(.black.opacity(0.4), in: Circle())
    }

    private var titleRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            if let icon {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
            }
            Text(appearance.maskTitles ? "•••" : titleText)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(truncationMode)
                .foregroundStyle(isSelected ? .primary : .secondary)
            Spacer(minLength: 0)
        }
        .frame(height: 18)
    }

    private var titleText: String {
        switch appearance.showTitles {
        case .windowTitle: return window.title
        case .appName: return window.appName
        case .appNameAndWindowTitle:
            return window.title.isEmpty ? window.appName : "\(window.appName) — \(window.title)"
        }
    }

    private var truncationMode: Text.TruncationMode {
        switch appearance.titleTruncation {
        case .start: return .head
        case .middle: return .middle
        case .end: return .tail
        }
    }
}
