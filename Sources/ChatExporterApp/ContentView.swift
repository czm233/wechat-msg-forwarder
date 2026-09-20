import ChatExporterCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: HistoryStore

    var body: some View {
        NavigationSplitView {
            List(store.records, selection: $store.selection) { record in
                HistoryRow(record: record)
                    .tag(record.id)
                    .contextMenu {
                        Button("复制 ZIP") { store.copy(record) }
                        Button("在 Finder 中显示") { store.reveal(record) }
                        Divider()
                        Button("删除", role: .destructive) { store.delete(record) }
                    }
            }
            .navigationTitle("Chat Exports")
            .overlay {
                if store.records.isEmpty {
                    ContentUnavailableView(
                        "还没有聊天记录",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("在微信中选择聊天记录，然后使用“转发到其他应用”。")
                    )
                }
            }
            .toolbar {
                Button { store.reload() } label: { Label("刷新", systemImage: "arrow.clockwise") }
            }
        } detail: {
            if let record = store.selectedRecord {
                ExportDetail(record: record)
            } else {
                ContentUnavailableView("选择一条记录", systemImage: "archivebox")
            }
        }
        .alert("提示", isPresented: Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )) { Button("好") { store.message = nil } } message: { Text(store.message ?? "") }
    }
}

private struct HistoryRow: View {
    let record: ExportRecord
    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "doc.zipper")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.green)
                .frame(width: 30, height: 34)
                .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(record.originalName).lineLimit(1)
                Text(record.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ExportDetail: View {
    @EnvironmentObject private var store: HistoryStore
    let record: ExportRecord
    @State private var previewURL: URL?
    @State private var previewError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(record.originalName).font(.title2.weight(.semibold)).lineLimit(1)
                    Text("\(ByteCountFormatter.string(fromByteCount: record.byteCount, countStyle: .file)) · \(record.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button { store.reveal(record) } label: { Label("Finder", systemImage: "folder") }
                Button { store.copy(record) } label: { Label("复制 ZIP", systemImage: "doc.on.clipboard") }
                    .buttonStyle(.borderedProminent).tint(.green)
            }
            .padding(22)
            Divider()
            Group {
                if let previewURL {
                    WebPreview(fileURL: previewURL)
                } else if let previewError {
                    ContentUnavailableView("无法生成预览", systemImage: "exclamationmark.triangle", description: Text(previewError))
                } else {
                    ProgressView("正在生成本地预览…")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: record.id) {
            previewURL = nil
            previewError = nil
            guard let archive = store.archiveURL(for: record) else { return }
            do {
                previewURL = try await Task.detached { try PreviewBuilder.build(for: record, archiveURL: archive) }.value
            } catch {
                previewError = error.localizedDescription
            }
        }
    }
}
