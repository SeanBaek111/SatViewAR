import XCTest
@testable import SatViewAROrbit

final class TLECatalogTests: XCTestCase {
    private let gpsPayload = """
    GPS BIIR-5  (PRN 22)
    1 26407U 00040A   26220.86016981  .00000080  00000+0  00000+0 0  9990
    2 26407  54.8456 213.0705 0119755 303.0972 212.3300  2.00557983191004
    """

    func testParserReturnsCompleteThreeLineRecords() throws {
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(forResource: "gps-ops", withExtension: "tle")
        )
        let payload = try String(contentsOf: fixtureURL, encoding: .utf8)

        let records = TLERecordParser.parse(payload, constellation: .gps)

        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0].name, "GPS BIIR-5  (PRN 22)")
        XCTAssertTrue(records[0].line1.hasPrefix("1 26407U"))
        XCTAssertTrue(records[0].line2.hasPrefix("2 26407"))
        XCTAssertEqual(records[0].constellation, .gps)
    }

    func testParserDropsIncompleteTrailingRecordAndComments() {
        let payload = """
        # generated fixture

        GPS BIIR-5  (PRN 22)
        1 26407U 00040A   26220.86016981  .00000080  00000+0  00000+0 0  9990
        2 26407  54.8456 213.0705 0119755 303.0972 212.3300  2.00557983191004
        INCOMPLETE
        1 00000U 00000A   26220.00000000  .00000000  00000+0  00000+0 0  0000
        """

        let records = TLERecordParser.parse(payload, constellation: .gps)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].name, "GPS BIIR-5  (PRN 22)")
    }

    func testFreshCacheAvoidsNetworkRequest() async throws {
        let now = Date(timeIntervalSince1970: 1_786_259_200)
        let cache = try makeCache()
        await cache.store(
            payload: gpsPayload,
            for: .gps,
            fetchedAt: now.addingTimeInterval(-11 * 60 * 60)
        )
        let fetcher = StubTLEFetcher(payload: gpsPayload, shouldFail: true)
        let catalog = TLECatalog(fetcher: fetcher, cache: cache)

        let records = try await catalog.records(for: .gps, now: now)

        XCTAssertEqual(records.count, 1)
        let requestCount = await fetcher.requestCount(for: .gps)
        XCTAssertEqual(requestCount, 0)
    }

    func testExpiredFreshCacheFetchesAndStoresReplacement() async throws {
        let now = Date(timeIntervalSince1970: 1_786_259_200)
        let cache = try makeCache()
        await cache.store(
            payload: gpsPayload.replacingOccurrences(of: "PRN 22", with: "PRN 01"),
            for: .gps,
            fetchedAt: now.addingTimeInterval(-13 * 60 * 60)
        )
        let replacement = gpsPayload.replacingOccurrences(of: "PRN 22", with: "PRN 16")
        let fetcher = StubTLEFetcher(payload: replacement)
        let catalog = TLECatalog(fetcher: fetcher, cache: cache)

        let records = try await catalog.records(for: .gps, now: now)

        XCTAssertEqual(records.first?.name, "GPS BIIR-5  (PRN 16)")
        let requestCount = await fetcher.requestCount(for: .gps)
        XCTAssertEqual(requestCount, 1)
        let cached = await cache.load(for: .gps)
        XCTAssertEqual(cached?.payload, replacement)
        XCTAssertEqual(cached?.fetchedAt, now)
    }

    func testNetworkFailureUsesCacheUpTo72HoursOld() async throws {
        let now = Date(timeIntervalSince1970: 1_786_259_200)
        let cache = try makeCache()
        await cache.store(
            payload: gpsPayload,
            for: .gps,
            fetchedAt: now.addingTimeInterval(-48 * 60 * 60)
        )
        let fetcher = StubTLEFetcher(payload: gpsPayload, shouldFail: true)
        let catalog = TLECatalog(fetcher: fetcher, cache: cache)

        let records = try await catalog.records(for: .gps, now: now)

        XCTAssertEqual(records.count, 1)
        let requestCount = await fetcher.requestCount(for: .gps)
        XCTAssertEqual(requestCount, 1)
    }

    func testNetworkFailureRejectsCacheOlderThan72Hours() async throws {
        let now = Date(timeIntervalSince1970: 1_786_259_200)
        let cache = try makeCache()
        await cache.store(
            payload: gpsPayload,
            for: .gps,
            fetchedAt: now.addingTimeInterval(-73 * 60 * 60)
        )
        let fetcher = StubTLEFetcher(payload: gpsPayload, shouldFail: true)
        let catalog = TLECatalog(fetcher: fetcher, cache: cache)

        do {
            _ = try await catalog.records(for: .gps, now: now)
            XCTFail("Expected unavailable data to throw")
        } catch let error as TLECatalogError {
            XCTAssertEqual(error, .unavailable(.gps))
        }
    }

    func testAllSelectionCombinesEveryConstellation() async throws {
        let now = Date(timeIntervalSince1970: 1_786_259_200)
        let cache = try makeCache()
        let fetcher = StubTLEFetcher(payload: gpsPayload)
        let catalog = TLECatalog(fetcher: fetcher, cache: cache)

        let records = try await catalog.records(for: .all, now: now)

        XCTAssertEqual(records.count, 5)
        XCTAssertEqual(Set(records.map(\.constellation)), Set(GNSSConstellation.all.expanded))
        for constellation in GNSSConstellation.all.expanded {
            let requestCount = await fetcher.requestCount(for: constellation)
            XCTAssertEqual(requestCount, 1)
        }
    }

    func testCelesTrakURLContainsHTTPSGroupAndTLEFormat() throws {
        let url = try CelesTrakTLEFetcher.url(for: .gps)

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "celestrak.org")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = try XCTUnwrap(components.queryItems)
        XCTAssertTrue(items.contains(URLQueryItem(name: "GROUP", value: "GPS-OPS")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "FORMAT", value: "TLE")))
    }

    private func makeCache() throws -> TLECache {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return TLECache(directory: directory)
    }
}

private enum StubFetchError: Error {
    case unavailable
}

private actor StubTLEFetcher: TLEFetching {
    private let payload: String
    private let shouldFail: Bool
    private var requests: [GNSSConstellation: Int] = [:]

    init(payload: String, shouldFail: Bool = false) {
        self.payload = payload
        self.shouldFail = shouldFail
    }

    func fetch(constellation: GNSSConstellation) async throws -> String {
        requests[constellation, default: 0] += 1
        if shouldFail {
            throw StubFetchError.unavailable
        }
        return payload
    }

    func requestCount(for constellation: GNSSConstellation) -> Int {
        requests[constellation, default: 0]
    }
}
