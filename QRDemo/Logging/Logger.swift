//
//  Logger.swift
//  QRDemo
//
//  Created by Codex on 2026/2/11.
//

import Foundation

private func logTimestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter.string(from: Date())
}

func logInfo(_ tag: String, items: Any...) {
    let message = items.map { String(describing: $0) }.joined(separator: " ")
    print("[INFO][\(logTimestamp())][\(tag)] \(message)")
}

func logError(_ tag: String, items: Any...) {
    let message = items.map { String(describing: $0) }.joined(separator: " ")
    print("[ERROR][\(logTimestamp())][\(tag)] \(message)")
}
