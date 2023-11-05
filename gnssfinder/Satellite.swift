import ARKit

class Satellite {
    let name: String
    let azimuth: Double
    let elevation: Double
    
    private var _planeNode: SCNNode?
    public var planeNode: SCNNode? {
        get {
            return _planeNode
        }
        set {
            _planeNode = newValue
        }
    }
    
    private var _isChecked: Bool = false
    private var _isLOS: Bool = true  // LOS (Line of Sight) is default. Set to false if it's NLOS (Non-Line of Sight).

    var isChecked: Bool {
        get {
            return _isChecked
        }
        set {
            _isChecked = newValue
        }
    }

    var isLOS: Bool {
        get {
            return _isLOS
        }
        set {
            _isLOS = newValue
        }
    }
    
    var pixelPosition: CGPoint?

    init(name: String, azimuth: Double, elevation: Double, planeNode: SCNNode? = nil) {
        self.name = name
        self.azimuth = azimuth
        self.elevation = elevation
        self._planeNode = planeNode
    }
    
    func getSatelliteInfo()-> String{
        var res = ""
        res += String(format:"%@, ", self.name)
        res += String(format:"El: %.2f, ", self.elevation)
        res += String(format:"Az: %.2f\n", self.azimuth)
        
        return res
    }
    
    /// Updates the position of the planeNode if it exists.
    func updatePlaneNodePosition(position: SCNVector3) {
        _planeNode?.position = position
    }
     
}
