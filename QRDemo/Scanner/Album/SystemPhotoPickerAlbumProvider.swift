//
//  SystemPhotoPickerAlbumProvider.swift
//  QRDemo
//
//  Created by Codex on 2026/2/13.
//

import UIKit
import PhotosUI

/// 基于 PHPicker 的系统相册实现。
final class SystemPhotoPickerAlbumProvider: NSObject, QRScannerAlbumProvider {
    weak var delegate: QRScannerAlbumProviderDelegate?

    /// 防止 didFinishPicking 与 presentationControllerDidDismiss 重复回调。
    private var hasCompletedFlow = false

    func startPicking(from presenter: UIViewController) {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = .images
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        picker.presentationController?.delegate = self
        hasCompletedFlow = false

        presenter.present(picker, animated: true) { [weak self] in
            guard let self else { return }
            self.delegate?.albumProviderDidPresentPicker(self)
        }
    }

    private func completeOnce(_ action: () -> Void) {
        guard !hasCompletedFlow else { return }
        hasCompletedFlow = true
        action()
    }
}

extension SystemPhotoPickerAlbumProvider: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            guard let result = results.first else {
                self.completeOnce {
                    self.delegate?.albumProviderDidCancel(self)
                }
                return
            }

            let provider = result.itemProvider
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                self.completeOnce {
                    self.delegate?.albumProvider(self, didFailToLoadImageWithDescription: "所选资源无法读取为图片")
                }
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                guard let self else { return }
                if let error {
                    DispatchQueue.main.async {
                        self.completeOnce {
                            self.delegate?.albumProvider(self, didFailToLoadImageWithDescription: error.localizedDescription)
                        }
                    }
                    return
                }

                guard let image = object as? UIImage else {
                    DispatchQueue.main.async {
                        self.completeOnce {
                            self.delegate?.albumProvider(self, didFailToLoadImageWithDescription: "读取相册图片失败: 类型转换失败")
                        }
                    }
                    return
                }

                DispatchQueue.main.async {
                    self.completeOnce {
                        self.delegate?.albumProvider(self, didPick: image)
                    }
                }
            }
        }
    }
}

extension SystemPhotoPickerAlbumProvider: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        completeOnce {
            delegate?.albumProviderDidCancel(self)
        }
    }
}
