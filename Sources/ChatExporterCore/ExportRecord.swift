import Foundation

public struct ExportRecord: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let originalName: String
    public let storedName: String
    public let createdAt: Date
    public let byteCount: Int64
    public var namingVersion: Int?

    public init(id: UUID, originalName: String, storedName: String, createdAt: Date, byteCount: Int64) {
        self.id = id
        self.originalName = originalName
        self.storedName = storedName
        self.createdAt = createdAt
        self.byteCount = byteCount
    }

    public func archiveURL(in root: URL) -> URL {
        root.appendingPathComponent("Inbox/Ready/\(id.uuidString)/\(storedName)")
    }
}

public enum ExportLibrary {
    public static let metadataName = "record.json"

    public static func prepareDirectories(fileManager: FileManager = .default) throws -> URL {
        let root = try AppGroup.container(fileManager: fileManager)
        for path in ["Inbox/Staging", "Inbox/Ready", "Preview"] {
            try fileManager.createDirectory(
                at: root.appendingPathComponent(path, isDirectory: true),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        return root
    }

    public static func records(fileManager: FileManager = .default) throws -> [ExportRecord] {
        let root = try prepareDirectories(fileManager: fileManager)
        let ready = root.appendingPathComponent("Inbox/Ready", isDirectory: true)
        let directories = try fileManager.contentsOfDirectory(
            at: ready,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return directories.compactMap { directory in
            let metadata = directory.appendingPathComponent(metadataName)
            guard let data = try? Data(contentsOf: metadata),
                  var record = try? decoder.decode(ExportRecord.self, from: data),
                  fileManager.fileExists(atPath: record.archiveURL(in: root).path) else { return nil }
            if record.namingVersion != 1,
               let updated = try? applyAutomaticName(record, in: directory) {
                record = updated
            }
            return record
        }.sorted { $0.createdAt > $1.createdAt }
    }

    public static func applyAutomaticName(_ record: ExportRecord, in directory: URL) throws -> ExportRecord {
        let source = directory.appendingPathComponent(record.storedName)
        let messages = (try? ArchiveTranscriptReader.read(from: source))?.messages ?? []
        let name = ArchiveName.make(messages: messages, fallbackDate: record.createdAt)
        let target = directory.appendingPathComponent(name)
        // Keep the original link so previously copied file URLs remain usable.
        // Publish metadata only after the named file exists; failures preserve the old record.
        if source != target && !FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.linkItem(at: source, to: target)
        }
        var updated = ExportRecord(id: record.id, originalName: name, storedName: name,
                                   createdAt: record.createdAt, byteCount: record.byteCount)
        updated.namingVersion = 1
        try write(updated, to: directory)
        return updated
    }

    public static func write(_ record: ExportRecord, to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(record).write(
            to: directory.appendingPathComponent(metadataName),
            options: [.atomic]
        )
    }

    public static func prune(olderThan days: Int, now: Date = Date(), fileManager: FileManager = .default) throws {
        guard days > 0 else { return }
        let root = try prepareDirectories(fileManager: fileManager)
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        for record in try records(fileManager: fileManager) where record.createdAt < cutoff {
            let directory = root.appendingPathComponent("Inbox/Ready/\(record.id.uuidString)", isDirectory: true)
            try? fileManager.removeItem(at: directory)
            try? fileManager.removeItem(at: root.appendingPathComponent("Preview/\(record.id.uuidString)", isDirectory: true))
        }
    }
}
