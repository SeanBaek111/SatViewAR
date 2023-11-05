//
//  ViewController.swift
//  SatViewAR
//
//  Created by Sean on 18/9/2023.
//
import UIKit
import ARKit
import CoreLocation
import SceneKit
import TensorFlowLiteTaskVision
import CoreMotion


class ViewController: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate {

    var arView: ARSCNView!
    var locationManager = CLLocationManager()
    var currentLocation: CLLocation?
    var refreshTimeLabel: UILabel!
    var headingLabel: UILabel!
    var trueNorthHeading: CLLocationDirection?
    var satelliteCountLabel: UILabel!
    var unCheckedCountLabel: UILabel!
    var inferenceStatusLabel: UILabel!
    
    var scrollView: UIScrollView!
    var satellitesStatusLabel: UILabel!
    var losLabal: UILabel!
    var nlosLabel: UILabel!
    var last10Label: UILabel!
    var resultLabel: UILabel!
    var testButton: UIButton!
    var refreshButton: UIButton!
    /// Target image to run image segmentation on.
    private var targetImage: UIImage?
    /// Image segmentator instance that runs image segmentation.
    private var imageSegmentationHelper: ImageSegmentationHelper?
    let motionManager = CMMotionManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        // CLLocationManager 설정
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingHeading()
        locationManager.startUpdatingLocation()
        // ARSCNView 설정
        arView = ARSCNView(frame: self.view.frame)
        self.view.addSubview(arView)
        
        // delegate 설정
        arView.delegate = self
        
        // 세션 설정
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        arView.session.run(configuration)
        
        // Initialize an image segmentator instance.
        ImageSegmentationHelper.newInstance { result in
          switch result {
          case let .success(segmentationHelper):
            // Store the initialized instance for use.
            self.imageSegmentationHelper = segmentationHelper

            // Run image segmentation on a demo image.
             
          case .failure(_):
            print("Failed to initialize.")
          }
        }
        
        // headingLabel 설정
        let labelWidth: CGFloat = self.view.frame.size.width/2-20
        let labelHeight: CGFloat = 40
        let labelX: CGFloat = 20
        let labelY: CGFloat = self.view.frame.size.height - labelHeight - 20
        
        DataManager.shared.frameSize = self.view.frame.size
       
        
        satelliteCountLabel = UILabel(frame: CGRect(x: labelX, y: labelY - 3 * labelHeight, width: labelWidth, height: labelHeight))
        satelliteCountLabel.backgroundColor = .lightGray
        satelliteCountLabel.layer.opacity = 0.5
        satelliteCountLabel.textColor = .black
        satelliteCountLabel.textAlignment = .left
        satelliteCountLabel.text = " Total Satellites: 0"
        self.view.addSubview(satelliteCountLabel)
        
        unCheckedCountLabel = UILabel(frame: CGRect(x: labelX+labelWidth, y: labelY - 3 * labelHeight, width: labelWidth, height: labelHeight))
        unCheckedCountLabel.backgroundColor = .lightGray
        unCheckedCountLabel.layer.opacity = 0.5
        unCheckedCountLabel.textColor = .black
        unCheckedCountLabel.textAlignment = .left
        
        unCheckedCountLabel.text = " Unchecked: 0"
        self.view.addSubview(unCheckedCountLabel)
        
         
        resultLabel = UILabel(frame: CGRect(x: labelWidth+20, y: labelY - 4 * labelHeight, width: labelWidth, height: labelHeight))
        resultLabel.backgroundColor = .yellow
        resultLabel.layer.opacity = 0.5
        resultLabel.textColor = .black
        resultLabel.textAlignment = .left
        resultLabel.text = "----"
        resultLabel.isHidden = true
        self.view.addSubview(resultLabel)
        
        losLabal = UILabel(frame: CGRect(x: labelX, y: labelY - 2 * labelHeight, width: labelWidth, height: labelHeight))
        losLabal.backgroundColor = .green
        losLabal.layer.opacity = 0.5
        losLabal.textColor = .black
        losLabal.textAlignment = .left
        losLabal.text = " LOS: -"
        self.view.addSubview(losLabal)
        
        nlosLabel = UILabel(frame: CGRect(x: labelWidth+20, y: labelY - 2 * labelHeight, width: labelWidth, height: labelHeight))
        nlosLabel.backgroundColor = .orange
        nlosLabel.layer.opacity = 0.5
        nlosLabel.textColor = .black
        nlosLabel.textAlignment = .left
        nlosLabel.text = " NLOS: -"
        self.view.addSubview(nlosLabel)
        
        
        
        testButton = UIButton(frame: CGRect(x: labelX+labelWidth , y: labelY-labelHeight, width: labelWidth, height: labelHeight*2))
        testButton.backgroundColor = .blue
        testButton.setTitle("Measure", for: .normal)
        testButton.addTarget(self, action: #selector(captureScreen), for: .touchUpInside)

       

        headingLabel = UILabel(frame: CGRect(x: labelX, y: labelY, width: labelWidth, height: labelHeight))
        headingLabel.backgroundColor = .lightGray
        headingLabel.layer.opacity = 0.5
        headingLabel.textColor = .black
        headingLabel.textAlignment = .left
        self.view.addSubview(headingLabel)
        
        
        self.view.addSubview(testButton)
        
        
        inferenceStatusLabel = UILabel(frame: CGRect(x: labelX, y: labelY - 1 * labelHeight, width: labelWidth, height: labelHeight))
        inferenceStatusLabel.backgroundColor = .lightGray
        inferenceStatusLabel.layer.opacity = 0.5
        inferenceStatusLabel.textColor = .black
        inferenceStatusLabel.textAlignment = .left
        inferenceStatusLabel.text = " Elapsed Time: 0ms"
        self.view.addSubview(inferenceStatusLabel)
        
         
        last10Label = UILabel(frame: CGRect(x: labelWidth+20, y: labelY - 6 * labelHeight, width: labelWidth, height: labelHeight*3))
        last10Label.backgroundColor = .yellow
        last10Label.layer.opacity = 0.4
        last10Label.textColor = .black
        last10Label.numberOfLines = 0
        last10Label.textAlignment = .left
        last10Label.isHidden = true
        last10Label.text = ""
        self.view.addSubview(last10Label)
        
        let satellitesStatusLabelHeight = labelHeight*10
         
       scrollView = UIScrollView(frame: CGRect(x: labelX, y: self.view.frame.size.height/2 - satellitesStatusLabelHeight/2 - labelHeight*2, width: self.view.frame.size.width - 40, height: satellitesStatusLabelHeight))
       self.view.addSubview(scrollView)
       
      
       satellitesStatusLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width - 40, height: 1000))
       satellitesStatusLabel.backgroundColor = .gray
       satellitesStatusLabel.layer.opacity = 0.7
       satellitesStatusLabel.textColor = .white
        satellitesStatusLabel.isHidden = true
       // satellitesStatusLabel.window.padding = 2
       satellitesStatusLabel.numberOfLines = 0
       satellitesStatusLabel.textAlignment = .left
       satellitesStatusLabel.text = "Loading..."
       scrollView.addSubview(satellitesStatusLabel)
       
      
       scrollView.contentSize = CGSize(width: satellitesStatusLabel.frame.size.width, height: satellitesStatusLabel.frame.size.height)
 
        
        refreshTimeLabel = UILabel(frame: CGRect(x: labelX, y: labelY - 5 * labelHeight, width: labelWidth, height: labelHeight))
        refreshTimeLabel.backgroundColor = .clear
        refreshTimeLabel.layer.opacity = 0.5
        refreshTimeLabel.textColor = .white
        refreshTimeLabel.numberOfLines = 0
        refreshTimeLabel.textAlignment = .left
        refreshTimeLabel.text = " Last Updated: --:--"
        self.view.addSubview(refreshTimeLabel)
        
        refreshButton = UIButton(frame: CGRect(x: labelX, y: labelY - 4 * labelHeight, width: labelWidth, height: labelHeight))

        
        refreshButton.backgroundColor = UIColor.blue.withAlphaComponent(0.7)

        
        refreshButton.layer.cornerRadius = 10
        refreshButton.clipsToBounds = true

   
        refreshButton.layer.shadowColor = UIColor.black.cgColor
        refreshButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        refreshButton.layer.shadowOpacity = 0.3
        refreshButton.layer.shadowRadius = 5

 
        refreshButton.setTitle("Refresh", for: .normal)
        refreshButton.setTitleColor(UIColor.white, for: .normal)
        refreshButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)

        refreshButton.addTarget(self, action: #selector(fetchGNSSData), for: .touchUpInside)
        self.view.addSubview(refreshButton)
  
       
        losLabal.backgroundColor = UIColor.green.withAlphaComponent(0.7)
        nlosLabel.backgroundColor = UIColor.orange.withAlphaComponent(0.7)

 
        applyButtonStyle(to: testButton)
        applyButtonStyle(to: refreshButton)

    
    }

    func handleDeviceMotionUpdate(data: CMDeviceMotion) {
        let pitchDegrees = data.attitude.pitch * (180.0 / .pi)   // Tilt forward/backward in degrees
       // let rollDegrees = data.attitude.roll * (180.0 / .pi)   // Tilt left/right in degrees
        let yawDegrees = data.attitude.yaw * (180.0 / .pi)     // Rotation around vertical axis in degrees

        print("pitchDegrees: \(pitchDegrees)°", "yawDegrees: ", yawDegrees  )

    }

    func overlayDataManagerImage() {
        
           let overlayImageView = UIImageView(frame: view.bounds)
           overlayImageView.contentMode = .scaleAspectFit
           overlayImageView.image = DataManager.shared.resultImage
           overlayImageView.alpha = 0.5
           arView.addSubview(overlayImageView)

 
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
               self.view.bringSubviewToFront(self.arView)
            
               //Bring ARView and other UI elements to front
        
               self.view.bringSubviewToFront(self.headingLabel)
               self.view.bringSubviewToFront(self.satelliteCountLabel)
               self.view.bringSubviewToFront(self.unCheckedCountLabel)
               self.view.bringSubviewToFront(self.inferenceStatusLabel)
               self.view.bringSubviewToFront(self.losLabal)
               self.view.bringSubviewToFront(self.nlosLabel)
               self.view.bringSubviewToFront(self.testButton)
               self.view.bringSubviewToFront(self.refreshButton)
               self.view.bringSubviewToFront(self.last10Label)
               self.view.bringSubviewToFront(self.resultLabel)
                self.view.bringSubviewToFront(self.refreshTimeLabel)
            //    self.view.bringSubviewToFront(self.satellitesStatusLabel)
                
               UIView.animate(withDuration: 0.5, animations: {
                   
                   overlayImageView.alpha = 0
                   
               }) { _ in
                   overlayImageView.removeFromSuperview()
                   
               }
           }
    }
    
    func applyDefaultStyle(to label: UILabel) {
        label.backgroundColor = UIColor.lightGray.withAlphaComponent(0.7)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.textColor = .black
        label.textAlignment = .left
        label.font = UIFont.systemFont(ofSize: 14)
        self.view.addSubview(label)
    }

    func applyButtonStyle(to button: UIButton) {
        button.backgroundColor = UIColor.blue.withAlphaComponent(0.7)
        button.layer.cornerRadius = 10
        button.clipsToBounds = true
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 5
        button.setTitleColor(UIColor.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        self.view.addSubview(button)
    }

   
    @objc func captureScreen(_ sender: UIButton) {
        DispatchQueue.main.async {
            self.satellitesStatusLabel.text = "Loading..."
           }
        // hide all satellite objects
        arView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == "satellite" {
                node.isHidden = true
            }
        }
        
        // capture screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            let screenshotImage = self.arView.snapshot()
 
            DataManager.shared.showSatellites()
            self.updateSatellitesPosition()
            self.runSegmentation(screenshotImage)
            
        }
    }
    
    
    func  updateSatellitesPosition(){
        for satellite in DataManager.shared.satellites{
            updatePixelPosition( for: satellite, worldPosition: satellite.planeNode!.position)
        }
        
    }
    
    func add3DBox(at degree: Double, elevation: Double) {
           let distance: Float = 1000.0  //
           
        let azimuthFixed = degree + 90.0
           // conver to radian
           let azimuthRadian = azimuthFixed * .pi / 180
           let elevationRadian = elevation * .pi / 180
           
           
           let x = -distance * cos(Float(elevationRadian)) * cos(Float(azimuthRadian))
           let y = distance * sin(Float(elevationRadian))
           let z = -distance * cos(Float(elevationRadian)) * sin(Float(azimuthRadian))
           
        let box = SCNBox(width: 20, height: 20, length: 20, chamferRadius: 0)
        
         let boxNode = SCNNode(geometry: box)
         boxNode.position = SCNVector3(x, y, z)
         
           arView.scene.rootNode.addChildNode(boxNode)
       }
    
    func showLast10(last10: [Satellite]) {
        let limit = 5
        var labelText = ""
        var cnt = 0
        for satellite in last10 {
            let prefixName = String(satellite.name.prefix(6))  // Extract the first 5 characters of the name
            labelText += " \(prefixName) \(Int(satellite.azimuth))°, \(Int(satellite.elevation))°"
            cnt+=1
            if cnt >= limit {
                break
            }
            if cnt < last10.count {
                labelText += "\n"}
        }
        last10Label.text = labelText
        last10Label.isHidden = false
       
        let labelHeight: CGFloat = 24
        
//        let diff:CGFloat = abs(last10LabelHeight - labelHeight * CGFloat(cnt))
//        print("diff ",diff)
        if cnt < 5 {
            let h1 = last10Label.frame.size.height
            last10Label.frame.size.height = labelHeight * CGFloat(cnt)
            let h2 = last10Label.frame.size.height
            let diff = h1 - h2
            last10Label.frame.origin.y += diff
            
        }
    }

    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        
           if newHeading.headingAccuracy > 0 {
               trueNorthHeading = newHeading.trueHeading
               headingLabel.text = String(format: " Azimuth: %d°", Int(trueNorthHeading!))

            
           }
       }
    
   
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            if let location = locations.last {
                currentLocation = location
              
                locationManager.stopUpdatingLocation()
            }
        }

    @IBAction func fetchGNSSData(_ sender: UIButton) {
        var satellitesStatus = ""
        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            self.losLabal.text = " LOS: -"
            self.nlosLabel.text = " NLOS: -"
            self.scrollView.isHidden = false
            self.satelliteCountLabel.text = "Loading..."
            self.satellitesStatusLabel.isHidden = false
            self.view.bringSubviewToFront(self.scrollView)
            self.view.bringSubviewToFront(self.satellitesStatusLabel)
            
          
        }
        last10Label.isHidden = true
        resultLabel.isHidden = true
        locationManager.startUpdatingLocation()

        guard let location = currentLocation else {
            print("Location data is not available.")
            return
        }
        let serverUrl = "http://122.151.161.76"
      //  serverUrl = "http://192.168.0.101:5001"
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        let altitude = location.altitude
        let group = "all"
        print("LOC :",latitude, longitude, altitude)
        satellitesStatus = "Longitude:" + String(format:"%.3f\n" , longitude) +
                            "Latitude:" + String(format:"%.3f\n" , latitude) +
                            "Altitude:" + String(format:"%.3f\n----------------------------\n" , altitude)
        let urlString = serverUrl+"/gnss?latitude=\(latitude)&longitude=\(longitude)&altitude=\(altitude)&group=\(group)&reload=true"
        if let url = URL(string: urlString) {
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("Error fetching data: \(error)")
                    return
                }
                
                if let data = data {
                    let parsedSatellites = DataManager.shared.parseSatellites(from: data)
                    self.placeSatellites(parsedSatellites)
                    
                    
                    DispatchQueue.main.async {
                        self.satelliteCountLabel.text = " Total Satellites: \(parsedSatellites.count)"
                        self.unCheckedCountLabel.text = " Unchecked: \(DataManager.shared.getUnCheckedCount())"
                        
                        for sat in parsedSatellites{
                            satellitesStatus +=  sat.getSatelliteInfo()
                        }
                        self.satellitesStatusLabel.text = satellitesStatus
                    }
                }

            }
            task.resume()
            // Get the current date and time
            let currentDate = Date()

            // Create a date formatter
            let formatter = DateFormatter()

            // Set the desired format
            formatter.dateFormat = "HH:mm"

            // Convert the date to the desired format
            let timestamp = formatter.string(from: currentDate)

            // Set the text of the label
            self.refreshTimeLabel.text = " Last Updated: \(timestamp)"
        }
        
        
    }
     

    func updateWorldOriginToTrueNorth(_ trueNorth: CLLocationDirection) {
        let angle = -1 * .pi * trueNorth / 180.0 // 변환된 각도
        let rotation = simd_float4x4(SCNMatrix4MakeRotation(Float(angle), 0, 1, 0))
        arView.session.setWorldOrigin(relativeTransform: rotation)
    }
     
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        
        arView.session.pause()
    }
    
    func add2DSatellite(satellite: Satellite, at position: SCNVector3) {
     
        let plane = SCNPlane(width: 30, height: 30)  // 적절한 크기로 조절하세요
        plane.firstMaterial?.diffuse.contents = UIImage(named: "satellite.png")
        
       
        let planeNode = SCNNode(geometry: plane)
        planeNode.position = position
        planeNode.name = "satellite"
        
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        planeNode.constraints = [billboardConstraint]
 
        let text = SCNText(string: satellite.name, extrusionDepth: 1.0)
        text.font = UIFont.systemFont(ofSize: 515.0)

        let textMaterial = SCNMaterial()
        textMaterial.diffuse.contents = UIColor.darkText
        text.materials = [textMaterial]

        let textNode = SCNNode(geometry: text)
        textNode.scale = SCNVector3(0.03, 0.03, 0.03)

        let minVec = text.boundingBox.min
        let maxVec = text.boundingBox.max
        let bound = SCNVector3Make(maxVec.x - minVec.x, maxVec.y - minVec.y, maxVec.z - minVec.z)
        textNode.pivot = SCNMatrix4MakeTranslation(bound.x / 2, bound.y / 2, bound.z / 2)
 
        let halfPlaneHeight = Float(-plane.height / 2)

        let halfBoundY = Float(bound.y / 2)
        let scaledBoundY = halfBoundY * textNode.scale.y
        textNode.position.y = halfPlaneHeight - scaledBoundY

        let lookAtConstraint = SCNLookAtConstraint(target: arView.pointOfView)
        lookAtConstraint.isGimbalLockEnabled = true
        lookAtConstraint.localFront = SCNVector3(0, 0, 1)
        textNode.constraints = [lookAtConstraint]

        planeNode.addChildNode(textNode)
 
        arView.scene.rootNode.addChildNode(planeNode)
        satellite.planeNode = planeNode
    }
     
    
    func placeSatellites(_ satellites: [Satellite]) {
       
        arView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == "satellite" {
                node.removeFromParentNode()
            }
        }
      
        for satellite in satellites {
     
            let sphere = SCNSphere(radius: 10.02)
           
            let material = SCNMaterial()
            material.diffuse.contents = UIImage(named: "earth.jpeg")
            sphere.materials = [material]
            
            let node = SCNNode(geometry: sphere)
            
            
            node.name = "satellite"
 
            
       let distanceFromCamera: Double = 1000.0
 
           
                // Compute the cartesian coordinates of the satellite
                let cartesianCoordinates = cartesianFromSpherical(azimuth: satellite.azimuth, elevation: satellite.elevation, distance: distanceFromCamera)
                
            add2DSatellite(satellite: satellite, at: cartesianCoordinates)
            }
    }

}

extension ViewController {

    func add3DObject(at position: SCNVector3) {
           let sphere = SCNSphere(radius: 2)
           let node = SCNNode(geometry: sphere)
           node.position = position
           arView.scene.rootNode.addChildNode(node)
       }

       // Function to convert 3D space coordinates to SCNVector3
       func cartesianFromSpherical(azimuth: Double, elevation: Double, distance: Double ) -> SCNVector3 {
           
           let azimuthFixed = azimuth + 90.0
           
           let azimuthRad = azimuthFixed * .pi / 180.0
           let elevationRad = elevation * .pi / 180.0
        
           let x = -distance * cos(elevationRad) * cos(azimuthRad)
           let y = distance * sin(elevationRad)
           let z = -distance * cos(elevationRad) * sin(azimuthRad)
           
           return SCNVector3(x, y, z)
       }
}
 
extension SCNVector3 {
    init(from simdVector: simd_float3) {
        self.init(x: Float(CGFloat(simdVector.x)), y: Float(CGFloat(simdVector.y)), z: Float(CGFloat(simdVector.z)))
    }
}
extension ViewController {
    func updatePixelPosition(for satellite: Satellite, worldPosition: SCNVector3) {
       // let worldPosition = SCNVector3(x: Float(satellite.azimuth), y: Float(satellite.elevation), z: 0)  // Adjust based on your 3D positioning.
        let projectedPoint = arView.projectPoint(worldPosition)
        let screenScale = UIScreen.main.scale
        let screenX = CGFloat(projectedPoint.x) * screenScale
        let screenY = CGFloat(projectedPoint.y) * screenScale
        
      
        satellite.pixelPosition = CGPoint(x: screenX , y: screenY)
        //print("POS",satellite.name, screenX, screenY, satellite.azimuth, satellite.elevation)
    }
}
extension ViewController {
  /// Run image segmentation on the given image, and show result on screen.
  ///  - Parameter image: The target image for segmentation.
  func runSegmentation(_ image: UIImage) {
    clearResults()
    // Cache the original image
      let originalSize = image.size

      // Resize the image to 513x513
      let newSize = CGSize(width: 513, height: 513)
      UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
      image.draw(in: CGRect(origin: CGPoint.zero, size: newSize))
      let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()

      // Use the resized image for further processing
      guard let targetImage = resizedImage?.transformOrientationToUp() else {
        inferenceStatusLabel.text = "ERROR: Image orientation couldn't be fixed."
        return
      }

   
    // Make sure that image segmentator is initialized.
    guard let imageSegmentator = imageSegmentationHelper else {
      inferenceStatusLabel.text = "ERROR: Image Segmentator is not ready."
      return
    }

    // Cache the target image.
    self.targetImage = targetImage
 
     let inputImage =  targetImage
        
    // Run image segmentation.
    imageSegmentator.runSegmentation(
      inputImage,
      completion: { result in
 
        // Show the segmentation result on screen
        switch result {
        case let .success(segmentationResult):
    
          // Show result metadata
          self.showInferenceTime(segmentationResult)
          self.showClassLegend(segmentationResult)
            print(segmentationResult.resultImage.size)
            
            let resizedResultImage = segmentationResult.resultImage.resized(to: originalSize)
            //bsh
            print(resizedResultImage.size)
            
            
            DispatchQueue.main.async {
                DataManager.shared.resultImage = resizedResultImage
                self.overlayDataManagerImage()
                DataManager.shared.updateSateliteStatus()
                let nUnCheckedCnt:Int = DataManager.shared.getUnCheckedCount()
                if nUnCheckedCnt == 0{
                    self.unCheckedCountLabel.text = "COMPLETED"
                    self.last10Label.isHidden = true
                    
                    self.resultLabel.isHidden = false
                    self.resultLabel.text = DataManager.shared.getResult()
                }
                else{
                    self.unCheckedCountLabel.text = " Unchecked: \(nUnCheckedCnt)"
                }
               
                self.losLabal.text = " LOS: \(DataManager.shared.getLosCount())"
                self.nlosLabel.text = " NLOS: \(DataManager.shared.getNlosCount())"
            
             
                let listLast10: [Satellite] = DataManager.shared.getLast10()
             //   print("list10 cnt ", listLast10.count)
                if  listLast10.count > 0 {
                    self.showLast10(last10: listLast10)
                }
           
               
            
          }
            
           
        case let .failure(error):
          self.inferenceStatusLabel.text = error.localizedDescription
        }
      })
  }

  /// Clear result from previous run to prepare for new segmentation run.
  private func clearResults() {
    inferenceStatusLabel.text = " Running.."
  }

  /// Show segmentation latency on screen.
  private func showInferenceTime(_ segmentationResult: ImageSegmentationResult) {
    let timeString =
      " Elapsed Time: \(Int(segmentationResult.inferenceTime * 1000))ms"

    inferenceStatusLabel.text = timeString
  }

  /// Show color legend of each class found in the image.
  private func showClassLegend(_ segmentationResult: ImageSegmentationResult) {
    let legendText = NSMutableAttributedString()

    // Loop through the classes founded in the image.
    segmentationResult.colorLegend.forEach { (className, color) in
      // If the color legend is light, use black text font. If not, use white text font.
      let textColor = color.isLight() ?? true ? UIColor.black : UIColor.white

      // Construct the legend text for current class.
      let attributes = [
        NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .headline),
        NSAttributedString.Key.backgroundColor: color,
        NSAttributedString.Key.foregroundColor: textColor,
      ]
      let string = NSAttributedString(string: " \(className) ", attributes: attributes)

      // Add class legend to string to show on the screen.
      legendText.append(string)
      legendText.append(NSAttributedString(string: "  "))
    }
 
  }
}
 
