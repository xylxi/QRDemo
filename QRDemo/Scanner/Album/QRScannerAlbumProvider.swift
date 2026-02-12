//
//  QRScannerAlbumProvider.swift
//  QRDemo
//
//  Created by Codex on 2026/2/13.
//

import UIKit

/// 相册来源抽象协议：系统相册或自定义相册都可以实现该协议。
protocol QRScannerAlbumProvider: AnyObject {
    /// 回调代理，由调用方（扫码页面）实现。
    var delegate: QRScannerAlbumProviderDelegate? { get set }
    /// 从指定页面发起选图流程。
    func startPicking(from presenter: UIViewController)
}

/// 相册来源回调协议，统一选图成功、取消与失败事件。
protocol QRScannerAlbumProviderDelegate: AnyObject {
    /// 相册页面展示完成。
    func albumProviderDidPresentPicker(_ provider: QRScannerAlbumProvider)
    /// 用户取消选图（包括按钮取消与手势下拉关闭）。
    func albumProviderDidCancel(_ provider: QRScannerAlbumProvider)
    /// 成功选择图片。
    func albumProvider(_ provider: QRScannerAlbumProvider, didPick image: UIImage)
    /// 选图流程失败（资源不可读/加载失败等）。
    func albumProvider(_ provider: QRScannerAlbumProvider, didFailToLoadImageWithDescription description: String)
}
