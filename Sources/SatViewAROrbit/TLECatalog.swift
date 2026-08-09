import Foundation

public struct TLERecord: Codable, Equatable, Sendable {
    public let name: String
    public let line1: String
    public let line2: String
    public let constellation: GNSSConstellation

    public init(
        name: String,
        line1: String,
        line2: String,
        constellation: GNSSConstellation
    ) {
        self.name = name
        self.line1 = line1
        self.line2 = line2
        self.constellation = constellation
    }
}

public enum TLERecordParser {
    public static func parse(
        _ payload: String,
        constellation: GNSSConstellation
    ) -> [TLERecord] {
        let lines = payload
            .split(whereSeparator: \Character.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        var records: [TLERecord] = []
        var index = 0

        while index + 2 < lines.count {
            let name = lines[index]
            let line1 = lines[index + 1]
            let line2 = lines[index + 2]

            if !name.hasPrefix("1 "),
               line1.hasPrefix("1 "),
               line2.hasPrefix("2 ") {
                records.append(
                    TLERecord(
                        name: name,
                        line1: line1,
                        line2: line2,
                        constellation: constellation
                    )
                )
                index += 3
            } else {
                index += 1
            }
        }

        return records
    }
}

public protocol TLEFetching: Sendable {
    func fetch(constellation: GNSSConstellation) async throws -> String
}

public enum CelesTrakTLEFetcherError: Error, Equatable {
    case invalidConstellation
    case invalidURL
    case invalidResponse
    case invalidEncoding
}

public struct CelesTrakTLEFetcher: TLEFetching {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public static func url(for constellation: GNSSConstellation) throws -> URL {
        guard let group = constellation.celestrakGroup else {
            throw CelesTrakTLEFetcherError.invalidConstellation
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "celestrak.org"
        components.path = "/NORAD/elements/gp.php"
        components.queryItems = [
            URLQueryItem(name: "GROUP", value: group),
            URLQueryItem(name: "FORMAT", value: "TLE")
        ]

        guard let url = components.url else {
            throw CelesTrakTLEFetcherError.invalidURL
        }
        return url
    }

    public func fetch(constellation: GNSSConstellation) async throws -> String {
        let url = try Self.url(for: constellation)
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CelesTrakTLEFetcherError.invalidResponse
        }
        guard let payload = String(data: data, encoding: .utf8) else {
            throw CelesTrakTLEFetcherError.invalidEncoding
        }
        return payload
    }
}

public actor TLECache {
    public struct Entry: Codable, Equatable, Sendable {
        public let fetchedAt: Date
        public let payload: String
    }

    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let cachesDirectory = FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.directory = cachesDirectory
                .appendingPathComponent("SatViewAR", isDirectory: true)
                .appendingPathComponent("TLE", isDirectory: true)
        }
        try? FileManager.default.createDirectory(
            at: self.directory,
            withIntermediateDirectories: true
        )
    }

    public func load(for constellation: GNSSConstellation) -> Entry? {
        guard constellation != .all,
              let data = try? Data(contentsOf: fileURL(for: constellation)) else {
            return nil
        }
        return try? decoder.decode(Entry.self, from: data)
    }

    public func store(
        payload: String,
        for constellation: GNSSConstellation,
        fetchedAt: Date
    ) {
        guard constellation != .all else {
            return
        }
        let entry = Entry(fetchedAt: fetchedAt, payload: payload)
        guard let data = try? encoder.encode(entry) else {
            return
        }
        try? data.write(to: fileURL(for: constellation), options: .atomic)
    }

    private func fileURL(for constellation: GNSSConstellation) -> URL {
        directory.appendingPathComponent("\(constellation.rawValue).json")
    }
}

public enum TLECatalogError: Error, Equatable {
    case unavailable(GNSSConstellation)
}

public protocol TLECatalogLoading: Sendable {
    func records(
        for selection: GNSSConstellation,
        now: Date
    ) async throws -> [TLERecord]
}

public actor TLECatalog {
    public static let freshLifetime: TimeInterval = 12 * 60 * 60
    public static let staleFallbackLifetime: TimeInterval = 72 * 60 * 60

    private let fetcher: any TLEFetching
    private let cache: TLECache

    public init(
        fetcher: any TLEFetching = CelesTrakTLEFetcher(),
        cache: TLECache = TLECache()
    ) {
        self.fetcher = fetcher
        self.cache = cache
    }

    public func records(
        for selection: GNSSConstellation,
        now: Date = Date()
    ) async throws -> [TLERecord] {
        try await withThrowingTaskGroup(of: [TLERecord].self) { group in
            for constellation in selection.expanded {
                group.addTask {
                    try await self.records(forConcrete: constellation, now: now)
                }
            }

            var combined: [TLERecord] = []
            for try await records in group {
                combined.append(contentsOf: records)
            }
            return combined
        }
    }

    private func records(
        forConcrete constellation: GNSSConstellation,
        now: Date
    ) async throws -> [TLERecord] {
        let cached = await cache.load(for: constellation)
        if let cached,
           age(of: cached, at: now) <= Self.freshLifetime {
            let records = TLERecordParser.parse(
                cached.payload,
                constellation: constellation
            )
            if !records.isEmpty {
                return records
            }
        }

        do {
            let payload = try await fetcher.fetch(constellation: constellation)
            let records = TLERecordParser.parse(payload, constellation: constellation)
            guard !records.isEmpty else {
                throw TLECatalogError.unavailable(constellation)
            }
            await cache.store(
                payload: payload,
                for: constellation,
                fetchedAt: now
            )
            return records
        } catch {
            if let cached,
               age(of: cached, at: now) <= Self.staleFallbackLifetime {
                let records = TLERecordParser.parse(
                    cached.payload,
                    constellation: constellation
                )
                if !records.isEmpty {
                    return records
                }
            }
            throw TLECatalogError.unavailable(constellation)
        }
    }

    private func age(of entry: TLECache.Entry, at now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(entry.fetchedAt))
    }
}

extension TLECatalog: TLECatalogLoading {}
