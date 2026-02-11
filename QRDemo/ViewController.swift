//
//  ViewController.swift
//  QRDemo
//
//  Created by ruirui on 2026/2/11.
//

import UIKit
import AVFoundation
import Photos

final class ViewController: UIViewController {

    private let logTag = "ViewController"
    private let personalPageURL = "https://example.com/user/ruir"

    private let scanButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("扫一扫（V1）", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 20)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 14
        button.heightAnchor.constraint(equalToConstant: 56).isActive = true
        return button
    }()

    private let scanV2Button: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("扫一扫（V2）", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 20)
        button.backgroundColor = .systemIndigo
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 14
        button.heightAnchor.constraint(equalToConstant: 56).isActive = true
        return button
    }()

    private let generateButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("生成个人页面二维码", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 20)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 14
        button.heightAnchor.constraint(equalToConstant: 56).isActive = true
        return button
    }()

    private let qrImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor.secondarySystemBackground
        imageView.layer.cornerRadius = 16
        imageView.clipsToBounds = true
        imageView.heightAnchor.constraint(equalToConstant: 280).isActive = true
        return imageView
    }()

    private let infoLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.text = "扫描结果将显示在这里"
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "二维码功能"
        view.backgroundColor = .systemBackground
        setupLayout()
        bindActions()
        logInfo(logTag, items: "首页加载完成")
    }

    private func setupLayout() {
        let stack = UIStackView(arrangedSubviews: [scanButton, scanV2Button, generateButton, qrImageView, infoLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 24)
        ])
    }

    private func bindActions() {
        scanButton.addTarget(self, action: #selector(didTapScan), for: .touchUpInside)
        scanV2Button.addTarget(self, action: #selector(didTapScanV2), for: .touchUpInside)
        generateButton.addTarget(self, action: #selector(didTapGenerateQRCode), for: .touchUpInside)
    }

    @objc private func didTapScan() {
        logInfo(logTag, items: "点击扫一扫 V1")
        requestCameraAndScan(version: .v1)
    }

    @objc private func didTapScanV2() {
        logInfo(logTag, items: "点击扫一扫 V2")
        requestCameraAndScan(version: .v2)
    }

    private func requestCameraAndScan(version: ScanVersion) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        logInfo(logTag, items: "当前相机权限:", status.rawValue)
        switch status {
        case .authorized:
            presentScanner(version: version)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        logInfo(self?.logTag ?? "ViewController", items: "用户授权相机，准备打开扫码页", version == .v1 ? "V1" : "V2")
                        self?.presentScanner(version: version)
                    } else {
                        logError(self?.logTag ?? "ViewController", items: "用户拒绝相机权限")
                        self?.showCameraDeniedAlert()
                    }
                }
            }
        case .denied, .restricted:
            logError(logTag, items: "相机权限不可用:", status.rawValue)
            showCameraDeniedAlert()
        @unknown default:
            logError(logTag, items: "未知相机权限状态")
            showCameraDeniedAlert()
        }
    }

    private func presentScanner(version: ScanVersion) {
        switch version {
        case .v1:
            logInfo(logTag, items: "present 扫码页面 V1")
            let scanner = QRScannerViewController()
            scanner.delegate = self
            scanner.modalPresentationStyle = .fullScreen
            present(scanner, animated: true)
        case .v2:
            logInfo(logTag, items: "present 扫码页面 V2")
            let scanner = QRScannerV2ViewController()
            scanner.delegate = self
            scanner.modalPresentationStyle = .fullScreen
            present(scanner, animated: true)
        }
    }

    @objc private func didTapGenerateQRCode() {
        logInfo(logTag, items: "点击生成二维码，内容:", personalPageURL)
        let avatar = AvatarFactory.makeAvatarImage()
        guard let qrImage = QRCodeBuilder.generate(content: personalPageURL, avatar: avatar, size: 800) else {
            logError(logTag, items: "二维码生成失败")
            showAlert(title: "生成失败", message: "二维码生成失败，请稍后重试")
            return
        }
        logInfo(logTag, items: "二维码生成成功，尺寸:", Int(qrImage.size.width), "x", Int(qrImage.size.height))
        qrImageView.image = qrImage
        infoLabel.text = "个人页面二维码已生成：\(personalPageURL)"
        saveQRCodeToPhotoLibrary(qrImage)
    }

    private func saveQRCodeToPhotoLibrary(_ image: UIImage) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        logInfo(logTag, items: "相册写入权限状态:", status.rawValue)
        switch status {
        case .authorized, .limited:
            writeImageToPhotoLibrary(image)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] newStatus in
                DispatchQueue.main.async {
                    switch newStatus {
                    case .authorized, .limited:
                        logInfo(self?.logTag ?? "ViewController", items: "用户授权相册写入，开始保存二维码")
                        self?.writeImageToPhotoLibrary(image)
                    case .denied, .restricted:
                        logError(self?.logTag ?? "ViewController", items: "用户拒绝相册权限:", newStatus.rawValue)
                        self?.showAlert(title: "保存失败", message: "请在系统设置中允许访问相册后重试。")
                    case .notDetermined:
                        logError(self?.logTag ?? "ViewController", items: "相册权限状态仍未决定")
                        self?.showAlert(title: "保存失败", message: "未获取到相册权限，请重试。")
                    @unknown default:
                        logError(self?.logTag ?? "ViewController", items: "未知相册权限状态")
                        self?.showAlert(title: "保存失败", message: "相册权限状态异常。")
                    }
                }
            }
        case .denied, .restricted:
            logError(logTag, items: "相册权限不可用:", status.rawValue)
            showAlert(title: "保存失败", message: "请在系统设置中允许访问相册后重试。")
        @unknown default:
            logError(logTag, items: "未知相册权限状态")
            showAlert(title: "保存失败", message: "相册权限状态异常。")
        }
    }

    private func writeImageToPhotoLibrary(_ image: UIImage) {
        logInfo(logTag, items: "开始写入二维码到相册")
        UIImageWriteToSavedPhotosAlbum(
            image,
            self,
            #selector(image(_:didFinishSavingWithError:contextInfo:)),
            nil
        )
    }

    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeMutableRawPointer?) {
        if let error {
            logError(logTag, items: "二维码保存到相册失败:", error.localizedDescription)
            showAlert(title: "保存失败", message: error.localizedDescription)
            return
        }
        logInfo(logTag, items: "二维码已保存到相册")
        showAlert(title: "保存成功", message: "二维码已保存到系统相册。")
    }

    private func showCameraDeniedAlert() {
        logError(logTag, items: "显示相机权限提示弹窗")
        let message = "请在系统设置中打开相机权限后再使用扫一扫。"
        showAlert(title: "无法使用相机", message: message)
    }

    private func showAlert(title: String, message: String) {
        logInfo(logTag, items: "弹窗:", title, message)
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

extension ViewController: QRScannerViewControllerDelegate {
    func qrScanner(_ controller: QRScannerViewController, didScan code: String) {
        controller.dismiss(animated: true) { [weak self] in
            logInfo(self?.logTag ?? "ViewController", items: "V1 扫码结果:", code)
            self?.infoLabel.text = "V1 扫码结果：\(code)"
        }
    }

    func qrScannerDidCancel(_ controller: QRScannerViewController) {
        logInfo(logTag, items: "用户关闭扫码页面 V1")
        controller.dismiss(animated: true)
    }
}

extension ViewController: QRScannerV2ViewControllerDelegate {
    func qrScannerV2(_ controller: QRScannerV2ViewController, didScan code: String) {
        controller.dismiss(animated: true) { [weak self] in
            logInfo(self?.logTag ?? "ViewController", items: "V2 扫码结果:", code)
            self?.infoLabel.text = "V2 扫码结果：\(code)"
        }
    }

    func qrScannerV2DidCancel(_ controller: QRScannerV2ViewController) {
        logInfo(logTag, items: "用户关闭扫码页面 V2")
        controller.dismiss(animated: true)
    }
}

private enum ScanVersion {
    case v1
    case v2
}
