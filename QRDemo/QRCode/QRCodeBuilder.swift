//
//  QRCodeBuilder.swift
//  QRDemo
//
//  Created by Codex on 2026/2/11.
//

import UIKit
import CoreImage

enum QRCodeBuilder {
    static func generate(content: String, avatar: UIImage, size: CGFloat) -> UIImage? {
        logInfo("QRCodeBuilder", items: "开始生成二维码，内容:", content, "目标尺寸:", Int(size))
        guard let data = content.data(using: .utf8) else {
            logError("QRCodeBuilder", items: "二维码内容 UTF8 编码失败")
            return nil
        }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            logError("QRCodeBuilder", items: "创建 CIQRCodeGenerator 失败")
            return nil
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else {
            logError("QRCodeBuilder", items: "CIQRCodeGenerator 输出为空")
            return nil
        }

        let originalExtent = outputImage.extent.integral
        let availableSide = min(size, size)
        let rawScale = floor(availableSide / max(originalExtent.width, originalExtent.height))
        let scale = max(1, rawScale)
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        logInfo("QRCodeBuilder", items: "二维码缩放倍数:", Int(scale))

        let context = CIContext()
        guard let qrCGImage = context.createCGImage(transformed, from: transformed.extent) else {
            logError("QRCodeBuilder", items: "createCGImage 失败")
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        let result = renderer.image { renderContext in
            let cgContext = renderContext.cgContext
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(x: 0, y: 0, width: size, height: size))
            cgContext.interpolationQuality = .none

            let qrWidth = transformed.extent.width
            let qrHeight = transformed.extent.height
            let qrRect = CGRect(
                x: (size - qrWidth) / 2,
                y: (size - qrHeight) / 2,
                width: qrWidth,
                height: qrHeight
            )
            cgContext.draw(qrCGImage, in: qrRect)

            let avatarSize = size * 0.18
            let avatarRect = CGRect(
                x: (size - avatarSize) / 2,
                y: (size - avatarSize) / 2,
                width: avatarSize,
                height: avatarSize
            )
            let backgroundRect = avatarRect.insetBy(dx: -6, dy: -6)

            let whiteBackground = UIBezierPath(
                roundedRect: backgroundRect,
                cornerRadius: backgroundRect.width * 0.18
            )
            UIColor.white.setFill()
            whiteBackground.fill()

            let clipPath = UIBezierPath(ovalIn: avatarRect)
            clipPath.addClip()
            avatar.draw(in: avatarRect)
        }

        logInfo("QRCodeBuilder", items: "二维码生成完成，最终像素:", Int(result.size.width), "x", Int(result.size.height))
        return result
    }
}
