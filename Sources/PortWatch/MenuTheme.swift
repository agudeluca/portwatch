import AppKit
import PortWatchCore

/// The menu's palette, the same one the README flyer uses: ports in blue, and IDLE coloured by
/// what it means — green for the server you are using, orange for the one nobody stopped.
///
/// Only text is coloured. Tinting a whole row would need a custom item view, which costs the
/// native hover highlight and the submenu arrow.
enum MenuTheme {
    static let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    static let emphasis = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
    static let headerFont = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .medium)

    static func row(_ segments: [Formatters.RowSegment]) -> NSAttributedString {
        let row = NSMutableAttributedString()
        for segment in segments {
            row.append(NSAttributedString(string: segment.text, attributes: attributes(for: segment.role)))
        }
        return row
    }

    static func header(_ title: String) -> NSAttributedString {
        NSAttributedString(string: title, attributes: [
            .font: headerFont,
            .foregroundColor: NSColor.tertiaryLabelColor,
        ])
    }

    private static func attributes(for role: Formatters.RowRole) -> [NSAttributedString.Key: Any] {
        switch role {
        case .port:
            return [.font: font, .foregroundColor: NSColor.systemBlue]
        case .memory, .uptime, .process:
            return [.font: font, .foregroundColor: NSColor.labelColor]
        case .idle(.inUse):
            return [.font: emphasis, .foregroundColor: NSColor.systemGreen]
        case .idle(.stale):
            return [.font: emphasis, .foregroundColor: NSColor.systemOrange]
        case .idle(.quiet):
            return [.font: font, .foregroundColor: NSColor.labelColor]
        case .idle(.unknown):
            return [.font: font, .foregroundColor: NSColor.tertiaryLabelColor]
        }
    }
}
