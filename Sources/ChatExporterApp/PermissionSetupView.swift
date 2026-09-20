import AppKit
import SwiftUI

struct PermissionSetupView: View {
    @EnvironmentObject private var store: HistoryStore
    @State private var confirmed = false
    @State private var settingsError: String?
    @State private var showingFailure = false
    @State private var failureMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Label("使用准备 · 权限配置", systemImage: "lock.shield")
                    .font(.headline).foregroundStyle(.green)
                Text("先配置权限，再开始导出")
                    .font(.largeTitle.weight(.semibold))
                Text("为减少 macOS 反复询问“访问其他 App 的数据”，请先为当前应用开启完全磁盘访问权限。配置完成前，应用不会自动读取导出记录。")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 18) {
                    step("1", "打开系统设置", "进入“隐私与安全性 → 完全磁盘访问权限”。")
                    Button("打开完全磁盘访问权限设置", action: openPermissionSettings)
                    step("2", "添加并开启当前应用", "点击设置中的“＋”，添加 WeChat Chat Exporter.app 并打开开关。也可以从 Finder 将应用拖入列表；请勿选择微信或旧版本。")
                    Button("在 Finder 中显示当前应用") {
                        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                    }
                    step("3", "重新打开应用并检查", "如果系统提示退出并重新打开，请照做。随后回到此页面，确认配置并检查导出目录。")
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
                Text("完全磁盘访问权限允许读取其他应用的受保护数据，授权范围较大。本应用仅处理你主动分享的聊天 ZIP，数据保留在本机；你可以随时在系统设置中撤销授权。")
                    .font(.callout).foregroundStyle(.secondary)
                Toggle("我已在系统设置中开启当前应用的权限", isOn: $confirmed)
                Button("检查权限并开始使用") {
                    store.completePermissionSetup()
                    if store.needsSetup {
                        failureMessage = store.setupError ?? "请先完成权限配置，再重新检查。"
                        showingFailure = true
                    }
                }
                    .buttonStyle(.borderedProminent).tint(.green)
                    .disabled(!confirmed)
                Text("每次启动都会重新检查受保护文件的访问能力，不读取其内容；检查通过后再验证导出目录。系统未提供直接查询此权限开关的公开接口。")
                    .font(.caption).foregroundStyle(.secondary)
                if let error = store.setupError ?? settingsError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange).textSelection(.enabled)
                }
            }
            .padding(32)
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .alert("暂时无法开始使用", isPresented: $showingFailure) {
            Button("打开权限设置", action: openPermissionSettings)
            Button("返回检查", role: .cancel) { }
        } message: {
            Text(failureMessage)
        }
    }

    private func openPermissionSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        if !NSWorkspace.shared.open(url) {
            settingsError = "无法打开系统设置，请手动进入“隐私与安全性 → 完全磁盘访问权限”。"
            failureMessage = settingsError!
            showingFailure = true
        }
    }

    private func step(_ number: String, _ title: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.headline).foregroundStyle(.green)
                .frame(width: 28, height: 28)
                .background(.green.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(description).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
