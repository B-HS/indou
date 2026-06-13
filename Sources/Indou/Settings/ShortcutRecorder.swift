import AppKit
import IndouKit
import SwiftUI

/// Records a hold-modifier + key trigger (e.g. ⌥Tab). Click to arm, then press
/// the combination. Requires at least one modifier; Esc cancels. While armed it
/// raises `onRecordingChange(true)` so the controller stops intercepting keys.
struct ShortcutRecorder: View {
    let modifiers: ModifierFlags
    let keyCode: UInt16
    let onChange: (ModifierFlags, UInt16) -> Void
    let onRecordingChange: (Bool) -> Void

    @State private var recording = false

    var body: some View {
        Button { recording.toggle() } label: {
            Text(recording ? String(localized: "Type a shortcut…") : display)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .frame(minWidth: 84)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(recording ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .strokeBorder(recording ? Color.accentColor : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .background(KeyCaptureView(recording: recording) { mods, key in
            if key == KeyCode.escape { recording = false; return }
            guard !mods.isEmpty else { return }
            onChange(mods, key)
            recording = false
        })
        .onChange(of: recording) { _, value in onRecordingChange(value) }
    }

    private var display: String {
        let key: String
        switch keyCode {
        case KeyCode.tab: key = "⇥"
        case KeyCode.backtick: key = "`"
        case KeyCode.space: key = "␣"
        case KeyCode.escape: key = "⎋"
        default: key = keyCharacter(keyCode)
        }
        return modifiers.symbolString + key
    }

    private func keyCharacter(_ code: UInt16) -> String {
        // Best-effort printable name for letter/number keys.
        let map: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 32: "U", 34: "I",
            31: "O", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        ]
        return map[code] ?? "key\(code)"
    }
}

private struct KeyCaptureView: NSViewRepresentable {
    let recording: Bool
    let onCapture: (ModifierFlags, UInt16) -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        nsView.setRecording(recording)
    }
}

final class KeyCaptureNSView: NSView {
    var onCapture: ((ModifierFlags, UInt16) -> Void)?
    private var recording = false

    func setRecording(_ value: Bool) {
        guard value != recording else { return }
        recording = value
        if value {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self)
            }
        } else if window?.firstResponder === self {
            window?.makeFirstResponder(nil)
        }
    }

    override var acceptsFirstResponder: Bool { recording }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        capture(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording else { return super.performKeyEquivalent(with: event) }
        capture(event)
        return true
    }

    private func capture(_ event: NSEvent) {
        let mods = ModifierFlags(rawValue: UInt(event.modifierFlags.rawValue)).triggerModifiers
        onCapture?(mods, event.keyCode)
    }
}
