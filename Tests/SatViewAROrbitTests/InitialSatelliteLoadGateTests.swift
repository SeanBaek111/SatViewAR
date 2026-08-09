import XCTest
@testable import SatViewAROrbit

final class InitialSatelliteLoadGateTests: XCTestCase {
    func testFirstLocationUpdateRequestsExactlyOneAutomaticLoad() {
        var gate = InitialSatelliteLoadGate()

        XCTAssertTrue(gate.shouldRequestLoad())
        XCTAssertFalse(gate.shouldRequestLoad())
        XCTAssertFalse(gate.shouldRequestLoad())
    }
}
