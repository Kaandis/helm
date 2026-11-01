import Foundation
import UniformTypeIdentifiers

/// Everything Helm can do with files, all with what macOS already has: no
/// downloads, no external tools.
enum Tool: String, CaseIterable, Sendable {
    // Convert
    case toJPG, toPNG, toHEIC, toTIFF, toPDF
    case pagesToPNG, pagesToJPG
    case toMP4, toMOV, toGIF, toM4A, toWAV, toAIFF
    // Tools
    case compressImage, halveImage, stripMetadata, makePDF, readQR
    case mergePDF, splitPDF, compressPDF
    case compressVideo, removeAudio
    case unzip
    // Actions
    case airDrop, copyPath, openTerminal, zip

    var title: String {
        switch self {
        case .toJPG, .pagesToJPG: "JPG"
        case .toPNG, .pagesToPNG: "PNG"
        case .toHEIC: "HEIC"
        case .toTIFF: "TIFF"
        case .toPDF: "PDF"
        case .toMP4: "MP4"
        case .toMOV: "MOV"
        case .toGIF: "GIF"
        case .toM4A: "M4A"
        case .toWAV: "WAV"
        case .toAIFF: "AIFF"
        case .compressImage, .compressPDF, .compressVideo: String(localized: "Compress")
        case .halveImage: String(localized: "Half Size")
        case .stripMetadata: String(localized: "Strip Metadata")
        case .makePDF: String(localized: "Make PDF")
        case .readQR: String(localized: "Read QR")
        case .mergePDF: String(localized: "Merge")
        case .splitPDF: String(localized: "Split Pages")
        case .removeAudio: String(localized: "Mute")
        case .unzip: String(localized: "Extract")
        case .airDrop: "AirDrop"
        case .copyPath: String(localized: "Copy Path")
        case .openTerminal: String(localized: "Terminal")
        case .zip: String(localized: "Zip")
        }
    }

    var symbol: String {
        switch self {
        case .toJPG, .toPNG, .toHEIC, .toTIFF, .pagesToPNG, .pagesToJPG: "photo"
        case .toPDF, .makePDF: "doc.richtext"
        case .toMP4, .toMOV: "film"
        case .toGIF: "square.stack.3d.forward.dottedline"
        case .toM4A, .toWAV, .toAIFF: "waveform"
        case .compressImage, .compressPDF, .compressVideo: "arrow.down.right.and.arrow.up.left"
        case .halveImage: "rectangle.compress.vertical"
        case .stripMetadata: "location.slash"
        case .readQR: "qrcode.viewfinder"
        case .mergePDF: "doc.on.doc"
        case .splitPDF: "scissors"
        case .removeAudio: "speaker.slash"
        case .unzip: "archivebox"
        case .airDrop: "dot.radiowaves.left.and.right"
        case .copyPath: "link"
        case .openTerminal: "terminal"
        case .zip: "doc.zipper"
        }
    }

    /// File extensions a conversion would produce; files already in that
    /// format aren't offered it.
    private var produces: Set<String> {
        switch self {
        case .toJPG: ["jpg", "jpeg"]
        case .toPNG: ["png"]
        case .toHEIC: ["heic", "heif"]
        case .toTIFF: ["tif", "tiff"]
        case .toMP4: ["mp4"]
        case .toMOV: ["mov"]
        case .toM4A: ["m4a"]
        case .toWAV: ["wav"]
        case .toAIFF: ["aif", "aiff"]
        default: []
        }
    }

    /// The tools a wheel offers for these files, in wheel order. Mixed kinds
    /// of files get only what applies to all of them.
    static func tools(for kind: WheelKind, files: [URL]) -> [Tool] {
        let extensions = Set(files.map { $0.pathExtension.lowercased() })
        return candidates(for: kind, files: files).filter { !extensions.isSubset(of: $0.produces) }
    }

    private static func candidates(for kind: WheelKind, files: [URL]) -> [Tool] {
        let kinds = Set(files.map(FileKind.init(url:)))
        let one = kinds.count == 1 ? kinds.first : nil
        let many = files.count > 1
        switch kind {
        case .convert:
            switch one {
            case .image: return [.toJPG, .toPNG, .toHEIC, .toPDF, .toTIFF]
            case .pdf: return [.pagesToPNG, .pagesToJPG]
            case .video: return [.toMP4, .toMOV, .toGIF, .toM4A]
            case .audio: return [.toM4A, .toWAV, .toAIFF]
            default: return []
            }
        case .tools:
            switch one {
            case .image: return [.compressImage, .halveImage, .stripMetadata, .makePDF, .readQR]
            case .pdf: return many ? [.mergePDF, .compressPDF, .splitPDF] : [.compressPDF, .splitPDF]
            case .video: return [.compressVideo, .removeAudio]
            case .archive: return [.unzip]
            default: return []
            }
        case .actions:
            return [.airDrop, .copyPath, .openTerminal, .zip]
        }
    }
}

/// What a file is, as far as the wheels care.
enum FileKind: Hashable {
    case image, pdf, video, audio, archive, folder, other

    init(url: URL) {
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
            ?? UTType(filenameExtension: url.pathExtension) ?? .data
        if type.conforms(to: .directory) && !type.conforms(to: .package) { self = .folder }
        else if type.conforms(to: .pdf) { self = .pdf }
        else if type.conforms(to: .image) { self = .image }
        else if type.conforms(to: .movie) || type.conforms(to: .video) { self = .video }
        else if type.conforms(to: .audio) { self = .audio }
        else if type.conforms(to: .zip) { self = .archive }
        else { self = .other }
    }
}
