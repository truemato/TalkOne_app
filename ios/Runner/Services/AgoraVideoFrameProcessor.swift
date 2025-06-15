import Foundation
import UIKit
import CoreImage
// import AgoraRtcKit // Temporarily disabled due to potential compatibility issues

class AgoraVideoFrameProcessor: NSObject {
    
    private let aiFilterService = AIFilterService.shared
    private var isFilterEnabled = false
    private var filterParams = AIFilterService.FilterParams()
    
    // Performance optimization
    private let processQueue = DispatchQueue(label: "com.talkone.videoprocessor", qos: .userInteractive)
    private var processingInProgress = false
    
    func setFilterEnabled(_ enabled: Bool) {
        isFilterEnabled = enabled
    }
    
    func setFilterParams(threshold1: Int, threshold2: Int, colorful: Bool) {
        filterParams.threshold1 = CGFloat(threshold1)
        filterParams.threshold2 = CGFloat(threshold2)
        filterParams.enableColorful = colorful
    }
    
    func release() {
        // Cleanup resources
        isFilterEnabled = false
    }
}

// MARK: - AgoraVideoFrameDelegate (Temporarily disabled)
/*
extension AgoraVideoFrameProcessor: AgoraVideoFrameDelegate {
    
    func onCapture(_ videoFrame: AgoraOutputVideoFrame, sourceType: AgoraVideoSourceType) -> Bool {
        guard isFilterEnabled else { return true }
        
        // Skip if already processing to maintain performance
        guard !processingInProgress else { return true }
        
        processingInProgress = true
        
        // Process video frame asynchronously
        processQueue.async { [weak self] in
            guard let self = self else { return }
            
            defer { self.processingInProgress = false }
            
            // Convert CVPixelBuffer to UIImage
            guard let pixelBuffer = videoFrame.pixelBuffer,
                  let image = self.pixelBufferToUIImage(pixelBuffer) else {
                return
            }
            
            // Apply AI filter
            guard let filteredImage = self.aiFilterService.applyAIFilter(to: image, params: self.filterParams) else {
                return
            }
            
            // Convert filtered image back to pixel buffer
            if let newPixelBuffer = self.uiImageToPixelBuffer(filteredImage, targetPixelBuffer: pixelBuffer) {
                // Update the video frame with filtered content
                CVPixelBufferLockBaseAddress(pixelBuffer, [])
                CVPixelBufferLockBaseAddress(newPixelBuffer, .readOnly)
                
                // Copy filtered pixels back to original buffer
                let srcData = CVPixelBufferGetBaseAddress(newPixelBuffer)
                let dstData = CVPixelBufferGetBaseAddress(pixelBuffer)
                let dataSize = CVPixelBufferGetDataSize(pixelBuffer)
                
                if let src = srcData, let dst = dstData {
                    memcpy(dst, src, dataSize)
                }
                
                CVPixelBufferUnlockBaseAddress(newPixelBuffer, .readOnly)
                CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            }
        }
        
        return true
    }
    
    func onRenderVideoFrame(_ videoFrame: AgoraOutputVideoFrame, uid: UInt, channelId: String) -> Bool {
        // Don't process remote video frames for now
        return true
    }
    
    func getVideoFrameProcessMode() -> AgoraVideoFrameProcessMode {
        return .readWrite
    }
    
    func getVideoFormatPreference() -> AgoraVideoFormat {
        return .cvPixelBGRA
    }
    
    func getRotationApplied() -> Bool {
        return false
    }
    
    func getMirrorApplied() -> Bool {
        return false
    }
    
    func getObservedFramePosition() -> AgoraVideoFramePosition {
        return .postCapture
    }
    
    // MARK: - Helper Methods
    
    private func pixelBufferToUIImage(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func uiImageToPixelBuffer(_ image: UIImage, targetPixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(targetPixelBuffer)
        let height = CVPixelBufferGetHeight(targetPixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(targetPixelBuffer)
        
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                       width,
                                       height,
                                       pixelFormat,
                                       attrs as CFDictionary,
                                       &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                               width: width,
                               height: height,
                               bitsPerComponent: 8,
                               bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                               space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        guard let ctx = context, let cgImage = image.cgImage else {
            return nil
        }
        
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return buffer
    }
}
*/