import AVFoundation
import AppKit

class ScreenRecorder: NSObject, AVCaptureFileOutputRecordingDelegate {
    private let session = AVCaptureSession()
    private var movieOutput = AVCaptureMovieFileOutput()
    private var screenInput: AVCaptureScreenInput?
    private var audioInput: AVCaptureDeviceInput?
    
    var onCompletion: ((URL?, Error?) -> Void)?
    var onStart: (() -> Void)?
    
    func start(
        destinationURL: URL,
        resolution: String, // "native", "1080p", "720p"
        captureMode: String, // "fullscreen", "selected"
        micEnabled: Bool,
        fps: Int, // 30 or 60
        quality: String, // "low", "medium", "high"
        cropRect: CGRect?, // custom drag-selected area crop rect
        completion: @escaping (URL?, Error?) -> Void
    ) {
        self.onCompletion = completion
        
        // Request Microphone access if enabled
        if micEnabled {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            if status == .notDetermined {
                AVCaptureDevice.requestAccess(for: .audio) { _ in
                    self.configureAndStart(destinationURL: destinationURL, resolution: resolution, captureMode: captureMode, micEnabled: true, fps: fps, quality: quality, cropRect: cropRect)
                }
                return
            } else if status == .denied || status == .restricted {
                // If denied, proceed without mic
                self.configureAndStart(destinationURL: destinationURL, resolution: resolution, captureMode: captureMode, micEnabled: false, fps: fps, quality: quality, cropRect: cropRect)
                return
            }
        }
        
        self.configureAndStart(destinationURL: destinationURL, resolution: resolution, captureMode: captureMode, micEnabled: micEnabled, fps: fps, quality: quality, cropRect: cropRect)
    }
    
    private func configureAndStart(
        destinationURL: URL,
        resolution: String,
        captureMode: String,
        micEnabled: Bool,
        fps: Int,
        quality: String,
        cropRect: CGRect?
    ) {
        session.beginConfiguration()
        
        // Clean existing inputs/outputs
        for input in session.inputs {
            session.removeInput(input)
        }
        for output in session.outputs {
            session.removeOutput(output)
        }
        
        // Screen input Setup
        let displayID = CGMainDisplayID()
        guard let screenInput = AVCaptureScreenInput(displayID: displayID) else {
            DispatchQueue.main.async {
                self.onCompletion?(nil, NSError(domain: "ScreenRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize screen input. Check screen recording permissions in System Settings."]))
            }
            return
        }
        
        // Config options
        screenInput.capturesCursor = true
        screenInput.capturesMouseClicks = true
        
        // Configure Frame Rate (30fps vs 60fps)
        let frameRate = max(1, min(120, fps))
        screenInput.minFrameDuration = CMTime(value: 1, timescale: Int32(frameRate))
        
        // Selected capture area (uses user drag selected window frame if available)
        if captureMode == "selected" {
            if let customCrop = cropRect {
                screenInput.cropRect = customCrop
            } else {
                let screenBounds = CGDisplayBounds(displayID)
                let width = screenBounds.width * 0.75
                let height = screenBounds.height * 0.75
                let x = (screenBounds.width - width) / 2
                let y = (screenBounds.height - height) / 2
                screenInput.cropRect = CGRect(x: x, y: y, width: width, height: height)
            }
        }
        
        // Resolution Scaling factoring Retina backingScaleFactor to get precise physical pixel output
        let screenBounds = CGDisplayBounds(displayID)
        let referenceHeight = captureMode == "selected" ? (cropRect?.height ?? (screenBounds.height * 0.75)) : screenBounds.height
        let backingScale = NSScreen.main?.backingScaleFactor ?? 2.0
        let referenceHeightPixels = referenceHeight * backingScale
        
        if resolution == "1080p" {
            let scale = 1080.0 / referenceHeightPixels
            if scale < 1.0 {
                screenInput.scaleFactor = scale
            }
        } else if resolution == "720p" {
            let scale = 720.0 / referenceHeightPixels
            if scale < 1.0 {
                screenInput.scaleFactor = scale
            }
        }
        
        if session.canAddInput(screenInput) {
            session.addInput(screenInput)
        }
        
        // Audio setup (Microphone)
        if micEnabled {
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            }
        }
        
        // Output setup
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        
        session.commitConfiguration()
        
        // Trigger system Screen Recording permission dialog prompt if needed
        if #available(macOS 14.0, *) {
            // Under macOS 14+, ScreenCaptureKit / CGRequestScreenCaptureAccess checks access
            _ = CGRequestScreenCaptureAccess()
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            
            // Apply hardware-accelerated HEVC (H.265) output compression settings for up to 50% smaller sizes at same quality
            if let connection = self.movieOutput.connection(with: .video) {
                var settings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.hevc
                ]
                
                var compressionProperties: [String: Any] = [:]
                // Target bitrates optimized for highly efficient HEVC compression
                // Low = 600 Kbps, Medium = 1.4 Mbps, High = 3.0 Mbps
                var averageBitrate: Int = 1_400_000 // default 1.4 Mbps
                if quality == "low" {
                    averageBitrate = 600_000
                } else if quality == "high" {
                    averageBitrate = 3_000_000
                } else if quality == "ultra" {
                    averageBitrate = 12_000_000
                }
                
                compressionProperties[AVVideoAverageBitRateKey] = averageBitrate
                compressionProperties[AVVideoMaxKeyFrameIntervalKey] = 120 // 2s at 60fps, increases compression efficiency
                settings[AVVideoCompressionPropertiesKey] = compressionProperties
                
                self.movieOutput.setOutputSettings(settings, for: connection)
            }
            
            self.movieOutput.startRecording(to: destinationURL, recordingDelegate: self)
            DispatchQueue.main.async {
                self.onStart?()
            }
        }
    }
    
    func pause() {
        guard session.isRunning && !movieOutput.isRecordingPaused else { return }
        movieOutput.pauseRecording()
    }
    
    func resume() {
        guard session.isRunning && movieOutput.isRecordingPaused else { return }
        movieOutput.resumeRecording()
    }
    
    func stop() {
        guard session.isRunning else { return }
        movieOutput.stopRecording()
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
    }
    
    // MARK: - AVCaptureFileOutputRecordingDelegate
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Started
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            // Check if recording succeeded despite minor stop errors
            if let err = error as NSError?, err.code == NSURLErrorUnknown {
                self.onCompletion?(outputFileURL, nil)
            } else {
                self.onCompletion?(outputFileURL, error)
            }
        }
    }
}
