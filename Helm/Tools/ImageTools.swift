import AppKit
import CoreImage
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import Vision

/// Images through ImageIO: convert, compress, shrink and clean, with the
/// photo's orientation baked in.
enum ImageTools {
    struct Options {
        var quality: Double = 0.9
        var maxPixel: CGFloat?
        var keepMetadata = true
    }

    static func write(_ source: URL, to destination: URL, type: UTType, options: Options = Options()) throws {
        guard let input = CGImageSourceCreateWithURL(source as CFURL, nil),
              CGImageSourceGetCount(input) > 0 else { throw ToolError.unreadable(source.lastPathComponent) }
        guard let output = CGImageDestinationCreateWithURL(destination as CFURL, type.identifier as CFString, 1, nil) else {
            throw ToolError.failed(String(localized: "This Mac can’t write \(type.preferredFilenameExtension?.uppercased() ?? "that format")."))
        }
        // Decoding through a thumbnail applies the EXIF orientation and any
        // size limit in one step.
        let pixelSize = options.maxPixel ?? largestSide(of: input)
        let decode: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(input, 0, decode as CFDictionary) else {
            throw ToolError.unreadable(source.lastPathComponent)
        }
        var properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: options.quality]
        if options.keepMetadata, let original = CGImageSourceCopyPropertiesAtIndex(input, 0, nil) as? [CFString: Any] {
            for key in [kCGImagePropertyExifDictionary, kCGImagePropertyGPSDictionary, kCGImagePropertyIPTCDictionary,
                        kCGImagePropertyTIFFDictionary] {
                if let value = original[key] { properties[key] = value }
            }
        }
        // The pixels are already upright.
        properties[kCGImagePropertyOrientation] = 1
        CGImageDestinationAddImage(output, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(output) else {
            throw ToolError.failed(String(localized: "Couldn’t save \(destination.lastPathComponent)."))
        }
    }

    private static func largestSide(of source: CGImageSource) -> CGFloat {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let width = properties[kCGImagePropertyPixelWidth] as? CGFloat ?? 4096
        let height = properties[kCGImagePropertyPixelHeight] as? CGFloat ?? 4096
        return max(width, height)
    }

    /// One PDF with a page per image, in the order given.
    static func makePDF(_ sources: [URL], to destination: URL) throws {
        let document = PDFDocument()
        for source in sources {
            guard let image = NSImage(contentsOf: source), let page = PDFPage(image: image) else {
                throw ToolError.unreadable(source.lastPathComponent)
            }
            document.insert(page, at: document.pageCount)
        }
        guard document.write(to: destination) else {
            throw ToolError.failed(String(localized: "Couldn’t save \(destination.lastPathComponent)."))
        }
    }

    /// The text of every QR code in the image.
    static func readQR(_ source: URL) throws -> [String] {
        guard let image = CIImage(contentsOf: source) else { throw ToolError.unreadable(source.lastPathComponent) }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        return (detector?.features(in: image) ?? []).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
    }

    /// The subject on a transparent background, as a PNG the size of the
    /// original, using the same on-device model as Preview and Photos.
    static func removeBackground(_ source: URL, to destination: URL) throws {
        let handler = VNImageRequestHandler(url: source)
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])
        guard let result = request.results?.first, !result.allInstances.isEmpty else {
            throw ToolError.failed(String(localized: "No subject found in \(source.lastPathComponent)."))
        }
        let masked = try result.generateMaskedImage(ofInstances: result.allInstances, from: handler,
                                                    croppedToInstancesExtent: false)
        let image = CIImage(cvPixelBuffer: masked)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        do {
            try CIContext().writePNGRepresentation(of: image, to: destination, format: .RGBA8, colorSpace: space)
        } catch {
            throw ToolError.failed(String(localized: "Couldn’t save \(destination.lastPathComponent)."))
        }
    }

    /// The text in a picture, read on this Mac in whatever language it's in.
    static func recognizeText(_ source: URL) throws -> String {
        try recognizeText(VNImageRequestHandler(url: source))
    }

    static func recognizeText(_ image: CGImage) throws -> String {
        try recognizeText(VNImageRequestHandler(cgImage: image))
    }

    private static func recognizeText(_ handler: VNImageRequestHandler) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        try handler.perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
