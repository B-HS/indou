import AppKit
import IndouKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - General

struct GeneralPane: View {
    let store: PreferenceStore
    @Bindable var launchAtLogin: LaunchAtLogin

    var body: some View {
        PaneHeader(title: String(localized: "General"), subtitle: String(localized: "App-wide preferences"), systemImage: "gearshape.fill")

        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label("Startup", systemImage: "power").font(.system(size: 13, weight: .semibold))
                Toggle(isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.setEnabled($0) })) {
                    Text("Open at Login").font(.system(size: 12))
                }
                .toggleStyle(.switch)
                Toggle(isOn: store.binding(\.general.showMenubarIcon)) {
                    Text("Show menu bar icon").font(.system(size: 12))
                }
                .toggleStyle(.switch)
            }
        }

        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label("Language", systemImage: "globe").font(.system(size: 13, weight: .semibold))
                HStack(spacing: DS.Spacing.sm) {
                    Picker("Language", selection: Binding(
                        get: { store.settings.general.language },
                        set: { language in
                            store.update { $0.general.language = language }
                            AppRelaunch.applyLanguage(language)
                        }
                    )) {
                        Text("System").tag(AppLanguage.system)
                        Text("한국어").tag(AppLanguage.ko)
                        Text("English").tag(AppLanguage.en)
                        Text("日本語").tag(AppLanguage.ja)
                    }
                    .labelsHidden()
                    .fixedSize()
                    if store.settings.general.language != AppRelaunch.languageAtLaunch {
                        Button("Relaunch") { AppRelaunch.relaunch() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                    Spacer()
                }
                Text("Changing the language takes effect after relaunching Indou.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }

        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label("Switcher display", systemImage: "display").font(.system(size: 13, weight: .semibold))
                Picker("Display", selection: store.binding(\.general.showOnScreen)) {
                    Text("Active display").tag(ShowOnScreen.active)
                    Text("Display with cursor").tag(ShowOnScreen.includingMouse)
                    Text("Display with menu bar").tag(ShowOnScreen.includingMenubar)
                }
                .labelsHidden()
            }
        }

        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label("Window list", systemImage: "macwindow.on.rectangle").font(.system(size: 13, weight: .semibold))
                Toggle(isOn: store.binding(\.general.showBackgroundApps)) {
                    Text("Show background apps").font(.system(size: 12))
                }
                .toggleStyle(.switch)
                Text("Also list running apps that have no open window, like the Force Quit Applications list.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Shortcuts

struct ShortcutsPane: View {
    let store: PreferenceStore
    let controller: SwitcherController

    var body: some View {
        PaneHeader(title: String(localized: "Shortcuts"), subtitle: String(localized: "Trigger profiles"), systemImage: "keyboard")

        ForEach(store.settings.profiles) { profile in
            Card {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack {
                        Text(profile.name).font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Toggle("", isOn: enabledBinding(for: profile)).labelsHidden().toggleStyle(.switch)
                    }
                    HStack(spacing: DS.Spacing.sm) {
                        Text("Trigger").font(.system(size: 11)).foregroundStyle(.secondary)
                        ShortcutRecorder(
                            modifiers: profile.holdModifiers,
                            keyCode: profile.nextKey,
                            onChange: { mods, key in updateTrigger(profile, mods, key) },
                            onRecordingChange: { controller.isRecordingShortcut = $0 }
                        )
                        Spacer()
                        Text(appsLabel(profile.filter.appsToShow)).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }
        }

        Text("Click the trigger, then press a modifier + key (e.g. ⌥Tab). Hold the modifier and press the key to cycle; release to focus. Press Space to lock the switcher open for mouse selection.")
            .font(.system(size: 10)).foregroundStyle(.secondary)
    }

    private func updateTrigger(_ profile: ShortcutProfile, _ modifiers: ModifierFlags, _ key: UInt16) {
        store.update { settings in
            guard let i = settings.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
            settings.profiles[i].holdModifiers = modifiers
            settings.profiles[i].nextKey = key
        }
    }

    private func enabledBinding(for profile: ShortcutProfile) -> Binding<Bool> {
        Binding(
            get: { store.settings.profiles.first { $0.id == profile.id }?.enabled ?? false },
            set: { value in store.update { settings in
                if let i = settings.profiles.firstIndex(where: { $0.id == profile.id }) { settings.profiles[i].enabled = value }
            } }
        )
    }

    private func appsLabel(_ apps: AppsToShow) -> String {
        switch apps {
        case .all: return String(localized: "All apps")
        case .active: return String(localized: "Active app")
        case .nonActive: return String(localized: "Other apps")
        }
    }
}

// MARK: - Appearance

struct AppearancePane: View {
    let store: PreferenceStore

    var body: some View {
        PaneHeader(title: String(localized: "Appearance"), subtitle: String(localized: "Switcher look & feel"), systemImage: "paintpalette.fill")

        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                pickerRow("Style", store.binding(\.appearance.style)) {
                    Text("Thumbnails").tag(AppearanceStyle.thumbnails)
                    Text("App icons").tag(AppearanceStyle.appIcons)
                    Text("Titles").tag(AppearanceStyle.titles)
                }
                pickerRow("Size", store.binding(\.appearance.size)) {
                    Text("Small").tag(AppearanceSize.small)
                    Text("Medium").tag(AppearanceSize.medium)
                    Text("Large").tag(AppearanceSize.large)
                    Text("Auto").tag(AppearanceSize.auto)
                    Text("Manual").tag(AppearanceSize.manual)
                }
                if store.settings.appearance.size == .manual {
                    HStack {
                        Text("Cell height").font(.system(size: 12)).frame(width: 90, alignment: .leading)
                        Slider(
                            value: Binding(
                                get: { Double(store.settings.appearance.manualCellHeight) },
                                set: { newValue in store.update { settings in settings.appearance.manualCellHeight = Int(newValue) } }
                            ),
                            in: 80...600
                        )
                        Text("\(store.settings.appearance.manualCellHeight)px")
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).frame(width: 50)
                    }
                }
                pickerRow("Theme", store.binding(\.appearance.theme)) {
                    Text("System").tag(AppearanceTheme.system)
                    Text("Light").tag(AppearanceTheme.light)
                    Text("Dark").tag(AppearanceTheme.dark)
                }
            }
        }

        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                pickerRow("Titles", store.binding(\.appearance.showTitles)) {
                    Text("Window title").tag(ShowTitles.windowTitle)
                    Text("App name").tag(ShowTitles.appName)
                    Text("App + window").tag(ShowTitles.appNameAndWindowTitle)
                }
                pickerRow("Truncate", store.binding(\.appearance.titleTruncation)) {
                    Text("Start").tag(TitleTruncation.start)
                    Text("Middle").tag(TitleTruncation.middle)
                    Text("End").tag(TitleTruncation.end)
                }
                toggle("Show thumbnails", store.binding(\.appearance.showThumbnails))
                toggle("Show status icons", store.binding(\.appearance.showStatusIcons))
                toggle("Show Space numbers", store.binding(\.appearance.showSpaceNumbers))
                toggle("Mask window titles", store.binding(\.appearance.maskTitles))
                toggle("Liquid Glass background", store.binding(\.appearance.useLiquidGlass))
            }
        }

        Card {
            HStack {
                Text("Columns (0 = auto)").font(.system(size: 12))
                Spacer()
                Stepper(value: store.binding(\.appearance.columns), in: 0...12) {
                    Text("\(store.settings.appearance.columns)").monospacedDigit()
                }
            }
        }
    }

    private func pickerRow(_ title: LocalizedStringKey, _ binding: Binding<some Hashable>, @ViewBuilder _ content: () -> some View) -> some View {
        HStack {
            Text(title).font(.system(size: 12)).frame(width: 90, alignment: .leading)
            Picker(title, selection: binding) { content() }.labelsHidden()
        }
    }

    private func toggle(_ title: LocalizedStringKey, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) { Text(title).font(.system(size: 12)) }.toggleStyle(.switch)
    }
}

// MARK: - Animations

struct AnimationsPane: View {
    let store: PreferenceStore

    var body: some View {
        PaneHeader(title: String(localized: "Animations"), subtitle: String(localized: "Transitions & motion"), systemImage: "wand.and.stars")

        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Toggle(isOn: store.binding(\.animation.enabled)) {
                    Text("Enable transition animations").font(.system(size: 12, weight: .medium))
                }.toggleStyle(.switch)
                Toggle(isOn: store.binding(\.animation.respectReduceMotion)) {
                    Text("Respect system Reduce Motion").font(.system(size: 12))
                }.toggleStyle(.switch)
                Toggle(isOn: store.binding(\.animation.fadeInOut)) {
                    Text("Fade in / out").font(.system(size: 12))
                }.toggleStyle(.switch)
                Toggle(isOn: store.binding(\.animation.springSelection)) {
                    Text("Spring selection").font(.system(size: 12))
                }.toggleStyle(.switch)
            }
        }

        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                slider("Summon delay", store.binding(\.animation.summonDelayMs), 0...500, "\(store.settings.animation.summonDelayMs) ms")
                slider("Duration", store.binding(\.animation.durationMs), 60...400, "\(store.settings.animation.durationMs) ms")
            }
        }
    }

    private func slider(_ title: LocalizedStringKey, _ binding: Binding<Int>, _ range: ClosedRange<Int>, _ readout: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.system(size: 12))
                Spacer()
                Text(readout).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(get: { Double(binding.wrappedValue) }, set: { binding.wrappedValue = Int($0) }),
                in: Double(range.lowerBound)...Double(range.upperBound)
            )
        }
    }
}

// MARK: - Input

struct InputPane: View {
    let store: PreferenceStore

    var body: some View {
        PaneHeader(title: String(localized: "Input"), subtitle: String(localized: "Navigation & mouse"), systemImage: "hand.tap.fill")
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Toggle(isOn: store.binding(\.input.arrowKeysEnabled)) { Text("Arrow keys move the grid").font(.system(size: 12)) }.toggleStyle(.switch)
                Toggle(isOn: store.binding(\.input.vimKeysEnabled)) { Text("Vim keys (h j k l)").font(.system(size: 12)) }.toggleStyle(.switch)
                Toggle(isOn: store.binding(\.input.mouseHoverEnabled)) { Text("Select on mouse hover").font(.system(size: 12)) }.toggleStyle(.switch)
            }
        }
    }
}

// MARK: - Filters

struct FiltersPane: View {
    let store: PreferenceStore
    @State private var newPrefix = ""

    var body: some View {
        PaneHeader(title: String(localized: "Filters"), subtitle: String(localized: "Hidden apps (blacklist)"), systemImage: "line.3.horizontal.decrease.circle.fill")

        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    TextField("Bundle id prefix (e.g. com.apple.finder)", text: $newPrefix)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        let trimmed = newPrefix.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        store.update { $0.exceptions.append(ExceptionRule(bundleIDPrefix: trimmed, hide: .always)) }
                        newPrefix = ""
                    }
                }
                if store.settings.exceptions.isEmpty {
                    Text("No filters. Added apps are hidden from the switcher.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                ForEach(store.settings.exceptions) { rule in
                    HStack {
                        Image(systemName: "xmark.circle").foregroundStyle(.secondary)
                        Text(rule.bundleIDPrefix).font(.system(size: 12, design: .monospaced))
                        Spacer()
                        Button(role: .destructive) {
                            store.update { $0.exceptions.removeAll { $0.id == rule.id } }
                        } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                }
            }
        }
    }
}

// MARK: - Advanced

struct AdvancedPane: View {
    let store: PreferenceStore
    let controller: SwitcherController

    var body: some View {
        PaneHeader(title: String(localized: "Advanced"), subtitle: String(localized: "Private APIs, performance, permissions"), systemImage: "slider.horizontal.3")

        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Toggle(isOn: store.binding(\.advanced.usePrivateSpaceAPIs)) { Text("Collect windows across Spaces (private API)").font(.system(size: 12)) }.toggleStyle(.switch)
                Toggle(isOn: store.binding(\.advanced.usePreciseFocus)) { Text("Precise window focus (private API)").font(.system(size: 12)) }.toggleStyle(.switch)
                Toggle(isOn: Binding(
                    get: { store.settings.advanced.disableNativeCmdTab },
                    set: { controller.setDisableNativeCmdTab($0) }
                )) { Text("Disable native ⌘Tab while running").font(.system(size: 12)) }.toggleStyle(.switch)
                Toggle(isOn: store.binding(\.advanced.captureMinimizedWindows)) { Text("Capture minimized windows (private API)").font(.system(size: 12)) }.toggleStyle(.switch)
            }
        }

        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label("Permissions", systemImage: "lock.shield").font(.system(size: 13, weight: .semibold))
                HStack {
                    Button("Open Accessibility…") { Permissions.openAccessibilitySettings() }
                    Button("Open Screen Recording…") { Permissions.openScreenRecordingSettings() }
                }
                Button("Restart key tap") { controller.restartEventTap() }
                    .controlSize(.small)
            }
        }

        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label("Settings file", systemImage: "doc").font(.system(size: 13, weight: .semibold))
                HStack {
                    Button("Export…") { export() }
                    Button("Import…") { importFile() }
                    Spacer()
                    Button(role: .destructive) { store.reset() } label: { Text("Reset to defaults") }
                }
            }
        }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "indou-settings.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url, let data = try? store.exportData() else { return }
        try? data.write(to: url)
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
        try? store.importData(data)
    }
}

// MARK: - About

struct AboutPane: View {
    @State private var newVersion: String?

    var body: some View {
        PaneHeader(title: String(localized: "About"), subtitle: "Indou", systemImage: "info.circle.fill")
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                row("Version", UpdateChecker.currentVersion)
                HStack {
                    Text("GitHub").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Link("github.com/B-HS/indou", destination: URL(string: "https://github.com/B-HS/indou")!)
                        .font(.system(size: 11))
                }
                if let newVersion {
                    Divider().padding(.vertical, 2)
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill").foregroundStyle(.green)
                        Text("New version \(newVersion) is available").font(.system(size: 12, weight: .medium))
                        Spacer()
                        Button(String(localized: "Download")) { NSWorkspace.shared.open(UpdateChecker.releasesURL) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                } else {
                    Text("A fast, modern macOS window switcher.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
        .task { newVersion = await UpdateChecker.newerVersionIfAvailable() }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, design: .monospaced))
        }
    }
}
