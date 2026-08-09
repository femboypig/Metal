//
//  Track.swift
//  Krank
//

import UIKit
import AVFoundation

struct Track {
    let url: URL
    var title: String
    var artist: String
    var duration: TimeInterval

    private static let artworkCache = NSCache<NSURL, UIImage>()

    var artwork: UIImage? {
        let nsURL = url as NSURL
        if let cached = Track.artworkCache.object(forKey: nsURL) {
            return cached
        }
        let asset = AVAsset(url: url)
        let metadata = asset.commonMetadata
        for item in metadata {
            guard let key = item.commonKey else { continue }
            if key == .commonKeyArtwork, let data = item.dataValue, let image = UIImage(data: data) {
                Track.artworkCache.setObject(image, forKey: nsURL)
                return image
            }
        }
        return nil
    }

    @available(iOS, deprecated: 16.0)
    init(url: URL) {
        self.url = url
        self.title = url.deletingPathExtension().lastPathComponent
        self.artist = "Unknown Artist"
        self.duration = 0

        let asset = AVAsset(url: url)

        // Duration extraction
        self.duration = CMTimeGetSeconds(asset.duration)
        if self.duration.isNaN || self.duration.isInfinite {
            self.duration = 0
        }

        // Metadata extraction
        let metadata = asset.commonMetadata
        for item in metadata {
            guard let key = item.commonKey else { continue }
            switch key {
            case .commonKeyTitle:
                if let titleVal = item.stringValue {
                    self.title = titleVal
                }
            case .commonKeyArtist:
                if let artistVal = item.stringValue {
                    self.artist = artistVal
                }
            default:
                break
            }
        }
    }
}
