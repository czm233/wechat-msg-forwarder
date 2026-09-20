import Foundation
import Testing
@testable import ChatExporterCore

@Test func parsesNativeTranscript() throws {
    let text = """
    ·Alice
    2026年9月20日 14:32
    Hello
    ·Bob
    2026年9月20日 14:33
    World
    """
    let records = try ChatTranscriptParser.parse(text, timeZone: TimeZone(secondsFromGMT: 0)!)
    #expect(records.count == 2)
    #expect(records[0].author == "Alice")
    #expect(records[1].content == "World")
}

@Test func rejectsTextWithoutWeChatHeaders() {
    #expect(throws: ExportError.self) {
        try ChatTranscriptParser.parse("hello")
    }
}
