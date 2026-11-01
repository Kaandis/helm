import Foundation

/// Where results go and what they're called: beside the original (or in
/// Downloads), never over an existing file.
enum Output {
    static func folder(for source: URL) -> URL {
        if Prefs.string(Prefs.saveLocation) == "downloads",
           let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            return downloads
        }
        return source.deletingLastPathComponent()
    }

    /// "photo.heic" → "photo.jpg"; "photo.jpg" → "photo compressed.jpg" when
    /// a suffix is given; " 2", " 3"… if the name is taken.
    static func file(for source: URL, ext: String, suffix: String? = nil) -> URL {
        var base = source.deletingPathExtension().lastPathComponent
        if let suffix { base += " " + suffix }
        return unique(folder(for: source).appendingPathComponent(base).appendingPathExtension(ext))
    }

    static func named(_ name: String, ext: String, beside source: URL) -> URL {
        unique(folder(for: source).appendingPathComponent(name).appendingPathExtension(ext))
    }

    static func folder(named name: String, beside source: URL) -> URL {
        let url = unique(folder(for: source).appendingPathComponent(name, isDirectory: true))
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func unique(_ url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        let folder = url.deletingLastPathComponent()
        for n in 2... {
            let candidate = folder.appendingPathComponent("\(base) \(n)")
            let named = ext.isEmpty ? candidate : candidate.appendingPathExtension(ext)
            if !fm.fileExists(atPath: named.path) { return named }
        }
        return url
    }
}

enum ToolError: LocalizedError {
    case unreadable(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unreadable(let name): String(localized: "Couldn’t read \(name).")
        case .failed(let detail): detail
        }
    }
}
