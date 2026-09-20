// swift-tools-version: 6.0
import PackageDescription

let shareSwiftOptions: [SwiftSetting] = [
    .unsafeFlags(["-application-extension"]),
    .swiftLanguageMode(.v5),
]
let shareEntryPoint = ["-Xlinker", "-e"] + ["-Xlinker", "_NSExtensionMain"]
let shareLinkOptions: [LinkerSetting] = [
    .unsafeFlags(shareEntryPoint + ["-Xlinker", "-application_extension"]),
]
let applicationProducts: [Product] = [
    .library(name: "ChatExporterCore", targets: ["ChatExporterCore"]),
    .executable(name: "WeChatChatExporter", targets: ["ChatExporterApp"]),
    .executable(name: "WeChatChatExporterShare", targets: ["ChatExporterShare"]),
]

let package = Package(
    name: "macos-wechat-chat-exporter",
    platforms: [.macOS(.v14)],
    products: applicationProducts,
    targets: [
        .target(
            name: "ChatExporterCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "ChatExporterApp",
            dependencies: ["ChatExporterCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ChatExporterCoreTests",
            dependencies: ["ChatExporterCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "ChatExporterShare",
            dependencies: ["ChatExporterCore"],
            swiftSettings: shareSwiftOptions,
            linkerSettings: shareLinkOptions
        ),
    ]
)
