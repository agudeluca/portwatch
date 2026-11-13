import XCTest
@testable import PortWatchCore

final class SystemPowerTests: XCTestCase {

    /// The shape `ioreg -rw0 -c AppleSmartBattery` shows on an M5 laptop on a weak USB charger.
    private let sample: [String: Any] = [
        "PowerTelemetryData": ["SystemLoad": 7695, "SystemPowerIn": 110] as [String: Any],
        "AdapterDetails": ["Watts": 8, "Description": "usb brick"] as [String: Any],
        "ExternalConnected": true,
        "Voltage": 12_719,
        "InstantAmperage": UInt64(18_446_744_073_709_551_035), // -581 mA
    ]

    func testParsesTheSample() {
        let reading = SystemPower.reading(from: sample)
        XCTAssertEqual(reading, PowerReading(
            systemLoad: 7695, chargerInput: 110, adapterWatts: 8,
            externalConnected: true, battery: -7389
        ))
    }

    func testSignedAmperageIsReinterpreted() {
        XCTAssertEqual(SystemPower.integer(UInt64(18_446_744_073_709_551_197)), -419)
        XCTAssertEqual(SystemPower.integer(NSNumber(value: UInt64(18_446_744_073_709_551_197))), -419)
        XCTAssertEqual(SystemPower.integer(1500), 1500)
        XCTAssertNil(SystemPower.integer("12"))
    }

    func testMissingDataIsNil() {
        XCTAssertNil(SystemPower.reading(from: [:]))
        XCTAssertNil(SystemPower.reading(from: ["PowerTelemetryData": ["SystemPowerIn": 110]]))
    }

    func testOptionalFieldsMayBeAbsent() {
        let reading = SystemPower.reading(from: ["PowerTelemetryData": ["SystemLoad": 4200]])
        XCTAssertEqual(reading, PowerReading(systemLoad: 4200, externalConnected: false))
    }

    func testWattsRoundToOneDecimal() {
        XCTAssertEqual(Formatters.watts(milliwatts: 7695), "7.7 W")
        XCTAssertEqual(Formatters.watts(milliwatts: 7649), "7.6 W")
        XCTAssertEqual(Formatters.watts(milliwatts: 110), "0.1 W")
        XCTAssertEqual(Formatters.watts(milliwatts: 0), "0.0 W")
    }

    func testPowerLineOnAWeakCharger() {
        let reading = SystemPower.reading(from: sample)!
        XCTAssertEqual(Formatters.power(reading), "Power 7.7 W · charger 8 W, battery draining")
    }

    func testPowerLineOnAChargerThatKeepsUp() {
        let reading = PowerReading(
            systemLoad: 7695, chargerInput: 30_000, adapterWatts: 96,
            externalConnected: true, battery: 20_000
        )
        XCTAssertEqual(Formatters.power(reading), "Power 7.7 W · charger 96 W")
    }

    func testPowerLineWithUnknownAdapter() {
        let reading = PowerReading(systemLoad: 7695, externalConnected: true)
        XCTAssertEqual(Formatters.power(reading), "Power 7.7 W · charger")
    }

    func testPowerLineOnBattery() {
        let reading = PowerReading(systemLoad: 7695, externalConnected: false, battery: -7400)
        XCTAssertEqual(Formatters.power(reading), "Power 7.7 W · on battery")
    }
}
