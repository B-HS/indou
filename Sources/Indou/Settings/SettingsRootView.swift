import IndouKit
import SwiftUI

extension PreferenceStore {
    /// A SwiftUI binding that persists through `update(_:)` (settings is private(set)).
    func binding<T>(_ keyPath: WritableKeyPath<SettingsSchema, T>) -> Binding<T> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { newValue in self.update { $0[keyPath: keyPath] = newValue } }
        )
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, shortcuts, appearance, animations, input, filters, advanced, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return String(localized: "General")
        case .shortcuts: return String(localized: "Shortcuts")
        case .appearance: return String(localized: "Appearance")
        case .animations: return String(localized: "Animations")
        case .input: return String(localized: "Input")
        case .filters: return String(localized: "Filters")
        case .advanced: return String(localized: "Advanced")
        case .about: return String(localized: "About")
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape.fill"
        case .shortcuts: return "keyboard"
        case .appearance: return "paintpalette.fill"
        case .animations: return "wand.and.stars"
        case .input: return "hand.tap.fill"
        case .filters: return "line.3.horizontal.decrease.circle.fill"
        case .advanced: return "slider.horizontal.3"
        case .about: return "info.circle.fill"
        }
    }
}

struct SettingsRootView: View {
    let store: PreferenceStore
    @Bindable var launchAtLogin: LaunchAtLogin
    let controller: SwitcherController

    @State private var selection: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 200)
                .background(Color(nsColor: .underPageBackgroundColor).opacity(0.5))
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 720, minHeight: 520)
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Color.clear.frame(height: 36)
            ForEach(SettingsSection.allCases) { section in
                sidebarButton(section)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
    }

    private func sidebarButton(_ section: SettingsSection) -> some View {
        let isSelected = selection == section
        return HStack(spacing: 8) {
            Image(systemName: section.systemImage)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? .white : Color.accentColor)
                .frame(width: 20)
            Text(section.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? .white : .primary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: DS.Radius.sm).fill(isSelected ? Color.accentColor : .clear))
        .contentShape(Rectangle())
        .onTapGesture { selection = section }
    }

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                switch selection {
                case .general: GeneralPane(store: store, launchAtLogin: launchAtLogin)
                case .shortcuts: ShortcutsPane(store: store, controller: controller)
                case .appearance: AppearancePane(store: store)
                case .animations: AnimationsPane(store: store)
                case .input: InputPane(store: store)
                case .filters: FiltersPane(store: store)
                case .advanced: AdvancedPane(store: store, controller: controller)
                case .about: AboutPane()
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Section header shown at the top of each pane.
struct PaneHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.18)).frame(width: 38, height: 38)
                Image(systemName: systemImage).font(.system(size: 18)).foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
