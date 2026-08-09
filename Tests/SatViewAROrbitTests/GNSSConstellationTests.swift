import XCTest
@testable import SatViewAROrbit

final class GNSSConstellationTests: XCTestCase {
    func testConcreteConstellationsMapToCelesTrakGroups() {
        XCTAssertEqual(GNSSConstellation.gps.celestrakGroup, "GPS-OPS")
        XCTAssertEqual(GNSSConstellation.glonass.celestrakGroup, "glo-ops")
        XCTAssertEqual(GNSSConstellation.galileo.celestrakGroup, "galileo")
        XCTAssertEqual(GNSSConstellation.beidou.celestrakGroup, "beidou")
        XCTAssertEqual(GNSSConstellation.sbas.celestrakGroup, "sbas")
    }

    func testAllExpandsInStableDisplayOrder() {
        XCTAssertEqual(
            GNSSConstellation.all.expanded,
            [.gps, .glonass, .galileo, .beidou, .sbas]
        )
    }

    func testDisplayPrefixesMatchExistingAppLabels() {
        XCTAssertEqual(GNSSConstellation.gps.displayPrefix, "GPS G")
        XCTAssertEqual(GNSSConstellation.glonass.displayPrefix, "GLONASS R")
        XCTAssertEqual(GNSSConstellation.galileo.displayPrefix, "Galileo E")
        XCTAssertEqual(GNSSConstellation.beidou.displayPrefix, "BeiDou B")
        XCTAssertEqual(GNSSConstellation.sbas.displayPrefix, "SBAS S")
    }
}
