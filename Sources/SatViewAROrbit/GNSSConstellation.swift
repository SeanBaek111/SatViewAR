public enum GNSSConstellation: String, CaseIterable, Codable, Sendable {
    case all
    case gps
    case glonass
    case galileo
    case beidou
    case sbas

    public var celestrakGroup: String? {
        switch self {
        case .all:
            nil
        case .gps:
            "GPS-OPS"
        case .glonass:
            "glo-ops"
        case .galileo:
            "galileo"
        case .beidou:
            "beidou"
        case .sbas:
            "sbas"
        }
    }

    public var displayPrefix: String {
        switch self {
        case .all:
            ""
        case .gps:
            "GPS G"
        case .glonass:
            "GLONASS R"
        case .galileo:
            "Galileo E"
        case .beidou:
            "BeiDou B"
        case .sbas:
            "SBAS S"
        }
    }

    public var expanded: [GNSSConstellation] {
        switch self {
        case .all:
            [.gps, .glonass, .galileo, .beidou, .sbas]
        default:
            [self]
        }
    }
}
