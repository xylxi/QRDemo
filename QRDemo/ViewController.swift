//
//  ViewController.swift
//  QRDemo
//
//  Created by ruirui on 2026/2/11.
//

import UIKit
import AVFoundation

final class ViewController: UIViewController {

    private let logTag = "ViewController"
    private let personalPageURL = "https://example.com/user/ruir"
    private let personalNickname = "ruir"
    private let qrGenerateQueue = DispatchQueue(label: "com.ruir.qrdemo.personal.qr.generate", qos: .userInitiated)
    private var isGeneratingPersonalQRCode = false

    private let scanButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("扫一扫", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 20)
        button.backgroundColor = .systemBlue
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
        let stack = UIStackView(arrangedSubviews: [scanButton, generateButton, infoLabel])
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
        generateButton.addTarget(self, action: #selector(didTapGenerateQRCode), for: .touchUpInside)
    }

    @objc private func didTapScan() {
        logInfo(logTag, items: "点击扫一扫")
        requestCameraAndScan()
    }

    private func requestCameraAndScan() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        logInfo(logTag, items: "当前相机权限:", status.rawValue)
        switch status {
        case .authorized:
            presentScanner()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        logInfo(self?.logTag ?? "ViewController", items: "用户授权相机，准备打开扫码页")
                        self?.presentScanner()
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

    private func presentScanner() {
        logInfo(logTag, items: "present 扫码页面")
        let scanner = QRScannerViewController()
        scanner.delegate = self
        scanner.modalPresentationStyle = .fullScreen
        present(scanner, animated: true)
    }

    @objc private func didTapGenerateQRCode() {
        guard !isGeneratingPersonalQRCode else { return }
        logInfo(logTag, items: "点击生成二维码，内容:", personalPageURL)
        isGeneratingPersonalQRCode = true
        setGenerateButtonLoading(true)

        let content = personalPageURL
        let nickname = personalNickname
        qrGenerateQueue.async { [weak self] in
            let avatar = AvatarFactory.makeAvatarImage()
            let qrImage = QRCodeBuilder.generate(content: content, avatar: avatar, size: 800)

            DispatchQueue.main.async {
                guard let self else { return }
                self.isGeneratingPersonalQRCode = false
                self.setGenerateButtonLoading(false)

                guard let qrImage else {
                    logError(self.logTag, items: "二维码生成失败")
                    self.showAlert(title: "生成失败", message: "二维码生成失败，请稍后重试")
                    return
                }

                logInfo(self.logTag, items: "二维码生成成功，准备打开个人二维码页面")
                let page = PersonalQRCodeViewController(
                    qrImage: qrImage,
                    nickname: nickname,
                    subtitle: "扫码二维码，关注我的个人账号"
                )
                if let navigationController = self.navigationController {
                    navigationController.pushViewController(page, animated: true)
                } else {
                    let nav = UINavigationController(rootViewController: page)
                    nav.modalPresentationStyle = .fullScreen
                    self.present(nav, animated: true)
                }
            }
        }
    }

    private func setGenerateButtonLoading(_ loading: Bool) {
        generateButton.isEnabled = !loading
        generateButton.alpha = loading ? 0.7 : 1.0
        let title = loading ? "生成中..." : "生成个人页面二维码"
        generateButton.setTitle(title, for: .normal)
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
            logInfo(self?.logTag ?? "ViewController", items: "扫码结果:", code)
            self?.infoLabel.text = "扫码结果：\(code)"
        }
    }

    func qrScannerDidCancel(_ controller: QRScannerViewController) {
        logInfo(logTag, items: "用户关闭扫码页面")
        controller.dismiss(animated: true)
    }
}
