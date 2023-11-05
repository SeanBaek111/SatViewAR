// Object3DManager.swift

import SceneKit

class Object3DManager {
    weak var scene: SCNScene?

    init(scene: SCNScene) {
        self.scene = scene
    }

    func add3DObject(at position: SCNVector3) {
        let sphereGeometry = SCNSphere(radius: 2)
        let sphereNode = SCNNode(geometry: sphereGeometry)
        sphereNode.position = position
        scene?.rootNode.addChildNode(sphereNode)
    }
}
