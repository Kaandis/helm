import AppKit
import CoreImage
import ImageIO
import PDFKit
import UniformTypeIdentifiers

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
}
