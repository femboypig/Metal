//
//  Track.swift
//  Metal
//

import UIKit
import AVFoundation

extension Notification.Name {
    static let metalTrackArtworkDidLoad = Notification.Name("MetalTrackArtworkDidLoad")
}

struct TrackMetadataSnapshot: Codable, Equatable {
    let fileSize: Int
    let modificationDate: TimeInterval
    let title: String
    let artist: String
    let duration: TimeInterval

    func matches(_ signature: (fileSize: Int, modificationDate: TimeInterval)) -> Bool {
        fileSize == signature.fileSize && modificationDate == signature.modificationDate
    }
}

struct Track {
    let url: URL
    var title: String
    var artist: String
    var duration: TimeInterval

    private static let artworkCache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 500
        cache.totalCostLimit = 256 * 1024 * 1024
        return cache
    }()

    var artwork: UIImage? {
        let nsURL = url as NSURL
        if let cached = Track.artworkCache.object(forKey: nsURL) {
            return cached
        }
        if let image = Track.extractArtwork(from: url) {
            let cost = Int(image.size.width * image.size.height * 4)
            Track.artworkCache.setObject(image, forKey: nsURL, cost: cost)
            return image
        }
        return nil
    }

    init(url: URL, metadata: TrackMetadataSnapshot? = nil) {
        self.url = url
        self.title = metadata?.title ?? url.deletingPathExtension().lastPathComponent
        self.artist = metadata?.artist ?? "Unknown Artist"
        self.duration = metadata?.duration ?? 0
    }

    static func fileSignature(for url: URL) -> (fileSize: Int, modificationDate: TimeInterval) {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return (
            values?.fileSize ?? -1,
            values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        )
    }

    static func loadMetadata(for url: URL) async -> TrackMetadataSnapshot {
        let signature = fileSignature(for: url)
        let asset = AVURLAsset(url: url)
        let loadedDuration = try? await asset.load(.duration)
        let metadata = (try? await asset.load(.commonMetadata)) ?? []
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"

        for item in metadata {
            switch item.commonKey {
            case .commonKeyTitle:
                if let value = try? await item.load(.stringValue), !value.isEmpty {
                    title = value
                }
            case .commonKeyArtist:
                if let value = try? await item.load(.stringValue), !value.isEmpty {
                    artist = value
                }
            default:
                break
            }
        }

        var duration = loadedDuration.map { CMTimeGetSeconds($0) } ?? 0
        if duration.isNaN || duration.isInfinite || duration < 0 {
            duration = 0
        }
        return TrackMetadataSnapshot(
            fileSize: signature.fileSize,
            modificationDate: signature.modificationDate,
            title: title,
            artist: artist,
            duration: duration
        )
    }

    static func prepareArtwork(for url: URL) {
        let nsURL = url as NSURL
        guard artworkCache.object(forKey: nsURL) == nil else { return }
        DispatchQueue.global(qos: .utility).async {
            if let image = extractArtwork(from: url) {
                let cost = Int(image.size.width * image.size.height * 4)
                artworkCache.setObject(image, forKey: nsURL, cost: cost)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .metalTrackArtworkDidLoad,
                        object: nil,
                        userInfo: ["url": url]
                    )
                }
            }
        }
    }

    static func preheatArtwork(for urls: [URL]) {
        DispatchQueue.global(qos: .utility).async {
            for url in urls {
                let nsURL = url as NSURL
                if artworkCache.object(forKey: nsURL) == nil {
                    if let image = extractArtwork(from: url) {
                        let cost = Int(image.size.width * image.size.height * 4)
                        artworkCache.setObject(image, forKey: nsURL, cost: cost)
                    }
                }
            }
        }
    }

    static func extractArtwork(from url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)

        // 1. Common metadata (ID3, iTunes, Vorbis, etc.)
        for item in asset.commonMetadata where item.commonKey == .commonKeyArtwork {
            if let img = imageFromMetadataItem(item) {
                return img
            }
        }

        // 2. All metadata (APIC, covr, attached picture)
        for item in asset.metadata {
            if isArtworkMetadataItem(item), let img = imageFromMetadataItem(item) {
                return img
            }
        }

        // 3. Format-specific metadata
        for format in asset.availableMetadataFormats {
            for item in asset.metadata(forFormat: format) {
                if isArtworkMetadataItem(item), let img = imageFromMetadataItem(item) {
                    return img
                }
            }
        }

        return nil
    }

    private static func isArtworkMetadataItem(_ item: AVMetadataItem) -> Bool {
        if item.commonKey == .commonKeyArtwork { return true }
        if let key = item.key as? String, key.caseInsensitiveCompare("APIC") == .orderedSame || key.caseInsensitiveCompare("covr") == .orderedSame { return true }
        if let id = item.identifier {
            if id == .commonIdentifierArtwork || id == .id3MetadataAttachedPicture || id == .iTunesMetadataCoverArt {
                return true
            }
            let raw = id.rawValue.lowercased()
            if raw.contains("artwork") || raw.contains("picture") || raw.contains("covr") {
                return true
            }
        }
        return false
    }

    private static func imageFromMetadataItem(_ item: AVMetadataItem) -> UIImage? {
        if let data = item.dataValue, let img = UIImage(data: data) {
            return img
        }
        if let data = item.value as? Data, let img = UIImage(data: data) {
            return img
        }
        if let dict = item.value as? [String: Any], let data = dict["data"] as? Data, let img = UIImage(data: data) {
            return img
        }
        if let dict = item.extraAttributes as? [String: Any], let data = dict["data"] as? Data, let img = UIImage(data: data) {
            return img
        }
        return nil
    }
}
