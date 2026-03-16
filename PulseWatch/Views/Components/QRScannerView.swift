import SwiftUI
import AVFoundation

/// QR Code 扫码配对视图
struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onScanned: (String, String, String) -> Void  // (url, token, agent)

    @State private var error: String?
    @State private var scanned = false
    @State private var cameraAuthorized = false
    @State private var permissionDenied = false

    var body: some View {
        ZStack {
            if cameraAuthorized {
                // 相机预览
                QRCameraPreview(onCodeFound: handleCode)
                    .ignoresSafeArea()
            } else if permissionDenied {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.gray)
                    Text("Camera access needed to scan QR code")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
            } else {
                Color.black.ignoresSafeArea()
            }

            // 覆盖层
            VStack {
                // 顶部栏
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding()
                }

                Spacer()

                // 扫描框
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                    .frame(width: 250, height: 250)
                    .overlay {
                        if scanned {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.green)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                Spacer()

                // 说明文字
                VStack(spacing: 8) {
                    if let error {
                        Text(error)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Scan OpenClaw pairing QR code")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Run openclaw pair --qr in terminal")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .animation(.spring(response: 0.3), value: scanned)
        .animation(.spring(response: 0.3), value: error)
        .task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                cameraAuthorized = true
            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                cameraAuthorized = granted
                permissionDenied = !granted
            default:
                permissionDenied = true
            }
        }
    }

    private func handleCode(_ code: String) {
        guard !scanned else { return }

        // 解析 JSON: {"url":"...","token":"...","agent":"..."}
        guard let data = code.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let url = json["url"], !url.isEmpty,
              let token = json["token"], !token.isEmpty else {
            error = String(localized: "Invalid pairing QR code")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { error = nil }
            return
        }

        let agent = json["agent"] ?? PulseOpenClawConfig.defaultAgentID

        scanned = true
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onScanned(url, token, agent)
            dismiss()
        }
    }
}

// MARK: - AVFoundation Camera Preview

struct QRCameraPreview: UIViewRepresentable {
    let onCodeFound: (String) -> Void

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black

        let session = AVCaptureSession()
        context.coordinator.session = session

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return view }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    /// UIView 子类，自动在 layoutSubviews 时更新 previewLayer frame
    class PreviewUIView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeFound: onCodeFound)
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onCodeFound: (String) -> Void
        var session: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        private var found = false

        init(onCodeFound: @escaping (String) -> Void) {
            self.onCodeFound = onCodeFound
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !found,
                  let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  obj.type == .qr,
                  let value = obj.stringValue else { return }
            found = true
            onCodeFound(value)
        }
    }
}
