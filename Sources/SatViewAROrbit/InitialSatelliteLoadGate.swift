public struct InitialSatelliteLoadGate: Sendable {
    private var hasRequestedLoad = false

    public init() {}

    public mutating func shouldRequestLoad() -> Bool {
        guard !hasRequestedLoad else {
            return false
        }
        hasRequestedLoad = true
        return true
    }
}
