//
//  PersonalQRCodeViewController.swift
//  QRDemo
//
//  Created by Codex on 2026/2/12.
//

import UIKit
import Photos

final class PersonalQRCodeViewController: UIViewController {
    private let logTag = "PersonalQRCodePage"
    private let qrImage: UIImage
    private let nickname: String
    private let subtitle: String

    private let topContainer = UIView()
    private let bottomContainer = UIView()

    private let qrImageView = UIImageView()
    private let nicknameLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let saveButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)

    init(qrImage: UIImage, nickname: String, subtitle: String) {
        self.qrImage = qrImage
        self.nickname = nickname
        self.subtitle = subtitle
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "个人页面二维码"
        view.backgroundColor = .systemBackground
        setupLayout()
        setupContent()
        setupActions()
        setupCloseButtonIfNeeded()
    }

    private func setupLayout() {
        topContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topContainer)
        view.addSubview(bottomContainer)

        NSLayoutConstraint.activate([
            topContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            topContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            bottomContainer.topAnchor.constraint(equalTo: topContainer.bottomAnchor),
            bottomContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            topContainer.heightAnchor.constraint(equalTo: bottomContainer.heightAnchor)
        ])

        let topStack = UIStackView(arrangedSubviews: [qrImageView, nicknameLabel, subtitleLabel])
        topStack.axis = .vertical
        topStack.spacing = 14
        topStack.alignment = .center
        topStack.translatesAutoresizingMaskIntoConstraints = false
        topContainer.addSubview(topStack)

        saveButton.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.addSubview(saveButton)

        let qrWidthByRatio = qrImageView.widthAnchor.constraint(equalTo: topContainer.widthAnchor, multiplier: 0.62)
        qrWidthByRatio.priority = .defaultHigh

        NSLayoutConstraint.activate([
            topStack.centerXAnchor.constraint(equalTo: topContainer.centerXAnchor),
            topStack.centerYAnchor.constraint(equalTo: topContainer.centerYAnchor, constant: -12),
            topStack.leadingAnchor.constraint(greaterThanOrEqualTo: topContainer.leadingAnchor, constant: 24),
            topStack.trailingAnchor.constraint(lessThanOrEqualTo: topContainer.trailingAnchor, constant: -24),

            qrWidthByRatio,
            qrImageView.heightAnchor.constraint(equalTo: qrImageView.widthAnchor),
            qrImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 320),

            saveButton.centerXAnchor.constraint(equalTo: bottomContainer.centerXAnchor),
            saveButton.centerYAnchor.constraint(equalTo: bottomContainer.centerYAnchor),
            saveButton.leadingAnchor.constraint(equalTo: bottomContainer.leadingAnchor, constant: 28),
            saveButton.trailingAnchor.constraint(equalTo: bottomContainer.trailingAnchor, constant: -28),
            saveButton.heightAnchor.constraint(equalToConstant: 52)
        ])

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 56)
        ])
    }

    private func setupContent() {
        qrImageView.image = qrImage
        qrImageView.contentMode = .scaleAspectFit
        qrImageView.layer.cornerRadius = 12
        qrImageView.clipsToBounds = true

        nicknameLabel.text = nickname
        nicknameLabel.textColor = .label
        nicknameLabel.font = .boldSystemFont(ofSize: 24)
        nicknameLabel.textAlignment = .center

        subtitleLabel.text = subtitle
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        saveButton.setTitle("保存至相册", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = .boldSystemFont(ofSize: 19)
        saveButton.backgroundColor = .systemBlue
        saveButton.layer.cornerRadius = 12

        closeButton.setTitle("关闭", for: .normal)
        closeButton.setTitleColor(.label, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        closeButton.isHidden = true
    }

    private func setupActions() {
        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
    }

    private func setupCloseButtonIfNeeded() {
        guard let navigationController else { return }
        let isModalRoot = navigationController.presentingViewController != nil && navigationController.viewControllers.first === self
        closeButton.isHidden = !isModalRoot
    }

    @objc private func didTapClose() {
        dismiss(animated: true)
    }

    @objc private func didTapSave() {
        let imageToSave = makePosterImage()
        saveToPhotoLibrary(imageToSave)
    }

    private func makePosterImage() -> UIImage {
        let canvasWidth: CGFloat = 1080
        let horizontalPadding: CGFloat = 120
        let qrSide: CGFloat = 680
        let topPadding: CGFloat = 170
        let nicknameTopMargin: CGFloat = 54
        let subtitleTopMargin: CGFloat = 26
        let bottomPadding: CGFloat = 200
        let textMaxWidth = canvasWidth - horizontalPadding * 2

        let nicknameParagraph = NSMutableParagraphStyle()
        nicknameParagraph.alignment = .center
        let nicknameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 64),
            .foregroundColor: UIColor.black,
            .paragraphStyle: nicknameParagraph
        ]

        let subtitleParagraph = NSMutableParagraphStyle()
        subtitleParagraph.alignment = .center
        subtitleParagraph.lineBreakMode = .byWordWrapping
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 42, weight: .medium),
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: subtitleParagraph
        ]

        let qrRect = CGRect(
            x: (canvasWidth - qrSide) / 2,
            y: topPadding,
            width: qrSide,
            height: qrSide
        )

        let nicknameSize = (nickname as NSString).boundingRect(
            with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: nicknameAttributes,
            context: nil
        ).integral.size
        let nicknameRect = CGRect(
            x: (canvasWidth - nicknameSize.width) / 2,
            y: qrRect.maxY + nicknameTopMargin,
            width: nicknameSize.width,
            height: nicknameSize.height
        )

        let subtitleSize = (subtitle as NSString).boundingRect(
            with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: subtitleAttributes,
            context: nil
        ).integral.size
        let subtitleRect = CGRect(
            x: (canvasWidth - subtitleSize.width) / 2,
            y: nicknameRect.maxY + subtitleTopMargin,
            width: subtitleSize.width,
            height: subtitleSize.height
        )

        let canvasHeight = subtitleRect.maxY + bottomPadding
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasWidth, height: canvasHeight))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
            qrImage.draw(in: qrRect)
            (nickname as NSString).draw(in: nicknameRect, withAttributes: nicknameAttributes)
            (subtitle as NSString).draw(in: subtitleRect, withAttributes: subtitleAttributes)
        }
    }

    private func saveToPhotoLibrary(_ image: UIImage) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        logInfo(logTag, items: "相册写入权限状态:", status.rawValue)
        switch status {
        case .authorized, .limited:
            writeImageToPhotoLibrary(image)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] newStatus in
                DispatchQueue.main.async {
                    guard let self else { return }
                    switch newStatus {
                    case .authorized, .limited:
                        self.writeImageToPhotoLibrary(image)
                    case .denied, .restricted:
                        self.showAlert(title: "保存失败", message: "请在系统设置中允许访问相册后重试。")
                    case .notDetermined:
                        self.showAlert(title: "保存失败", message: "未获取到相册权限，请重试。")
                    @unknown default:
                        self.showAlert(title: "保存失败", message: "相册权限状态异常。")
                    }
                }
            }
        case .denied, .restricted:
            showAlert(title: "保存失败", message: "请在系统设置中允许访问相册后重试。")
        @unknown default:
            showAlert(title: "保存失败", message: "相册权限状态异常。")
        }
    }

    private func writeImageToPhotoLibrary(_ image: UIImage) {
        logInfo(logTag, items: "开始写入个人二维码海报到相册")
        UIImageWriteToSavedPhotosAlbum(
            image,
            self,
            #selector(image(_:didFinishSavingWithError:contextInfo:)),
            nil
        )
    }

    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeMutableRawPointer?) {
        if let error {
            logError(logTag, items: "保存个人二维码海报失败:", error.localizedDescription)
            showAlert(title: "保存失败", message: error.localizedDescription)
            return
        }
        logInfo(logTag, items: "个人二维码海报保存成功")
        showAlert(title: "保存成功", message: "图片已保存到系统相册。")
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}
