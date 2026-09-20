import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: HistoryStore
    @State private var days = 30

    var body: some View {
        Form {
            Section("文件管理") {
                Picker("自动清理", selection: $days) {
                    Text("7 天后").tag(7)
                    Text("30 天后").tag(30)
                    Text("90 天后").tag(90)
                    Text("永不").tag(Int.max)
                }
                Text("清理只会删除本应用共享文件夹中的历史 ZIP 和预览缓存。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("隐私") {
                Button("重新查看权限配置引导") { store.showPermissionSetup() }
                Label("不包含网络请求、账号登录或遥测代码", systemImage: "lock.shield")
                Label("聊天 ZIP 与 HTML 预览只保存在本机", systemImage: "internaldrive")
            }
        }
        .onAppear { days = store.retentionDays }
        .onChange(of: days) { _, value in store.retentionDays = value }
    }
}
