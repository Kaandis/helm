import AppKit
import PDFKit
import UniformTypeIdentifiers

/// PDFs through PDFKit: merge, split, shrink, and pages to pictures.
enum PDFTools {
    static func open(_ source: URL) throws -> PDFDocument {
        guard let document = PDFDocument(url: source) else { throw ToolError.unreadable(source.lastPathComponent) }
        return document
    }

    static func merge(_ sources: [URL], to destination: URL) throws {
        let merged = PDFDocument()
        for source in sources {
            let document = try open(source)
            for index in 0..<document.pageCount {
                if let page = document.page(at: index) { merged.insert(page, at: merged.pageCount) }
            }
        }
        try save(merged, to: destination)
    }

    /// Each page as its own PDF, in a folder.
    static func split(_ source: URL, into folder: URL) throws {
        let document = try open(source)
        let base = source.deletingPathExtension().lastPathComponent
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let single = PDFDocument()
            single.insert(page, at: 0)
            try save(single, to: folder.appendingPathComponent("\(base) \(index + 1).pdf"))
        }
    }

    /// Re-saves with images recompressed as JPEG at screen resolution.
    static func compress(_ source: URL, to destination: URL) throws {
        let document = try open(source)
        let options: [PDFDocumentWriteOption: Any] = [.saveImagesAsJPEGOption: true, .optimizeImagesForScreenOption: true]
        guard document.write(to: destination, withOptions: options) else {
            throw ToolError.failed(String(localized: "Couldn’t save \(destination.lastPathComponent)."))
        }
    }

    /// Every page as a picture at twice its size, so text stays sharp.
    /// Returns the files written.
    static func pages(_ source: URL, as type: UTType, beside: URL) throws -> [URL] {
        let document = try open(source)
        let base = source.deletingPathExtension().lastPathComponent
        let ext = type == .jpeg ? "jpg" : type.preferredFilenameExtension ?? "png"
        let folder = document.pageCount > 1
            ? Output.folder(named: String(localized: "\(base) pages"), beside: beside) : nil
        var written: [URL] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let size = CGSize(width: bounds.width * 2, height: bounds.height * 2)
            let image = page.thumbnail(of: size, for: .mediaBox)
            guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
            let destination = folder.map { $0.appendingPathComponent("\(base) \(index + 1).\(ext)") }
                ?? Output.file(for: source, ext: ext)
            guard let output = CGImageDestinationCreateWithURL(destination as CFURL, type.identifier as CFString, 1, nil) else { continue }
            CGImageDestinationAddImage(output, cg, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
            if CGImageDestinationFinalize(output) { written.append(destination) }
        }
        return folder.map { [$0] } ?? written
    }

    /// The PDF's text; scanned pages without any are read like pictures.
    static func text(_ source: URL) throws -> String {
        let document = try open(source)
        if let text = document.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty { return text }
        var pages: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let image = page.thumbnail(of: CGSize(width: bounds.width * 2, height: bounds.height * 2), for: .mediaBox)
            guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
            pages.append(try ImageTools.recognizeText(cg))
        }
        return pages.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private static func save(_ document: PDFDocument, to destination: URL) throws {
        guard document.write(to: destination) else {
            throw ToolError.failed(String(localized: "Couldn’t save \(destination.lastPathComponent)."))
        }
    }
}
