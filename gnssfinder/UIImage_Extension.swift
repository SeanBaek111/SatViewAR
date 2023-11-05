//
//  UIImage_Extension.swift
//  GnssFinder
//
//  Created by Sean on 5/11/2023.
//

import UIKit
extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        self.draw(in: CGRect(origin: .zero, size: size))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage ?? self
    }
}
extension UIImage {
    func averagePixelValue(centeredAt point: CGPoint) -> Int? {
        guard let cgImage = self.cgImage else { return nil }
        
        let width = Int(self.size.width)
        let height = Int(self.size.height)
        
        guard point.x < CGFloat(width) && point.y < CGFloat(height) && point.x >= 0 && point.y >= 0 else {
            return nil
        }
        
        let bitsPerComponent = 8
        let bytesPerPixel = 4
        let totalBytes = width * height * bytesPerPixel
        
        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(data: &pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerPixel * width,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var rTotal: UInt32 = 0
    
        let sampleSize = 3
        
        for i in -1...1 {
            for j in -1...1 {
                let x = min(max(0, Int(point.x) + i), width - 1)
                let y = min(max(0, Int(point.y) + j), height - 1)
                let index = ((width * y) + x) * bytesPerPixel
                rTotal += UInt32(pixelData[index])
            
                
            }
        }
        
        let count = UInt32(sampleSize * sampleSize)
        let r = UInt8(rTotal / count)
   
        
        var res:Int = 0
        if r < 100 {
       //     print("이게 rrrr ", r)
            res = 6
        }
        else{
           res = 200
        }
        return res
    }

    
    func pixelValue(at point: CGPoint) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)? {
      
        guard let cgImage = self.cgImage else {
            return nil }
        
        let width = Int(self.size.width)
        let height = Int(self.size.height)
        
        print("in pixelValue", point.x, point.y, width, height)
        guard point.x < CGFloat(width) && point.y < CGFloat(height) && point.x >= 0 && point.y >= 0 else {
            return nil
        }
        
        let bitsPerComponent = 8
        let bytesPerPixel = 4
        let totalBytes = width * height * bytesPerPixel
        
        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(data: &pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerPixel * width,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let index = ((width * Int(point.y)) + Int(point.x)) * bytesPerPixel
        let r = pixelData[index]
        let g = pixelData[index + 1]
        let b = pixelData[index + 2]
        let a = pixelData[index + 3]
        
        return (r, g, b, a)
    }
}
