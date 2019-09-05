import AVFoundation
import UIKit

public final class AVDocumentScanner: NSObject {
    var lastTorchLevel: Float = 0
    public var desiredJitter: CGFloat = 100 {
        didSet { progress.completedUnitCount = Int64(desiredJitter) }
    }
    public var torchMode: AVCaptureDevice.TorchMode = .auto {
        didSet {
            if let device = device {
                do {
                    try device.lockForConfiguration()
                    device.torchMode = torchMode
                    device.unlockForConfiguration()
                } catch let error {
                    print("Couldn't set torch mode for device - \(error.localizedDescription)")
                }
            }
        }
    }
    public var flashMode: AVCaptureDevice.FlashMode = .auto
    public var featuresRequired: Int = 7
    public var detectorEnabled: Bool = true {
        didSet {
            updateOutput()
        }
    }

    public let progress = Progress()

    public lazy var previewLayer: CALayer = {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        return layer
    }()

    init(sessionPreset: AVCaptureSession.Preset) {
        let session = AVCaptureSession()

        if let device = device {
            do {
                try device.lockForConfiguration()
                device.focusMode = .continuousAutoFocus
                device.unlockForConfiguration()

                let input = try AVCaptureDeviceInput(device: device)

                session.beginConfiguration()
                if device.supportsSessionPreset(sessionPreset) {
                    session.sessionPreset = sessionPreset
                }
                session.addInput(input)
                session.commitConfiguration()
                //session.startRunning()
            } catch let error {
                fatalError("Device couldn't be initialized - \(error.localizedDescription)")
            }
        }

        captureSession = session
        imageCapturer = ImageCapturer(session: session)
        super.init()
        progress.completedUnitCount = Int64(desiredJitter)
        
        updateOutput()
    }

    public convenience init(sessionPreset: AVCaptureSession.Preset = .photo,
                            delegate: DocumentScannerDelegate) {
        self.init(sessionPreset: sessionPreset)
        self.delegate = delegate
    }

    private weak var delegate: DocumentScannerDelegate?
    private var isStopped = false
    private let imageCapturer: ImageCapturer
    private var lastFeatures: [RectangleFeature] = []
    private let captureSession: AVCaptureSession
    private let imageQueue = DispatchQueue(label: "imageQueue")

    private let device: AVCaptureDevice? = {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back
            ).devices
            .first { $0.hasTorch }
    }()

    private lazy var videoOutput: AVCaptureVideoDataOutput = {
        let output = AVCaptureVideoDataOutput()

        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        return output
    }()
    
    private var captureOutput: AVCaptureOutput?

    private let detector = CIDetector(ofType: CIDetectorTypeRectangle, context: nil, options: [
        CIDetectorAccuracy: CIDetectorAccuracyHigh,
        CIDetectorMaxFeatureCount: 10

        // swiftlint:disable:next force_unwrapping
        ])!
    
    private func updateOutput() {
        if let captureOutput = captureOutput {
            captureSession.beginConfiguration()
            captureSession.removeOutput(captureOutput)
            captureSession.commitConfiguration()
        }
        
        captureSession.beginConfiguration()
        if detectorEnabled {
            let layer = previewLayer as! AVCaptureVideoPreviewLayer
            layer.videoGravity = .resizeAspectFill
            
            videoOutput.setSampleBufferDelegate(self, queue: imageQueue)
            captureSession.addOutput(videoOutput)
            videoOutput.connection(with: .video)?.videoOrientation = .portrait
            captureOutput = videoOutput
        }
        else {
            let layer = previewLayer as! AVCaptureVideoPreviewLayer
            layer.videoGravity = .resizeAspect
            
            videoOutput.setSampleBufferDelegate(nil, queue: nil)
            captureOutput = nil
            
            let photoOutput: AVCapturePhotoOutput = captureSession.outputs[0] as! AVCapturePhotoOutput
            photoOutput.connection(with: .video)?.videoOrientation = .portrait
        }
        captureSession.commitConfiguration()
    }
}

extension AVDocumentScanner: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_: AVCaptureOutput,
                              didOutput sampleBuffer: CMSampleBuffer,
                              from _: AVCaptureConnection) {
        
        guard isStopped == false,
            CMSampleBufferIsValid(sampleBuffer),
            let buffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            else { return }

        let image = CIImage(cvImageBuffer: buffer)
        
        if !detectorEnabled {
            return
        }
        
        let feature = detector.features(in: image)
            .compactMap { $0 as? CIRectangleFeature }
            .map(RectangleFeature.init)
            .max()
            .map {
                $0.normalized(source: image.extent.size,
                              target: UIScreen.main.bounds.size)
            }
            .flatMap { smooth(feature: $0, in: image) }

        DispatchQueue.main.async {
            self.delegate?.didRecognize(feature: feature, in: image)
        }
    }

    func smooth(feature: RectangleFeature?, in image: CIImage) -> RectangleFeature? {
        guard let feature = feature else { return nil }

        var (smoothed, newFeatures) = feature.smoothed(with: lastFeatures)
        lastFeatures = newFeatures
        progress.totalUnitCount = Int64(newFeatures.jitter)
        smoothed.calculateAccuracy()

        if newFeatures.count > featuresRequired,
            newFeatures.jitter < desiredJitter,
            isStopped == false,
            smoothed.accuracy == nil,
            let delegate = delegate {

            pause()

            captureImage(in: smoothed) { [weak delegate] image in
                delegate?.didCapture(image: image)
            }
        }

        return smoothed
    }
}

extension AVDocumentScanner: DocumentScanner {
    public func captureImage(in bounds: RectangleFeature?, completion: @escaping (UIImage) -> Void) {
        imageCapturer.captureImage(in: bounds, completion: completion)
    }
    public func start() {
        guard !captureSession.isRunning else {
            return
        }
        captureSession.startRunning()
        isStopped = false
    }
    public func pause() {
        isStopped = true
    }
    public func stop() {
        guard captureSession.isRunning else {
            return
        }
        captureSession.stopRunning()
    }
    public func capturePhoto() {
        if detectorEnabled {
            return
        }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        let photoOutput: AVCapturePhotoOutput = captureSession.outputs[0] as! AVCapturePhotoOutput
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension AVDocumentScanner: TorchPickerViewDelegate {
    func toggleTorch() {
        do {
            try device?.lockForConfiguration()
            if device?.torchMode == .off {
                let level = lastTorchLevel != 0 ? lastTorchLevel : 0.5
                try device?.setTorchModeOn(level: level)
                lastTorchLevel = level
            } else {
                device?.torchMode = .off
                lastTorchLevel = 0
            }
            device?.unlockForConfiguration()
        } catch {}
    }

    func didPickTorchLevel(_ level: Float) {
        lastTorchLevel = level
        do {
            try device?.lockForConfiguration()
            switch level {
            case 0:
                device?.torchMode = .off
                lastTorchLevel = 0
            default:
                try device?.setTorchModeOn(level: level)
            }
            device?.unlockForConfiguration()
        } catch {}
    }
}

extension AVDocumentScanner: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            return
        }
        
        guard let data = photo.fileDataRepresentation() else {
            return
        }
        
        let dataProvider = CGDataProvider(data: data as CFData)
        let cgImageRef: CGImage! = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        let image = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: UIImage.Orientation.right)
        self.delegate?.didCapturePhoto(image: image)
    }
}
