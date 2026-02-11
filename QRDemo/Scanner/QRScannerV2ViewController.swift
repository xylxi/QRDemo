//
//  QRScannerV2ViewController.swift
//  QRDemo
//
//  Created by Codex on 2026/2/11.
//

import UIKit
import AVFoundation

protocol QRScannerV2ViewControllerDelegate: AnyObject {
    func qrScannerV2(_ controller: QRScannerV2ViewController, didScan code: String)
    func qrScannerV2DidCancel(_ controller: QRScannerV2ViewController)
}

final class QRScannerV2ViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    weak var delegate: QRScannerV2ViewControllerDelegate?
    private let logTag = "QRScannerV2"

    private let captureSession = AVCaptureSession()
    private let queueSpecificKey = DispatchSpecificKey<Void>()
    private lazy var sessionQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "com.ruir.qrdemo.capture.session.v2")
        queue.setSpecific(key: queueSpecificKey, value: ())
        return queue
    }()
    private let metadataOutput = AVCaptureMetadataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isSessionConfigured = false
    private var wantsSessionRunning = false
    private var hasHandledCode = false
    private var didStartLineAnimation = false

    private let overlayLayer = CAShapeLayer()
    private let scanFrameView = UIView()
    private let scanLine = UIView()
    private let tipLabel: UILabel = {
        let label = UILabel()
        label.text = "V2：将二维码放入框内即可自动扫描"
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        setupCaptureSession()
        logInfo(logTag, items: "扫码页 V2 加载完成")
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
        logInfo(logTag, items: "扫码页 V2 即将显示")

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsSessionRunning = true
            guard self.isSessionConfigured else { return }

            self.captureSession.beginConfiguration()
            self.metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            self.metadataOutput.metadataObjectTypes = [.qr]
            self.captureSession.commitConfiguration()

            if !self.captureSession.isRunning {
                logInfo(self.logTag, items: "V2 启动 AVCaptureSession")
                self.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        logInfo(logTag, items: "扫码页即将消失")

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsSessionRunning = false

            if self.captureSession.isRunning {
                logInfo(self.logTag, items: "停止 AVCaptureSession")
                self.captureSession.stopRunning()
            }

            self.captureSession.beginConfiguration()
            self.metadataOutput.setMetadataObjectsDelegate(nil, queue: nil)
            self.metadataOutput.metadataObjectTypes = []
            self.captureSession.commitConfiguration()

            logInfo(self.logTag, items: "已重置元数据监听")
        }
    }

    deinit {
        logInfo(logTag, items: "QRScannerViewController V2 销毁")

        let cleanupSession = { [self] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }

            captureSession.beginConfiguration()
            captureSession.inputs.forEach { input in
                captureSession.removeInput(input)
            }
            captureSession.outputs.forEach { output in
                captureSession.removeOutput(output)
            }
            captureSession.commitConfiguration()
        }

        if DispatchQueue.getSpecific(key: queueSpecificKey) != nil {
            cleanupSession()
        } else {
            sessionQueue.sync(execute: cleanupSession)
        }

        let cleanupPreview = { [self] in
            previewLayer?.removeFromSuperlayer()
            previewLayer = nil
        }
        if Thread.isMainThread {
            cleanupPreview()
        } else {
            DispatchQueue.main.sync(execute: cleanupPreview)
        }

        logInfo(logTag, items: "资源清理完成")
    }

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
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10)
        ])
    }

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

    private func setupCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.isSessionConfigured else { return }
            logInfo(self.logTag, items: "V2 开始配置 AVCaptureSession")

            guard let camera = AVCaptureDevice.default(for: .video) else {
                DispatchQueue.main.async {
                    logError(self.logTag, items: "V2 无法获取相机设备")
                    self.delegate?.qrScannerV2DidCancel(self)
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
                    self.metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
                    self.metadataOutput.metadataObjectTypes = [.qr]
                    self.metadataOutput.rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
                }

                self.captureSession.commitConfiguration()
                self.isSessionConfigured = true
                logInfo(self.logTag, items: "V2 AVCaptureSession 配置完成")

                if self.wantsSessionRunning && !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                }

                let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
                preview.videoGravity = .resizeAspectFill

                DispatchQueue.main.async {
                    self.view.layer.insertSublayer(preview, at: 0)
                    self.previewLayer = preview
                    self.previewLayer?.frame = self.view.bounds
                    self.updateScanOverlay()
                    logInfo(self.logTag, items: "V2 相机预览层已添加")
                }
            } catch {
                DispatchQueue.main.async {
                    logError(self.logTag, items: "V2 配置 AVCaptureSession 失败:", error.localizedDescription)
                    self.delegate?.qrScannerV2DidCancel(self)
                }
            }
        }
    }

    private func updateScanOverlay() {
        let fullPath = UIBezierPath(rect: view.bounds)
        let holeRect = scanFrameView.frame.insetBy(dx: -2, dy: -2)
        let holePath = UIBezierPath(roundedRect: holeRect, cornerRadius: 14)
        fullPath.append(holePath)
        overlayLayer.path = fullPath.cgPath
    }

    @objc private func didTapClose() {
        logInfo(logTag, items: "V2 点击关闭扫码页")
        delegate?.qrScannerV2DidCancel(self)
    }

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

        hasHandledCode = true
        logInfo(logTag, items: "V2 识别到二维码:", code)
        delegate?.qrScannerV2(self, didScan: code)
    }
}
