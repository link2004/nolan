import AVFoundation
import SwiftUI
import UIKit

/// AVCaptureVideoPreviewLayer をホストするプレビュー
struct CameraPreviewView: UIViewRepresentable {
    let session: CameraSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session.raw
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if uiView.previewLayer.session !== session.raw {
            uiView.previewLayer.session = session.raw
        }
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        // 回転はレイアウト変化と同時にしか起きないので layoutSubviews で追従する
        override func layoutSubviews() {
            super.layoutSubviews()
            guard
                let connection = previewLayer.connection,
                let orientation = window?.windowScene?.interfaceOrientation
            else { return }
            let angle = orientation.videoRotationAngle
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
    }
}
