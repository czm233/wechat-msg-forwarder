import Foundation

public struct ArchiveTranscript {
    public let text: String
    public let messages: [ChatMessage]?
}

public enum ArchiveTranscriptReader {
    private static let maximumListingBytes = 1_048_576
    private static let maximumTranscriptBytes = 16_777_216
    private static let maximumTextCandidates = 32

    public static func read(from archive: URL) throws -> ArchiveTranscript? {
        if let primary = try? runTar(
            ["-xOf", archive.path, "--include", "聊天记录.txt"],
            byteLimit: maximumTranscriptBytes
        ), !primary.isEmpty, let transcript = decoded(primary) {
            return transcript
        }

        let listing = try runTar(["-tf", archive.path], byteLimit: maximumListingBytes)
        guard let listingText = String(data: listing, encoding: .utf8) else { throw ExportError.invalidArchive }

        let candidates = listingText
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { isSafeTextPath($0) }
        guard candidates.count <= maximumTextCandidates else { throw ExportError.invalidArchive }

        let ordered = candidates.sorted { left, right in
            let preferredName = "聊天记录.txt"
            let leftPreferred = (left as NSString).lastPathComponent == preferredName
            let rightPreferred = (right as NSString).lastPathComponent == preferredName
            return leftPreferred && !rightPreferred
        }

        var fallback: ArchiveTranscript?
        for entry in ordered {
            let bytes = try runTar(["-xOf", archive.path, "--", entry], byteLimit: maximumTranscriptBytes)
            guard let transcript = decoded(bytes) else { continue }
            if (entry as NSString).lastPathComponent == "聊天记录.txt" { return transcript }
            if (transcript.messages?.count ?? 0) > (fallback?.messages?.count ?? 0) { fallback = transcript }
            if fallback == nil { fallback = transcript }
        }
        return fallback
    }

    private static func decoded(_ data: Data) -> ArchiveTranscript? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return ArchiveTranscript(text: text, messages: try? ChatTranscriptParser.parse(text))
    }

    private static func isSafeTextPath(_ path: String) -> Bool {
        let forbidden = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "\\:"))
        guard path.utf8.count <= 1_024,
              path.lowercased().hasSuffix(".txt"),
              path.first != "/",
              path.unicodeScalars.allSatisfy({ !forbidden.contains($0) }) else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return !components.isEmpty && components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    private static func runTar(_ arguments: [String], byteLimit: Int) throws -> Data {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()

        var data = Data()
        while true {
            let chunk = output.fileHandleForReading.availableData
            if chunk.isEmpty { break }
            guard data.count <= byteLimit - chunk.count else {
                process.terminate()
                process.waitUntilExit()
                throw ExportError.invalidArchive
            }
            data.append(chunk)
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ExportError.invalidArchive }
        return data
    }
}
