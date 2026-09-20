import Foundation

public enum ArchiveName {
    public static func make(messages: [ChatMessage], fallbackDate: Date, timeZone: TimeZone = .current) -> String {
        var seen = Set<String>()
        let authors = messages.map(\.author).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        let forbidden = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/\\:"))
        let names = authors.prefix(2).map { name in
            let safe = name.unicodeScalars.map { forbidden.contains($0) ? "-" : String($0) }.joined()
            var shortened = ""
            for character in safe {
                guard (shortened + String(character)).utf8.count <= 60 else { break }
                shortened.append(character)
            }
            return shortened.isEmpty ? "未命名发言人" : shortened
        }
        let prefix = names.isEmpty ? "聊天记录" : names.joined(separator: "、") + (authors.count > 2 ? "等\(authors.count)人" : "")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let dates = messages.map(\.timestamp)
        let first = formatter.string(from: dates.min() ?? fallbackDate)
        let last = formatter.string(from: dates.max() ?? fallbackDate)
        return "\(prefix)_\(first)\(first == last ? "" : "至" + last).zip"
    }
}
