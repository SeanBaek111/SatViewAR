import Foundation
import SatelliteKit

public struct ObserverLocation: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let altitudeMeters: Double

    public init(
        latitude: Double,
        longitude: Double,
        altitudeMeters: Double
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitudeMeters = altitudeMeters
    }
}

public struct VisibleSatellite: Equatable, Sendable {
    public let name: String
    public let azimuth: Double
    public let elevation: Double
    public let constellation: GNSSConstellation

    public init(
        name: String,
        azimuth: Double,
        elevation: Double,
        constellation: GNSSConstellation
    ) {
        self.name = name
        self.azimuth = azimuth
        self.elevation = elevation
        self.constellation = constellation
    }
}

public enum LocalSatelliteProviderError: Error, Equatable {
    case noUsableSatellites
}

public actor LocalSatelliteProvider {
    private let catalog: any TLECatalogLoading

    public init(catalog: any TLECatalogLoading = TLECatalog()) {
        self.catalog = catalog
    }

    public func visibleSatellites(
        selection: GNSSConstellation,
        observer: ObserverLocation,
        at date: Date = Date()
    ) async throws -> [VisibleSatellite] {
        let records = try await catalog.records(for: selection, now: date)
        let observerPosition = LatLonAlt(
            observer.latitude,
            observer.longitude,
            observer.altitudeMeters / 1_000
        )

        let visible = records.compactMap { record -> VisibleSatellite? in
            guard formatOK(record.line1, record.line2) else {
                return nil
            }
            do {
                let elements = try Elements(
                    record.name,
                    record.line1,
                    record.line2
                )
                let satellite = Satellite(withTLE: elements)
                let position = try satellite.topPosition(
                    julianDays: date.julianDate,
                    observer: observerPosition
                )
                guard position.elev > 0 else {
                    return nil
                }
                return VisibleSatellite(
                    name: displayName(for: record),
                    azimuth: position.azim,
                    elevation: position.elev,
                    constellation: record.constellation
                )
            } catch {
                return nil
            }
        }

        guard !visible.isEmpty else {
            throw LocalSatelliteProviderError.noUsableSatellites
        }

        return visible.sorted { lhs, rhs in
            let leftOrder = constellationOrder(lhs.constellation)
            let rightOrder = constellationOrder(rhs.constellation)
            if leftOrder != rightOrder {
                return leftOrder < rightOrder
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func displayName(for record: TLERecord) -> String {
        guard let identifier = satelliteIdentifier(from: record.name) else {
            return record.name
        }
        return "\(record.constellation.displayPrefix)\(identifier)"
    }

    private func satelliteIdentifier(from name: String) -> String? {
        let markers = ["PRN E", "PRN ", "(C", "("]
        for marker in markers {
            guard let markerRange = name.range(of: marker) else {
                continue
            }
            let suffix = name[markerRange.upperBound...]
            let digits = suffix
                .drop(while: { !$0.isNumber })
                .prefix(while: \.isNumber)
            if !digits.isEmpty {
                return String(digits)
            }
        }
        return nil
    }

    private func constellationOrder(_ constellation: GNSSConstellation) -> Int {
        switch constellation {
        case .gps:
            0
        case .glonass:
            1
        case .galileo:
            2
        case .beidou:
            3
        case .sbas:
            4
        case .all:
            5
        }
    }
}
