import Foundation

/// Compact, fixed-width renderings for a menu where every row has to line up.
public enum Formatters {

    /// Bytes as the menu bar shows them: `4.6G`, `188M`, `912K`.
    public static func memory(_ bytes: UInt64) -> String {
        let kilobyte = 1024.0
        let value = Double(bytes)

        if value >= kilobyte * kilobyte * kilobyte {
            return String(format: "%.1fG", value / (kilobyte * kilobyte * kilobyte))
        }
        if value >= kilobyte * kilobyte {
            return String(format: "%.0fM", value / (kilobyte * kilobyte))
        }
        if value >= kilobyte {
            return String(format: "%.0fK", value / kilobyte)
        }
        return "\(bytes)B"
    }

    /// Coarse on purpose: at a glance you want "this has been up for days", not the seconds.
    public static func uptime(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60

        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(total)s"
    }

    public static func ports(_ ports: [UInt16]) -> String {
        ports.map { ":\($0)" }.joined(separator: ", ")
    }

    /// Left-aligned padding to a fixed column width; longer values are left intact rather than
    /// truncated, since a wrong port number is worse than a ragged column.
    public static func pad(_ value: String, to width: Int) -> String {
        value.count >= width ? value : value + String(repeating: " ", count: width - value.count)
    }

    // MARK: - Menu rows

    private static let portColumn = 8
    private static let memoryColumn = 7
    private static let uptimeColumn = 9
    private static let idleColumn = 9

    public static let serverRowHeader =
        pad("PORT", to: portColumn) + pad("MEM", to: memoryColumn)
        + pad("UP", to: uptimeColumn) + pad("IDLE", to: idleColumn) + "PROCESS"

    /// What a piece of a row is, so the menu can colour it without re-parsing the string.
    public enum RowRole: Equatable {
        case port, memory, uptime, idle(IdleVerdict), process
    }

    public struct RowSegment: Equatable {
        public let text: String
        public let role: RowRole
    }

    /// How an IDLE reading should be read at a glance.
    public enum IdleVerdict: Equatable {
        /// Not watched across two scans yet.
        case unknown
        /// Did work within the last hour: the one you are using.
        case inUse
        /// Quiet for a while, not long enough to call it forgotten.
        case quiet
        /// Untouched for a day or more: what nobody remembered to stop.
        case stale
    }

    public static func idleVerdict(since lastUsed: Date?, now: Date = Date()) -> IdleVerdict {
        guard let lastUsed else { return .unknown }
        let interval = now.timeIntervalSince(lastUsed)
        if interval < 3_600 { return .inUse }
        return interval < 86_400 ? .quiet : .stale
    }

    /// One aligned row: port, memory, how long it has been up, how long since it did anything,
    /// and what it is.
    ///
    /// UP and IDLE earn their place side by side. Either alone is ambiguous — up for ten days is
    /// fine for a database, idle for six days is fine for something started an hour ago — but the
    /// pair reads as a verdict: up 9d 22h, idle 6d 4h is a bundler nobody remembered to stop.
    public static func serverRow(
        _ server: DevServer, lastUsed: Date? = nil, now: Date = Date()
    ) -> String {
        serverRowSegments(server, lastUsed: lastUsed, now: now).map(\.text).joined()
    }

    /// The same row as `serverRow`, split into its columns. Padding stays inside each segment so
    /// the joined text is exactly the plain row.
    public static func serverRowSegments(
        _ server: DevServer, lastUsed: Date? = nil, now: Date = Date()
    ) -> [RowSegment] {
        let port = server.primaryPort.map { ":\($0)" } ?? "—"
        return [
            RowSegment(text: pad(port, to: portColumn), role: .port),
            RowSegment(text: pad(memory(server.footprint), to: memoryColumn), role: .memory),
            RowSegment(text: pad(uptime(server.uptime(at: now)), to: uptimeColumn), role: .uptime),
            RowSegment(
                text: pad(idle(since: lastUsed, now: now), to: idleColumn),
                role: .idle(idleVerdict(since: lastUsed, now: now))
            ),
            RowSegment(text: "\(server.kind.displayName) — \(server.label)", role: .process),
        ]
    }

    /// How long since the server last did measurable work.
    ///
    /// `—` when it has never been seen working. That is not the same as "idle forever": the
    /// counters are cumulative, so a rate needs two scans, and until the app has watched a server
    /// across a window it genuinely does not know. Printing a zero there would be a lie that
    /// happens to look like data.
    public static func idle(since lastUsed: Date?, now: Date = Date()) -> String {
        guard let lastUsed else { return "—" }
        let interval = now.timeIntervalSince(lastUsed)
        // Anything inside a minute is being used right now; the exact seconds are noise.
        return interval < 60 ? "active" : uptime(interval)
    }

    /// A server that is no longer running, labelled with how long ago it was last seen.
    public static func recentRow(_ known: KnownServer, now: Date = Date()) -> String {
        let port = known.primaryPort.map { " :\($0)" } ?? ""
        let age = uptime(now.timeIntervalSince(known.lastSeen))
        return "\(known.kind.displayName) — \(known.label)\(port) · \(age) ago"
    }

    /// The body of the confirmation dialog: one line per process, so the choice is made against
    /// the actual list rather than a count.
    public static func bulkStopSummary(_ servers: [DevServer], now: Date = Date()) -> String {
        servers.map { server in
            let port = server.primaryPort.map { ":\($0)" } ?? "—"
            return "\(port)  \(server.kind.displayName) — \(server.label)  ·  \(uptime(server.uptime(at: now)))"
        }.joined(separator: "\n")
    }

    public static func swap(_ usage: SwapUsage) -> String {
        let percent = Int((usage.fraction * 100).rounded())
        return "Swap \(memory(usage.used)) / \(memory(usage.total)) (\(percent)%)"
    }

    /// Milliwatts as watts with one decimal: 7695 → `7.7 W`.
    public static func watts(milliwatts: Int) -> String {
        String(format: "%.1f W", Double(milliwatts) / 1000)
    }

    /// `Power 7.7 W · on battery`, or with the charger's rating when one is plugged in. A charger
    /// too weak for the load is called out, since "plugged in" otherwise reads as "fine".
    public static func power(_ reading: PowerReading) -> String {
        let load = "Power \(watts(milliwatts: reading.systemLoad))"
        guard reading.externalConnected else { return load + " · on battery" }
        let charger = reading.adapterWatts.map { "charger \($0) W" } ?? "charger"
        return load + " · " + charger + (reading.isDrainingOnCharger ? ", battery draining" : "")
    }

    // MARK: - Updates

    /// The count carries the weight here: "update available" says nothing about whether it is a
    /// typo fix or a fortnight of work.
    public static func updateTitle(_ update: PendingUpdate) -> String {
        "Update available (\(update.count) commit\(update.count == 1 ? "" : "s"))"
    }

    /// The body of the confirmation: what is about to be installed, and the part that surprises
    /// people — the app disappears and comes back on its own.
    public static func updateSummary(_ update: PendingUpdate, source: String) -> String {
        let subjects = update.subjects.map { "• \($0)" }.joined(separator: "\n")
        let outcome = "Rebuilds from \(source), then restarts."
        return subjects.isEmpty ? outcome : subjects + "\n\n" + outcome
    }
}
