import ChatExporterCore
import Foundation

enum PreviewBuilder {
    static func build(for record: ExportRecord, archiveURL: URL) throws -> URL {
        let root = try ExportLibrary.prepareDirectories()
        let directory = root.appendingPathComponent("Preview/\(record.id.uuidString)", isDirectory: true)
        let output = directory.appendingPathComponent("index-named.html")
        if FileManager.default.fileExists(atPath: output.path) { return output }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let transcript = try ArchiveTranscriptReader.read(from: archiveURL)
        let html = render(name: record.originalName, transcript: transcript)
        try Data(html.utf8).write(to: output, options: .atomic)
        return output
    }

    private static func render(name: String, transcript: ArchiveTranscript?) -> String {
        let title = htmlEscaped(name)
        let body: String
        if let messages = transcript?.messages, !messages.isEmpty {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            body = messages.map { message in
                """
                <article class="message">
                  <header><strong>\(htmlEscaped(message.author))</strong><time>\(formatter.string(from: message.timestamp))</time></header>
                  <div>\(htmlEscaped(message.content).replacingOccurrences(of: "\n", with: "<br>"))</div>
                </article>
                """
            }.joined(separator: "\n")
        } else if let transcript {
            body = "<pre>\(htmlEscaped(transcript.text))</pre>"
        } else {
            body = "<div class=\"empty\">ZIP 中没有找到可读取的聊天文字。</div>"
        }
        return """
        <!doctype html><html lang="zh-CN"><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src file: data:; connect-src 'none'">
        <meta name="viewport" content="width=device-width,initial-scale=1"><title>\(title)</title>
        <style>
        :root{color-scheme:light dark}*{box-sizing:border-box}body{margin:0;padding:38px;background:#f4f5f2;color:#20231f;font:14px/1.65 -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}
        main{max-width:760px;margin:auto}h1{font-size:20px;margin:0 0 6px}.subtitle{color:#7b8179;margin:0 0 30px}.message{background:#fff;border:1px solid #e2e6df;border-radius:12px;padding:14px 16px;margin:12px 0;box-shadow:0 1px 2px #00000008}.message header{display:flex;justify-content:space-between;gap:20px;margin-bottom:6px;color:#2a7451}.message time{font-size:11px;color:#91978f}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#fff;border:1px solid #e2e6df;border-radius:12px;padding:20px}.empty{text-align:center;padding:80px;color:#858b83}
        @media(prefers-color-scheme:dark){body{background:#171916;color:#eef1eb}.message,pre{background:#222520;border-color:#333831}.message header{color:#67d59e}.subtitle,.message time,.empty{color:#9aa297}}
        </style></head><body><main><h1>聊天记录</h1><p class="subtitle">\(title) · 本地 HTML 预览</p>\(body)</main></body></html>
        """
    }

    private static func htmlEscaped(_ value: String) -> String {
        var result = value
        for (character, entity) in [("&", "&amp;"), ("<", "&lt;"), (">", "&gt;"), ("\"", "&quot;"), ("'", "&#39;")] {
            result = result.replacingOccurrences(of: character, with: entity)
        }
        return result
    }
}
