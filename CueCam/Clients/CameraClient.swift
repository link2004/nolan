import AVFoundation
import ComposableArchitecture
import UIKit

/// AVCaptureSession 自体は Sendable ではないが、構成変更は CameraManager が
/// 専用シリアルキュー上でのみ行い、View 側はプレビュー表示への接続にしか使わないため共有できる
struct CameraSession: @unchecked Sendable, Equatable {
    let raw: AVCaptureSession

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.raw === rhs.raw }
}

enum CameraClientError: Error {
    case notRecording
}

@DependencyClient
struct CameraClient {
    /// カメラ+マイクの利用許可をまとめて要求する
    var requestAuthorization: @Sendable () async -> Bool = { false }
    /// セッションを構成・開始してプレビュー用に返す。カメラ非搭載環境(シミュレータ)では nil
    var startSession: @Sendable () async -> CameraSession? = { nil }
    var stopSession: @Sendable () async -> Void
    /// 一時ディレクトリの .mov へ録画を開始する
    var startRecording: @Sendable () async -> Void
    /// 録画を停止し、完成した動画ファイルの URL を返す
    var stopRecording: @Sendable () async throws -> URL
}

extension CameraClient: DependencyKey {
    static let liveValue: CameraClient = {
        let manager = CameraManager()
        return CameraClient(
            requestAuthorization: {
                let video = await AVCaptureDevice.requestAccess(for: .video)
                let audio = await AVCaptureDevice.requestAccess(for: .audio)
                return video && audio
            },
            startSession: { await manager.startSession() },
            stopSession: { await manager.stopSession() },
            startRecording: {
                let angle = await MainActor.run {
                    UIApplication.shared.interfaceOrientation?.videoRotationAngle ?? 0
                }
                manager.startRecording(angle: angle)
            },
            stopRecording: { try await manager.stopRecording() }
        )
    }()

    static let testValue = CameraClient()

    static let previewValue = CameraClient(
        requestAuthorization: { true },
        startSession: { nil },
        stopSession: {},
        startRecording: {},
        stopRecording: { throw CameraClientError.notRecording }
    )
}

extension DependencyValues {
    var cameraClient: CameraClient {
        get { self[CameraClient.self] }
        set { self[CameraClient.self] = newValue }
    }
}

extension UIInterfaceOrientation {
    /// AVCaptureConnection.videoRotationAngle への変換
    /// (旧APIの videoOrientation との対応: landscapeRight=0° / portrait=90° / landscapeLeft=180° / upsideDown=270°)
    var videoRotationAngle: CGFloat {
        switch self {
        case .landscapeRight: 0
        case .landscapeLeft: 180
        case .portraitUpsideDown: 270
        default: 90
        }
    }
}

extension UIApplication {
    var interfaceOrientation: UIInterfaceOrientation? {
        (connectedScenes.first as? UIWindowScene)?.interfaceOrientation
    }
}

/// AVCaptureSession の構成・録画を専用シリアルキュー上で行う(Apple推奨パターン)。
/// 可変状態には sessionQueue 上でのみ触れるため @unchecked Sendable
private final class CameraManager: NSObject, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "com.cuecam.camera-session")

    private var isConfigured = false
    private var isRecordingRequested = false
    /// 録画開始コールバック前に停止要求が来た場合のフラグ(超高速タップ対策)
    private var pendingStop = false
    private var recordingContinuation: CheckedContinuation<URL, any Error>?

    func startSession() async -> CameraSession? {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard self.configureIfNeeded() else {
                    continuation.resume(returning: nil)
                    return
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                continuation.resume(returning: CameraSession(raw: self.session))
            }
        }
    }

    func stopSession() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                if self.session.isRunning {
                    self.session.stopRunning()
                }
                continuation.resume()
            }
        }
    }

    func startRecording(angle: CGFloat) {
        sessionQueue.async {
            guard self.isConfigured, !self.isRecordingRequested else { return }
            self.isRecordingRequested = true
            if let connection = self.movieOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopRecording() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                guard self.isRecordingRequested else {
                    continuation.resume(throwing: CameraClientError.notRecording)
                    return
                }
                self.recordingContinuation = continuation
                if self.movieOutput.isRecording {
                    self.movieOutput.stopRecording()
                } else {
                    self.pendingStop = true
                }
            }
        }
    }

    private func configureIfNeeded() -> Bool {
        if isConfigured { return true }
        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let videoInput = try? AVCaptureDeviceInput(device: camera)
        else { return false }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high
        guard session.canAddInput(videoInput) else { return false }
        session.addInput(videoInput)

        if let mic = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        guard session.canAddOutput(movieOutput) else { return false }
        session.addOutput(movieOutput)

        isConfigured = true
        return true
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        sessionQueue.async {
            if self.pendingStop {
                self.pendingStop = false
                self.movieOutput.stopRecording()
            }
        }
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: (any Error)?
    ) {
        sessionQueue.async {
            self.isRecordingRequested = false
            self.pendingStop = false
            guard let continuation = self.recordingContinuation else { return }
            self.recordingContinuation = nil
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: outputFileURL)
            }
        }
    }
}
