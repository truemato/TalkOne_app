import Foundation
import CoreImage
import UIKit
import Accelerate

class AIFilterService {
    
    // Singleton instance
    static let shared = AIFilterService()
    
    // Filter parameters
    var threshold1: CGFloat = 100.0
    var threshold2: CGFloat = 200.0
    var enableColorful: Bool = true
    
    // Core Image filters
    private let context = CIContext()
    private let edgeDetector = CIFilter(name: "CIEdges")
    private let colorControls = CIFilter(name: "CIColorControls")
    
    private init() {}
    
    struct FilterParams {
        var threshold1: CGFloat = 100.0
        var threshold2: CGFloat = 200.0
        var enableColorful: Bool = true
        var detectFaceOnly: Bool = true
    }
    
    /// Apply AI filter to transform face into colorful edge detection
    func applyAIFilter(to image: UIImage, params: FilterParams) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // Convert to grayscale for edge detection
        let grayscale = ciImage.applyingFilter("CIPhotoEffectNoir")
        
        // Apply Gaussian blur to reduce noise
        let blurred = grayscale.applyingGaussianBlur(sigma: 1.4)
        
        // Apply edge detection (Canny-like effect using CIEdges)
        edgeDetector?.setValue(blurred, forKey: kCIInputImageKey)
        edgeDetector?.setValue(params.threshold1 / 255.0, forKey: kCIInputIntensityKey)
        
        guard let edges = edgeDetector?.outputImage else { return nil }
        
        // Create black background
        let blackBackground = CIImage(color: CIColor.black)
            .cropped(to: ciImage.extent)
        
        var result: CIImage
        
        if params.enableColorful {
            // Apply colorful edge effect
            result = applyColorfulEdges(edges: edges, originalImage: ciImage)
        } else {
            // Simple white edges on black background
            result = edges
        }
        
        // Composite edges over black background
        let composite = result.composited(over: blackBackground)
        
        // Convert back to UIImage
        guard let cgImage = context.createCGImage(composite, from: composite.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    /// Apply colorful edges based on edge angles (similar to the Python/Java implementation)
    private func applyColorfulEdges(edges: CIImage, originalImage: CIImage) -> CIImage {
        // Detect lines using custom implementation
        let lines = detectLines(in: edges)
        
        // Create a new image for colored edges
        let extent = edges.extent
        UIGraphicsBeginImageContextWithOptions(extent.size, false, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return edges
        }
        
        // Fill with black background
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(CGRect(origin: .zero, size: extent.size))
        
        if !lines.isEmpty {
            // Draw colored lines based on angle
            for line in lines {
                let angle = atan2(line.end.y - line.start.y, line.end.x - line.start.x)
                let degrees = (angle * 180.0 / .pi) + 90
                
                // Convert angle to hue (0-360 degrees to 0-1 hue)
                let hue = CGFloat(degrees.truncatingRemainder(dividingBy: 360.0)) / 360.0
                let color = UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
                
                ctx.setStrokeColor(color.cgColor)
                ctx.setLineWidth(3.0)
                ctx.move(to: line.start)
                ctx.addLine(to: line.end)
                ctx.strokePath()
            }
        } else {
            // If no lines detected, show rainbow gradient edges
            guard let cgImage = context.createCGImage(edges, from: edges.extent) else {
                UIGraphicsEndImageContext()
                return edges
            }
            
            let edgeImage = UIImage(cgImage: cgImage)
            
            // Apply rainbow gradient based on position
            for y in stride(from: 0, to: Int(extent.height), by: 2) {
                for x in stride(from: 0, to: Int(extent.width), by: 2) {
                    let point = CGPoint(x: x, y: y)
                    
                    // Check if edge exists at this point
                    if isEdgeAt(point: point, in: edgeImage) {
                        let hue = CGFloat((x + y) % 180) / 180.0
                        let color = UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
                        
                        ctx.setFillColor(color.cgColor)
                        ctx.fill(CGRect(x: CGFloat(x), y: CGFloat(y), width: 2, height: 2))
                    }
                }
            }
        }
        
        let coloredImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let finalImage = coloredImage,
              let ciColoredImage = CIImage(image: finalImage) else {
            return edges
        }
        
        return ciColoredImage
    }
    
    /// Detect lines in edge image (simplified Hough transform)
    private func detectLines(in edgeImage: CIImage) -> [Line] {
        var lines: [Line] = []
        
        // Convert to CGImage for pixel access
        guard let cgImage = context.createCGImage(edgeImage, from: edgeImage.extent) else {
            return lines
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Simple line detection (simplified for performance)
        let minLineLength = 80
        let maxGap = 5
        
        // Scan for horizontal and vertical lines
        for y in stride(from: 0, to: height, by: 10) {
            var lineStart: CGPoint?
            var lineLength = 0
            
            for x in 0..<width {
                if isPixelBright(at: CGPoint(x: x, y: y), in: cgImage) {
                    if lineStart == nil {
                        lineStart = CGPoint(x: x, y: y)
                    }
                    lineLength += 1
                } else {
                    if let start = lineStart, lineLength > minLineLength {
                        lines.append(Line(start: start, end: CGPoint(x: x - 1, y: y)))
                    }
                    lineStart = nil
                    lineLength = 0
                }
            }
        }
        
        return lines
    }
    
    /// Check if pixel is bright (edge)
    private func isPixelBright(at point: CGPoint, in cgImage: CGImage) -> Bool {
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data else {
            return false
        }
        
        let pixelData = CFDataGetBytePtr(data)
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        
        let pixelOffset = Int(point.y) * bytesPerRow + Int(point.x) * bytesPerPixel
        
        if pixelOffset < CFDataGetLength(data) {
            let brightness = pixelData?[pixelOffset] ?? 0
            return brightness > 128
        }
        
        return false
    }
    
    /// Check if edge exists at point
    private func isEdgeAt(point: CGPoint, in image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        return isPixelBright(at: point, in: cgImage)
    }
    
    /// Line structure
    private struct Line {
        let start: CGPoint
        let end: CGPoint
    }
}