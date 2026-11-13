import Foundation
import IOKit

/// One sample of where the Mac's power is going, in milliwatts as the battery controller
/// reports it.
public struct PowerReading: Equatable {
    /// Total system draw, whatever its source.
    public let systemLoad: Int
    /// What is coming in from the charger right now, when known.
    public let chargerInput: Int?
    /// The adapter's rated wattage, when one is connected and identifies itself.
    public let adapterWatts: Int?
    public let externalConnected: Bool
    /// Battery power: negative while discharging, positive while charging.
    public let battery: Int?

    public init(
        systemLoad: Int, chargerInput: Int? = nil, adapterWatts: Int? = nil,
        externalConnected: Bool, battery: Int? = nil
    ) {
        self.systemLoad = systemLoad
        self.chargerInput = chargerInput
        self.adapterWatts = adapterWatts
        self.externalConnected = externalConnected
        self.battery = battery
    }

    /// Plugged in but still losing charge: the adapter cannot keep up with the load.
    public var isDrainingOnCharger: Bool {
        guard externalConnected, let battery else { return false }
        return battery < -500
    }
}

public enum SystemPower {

    /// Reads the `AppleSmartBattery` service. Nil on Macs without one (desktops), or when the
    /// controller does not publish a system load figure.
    public static func reading() -> PowerReading? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dictionary = properties?.takeRetainedValue() as? [String: Any]
        else { return nil }
        return reading(from: dictionary)
    }

    /// The parsing half, kept free of IOKit so it can be tested against plain dictionaries.
    public static func reading(from properties: [String: Any]) -> PowerReading? {
        guard let telemetry = properties["PowerTelemetryData"] as? [String: Any],
              let load = integer(telemetry["SystemLoad"])
        else { return nil }

        let adapter = properties["AdapterDetails"] as? [String: Any]
        var battery: Int?
        if let millivolts = integer(properties["Voltage"]),
           let milliamps = integer(properties["InstantAmperage"]) {
            battery = Int((Int64(millivolts) * Int64(milliamps)) / 1000)
        }

        return PowerReading(
            systemLoad: Int(load),
            chargerInput: integer(telemetry["SystemPowerIn"]).map(Int.init),
            adapterWatts: integer(adapter?["Watts"]).map(Int.init),
            externalConnected: (properties["ExternalConnected"] as? Bool) ?? false,
            battery: battery
        )
    }

    /// IOKit hands signed counters back as unsigned 64-bit values, so a small negative current
    /// arrives as something like 18446744073709551197. Reinterpret the bits rather than trusting
    /// the sign.
    static func integer(_ value: Any?) -> Int64? {
        switch value {
        case let value as Int64: return value
        case let value as UInt64: return Int64(bitPattern: value)
        case let value as Int: return Int64(value)
        case let value as NSNumber: return value.int64Value
        default: return nil
        }
    }
}
