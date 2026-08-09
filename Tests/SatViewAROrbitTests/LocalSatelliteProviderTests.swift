import XCTest
@testable import SatViewAROrbit

final class LocalSatelliteProviderTests: XCTestCase {
    private let observer = ObserverLocation(
        latitude: -27.4698,
        longitude: 153.0251,
        altitudeMeters: 27
    )

    func testProviderComputesExpectedTopocentricPosition() async throws {
        let provider = LocalSatelliteProvider(
            catalog: StubTLECatalog(records: [fixtureRecord(constellation: .gps)])
        )
        let date = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-08-09T00:00:00Z")
        )

        let satellites = try await provider.visibleSatellites(
            selection: .gps,
            observer: observer,
            at: date
        )

        XCTAssertEqual(satellites.count, 1)
        XCTAssertEqual(satellites[0].name, "GPS G22")
        XCTAssertEqual(satellites[0].azimuth, 196.3399, accuracy: 0.05)
        XCTAssertEqual(satellites[0].elevation, 55.8687, accuracy: 0.05)
    }

    func testProviderFiltersSatelliteBelowHorizon() async throws {
        let provider = LocalSatelliteProvider(
            catalog: StubTLECatalog(records: [fixtureRecord(constellation: .gps)])
        )
        let date = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-08-09T09:00:00Z")
        )

        do {
            _ = try await provider.visibleSatellites(
                selection: .gps,
                observer: observer,
                at: date
            )
            XCTFail("Expected a below-horizon-only result to fail")
        } catch let error as LocalSatelliteProviderError {
            XCTAssertEqual(error, .noUsableSatellites)
        }
    }

    func testProviderSortsCombinedResultsByConstellationOrder() async throws {
        let records = GNSSConstellation.all.expanded.map(fixtureRecord)
        let provider = LocalSatelliteProvider(
            catalog: StubTLECatalog(records: records)
        )
        let date = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-08-09T00:00:00Z")
        )

        let satellites = try await provider.visibleSatellites(
            selection: .all,
            observer: observer,
            at: date
        )

        XCTAssertEqual(
            satellites.map(\.name),
            ["GPS G22", "GLONASS R22", "Galileo E22", "BeiDou B22", "SBAS S22"]
        )
    }

    func testProviderThrowsWhenEveryRecordIsInvalid() async throws {
        let invalid = TLERecord(
            name: "INVALID",
            line1: "not a TLE",
            line2: "not a TLE",
            constellation: .gps
        )
        let provider = LocalSatelliteProvider(
            catalog: StubTLECatalog(records: [invalid])
        )

        do {
            _ = try await provider.visibleSatellites(
                selection: .gps,
                observer: observer,
                at: Date(timeIntervalSince1970: 1_786_259_200)
            )
            XCTFail("Expected invalid TLE records to fail")
        } catch let error as LocalSatelliteProviderError {
            XCTAssertEqual(error, .noUsableSatellites)
        }
    }

    private func fixtureRecord(
        constellation: GNSSConstellation
    ) -> TLERecord {
        TLERecord(
            name: "GPS BIIR-5  (PRN 22)",
            line1: "1 26407U 00040A   26220.86016981  .00000080  00000+0  00000+0 0  9990",
            line2: "2 26407  54.8456 213.0705 0119755 303.0972 212.3300  2.00557983191004",
            constellation: constellation
        )
    }
}

private struct StubTLECatalog: TLECatalogLoading {
    let records: [TLERecord]

    func records(
        for selection: GNSSConstellation,
        now: Date
    ) async throws -> [TLERecord] {
        records
    }
}
