//
//  AvatarFactory.swift
//  QRDemo
//
//  Created by Codex on 2026/2/11.
//

import UIKit

enum AvatarFactory {
    static func makeAvatarImage() -> UIImage {
        let candidates = ["JPEG", "jpg", "jpeg", "JPG"]
        for ext in candidates {
            if let image = loadBundleImage(resource: "avatar", ext: ext) {
                logInfo("AvatarFactory", items: "使用 Bundle 文件加载 avatar.\(ext)")
                return image
            }
        }

        logError("AvatarFactory", items: "未找到头像资源，使用默认占位头像")
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            UIColor.systemBlue.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()

            if let symbol = UIImage(systemName: "person.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                let symbolSize = CGSize(width: 170, height: 170)
                let symbolRect = CGRect(
                    x: (size.width - symbolSize.width) / 2,
                    y: (size.height - symbolSize.height) / 2,
                    width: symbolSize.width,
                    height: symbolSize.height
                )
                symbol.draw(in: symbolRect)
            }
        }
    }

    private static func loadBundleImage(resource: String, ext: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }
}
