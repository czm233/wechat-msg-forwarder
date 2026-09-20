import Foundation

public enum AppGroup {
    public static let infoKey = "MWCEAppGroupIdentifier"
    public static let fallbackIdentifier = "377U5HWB3A.com.czm.macos-wechat-chat-exporter.shared"
    public static let storageNamespace = "macos-wechat-chat-exporter"

    public static var identifier: String {
        let value = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String
        return value?.isEmpty == false ? value! : fallbackIdentifier
    }

    public static func container(fileManager: FileManager = .default) throws -> URL {
        guard let url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            throw ExportError.containerUnavailable
        }
        return url.appendingPathComponent(storageNamespace, isDirectory: true)
    }
}

public enum ExportError: Error, LocalizedError {
    case containerUnavailable
    case invalidArchive
    case emptyShare

    public var errorDescription: String? {
        switch self {
        case .containerUnavailable: "无法访问应用共享文件夹，请检查签名与 App Group 配置。"
        case .invalidArchive: "这不是可读取的微信聊天 ZIP，原始文件仍会保留。"
        case .emptyShare: "没有收到可以保存的文件。"
        }
    }
}
