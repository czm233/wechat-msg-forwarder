import AppKit
import ChatExporterCore
import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [ExportRecord] = []
    @Published var selection: ExportRecord.ID?
    @Published var message: String?

    @Published private(set) var needsSetup = true
    private var didStart = false
    @Published var setupError: String?

    func showPermissionSetup() {
        timer?.invalidate()
        timer = nil
        needsSetup = true
        records = []
        selection = nil
        root = nil
        UserDefaults.standard.set(false, forKey: "permissionSetupCompleted")
    }

    @discardableResult
    func checkDiskAccess() -> Bool {
        switch DiskAccessCheck.current() {
        case .available:
            return true
        case .denied:
            showPermissionSetup()
            setupError = "尚未获得所需的磁盘访问能力，或授权已撤销。请在系统设置中开启当前应用的完全磁盘访问权限，再完全退出并重新打开应用。"
        case .unavailable(let code):
            showPermissionSetup()
            setupError = "暂时无法确认磁盘访问能力（错误码：\(code)）。请检查系统设置并重新启动应用；检查失败不一定表示未授权。"
        }
        return false
    }

    func applicationBecameActive() {
        guard didStart else { return }
        _ = checkDiskAccess()
    }

    func launch() {
        guard !didStart else { return }
        didStart = true
        let previouslyCompleted = UserDefaults.standard.bool(forKey: "permissionSetupCompleted")
        guard checkDiskAccess() else { return }
        if previouslyCompleted {
            needsSetup = false
            start()
        }
    }

    func completePermissionSetup() {
        setupError = nil
        guard checkDiskAccess() else { return }
        do {
            let directory = try ExportLibrary.prepareDirectories()
            let probe = directory.appendingPathComponent(".access-check-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: probe) }
            let data = Data("access-check".utf8)
            try data.write(to: probe, options: .atomic)
            guard try Data(contentsOf: probe) == data else { throw ExportError.containerUnavailable }
            _ = try ExportLibrary.records()
            UserDefaults.standard.set(true, forKey: "permissionSetupCompleted")
            needsSetup = false
            start()
        } catch {
            setupError = "导出目录仍不可用。请确认已添加当前应用并开启权限，完全退出后重新打开再试。若仍失败，请检查应用签名与共享目录配置。\n\(error.localizedDescription)"
        }
    }

    private var timer: Timer?
    private var root: URL?

    var selectedRecord: ExportRecord? { records.first { $0.id == selection } }

    func start() {
        guard !needsSetup, timer == nil else { return }
        reload()
        guard !needsSetup else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    func reload() {
        guard !needsSetup else { return }
        do {
            root = try ExportLibrary.prepareDirectories()
            try ExportLibrary.prune(olderThan: retentionDays)
            let loaded = try ExportLibrary.records()
            guard loaded != records else { return }
            records = loaded
            if selection == nil || !loaded.contains(where: { $0.id == selection }) {
                selection = loaded.first?.id
            }
        } catch {
            showPermissionSetup()
            setupError = "导出目录无法访问，请重新检查权限。\n\(error.localizedDescription)"
        }
    }

    func archiveURL(for record: ExportRecord) -> URL? {
        root.map { record.archiveURL(in: $0) }
    }

    func copy(_ record: ExportRecord) {
        guard let url = archiveURL(for: record) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if pasteboard.writeObjects([url as NSURL]) {
            message = "ZIP 已复制到剪贴板"
        }
    }

    func reveal(_ record: ExportRecord) {
        guard let url = archiveURL(for: record) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func delete(_ record: ExportRecord) {
        guard let root else { return }
        let directory = root.appendingPathComponent("Inbox/Ready/\(record.id.uuidString)", isDirectory: true)
        let preview = root.appendingPathComponent("Preview/\(record.id.uuidString)", isDirectory: true)
        do {
            try FileManager.default.trashItem(at: directory, resultingItemURL: nil)
            try? FileManager.default.removeItem(at: preview)
            reload()
        } catch {
            message = error.localizedDescription
        }
    }

    var retentionDays: Int {
        get { UserDefaults(suiteName: AppGroup.identifier)?.integer(forKey: "retentionDays").nonzero ?? 30 }
        set {
            UserDefaults(suiteName: AppGroup.identifier)?.set(newValue, forKey: "retentionDays")
            reload()
        }
    }
}

private extension Int {
    var nonzero: Int? { self > 0 ? self : nil }
}
