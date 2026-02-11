//
//  AvatarFactory.swift
//  QRDemo
//
//  Created by Codex on 2026/2/11.
//

import UIKit

enum AvatarFactory {
    static func makeAvatarImage() -> UIImage {
        if let image = UIImage(named: "avatar.JPEG") {
            logInfo("AvatarFactory", items: "使用 UIImage(named:) 加载 avatar.JPEG")
            return image
        }

        if let url = Bundle.main.url(forResource: "avatar", withExtension: "JPEG"),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            logInfo("AvatarFactory", items: "使用 Bundle 文件加载 avatar.JPEG")
            return image
        }

        if let image = UIImage(named: "avatar") {
            logInfo("AvatarFactory", items: "使用 UIImage(named:) 加载 avatar")
            return image
        }

        if let url = Bundle.main.url(forResource: "avatar", withExtension: "jpg"),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            logInfo("AvatarFactory", items: "使用 Bundle 文件加载 avatar.jpg")
            return image
        }

        if let url = Bundle.main.url(forResource: "avatar", withExtension: "jpeg"),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            logInfo("AvatarFactory", items: "使用 Bundle 文件加载 avatar.jpeg")
            return image
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
}
