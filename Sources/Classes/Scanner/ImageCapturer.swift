import AVFoundation
import UIKit

final class ImageCapturer: NSObject {
    private var feature: RectangleFeature?
    private var imageClosure: ((UIImage) -> Void)

    private let output: AVCapturePhotoOutput

    init(session: AVCaptureSession) {
        let output = AVCapturePhotoOutput()
        output.isHighResolutionCaptureEnabled = true
        session.addOutput(output)
        self.output = output
        imageClosure = { _ in }

        super.init()
    }

    func captureImage(in rectangleFeature: RectangleFeature?, completion: @escaping (UIImage) -> Void) {
        feature = rectangleFeature
        imageClosure = completion

        let settings = AVCapturePhotoSettings()
        settings.isAutoStillImageStabilizationEnabled = true
        settings.isHighResolutionPhotoEnabled = true

        output.capturePhoto(with: settings, delegate: self)
    }
}

extension ImageCapturer: AVCapturePhotoCaptureDelegate {

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?,
                     previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
                     resolvedSettings: AVCaptureResolvedPhotoSettings,
                     bracketSettings: AVCaptureBracketedStillImageSettings?,
                     error: Error?) {

        guard let sampleBuffer = photoSampleBuffer,
            let imageData = AVCapturePhotoOutput
                .jpegPhotoDataRepresentation(
                    forJPEGSampleBuffer: sampleBuffer,
                    previewPhotoSampleBuffer: previewPhotoSampleBuffer),
            let image = CIImage(data: imageData)?.oriented(forExifOrientation: 6)
            else { return }

        let processed: CIImage
        if let feature = feature {
            let normalized = feature.normalized(source: UIScreen.main.bounds.size,
                                                target: image.extent.size)

            var topLeft = normalized.topLeft, topRight = normalized.topRight, bottomLeft = normalized.bottomLeft, bottomRight = normalized.bottomRight
            (topLeft, bottomRight) = extend(point1: topLeft, point2: bottomRight)
            (topRight, bottomLeft) = extend(point1: topRight, point2: bottomLeft)
            processed = image
                .applyingFilter("CIPerspectiveCorrection", parameters: [
                    "inputTopLeft": CIVector(cgPoint: topLeft),
                    "inputTopRight": CIVector(cgPoint: topRight),
                    "inputBottomLeft": CIVector(cgPoint: bottomLeft),
                    "inputBottomRight": CIVector(cgPoint: bottomRight)
                ])
        } else {
            processed = image
        }

        // This is necessary because most UIKit functionality expects UIImages
        // that have the cgImage property set
        if let cgImage = CIContext().createCGImage(processed, from: processed.extent) {
            imageClosure(UIImage(cgImage: cgImage))
        }
        
        /*if let image = processed.applyingAdaptiveThreshold() {
         imageClosure(image)
         }*/
        
        /*let enhancedImage = OpenCVWarpper.enhanceImage(processed)
        imageClosure(enhancedImage)*/
    }
}
