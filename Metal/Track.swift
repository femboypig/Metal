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
        cache.countLimit = 80
        cache.totalCostLimit = 96 * 1_024 * 1_024
        return cache
    }()
    private static let artworkRequestLock = NSLock()
    private static var artworkRequests: Set<URL> = []

    var artwork: UIImage? {
        let nsURL = url as NSURL
        if let cached = Track.artworkCache.object(forKey: nsURL) {
            return cached
        }
        Track.prepareArtwork(for: url)
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
        guard artworkCache.object(forKey: url as NSURL) == nil else { return }
        artworkRequestLock.lock()
        let shouldStart = artworkRequests.insert(url).inserted
        artworkRequestLock.unlock()
        guard shouldStart else { return }

        Task.detached(priority: .utility) {
            let image = await loadArtwork(for: url)
            if let image {
                let estimatedCost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
                artworkCache.setObject(image, forKey: url as NSURL, cost: estimatedCost)
            }

            artworkRequestLock.lock()
            artworkRequests.remove(url)
            artworkRequestLock.unlock()

            guard image != nil else { return }
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .metalTrackArtworkDidLoad,
                    object: nil,
                    userInfo: ["url": url]
                )
            }
        }
    }

    static func preheatArtwork(for urls: [URL]) {
        urls.forEach(prepareArtwork(for:))
    }

    private static func loadArtwork(for url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        guard let metadata = try? await asset.load(.commonMetadata) else { return nil }
        for item in metadata where item.commonKey == .commonKeyArtwork {
            if let data = try? await item.load(.dataValue),
               let image = UIImage(data: data) {
                return image
            }
        }
        return nil
    }
}
