import AppKit
import AVFoundation
import UniformTypeIdentifiers

/// Runs a tool on the dropped files, off the main thread, and says what
/// came of it.
enum ToolRunner {
    struct Outcome: Sendable {
        var outputs: [URL] = []
        /// A short line for the toast, when there's something to say besides
        /// the files (the text of a QR code, "Path copied").
        var message: String?
    }

    static func run(_ tool: Tool, on files: [URL], progress: @escaping @Sendable (Double) -> Void) async throws -> Outcome {
        switch tool {
        // Images
        case .toJPG: return try images(files, ext: "jpg", type: .jpeg, progress: progress)
        case .toPNG: return try images(files, ext: "png", type: .png, progress: progress)
        case .toHEIC: return try images(files, ext: "heic", type: .heic, progress: progress)
        case .toTIFF: return try images(files, ext: "tiff", type: .tiff, progress: progress)
        case .toPDF:
            return try each(files, progress: progress) { source in
                let destination = Output.file(for: source, ext: "pdf")
                try ImageTools.makePDF([source], to: destination)
                return destination
            }
        case .compressImage:
            return try each(files, progress: progress) { source in
                let type = UTType(filenameExtension: source.pathExtension) ?? .jpeg
                // PNG has no quality setting, so it shrinks to JPEG.
                let (outType, ext) = type == .png ? (UTType.jpeg, "jpg") : (type, source.pathExtension)
                let destination = Output.file(for: source, ext: ext, suffix: String(localized: "compressed"))
                try ImageTools.write(source, to: destination, type: outType, options: .init(quality: 0.6))
                return destination
            }
        case .halveImage:
            return try each(files, progress: progress) { source in
                let type = UTType(filenameExtension: source.pathExtension) ?? .jpeg
                let destination = Output.file(for: source, ext: source.pathExtension, suffix: String(localized: "half"))
                let size = NSImageRep(contentsOf: source).map { CGFloat(max($0.pixelsWide, $0.pixelsHigh)) / 2 } ?? 2048
                try ImageTools.write(source, to: destination, type: type, options: .init(maxPixel: size))
                return destination
            }
        case .stripMetadata:
            return try each(files, progress: progress) { source in
                let type = UTType(filenameExtension: source.pathExtension) ?? .jpeg
                let destination = Output.file(for: source, ext: source.pathExtension, suffix: String(localized: "clean"))
                try ImageTools.write(source, to: destination, type: type, options: .init(quality: 0.95, keepMetadata: false))
                return destination
            }
        case .makePDF:
            guard let first = files.first else { return Outcome() }
            let name = files.count == 1 ? first.deletingPathExtension().lastPathComponent : String(localized: "Images")
            let destination = Output.named(name, ext: "pdf", beside: first)
            try ImageTools.makePDF(files.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending },
                                   to: destination)
            return Outcome(outputs: [destination])
        case .readQR:
            let texts = try files.flatMap(ImageTools.readQR)
            guard !texts.isEmpty else { return Outcome(message: String(localized: "No QR code found")) }
            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(texts.joined(separator: "\n"), forType: .string)
            }
            return Outcome(message: texts.joined(separator: "\n"))

        case .removeBackground:
            return try each(files, progress: progress) { source in
                let destination = Output.file(for: source, ext: "png", suffix: String(localized: "cutout"))
                try ImageTools.removeBackground(source, to: destination)
                return destination
            }
        case .extractText:
            let text = try files.map { FileKind(url: $0) == .pdf ? try PDFTools.text($0) : try ImageTools.recognizeText($0) }
                .filter { !$0.isEmpty }.joined(separator: "\n\n")
            guard !text.isEmpty else { return Outcome(message: String(localized: "No text found")) }
            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            let lines = text.split(whereSeparator: \.isNewline).count
            return Outcome(message: String(localized: "Text copied, \(lines) lines"))

        // PDF
        case .pagesToPNG, .pagesToJPG:
            let type: UTType = tool == .pagesToPNG ? .png : .jpeg
            var outcome = Outcome()
            for (index, source) in files.enumerated() {
                outcome.outputs += try PDFTools.pages(source, as: type, beside: source)
                progress(Double(index + 1) / Double(files.count))
            }
            return outcome
        case .mergePDF:
            guard let first = files.first else { return Outcome() }
            let destination = Output.named(String(localized: "Merged"), ext: "pdf", beside: first)
            try PDFTools.merge(files.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending },
                               to: destination)
            return Outcome(outputs: [destination])
        case .splitPDF:
            return try each(files, progress: progress) { source in
                let folder = Output.folder(named: source.deletingPathExtension().lastPathComponent, beside: source)
                try PDFTools.split(source, into: folder)
                return folder
            }
        case .compressPDF:
            return try each(files, progress: progress) { source in
                let destination = Output.file(for: source, ext: "pdf", suffix: String(localized: "compressed"))
                try PDFTools.compress(source, to: destination)
                return destination
            }

        // Video and audio
        case .toMP4: return try await media(files, ext: "mp4", preset: AVAssetExportPresetHighestQuality, type: .mp4, progress: progress)
        case .toMOV: return try await media(files, ext: "mov", preset: AVAssetExportPresetHighestQuality, type: .mov, progress: progress)
        case .toM4A:
            for source in files where try await AVURLAsset(url: source).loadTracks(withMediaType: .audio).isEmpty {
                throw ToolError.failed(String(localized: "\(source.lastPathComponent) has no sound."))
            }
            return try await media(files, ext: "m4a", preset: AVAssetExportPresetAppleM4A, type: .m4a, progress: progress)
        case .compressVideo:
            return try await media(files, ext: "mp4", suffix: String(localized: "compressed"),
                                   preset: AVAssetExportPreset1280x720, type: .mp4, progress: progress)
        case .removeAudio:
            var outcome = Outcome()
            for source in files {
                let destination = Output.file(for: source, ext: source.pathExtension, suffix: String(localized: "muted"))
                try await MediaTools.mute(source, to: destination, progress: progress)
                outcome.outputs.append(destination)
            }
            return outcome
        case .toGIF:
            var outcome = Outcome()
            for source in files {
                let destination = Output.file(for: source, ext: "gif")
                try await MediaTools.gif(source, to: destination, progress: progress)
                outcome.outputs.append(destination)
            }
            return outcome
        case .toWAV, .toAIFF:
            let ext = tool == .toWAV ? "wav" : "aiff"
            return try each(files, progress: { _ in }) { source in
                let destination = Output.file(for: source, ext: ext)
                try MediaTools.pcm(source, to: destination, progress: progress)
                return destination
            }

        // Archives
        case .unzip:
            // Like Archive Utility: one item inside comes out on its own,
            // several come out together in a folder named after the archive.
            return try each(files, progress: progress) { source in
                let fm = FileManager.default
                let scratch = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                         appropriateFor: source, create: true)
                defer { try? fm.removeItem(at: scratch) }
                try shell("/usr/bin/ditto", ["-x", "-k", source.path, scratch.path])
                let items = try fm.contentsOfDirectory(at: scratch, includingPropertiesForKeys: nil)
                    .filter { $0.lastPathComponent != "__MACOSX" && $0.lastPathComponent != ".DS_Store" }
                if items.count == 1 {
                    let destination = Output.unique(Output.folder(for: source)
                        .appendingPathComponent(items[0].lastPathComponent))
                    try fm.moveItem(at: items[0], to: destination)
                    return destination
                }
                let folder = Output.folder(named: source.deletingPathExtension().lastPathComponent, beside: source)
                for item in items {
                    try fm.moveItem(at: item, to: folder.appendingPathComponent(item.lastPathComponent))
                }
                return folder
            }
        case .zip:
            guard let first = files.first else { return Outcome() }
            if files.count == 1 {
                let destination = Output.file(for: first, ext: "zip")
                // A folder goes in under its own name; a file goes in bare.
                let isFolder = (try? first.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                try shell("/usr/bin/ditto", ["-c", "-k", "--norsrc"] + (isFolder ? ["--keepParent"] : [])
                          + [first.path, destination.path])
                return Outcome(outputs: [destination])
            }
            let destination = Output.named(String(localized: "Archive"), ext: "zip", beside: first)
            try shell("/usr/bin/zip", ["-r", "-q", "-X", destination.path] + files.map(\.lastPathComponent),
                      in: first.deletingLastPathComponent())
            return Outcome(outputs: [destination])

        // Actions
        case .cut, .moveTo, .copyTo:
            // These ask where first (or go to the shelf); see AppDelegate.
            return Outcome()
        case .copyFiles:
            // As ⌘C in Finder: ⌘V in a folder puts copies there.
            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects(files as [NSURL])
            }
            return Outcome(message: String(localized: "Copied. Press ⌘V in a folder to paste."))
        case .duplicate:
            return try each(files, progress: progress) { source in
                let copy = Output.unique(source.deletingLastPathComponent()
                    .appendingPathComponent(Output.duplicateName(of: source)))
                do { try FileManager.default.copyItem(at: source, to: copy) } catch {
                    throw ToolError.failed(String(localized: "Couldn’t save \(copy.lastPathComponent)."))
                }
                return copy
            }
        case .copyImage:
            await MainActor.run {
                let images = files.compactMap(NSImage.init(contentsOf:))
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects(images)
            }
            return Outcome(message: files.count == 1 ? String(localized: "Image copied") : String(localized: "\(files.count) images copied"))
        case .mail:
            await MainActor.run { NSSharingService(named: .composeEmail)?.perform(withItems: files) }
            return Outcome()
        case .airDrop:
            await MainActor.run { NSSharingService(named: .sendViaAirDrop)?.perform(withItems: files) }
            return Outcome()
        case .copyPath:
            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(files.map(\.path).joined(separator: "\n"), forType: .string)
            }
            return Outcome(message: files.count == 1 ? String(localized: "Path copied") : String(localized: "\(files.count) paths copied"))
        case .openTerminal:
            let folders = Set(files.map { FileKind(url: $0) == .folder ? $0 : $0.deletingLastPathComponent() })
            let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
            await MainActor.run {
                NSWorkspace.shared.open(Array(folders), withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
            }
            return Outcome()
        }
    }

    /// Moves or copies files into `folder`, never over anything already there.
    static func transfer(_ files: [URL], to folder: URL, move: Bool) throws -> Outcome {
        var outcome = Outcome()
        let fm = FileManager.default
        for source in files {
            let destination = Output.unique(folder.appendingPathComponent(source.lastPathComponent))
            // Already where it was asked to go: nothing to do.
            if move, source.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL { continue }
            do {
                if move { try fm.moveItem(at: source, to: destination) } else { try fm.copyItem(at: source, to: destination) }
            } catch {
                throw ToolError.failed(String(localized: "Couldn’t put \(source.lastPathComponent) in \(folder.lastPathComponent)."))
            }
            outcome.outputs.append(destination)
        }
        let place = folder.lastPathComponent
        outcome.message = move ? String(localized: "Moved to \(place)") : String(localized: "Copied to \(place)")
        return outcome
    }

    // MARK: Helpers

    private static func images(_ files: [URL], ext: String, type: UTType, progress: @escaping @Sendable (Double) -> Void) throws -> Outcome {
        try each(files, progress: progress) { source in
            let destination = Output.file(for: source, ext: ext)
            try ImageTools.write(source, to: destination, type: type)
            return destination
        }
    }

    private static func media(_ files: [URL], ext: String, suffix: String? = nil, preset: String, type: AVFileType,
                              progress: @escaping @Sendable (Double) -> Void) async throws -> Outcome {
        var outcome = Outcome()
        for (index, source) in files.enumerated() {
            let destination = Output.file(for: source, ext: ext, suffix: suffix)
            let share = 1 / Double(files.count)
            try await MediaTools.export(source, to: destination, preset: preset, type: type) { fraction in
                progress((Double(index) + fraction) * share)
            }
            outcome.outputs.append(destination)
        }
        return outcome
    }

    /// Runs `work` on each file in turn, reporting progress per file.
    private static func each(_ files: [URL], progress: @escaping @Sendable (Double) -> Void,
                             _ work: (URL) throws -> URL) throws -> Outcome {
        var outcome = Outcome()
        for (index, source) in files.enumerated() {
            outcome.outputs.append(try work(source))
            progress(Double(index + 1) / Double(files.count))
        }
        return outcome
    }

    private static func shell(_ tool: String, _ arguments: [String], in folder: URL? = nil) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.currentDirectoryURL = folder
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ToolError.failed(String(localized: "The archive couldn’t be made.")) }
    }
}
