import AVFoundation
import ImageIO
import UniformTypeIdentifiers

/// Video and audio through AVFoundation: re-wrap, shrink, pull the sound
/// out, mute, and turn a clip into a GIF.
enum MediaTools {
    /// Exports with a preset, reporting progress from 0 to 1.
    static func export(_ source: URL, to destination: URL, preset: String, type: AVFileType,
                       progress: @escaping @Sendable (Double) -> Void) async throws {
        let asset = AVURLAsset(url: source)
        try await export(asset, to: destination, preset: preset, type: type, progress: progress)
    }

    static func export(_ asset: AVAsset, to destination: URL, preset: String, type: AVFileType,
                       progress: @escaping @Sendable (Double) -> Void) async throws {
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw ToolError.failed(String(localized: "This file can’t be exported that way."))
        }
        let watcher = Task {
            for await state in session.states(updateInterval: 0.2) {
                if case .exporting(let p) = state { progress(p.fractionCompleted) }
            }
        }
        defer { watcher.cancel() }
        try await session.export(to: destination, as: type)
    }

    /// The video without its sound, copied without re-encoding.
    static func mute(_ source: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        let asset = AVURLAsset(url: source)
        let composition = AVMutableComposition()
        let duration = try await asset.load(.duration)
        for track in try await asset.loadTracks(withMediaType: .video) {
            let copy = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            try copy?.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: track, at: .zero)
            copy?.preferredTransform = try await track.load(.preferredTransform)
        }
        let type: AVFileType = destination.pathExtension.lowercased() == "mp4" ? .mp4 : .mov
        try await export(composition, to: destination, preset: AVAssetExportPresetPassthrough, type: type, progress: progress)
    }

    /// Uncompressed audio (WAV or AIFF) from any audio file.
    static func pcm(_ source: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) throws {
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: destination.pathExtension.lowercased() == "aiff",
        ]
        let output = try AVAudioFile(forWriting: destination, settings: settings,
                                     commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        let total = max(Double(input.length), 1)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 65_536) else {
            throw ToolError.failed(String(localized: "Couldn’t convert the audio."))
        }
        while input.framePosition < input.length {
            try input.read(into: buffer)
            try output.write(from: buffer)
            progress(Double(input.framePosition) / total)
        }
    }

    /// A looping GIF of the first half-minute, ten frames a second, at most
    /// 480 points wide.
    static func gif(_ source: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        let asset = AVURLAsset(url: source)
        let duration = min(try await asset.load(.duration).seconds, 30)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let fps = 10.0
        let count = max(Int(duration * fps), 1)
        guard let output = CGImageDestinationCreateWithURL(destination as CFURL, UTType.gif.identifier as CFString, count, nil) else {
            throw ToolError.failed(String(localized: "Couldn’t save \(destination.lastPathComponent)."))
        }
        CGImageDestinationSetProperties(output, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let frame: [CFString: Any] = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]]
        for index in 0..<count {
            let time = CMTime(seconds: Double(index) / fps, preferredTimescale: 600)
            let image = try await generator.image(at: time).image
            CGImageDestinationAddImage(output, image, frame as CFDictionary)
            progress(Double(index + 1) / Double(count))
        }
        guard CGImageDestinationFinalize(output) else {
            throw ToolError.failed(String(localized: "Couldn’t save \(destination.lastPathComponent)."))
        }
    }
}
