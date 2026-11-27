import SwiftUI
import WidgetKit
import UIKit
import ImageIO

struct MetalWidgetEntry: TimelineEntry {
    let date: Date
    let track: MetalWidgetTrack?
    var destination: URL { track?.deepLinkURL ?? MetalWidgetBridge.libraryURL }
    static var preview: MetalWidgetEntry {
        MetalWidgetEntry(date: Date(), track: nil)
    }
}

struct MetalTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MetalWidgetEntry { .preview }
    func getSnapshot(in context: Context, completion: @escaping (MetalWidgetEntry) -> Void) {
        completion(context.isPreview ? .preview : current())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<MetalWidgetEntry>) -> Void) {
        // The shown track is stable. Never rotate it independently of the app.
        let entry = current()
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
    }
    private func current() -> MetalWidgetEntry {
        MetalWidgetEntry(date: Date(), track: MetalWidgetBridge.load()?.tracks.first)
    }
}

struct MetalSquareWidgetView: View {
    let entry: MetalWidgetEntry

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let inset = max(12, side * 0.09)
            let artworkSide = side * 0.54
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    artwork
                        .frame(width: artworkSide, height: artworkSide)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Spacer(minLength: 0)
                    Image("MetalStar")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: side * 0.15, height: side * 0.15)
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 7)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.track?.title ?? "Your music")
                        .font(.system(size: min(18, side * 0.095), weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(entry.track.map { $0.artist.isEmpty ? "Metal" : $0.artist } ?? "Open Metal")
                        .font(.system(size: min(16, side * 0.085), weight: .regular))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(inset)
        }
        .widgetURL(entry.destination)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.track.map { "\($0.title), \($0.artist). Open in Metal." } ?? "Open your music in Metal")
        .accessibilityAddTraits(.isButton)
        .metalWidgetBackground()
    }

    @ViewBuilder private var artwork: some View {
        if let image = thumbnail(entry.track?.artworkData) {
            if #available(iOS 18.0, *) {
                Image(uiImage: image).resizable().widgetAccentedRenderingMode(.fullColor).scaledToFill()
            } else { Image(uiImage: image).resizable().scaledToFill() }
        } else {
            ZStack {
                Color(white: 0.13)
                Image("MetalStar").renderingMode(.template).resizable().scaledToFit()
                    .foregroundStyle(.white.opacity(0.35)).padding(17)
            }
        }
    }
    private func thumbnail(_ data: Data?) -> UIImage? {
        guard let data, data.count <= 512_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 300,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}

private extension View {
    @ViewBuilder func metalWidgetBackground() -> some View {
        if #available(iOS 17.0, *) { containerBackground(for: .widget) { Color.black } }
        else { background(Color.black) }
    }
}

struct MetalSquareWidget: Widget {
    let kind = MetalWidgetBridge.kind
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetalTimelineProvider()) { entry in
            MetalSquareWidgetView(entry: entry)
        }
        .configurationDisplayName("Metal")
        .description("Your latest track, one tap away.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(false)
    }
}

@main struct MetalWidgetsBundle: WidgetBundle {
    var body: some Widget { MetalSquareWidget() }
}
