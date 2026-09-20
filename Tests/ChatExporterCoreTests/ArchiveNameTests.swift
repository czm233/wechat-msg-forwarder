import Foundation
import Testing
@testable import ChatExporterCore

@Test func namesUseDistinctAuthorsAndDateRange() {
    let date = Date(timeIntervalSince1970: 1_789_862_400)
    let messages = ["Alice", "Bob", "Alice", "Carol"].enumerated().map {
        ChatMessage(author: $0.element, timestamp: date.addingTimeInterval(Double($0.offset) * 86400), content: "")
    }
    let name = ArchiveName.make(messages: messages, fallbackDate: date, timeZone: TimeZone(secondsFromGMT: 0)!)
    #expect(name.hasPrefix("Alice、Bob等3人_"))
    #expect(name.contains("至"))
    #expect(ArchiveName.make(messages: [], fallbackDate: date).hasPrefix("聊天记录_"))
}

@Test func namesAreSafeAndFitFilesystemByteLimit() {
    let messages = [ChatMessage(author: String(repeating: "😀", count: 200) + "/bad", timestamp: Date(), content: ""),
                    ChatMessage(author: "a/b:c\\d\n", timestamp: Date(), content: "")]
    let name = ArchiveName.make(messages: messages, fallbackDate: Date())
    #expect(name.utf8.count < 255)
    #expect(!name.contains("/"))
    #expect(!name.contains(":"))
    #expect(!name.contains("\\"))
}

@Test func migrationPreservesOriginalBytesAndOldURL() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let bytes = Data("unreadable archive fallback".utf8)
    let original = dir.appendingPathComponent("Zip归档.zip")
    try bytes.write(to: original)
    let record = ExportRecord(id: UUID(), originalName: "Zip归档.zip", storedName: "Zip归档.zip", createdAt: Date(), byteCount: Int64(bytes.count))
    let updated = try ExportLibrary.applyAutomaticName(record, in: dir)
    #expect(updated.namingVersion == 1)
    #expect(updated.originalName == updated.storedName)
    #expect(try Data(contentsOf: original) == bytes)
    #expect(try Data(contentsOf: dir.appendingPathComponent(updated.storedName)) == bytes)
}
