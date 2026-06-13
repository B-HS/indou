import SwiftUI

/// Shared design language tokens (spacing / radius / palette) used by both the
/// switcher overlay and the Settings window. Mirrors the tiny-razer `DS` system.
enum DS {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let cell: CGFloat = 12
    }

    enum Palette {
        static let cardBackground = Color(nsColor: .controlBackgroundColor).opacity(0.6)
        static let cardStroke = Color.primary.opacity(0.08)
        static let subtle = Color.primary.opacity(0.05)
        static let accent = Color.accentColor
    }
}

/// Card container used across the Settings panes (tiny-razer parity).
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.md)
            .background(DS.Palette.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(DS.Palette.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

struct SectionLabel: View {
    let title: String
    let systemImage: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            if let trailing {
                Spacer()
                Text(trailing).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
