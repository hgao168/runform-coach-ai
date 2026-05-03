import SwiftUI
import AVFoundation
import Vision

struct LiveGuidanceRecorderView: View {
    let videoMode: VideoMode
    let onRecorded: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = LiveGuidanceRecorderController()

    var body: some View {
        ZStack {
            CameraPreview(session: recorder.session)
                .ignoresSafeArea()

            guideFrameOverlay

            VStack(spacing: 12) {
                topBar
                Spacer()
                guidancePanel
                controlsBar
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
        .background(Color.black)
        .onAppear {
            recorder.startSession(videoMode: videoMode)
        }
        .onDisappear {
            recorder.stopSession()
        }
        .onChange(of: recorder.recordedURL) { url in
            guard let url else { return }
            onRecorded(url)
            dismiss()
        }
        .alert("Camera Access Needed", isPresented: $recorder.showPermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Allow camera access in iOS Settings to record a running clip with live guidance.")
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Label("Close", systemImage: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.45))
                    .clipShape(Capsule())
            }

            Spacer()

            StatusBadge(
                text: "Quality \(Int(recorder.liveQualityScore * 100))%",
                color: recorder.liveQualityScore >= 0.65 ? AppTheme.mint : AppTheme.orange
            )
        }
    }

    private var guideFrameOverlay: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(.white.opacity(0.40), style: StrokeStyle(lineWidth: 2, dash: [9, 7]))
            .padding(.horizontal, 26)
            .padding(.vertical, 118)
            .allowsHitTesting(false)
    }

    private var guidancePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(videoMode == .side ? "Side View Guidance" : "Rear View Guidance", systemImage: "viewfinder.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(recorder.isRecording ? "REC \(recorder.recordingSeconds)s" : "Ready")
                    .font(.caption.bold())
                    .foregroundStyle(recorder.isRecording ? .red : .white.opacity(0.72))
            }

            if recorder.warnings.isEmpty {
                Label("Great framing. Keep full body in the guide box.", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mint)
            } else {
                ForEach(recorder.warnings.prefix(3), id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
        }
        .padding(14)
        .background(.black.opacity(0.46))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var controlsBar: some View {
        HStack(spacing: 12) {
            Button {
                if recorder.isRecording {
                    recorder.stopRecording()
                } else {
                    recorder.startRecording()
                }
            } label: {
                Label(recorder.isRecording ? "Stop" : "Record", systemImage: recorder.isRecording ? "stop.fill" : "record.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GradientButtonStyle(disabled: !recorder.canRecord))
            .disabled(!recorder.canRecord)

            Button {
                dismiss()
            } label: {
                Label("Use Library", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}

private final class LiveGuidanceRecorderController: NSObject, ObservableObject {
    @Published var warnings: [String] = []
    @Published var liveQualityScore: Double = 0.0
    @Published var isRecording = false
    @Published var canRecord = false
    @Published var showPermissionAlert = false
    @Published var recordingSeconds = 0
    @Published var recordedURL: URL?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "runform.live.session")
    private let frameQueue = DispatchQueue(label: "runform.live.frames")
    private let movieOutput = AVCaptureMovieFileOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let request = VNDetectHumanBodyPoseRequest()

    private var configured = false
    private var expectedMode: VideoMode = .side
    private var frameCounter = 0
    private var recordTimer: Timer?
    private var tempFileURL: URL?

    func startSession(videoMode: VideoMode) {
        expectedMode = videoMode
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch currentStatus {
        case .authorized:
            configureAndRunIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if !granted {
                        self.showPermissionAlert = true
                        self.canRecord = false
                        return
                    }
                    self.configureAndRunIfNeeded()
                }
            }
        default:
            showPermissionAlert = true
            canRecord = false
        }
    }

    func stopSession() {
        stopRecording()
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func startRecording() {
        guard canRecord, !movieOutput.isRecording else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        tempFileURL = url
        recordingSeconds = 0
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
        startTimer()
    }

    func stopRecording() {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        }
        stopTimer()
        isRecording = false
    }

    private func configureAndRunIfNeeded() {
        sessionQueue.async {
            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high

                guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: camera),
                      self.session.canAddInput(input) else {
                    DispatchQueue.main.async { self.canRecord = false }
                    self.session.commitConfiguration()
                    return
                }
                self.session.addInput(input)

                if self.session.canAddOutput(self.movieOutput) {
                    self.session.addOutput(self.movieOutput)
                }

                self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.setSampleBufferDelegate(self, queue: self.frameQueue)
                if self.session.canAddOutput(self.videoOutput) {
                    self.session.addOutput(self.videoOutput)
                }

                self.movieOutput.connection(with: .video)?.videoOrientation = .portrait
                self.videoOutput.connection(with: .video)?.videoOrientation = .portrait

                self.session.commitConfiguration()
                self.configured = true
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.canRecord = self.configured
            }
        }
    }

    private func startTimer() {
        stopTimer()
        recordTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.recordingSeconds += 1
            if self.recordingSeconds >= 20 {
                self.stopRecording()
            }
        }
    }

    private func stopTimer() {
        recordTimer?.invalidate()
        recordTimer = nil
    }

    private func evaluate(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameCounter += 1
        if frameCounter % 6 != 0 { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let observation = request.results?.first else {
            publish(warnings: ["Runner not detected. Step into frame and keep full body visible."], score: 0.12)
            return
        }

        func point(_ joint: VNHumanBodyPoseObservation.JointName) -> VNRecognizedPoint? {
            guard let p = try? observation.recognizedPoint(joint), p.confidence > 0.25 else { return nil }
            return p
        }

        let nose = point(.nose)
        let leftAnkle = point(.leftAnkle)
        let rightAnkle = point(.rightAnkle)
        let leftHip = point(.leftHip)
        let rightHip = point(.rightHip)
        let leftShoulder = point(.leftShoulder)
        let rightShoulder = point(.rightShoulder)

        var warnings: [String] = []
        var score = 1.0

        if nose == nil || (leftAnkle == nil && rightAnkle == nil) {
            warnings.append("Full body not detected. Keep head and feet visible.")
            score -= 0.26
        }

        if leftAnkle == nil || rightAnkle == nil {
            warnings.append("Feet not fully visible. Keep both feet in frame.")
            score -= 0.18
        }

        if let lh = leftHip, let rh = rightHip {
            let midX = (lh.location.x + rh.location.x) / 2.0
            if midX < 0.35 || midX > 0.65 {
                warnings.append("Runner not centered. Move to middle of frame.")
                score -= 0.15
            }
        }

        let points = [nose, leftAnkle, rightAnkle, leftHip, rightHip, leftShoulder, rightShoulder].compactMap { $0 }
        if !points.isEmpty {
            let ys = points.map { $0.location.y }
            if let topY = ys.max(), let bottomY = ys.min() {
                let height = topY - bottomY
                if height > 0.82 {
                    warnings.append("Move back from camera.")
                    score -= 0.14
                } else if height < 0.42 {
                    warnings.append("Move a little closer so full body fills guide box.")
                    score -= 0.10
                }
            }
        }

        if let ls = leftShoulder, let rs = rightShoulder, let lh = leftHip, let rh = rightHip {
            let shoulderY = (ls.location.y + rs.location.y) / 2.0
            let hipY = (lh.location.y + rh.location.y) / 2.0
            if shoulderY > 0.86 || (shoulderY - hipY) < 0.10 {
                warnings.append("Camera too low. Raise to around hip height.")
                score -= 0.12
            }

            if expectedMode == .side {
                let shoulderSpread = abs(ls.location.x - rs.location.x)
                let hipSpread = abs(lh.location.x - rh.location.x)
                if shoulderSpread > 0.18 || hipSpread > 0.18 {
                    warnings.append("Side-view needed. Rotate to true side profile.")
                    score -= 0.16
                }
            }
        }

        let brightness = averageBrightness(pixelBuffer)
        if brightness < 0.22 {
            warnings.append("Low lighting. Move to brighter light.")
            score -= 0.16
        }

        publish(warnings: warnings, score: max(0.05, min(1.0, score)))
    }

    private func publish(warnings: [String], score: Double) {
        DispatchQueue.main.async {
            self.warnings = warnings
            self.liveQualityScore = score
        }
    }

    private func averageBrightness(_ pixelBuffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard CVPixelBufferGetPlaneCount(pixelBuffer) > 0,
              let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return 0.0 }

        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)

        let step = 8
        var total = 0.0
        var count = 0.0
        for y in stride(from: 0, to: height, by: step) {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in stride(from: 0, to: width, by: step) {
                total += Double(row[x])
                count += 1
            }
        }
        guard count > 0 else { return 0.0 }
        return (total / count) / 255.0
    }
}

extension LiveGuidanceRecorderController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        evaluate(sampleBuffer: sampleBuffer)
    }
}

extension LiveGuidanceRecorderController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {}

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.stopTimer()
            if error == nil {
                self.recordedURL = outputFileURL
            }
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}