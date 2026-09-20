import AppKit
import ChatExporterCore
import Foundation

@objc(MWCEShareViewController)
final class ShareViewController: NSViewController {
    private var receiveTask: Task<Void, Never>?

    override func loadView() {
        let panel = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 86))
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.startAnimation(nil)
        indicator.translatesAutoresizingMaskIntoConstraints = false

        let message = NSTextField(labelWithString: "正在保存聊天记录…")
        message.font = .systemFont(ofSize: 13, weight: .medium)
        message.translatesAutoresizingMaskIntoConstraints = false

        panel.addSubview(indicator)
        panel.addSubview(message)
        NSLayoutConstraint.activate([
            indicator.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),
            indicator.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
            message.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 12),
            message.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
            message.trailingAnchor.constraint(lessThanOrEqualTo: panel.trailingAnchor, constant: -24),
        ])
        view = panel
        preferredContentSize = panel.frame.size
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        guard receiveTask == nil, let request = extensionContext else { return }
        receiveTask = Task { @MainActor in
            do {
                let savedFile = try await ShareReceiver.receive(request.inputItems)
                NSPasteboard.general.clearContents()
                _ = NSPasteboard.general.writeObjects([savedFile as NSURL])
                request.completeRequest(returningItems: nil)
            } catch {
                request.cancelRequest(withError: NSError(
                    domain: "com.macos-wechat-chat-exporter.share",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
                ))
            }
        }
    }
}

private enum ShareReceiver {
    private struct ImportedFile: Sendable {
        let location: URL
        let displayName: String
    }

    static func receive(_ inputItems: [Any]) async throws -> URL {
        guard let provider = inputItems
            .compactMap({ $0 as? NSExtensionItem })
            .flatMap({ $0.attachments ?? [] })
            .first else { throw ExportError.emptyShare }

        let library = try ExportLibrary.prepareDirectories()
        let identifier = UUID()
        let workDirectory = library
            .appendingPathComponent("Inbox", isDirectory: true)
            .appendingPathComponent("Staging", isDirectory: true)
            .appendingPathComponent(identifier.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: false)

        do {
            let imported = try await importFile(from: provider, into: workDirectory)
            let values = try imported.location.resourceValues(forKeys: [.fileSizeKey])
            guard let size = values.fileSize, size > 0 else { throw ExportError.invalidArchive }

            var record = ExportRecord(
                id: identifier,
                originalName: imported.displayName,
                storedName: imported.location.lastPathComponent,
                createdAt: Date(),
                byteCount: Int64(size)
            )
            try ExportLibrary.write(record, to: workDirectory)
            record = (try? ExportLibrary.applyAutomaticName(record, in: workDirectory)) ?? record

            let readyDirectory = library
                .appendingPathComponent("Inbox", isDirectory: true)
                .appendingPathComponent("Ready", isDirectory: true)
                .appendingPathComponent(identifier.uuidString, isDirectory: true)
            try FileManager.default.moveItem(at: workDirectory, to: readyDirectory)
            return readyDirectory.appendingPathComponent(record.storedName)
        } catch {
            try? FileManager.default.removeItem(at: workDirectory)
            throw error
        }
    }

    private static func importFile(from provider: NSItemProvider, into directory: URL) async throws -> ImportedFile {
        let acceptedTypes = ["public.zip-archive", "com.pkware.zip-archive", "public.file-url", "public.data"]
        guard let type = acceptedTypes.first(where: provider.hasItemConformingToTypeIdentifier)
                ?? provider.registeredTypeIdentifiers.first else { throw ExportError.emptyShare }
        let proposedName = provider.suggestedName

        return try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: type) { source, loadingError in
                do {
                    if let loadingError { throw loadingError }
                    guard let source else { throw ExportError.emptyShare }
                    let name = safeArchiveName(proposedName ?? source.lastPathComponent)
                    let target = directory.appendingPathComponent(name, isDirectory: false)
                    try FileManager.default.copyItem(at: source, to: target)
                    continuation.resume(returning: ImportedFile(location: target, displayName: name))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func safeArchiveName(_ proposedName: String) -> String {
        let leaf = (proposedName as NSString).lastPathComponent
        let forbidden = CharacterSet(charactersIn: "/:\\").union(.controlCharacters)
        let cleaned = leaf.unicodeScalars.map { forbidden.contains($0) ? "-" : String($0) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let base = cleaned.isEmpty ? "聊天记录" : String(cleaned.prefix(180))
        return base.lowercased().hasSuffix(".zip") ? base : base + ".zip"
    }
}
