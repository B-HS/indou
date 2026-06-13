import Foundation
import os

enum Log {
    static let app = Logger(subsystem: "com.hyunseokbyun.indou", category: "app")
    static let hotkey = Logger(subsystem: "com.hyunseokbyun.indou", category: "hotkey")
    static let windows = Logger(subsystem: "com.hyunseokbyun.indou", category: "windows")
    static let capture = Logger(subsystem: "com.hyunseokbyun.indou", category: "capture")
    static let overlay = Logger(subsystem: "com.hyunseokbyun.indou", category: "overlay")
    static let permissions = Logger(subsystem: "com.hyunseokbyun.indou", category: "permissions")
}
