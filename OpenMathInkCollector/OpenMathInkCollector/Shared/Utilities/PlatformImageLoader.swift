import SwiftUI

#if canImport(UIKit)
import UIKit

/// 支持内存缓存的跨平台图片加载器
enum PlatformImageLoader {
    /// 内存缓存（存储原始 Data，避免重复读取和编码）
    private static let cache = NSCache<NSURL, NSData>()

    static {
        cache.countLimit = 50
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    /// 从缓存或磁盘异步加载图片原始数据
    static func loadData(from url: URL) async -> Data? {
        // 先查缓存
        if let cached = cache.object(forKey: url as NSURL) {
            return cached as Data
        }

        // 磁盘异步读取
        let data = await Task.detached(priority: .userInitiated) { () -> Data? in
            try? Data(contentsOf: url)
        }.value

        // 缓存结果
        if let data {
            cache.setObject(data as NSData, forKey: url as NSURL)
        }

        return data
    }

    /// 清除所有缓存
    static func clearCache() {
        cache.removeAllObjects()
    }
}

extension Image {
    init(platformImage: UIImage) {
        self = Image(uiImage: platformImage)
    }
}

#elseif canImport(AppKit)
import AppKit

enum PlatformImageLoader {
    private static let cache = NSCache<NSURL, NSData>()

    static {
        cache.countLimit = 50
        cache.totalCostLimit = 50 * 1024 * 1024
    }

    static func loadData(from url: URL) async -> Data? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached as Data
        }

        let data = await Task.detached(priority: .userInitiated) { () -> Data? in
            try? Data(contentsOf: url)
        }.value

        if let data {
            cache.setObject(data as NSData, forKey: url as NSURL)
        }

        return data
    }

    static func clearCache() {
        cache.removeAllObjects()
    }
}

extension Image {
    init(platformImage: NSImage) {
        self = Image(nsImage: platformImage)
    }
}

#endif
