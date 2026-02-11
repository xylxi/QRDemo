//
//  QRScannerViewController.swift
//  QRDemo
//
//  Created by Codex on 2026/2/11.
//

import UIKit
import AVFoundation
import PhotosUI
import CoreImage
import Vision
import ImageIO

/// 扫码结果回调协议。
protocol QRScannerViewControllerDelegate: AnyObject {
    /// 成功识别到二维码内容后回调。
    func qrScanner(_ controller: QRScannerViewController, didScan code: String)
    /// 用户主动取消或扫码不可用时回调。
    func qrScannerDidCancel(_ controller: QRScannerViewController)
}

/// 基于 AVCaptureSession 的二维码扫描页面。
final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    weak var delegate: QRScannerViewControllerDelegate?
    private let logTag = "QRScanner"

    // 会话相关状态都在 sessionQueue 上操作，避免线程竞态。
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.ruir.qrdemo.capture.session")
    private let metadataOutput = AVCaptureMetadataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isSessionConfigured = false
    private var wantsSessionRunning = false

    private let overlayLayer = CAShapeLayer()
    private let scanFrameView = UIView()
    private let scanLine = UIView()
    private let tipLabel: UILabel = {
        let label = UILabel()
        label.text = "将二维码放入框内即可自动扫描"
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        return label
    }()

    // 首次识别成功后置为 true，避免重复回调业务层。
    private var hasHandledCode = false
    // 扫描线动画仅在布局稳定后启动一次。
    private var didStartLineAnimation = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        setupCaptureSession()
        logInfo(logTag, items: "扫码页加载完成")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updateScanOverlay()
        if !didStartLineAnimation, scanFrameView.bounds.height > 0 {
            startScanLineAnimation()
            didStartLineAnimation = true
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasHandledCode = false
        logInfo(logTag, items: "扫码页即将显示")
        // 页面显示后请求启动会话；若尚未配置完成，会在配置完成后启动。
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsSessionRunning = true
            if self.isSessionConfigured {
                if !self.captureSession.isRunning {
                    logInfo(self.logTag, items: "开始运行 AVCaptureSession")
                    self.captureSession.startRunning()
                }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        logInfo(logTag, items: "扫码页即将消失")
        // 页面离开时停止会话，避免后台继续占用相机资源。
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsSessionRunning = false
            if self.captureSession.isRunning {
                logInfo(self.logTag, items: "停止 AVCaptureSession")
                self.captureSession.stopRunning()
            }
        }
    }
    
    deinit {
        logInfo(logTag, items: "deinit")
    }

    /// 搭建扫码页 UI：遮罩、扫描框、扫描线、提示文案和关闭按钮。
    private func setupUI() {
        overlayLayer.fillColor = UIColor.black.withAlphaComponent(0.55).cgColor
        overlayLayer.fillRule = .evenOdd
        view.layer.addSublayer(overlayLayer)

        scanFrameView.layer.borderColor = UIColor.white.cgColor
        scanFrameView.layer.borderWidth = 2
        scanFrameView.layer.cornerRadius = 14
        scanFrameView.backgroundColor = .clear
        scanFrameView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanFrameView)

        scanLine.backgroundColor = .systemGreen
        scanLine.layer.cornerRadius = 1.5
        scanLine.translatesAutoresizingMaskIntoConstraints = false
        scanFrameView.addSubview(scanLine)

        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tipLabel)

        let closeButton = UIButton(type: .system)
        closeButton.setTitle("关闭", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        view.addSubview(closeButton)

        let albumButton = UIButton(type: .system)
        albumButton.setTitle("相册", for: .normal)
        albumButton.setTitleColor(.white, for: .normal)
        albumButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        albumButton.translatesAutoresizingMaskIntoConstraints = false
        albumButton.addTarget(self, action: #selector(didTapAlbum), for: .touchUpInside)
        view.addSubview(albumButton)

        let side = min(view.bounds.width * 0.7, 280)
        NSLayoutConstraint.activate([
            scanFrameView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanFrameView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            scanFrameView.widthAnchor.constraint(equalToConstant: side),
            scanFrameView.heightAnchor.constraint(equalToConstant: side),

            scanLine.leadingAnchor.constraint(equalTo: scanFrameView.leadingAnchor, constant: 12),
            scanLine.trailingAnchor.constraint(equalTo: scanFrameView.trailingAnchor, constant: -12),
            scanLine.topAnchor.constraint(equalTo: scanFrameView.topAnchor, constant: 12),
            scanLine.heightAnchor.constraint(equalToConstant: 3),

            tipLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tipLabel.topAnchor.constraint(equalTo: scanFrameView.bottomAnchor, constant: 18),

            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),

            albumButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            albumButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10)
        ])
    }

    /// 启动扫描线在扫描框内的往返动画。
    private func startScanLineAnimation() {
        scanLine.layer.removeAnimation(forKey: "scan")
        view.layoutIfNeeded()
        let animation = CABasicAnimation(keyPath: "position.y")
        animation.fromValue = scanLine.layer.position.y
        animation.toValue = scanFrameView.bounds.height - 12
        animation.duration = 2.0
        animation.repeatCount = .infinity
        animation.autoreverses = true
        scanLine.layer.add(animation, forKey: "scan")
    }

    /// 配置相机会话输入输出；该流程只会执行一次。
    private func setupCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.isSessionConfigured else { return }
            logInfo(self.logTag, items: "开始配置 AVCaptureSession")

            guard let camera = AVCaptureDevice.default(for: .video) else {
                DispatchQueue.main.async {
                    logError(self.logTag, items: "无法获取相机设备")
                    self.delegate?.qrScannerDidCancel(self)
                }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                self.captureSession.beginConfiguration()

                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                }

                if self.captureSession.canAddOutput(self.metadataOutput) {
                    self.captureSession.addOutput(self.metadataOutput)
                    self.metadataOutput.metadataObjectTypes = [.qr]
                    self.metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
                    // 先使用全屏识别区域，后续如需优化可按扫描框映射缩小区域。
                    self.metadataOutput.rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
                }

                self.captureSession.commitConfiguration()
                self.isSessionConfigured = true
                logInfo(self.logTag, items: "AVCaptureSession 配置完成")
                if self.wantsSessionRunning && !self.captureSession.isRunning {
                    logInfo(self.logTag, items: "配置完成后启动 AVCaptureSession")
                    self.captureSession.startRunning()
                }

                let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
                preview.videoGravity = .resizeAspectFill

                DispatchQueue.main.async {
                    self.view.layer.insertSublayer(preview, at: 0)
                    self.previewLayer = preview
                    self.previewLayer?.frame = self.view.bounds
                    self.updateScanOverlay()
                    logInfo(self.logTag, items: "相机预览层已添加")
                }
            } catch {
                DispatchQueue.main.async {
                    logError(self.logTag, items: "配置 AVCaptureSession 失败:", error.localizedDescription)
                    self.delegate?.qrScannerDidCancel(self)
                }
            }
        }
    }

    /// 更新遮罩路径：整屏半透明 + 扫描框区域挖空。
    private func updateScanOverlay() {
        let fullPath = UIBezierPath(rect: view.bounds)
        let holeRect = scanFrameView.frame.insetBy(dx: -2, dy: -2)
        let holePath = UIBezierPath(roundedRect: holeRect, cornerRadius: 14)
        fullPath.append(holePath)
        overlayLayer.path = fullPath.cgPath
    }

    @objc private func didTapClose() {
        logInfo(logTag, items: "点击关闭扫码页")
        delegate?.qrScannerDidCancel(self)
    }

    private func handleDetectedCode(_ code: String, source: String) {
        guard !hasHandledCode else { return }

        hasHandledCode = true
        logInfo(logTag, items: "\(source)识别到二维码:", code)
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsSessionRunning = false
            // 移除可识别类型即可停止回调，防止重复触发。
            self.metadataOutput.metadataObjectTypes = []
            logInfo(self.logTag, items: "已停止后续识别回调")
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.qrScanner(self, didScan: code)
        }
    }

    /// 识别到二维码后上报结果，并立即关闭后续识别回调。
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasHandledCode else { return }
        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            object.type == .qr,
            let code = object.stringValue,
            !code.isEmpty
        else {
            return
        }

        handleDetectedCode(code, source: "相机")
    }
}

// MARK: - 相册选图
extension QRScannerViewController {
    @objc private func didTapAlbum() {
        guard !hasHandledCode else { return }
        logInfo(logTag, items: "点击相册入口")
        presentPhotoPicker()
    }

    private func presentPhotoPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = .images
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    /// iOS 15+：使用 Vision 识别二维码（支持多方向、更稳）
    /// - Note: 这是同步实现；如果你用于相机实时流，建议放到后台队列或改成 async。
    private func detectQRCodeV2(in image: UIImage) -> String? {
        // 1) 优先使用 CGImage（Vision 对 CGImage 最直接）
        guard let cgImage = image.cgImage else { return nil }

        // 2) 处理图片方向（非常重要：相册/拍照图片常有 orientation）
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        // 3) 只识别 QR（更快、更准）；如需条形码可扩展 symbologies
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]

        // 4) 执行识别
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        // 5) 取第一个有效 payload（如需多码可改成返回数组）
        let results = request.results ?? []
        return results
            .compactMap { $0.payloadStringValue }
            .first { !$0.isEmpty }
    }

    private func detectQRCodeV1(in image: UIImage) -> String? {
        guard let ciImage = CIImage(image: image) else {
            return nil
        }
        let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        guard let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: options) else {
            return nil
        }
        let features = detector.features(in: ciImage)
        return features .compactMap { ($0 as? CIQRCodeFeature)?.messageString } .first { !$0.isEmpty } }
    
    private func showAlbumRecognizeFailedAlert() {
        let alert = UIAlertController(title: "未识别到二维码", message: "请重新选择一张包含清晰二维码的图片。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIImageOrientation -> CGImagePropertyOrientation
private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

extension QRScannerViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self else { return }

            guard let result = results.first else {
                logInfo(self.logTag, items: "用户取消相册选择")
                return
            }

            let provider = result.itemProvider
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                logError(self.logTag, items: "所选资源无法读取为图片")
                self.showAlbumRecognizeFailedAlert()
                return
            }

            logInfo(self.logTag, items: "开始识别相册图片二维码")
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                guard let self else { return }

                if let error {
                    DispatchQueue.main.async {
                        logError(self.logTag, items: "读取相册图片失败:", error.localizedDescription)
                        self.showAlbumRecognizeFailedAlert()
                    }
                    return
                }

                guard let image = object as? UIImage else {
                    DispatchQueue.main.async {
                        logError(self.logTag, items: "读取相册图片失败: 类型转换失败")
                        self.showAlbumRecognizeFailedAlert()
                    }
                    return
                }

                guard let code = self.detectQRCodeV2(in: image) else {
                    DispatchQueue.main.async {
                        logInfo(self.logTag, items: "相册图片中未识别到二维码")
                        self.showAlbumRecognizeFailedAlert()
                    }
                    return
                }

                DispatchQueue.main.async { [weak self] in
                    self?.handleDetectedCode(code, source: "相册")
                }
            }
        }
    }
}
