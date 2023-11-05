//
//  SatelliteManager.swift
//  SatViewAR
//
//  Created by Sean on 18/9/2023.
//

import Foundation
import UIKit
import SceneKit

enum Direction {
    case up
    case down
    case left
    case right
    case none
}

class DataManager {
    static let shared = DataManager()  // create singleton instance

    private init() {}
    
    var resultImage: UIImage? = nil
    var satellites: [Satellite] = []
    var frameSize: CGSize = CGSize.zero
    func satelliteCount() -> Int {
            return satellites.count
        }
    
    func shortestDirection(from angle1: Double, to angle2: Double) -> (diff:Double, direction: Direction) {
        let delta = (angle2 - angle1 + 180).truncatingRemainder(dividingBy: 360) - 180
        return delta > 0 ? ( delta, Direction.right) : (delta, Direction.left)
    }

    func getLast10()->[Satellite]{
        var resList:[Satellite] = []
        
        let unCheckedCnt = getUnCheckedCount()
        if unCheckedCnt > 0 && unCheckedCnt <= 20 {
            
            for satellite in satellites{
                if satellite.isChecked == false {
                    resList.append(satellite)
                }
            }
        }
        
        return resList
    }
    func updateSateliteStatus()  {
        let screenScale = UIScreen.main.scale
        let originalFrameWidth = frameSize.width * screenScale
        let originalFrameHeight = frameSize.height * screenScale
        for satellite in satellites {
             
            if satellite.isChecked{
                satellite.planeNode?.isHidden = true
                continue
            }
            if let pixelPositionX = satellite.pixelPosition?.x, let pixelPositionY = satellite.pixelPosition?.y {
                if pixelPositionX < 0 || pixelPositionX > originalFrameWidth || pixelPositionY < 0 || pixelPositionY > originalFrameHeight {
                    // Satellite's position is outside the screen, so continue to the next iteration or perform some action
            
                    continue
                }
                else{
                    //   print("updateSateliteStatus", satellite.name, satellite.pixelPosition)
                    let coordinate = satellite.pixelPosition
                  // print("okokzzzzzzz" , satellite.name, coordinate)
                    if let pixelValue = resultImage?.averagePixelValue(centeredAt: coordinate!) {
                    //   print(satellite.name, "Red: \(pixelValue.red), Green: \(pixelValue.green), Blue: \(pixelValue.blue), Alpha: \(pixelValue.alpha)")
                        isLOS(sat: satellite, avgVal: pixelValue)
               //        print(" LOS " , satellite.name, satellite.isLOS)
                       if satellite.isLOS {
                           
                       }
                       else{
                           let plane = SCNPlane(width: 30, height: 30)  // 적절한 크기로 조절하세요
                           plane.firstMaterial?.diffuse.contents = UIImage(named: "nlos.png")
                           
                           satellite.planeNode?.geometry = plane
                       }
                        if satellite.isChecked{
                            satellite.planeNode?.isHidden = true
                           
                        }
                   }
                }
            }
            
            
        }
    }
    
    func isLOS(sat: Satellite, avgVal: Int) -> Void {
    //    print("isLOS ", sat.name, avgVal)
        if avgVal > 100 { sat.isLOS = false}
        else {sat.isLOS = true}
        sat.isChecked = true
    }
    func showSatellites(){
        for satellite in satellites {
            if satellite.isChecked == false {
                satellite.planeNode?.isHidden = false
            }
        }
    }
    
    func getResult() -> String {
        let nLosCnt = getLosCount()
        let nNlosCnt = getNlosCount()
        if (nLosCnt + nNlosCnt) != 0 {
            let percentage = (Double(nLosCnt) / Double(nLosCnt + nNlosCnt)) * 100.0
            return String(format: " LOS / Total: %.2f%%", percentage)
        } else {
            return " LOS / Total: N/A"
        }

    }
    func getUnCheckedCount() -> Int {
        var resCnt = 0
        for satellite in satellites {
            if satellite.isChecked == false {
                resCnt+=1
            }
        }
        if resCnt == 0{
            for satellite in satellites {
                satellite.planeNode?.isHidden = false
            }
        }
        return resCnt
    }
    func getNlosCount() -> Int{
        var resCnt = 0
        for satellite in satellites {
            if satellite.isChecked == true && satellite.isLOS == false {
                resCnt+=1
            }
        }
        return resCnt
    }
    func getLosCount() -> Int{
        var resCnt = 0
        for satellite in satellites {
            if satellite.isChecked == true && satellite.isLOS == true {
                resCnt+=1
            }
        }
        return resCnt
    }
    func parseSatellites(from data: Data) -> [Satellite] {
        var parsedSatellites: [Satellite] = []

        do {
            if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                for satelliteData in jsonResponse {
                    if let name = satelliteData["satellite"] as? String,
                       let azimuth = satelliteData["azimuth"] as? Double,
                       let elevation = satelliteData["elevation"] as? Double {
                        let satellite = Satellite(name: name, azimuth: azimuth, elevation: elevation)
                        parsedSatellites.append(satellite)
                    }
                }
            }
        } catch let parseError {
            print("Error parsing JSON: \(parseError)")
        }

        self.satellites = parsedSatellites
        return parsedSatellites
    }
}
