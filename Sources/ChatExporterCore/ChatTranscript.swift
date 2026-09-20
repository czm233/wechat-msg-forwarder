import Foundation

public struct ChatMessage: Equatable, Sendable {
    public let author: String
    public let timestamp: Date
    public let content: String

    public init(author: String, timestamp: Date, content: String) {
        self.author = author
        self.timestamp = timestamp
        self.content = content
    }
}

public enum ChatTranscriptParser {
    private struct Header {
        let lineIndex: Int
        let author: String
        let timestamp: Date
    }

    public static func parse(_ text: String, timeZone: TimeZone = .current) throws -> [ChatMessage] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: CharacterSet(charactersIn: "\u{feff}"))
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var headers: [Header] = []
        for index in lines.indices.dropLast() {
            guard lines[index].first == "·" else { continue }
            let author = String(lines[index].dropFirst()).trimmingCharacters(in: .whitespaces)
            guard !author.isEmpty,
                  let timestamp = parseTimestamp(lines[index + 1], timeZone: timeZone) else { continue }
            headers.append(Header(lineIndex: index, author: author, timestamp: timestamp))
        }

        guard let first = headers.first,
              lines[..<first.lineIndex].allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            throw ExportError.invalidArchive
        }

        return headers.enumerated().map { position, header in
            let contentStart = header.lineIndex + 2
            let contentEnd = position + 1 < headers.count ? headers[position + 1].lineIndex : lines.count
            let content = lines[contentStart..<contentEnd]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return ChatMessage(author: header.author, timestamp: header.timestamp, content: content)
        }
    }

    private static func parseTimestamp(_ value: String, timeZone: TimeZone) -> Date? {
        let scanner = Scanner(string: value)
        scanner.charactersToBeSkipped = nil
        guard let year = scanner.scanInt(), scanner.scanString("年") != nil,
              let month = scanner.scanInt(), scanner.scanString("月") != nil,
              let day = scanner.scanInt(), scanner.scanString("日 ") != nil,
              let hour = scanner.scanInt(), scanner.scanString(":") != nil,
              let minute = scanner.scanInt(), scanner.isAtEnd else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))
    }
}
