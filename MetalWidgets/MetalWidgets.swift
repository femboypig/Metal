import SwiftUI
import WidgetKit
import UIKit

private let sharedSuiteName = "group.ru.femboypig.Metal"

struct MetalWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let artist: String
    let duration: TimeInterval
    let elapsed: TimeInterval
    let isPlaying: Bool
    let artworkData: Data?

    static let placeholder = MetalWidgetEntry(
        date: Date(),
        title: "Your auditory shelf.",
        artist: "Open Metal to start listening",
        duration: 1,
        elapsed: 0,
        isPlaying: false,
        artworkData: nil
    )

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }
}

struct MetalTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MetalWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (MetalWidgetEntry) -> Void) {
        completion(context.isPreview ? .placeholder : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MetalWidgetEntry>) -> Void) {
        let entry = currentEntry()
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func currentEntry() -> MetalWidgetEntry {
        guard let defaults = UserDefaults(suiteName: sharedSuiteName),
              let title = defaults.string(forKey: "widget.track.title"),
              !title.isEmpty else {
            return .placeholder
        }

        return MetalWidgetEntry(
            date: Date(),
            title: title,
            artist: defaults.string(forKey: "widget.track.artist") ?? "",
            duration: defaults.double(forKey: "widget.track.duration"),
            elapsed: defaults.double(forKey: "widget.track.elapsed"),
            isPlaying: defaults.bool(forKey: "widget.track.isPlaying"),
            artworkData: defaults.data(forKey: "widget.track.artwork")
        )
    }
}

private struct MetalArtwork: View {
    let data: Data?
    var cornerRadius: CGFloat = 16

    private var image: Image {
        if let data, let image = UIImage(data: data) {
            return Image(uiImage: image)
        }
        return Image("PlaceholderArtwork")
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 18.0, *) {
            styled(image.resizable().widgetAccentedRenderingMode(.fullColor))
        } else {
            styled(image.resizable())
        }
    }

    private func styled<Content: View>(_ content: Content) -> some View {
        content
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct MetalWidgetBackdrop: View {
    let data: Data?

    var body: some View {
        ZStack {
            Color.black

            MetalArtwork(data: data, cornerRadius: 0)
                .scaleEffect(1.18)
                .blur(radius: 30)
                .opacity(0.38)

            LinearGradient(
                colors: [.black.opacity(0.14), .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private extension View {
    @ViewBuilder
    func metalWidgetBackground(artworkData: Data?) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) {
                MetalWidgetBackdrop(data: artworkData)
            }
        } else {
            background(MetalWidgetBackdrop(data: artworkData))
        }
    }
}

struct MetalSquareWidgetView: View {
    let entry: MetalWidgetEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MetalArtwork(data: entry.artworkData, cornerRadius: 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LinearGradient(
                colors: [.clear, .black.opacity(0.12), .black.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Text(entry.artist.isEmpty ? "Metal" : entry.artist)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
            }
            .padding(14)
        }
        .foregroundStyle(.white)
        .metalWidgetBackground(artworkData: entry.artworkData)
    }
}

struct MetalWideWidgetView: View {
    let entry: MetalWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            MetalArtwork(data: entry.artworkData)
                .frame(width: 128, height: 128)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.title)
                    .font(.headline.weight(.bold))
                    .lineLimit(2)

                Text(entry.artist.isEmpty ? "Metal" : entry.artist)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)

                Spacer(minLength: 0)

                HStack(spacing: 9) {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 29, height: 29)
                        Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.black)
                            .offset(x: entry.isPlaying ? 0 : 1)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.18))
                            Capsule()
                                .fill(.white.opacity(0.9))
                                .frame(width: proxy.size.width * entry.progress)
                        }
                    }
                    .frame(height: 3)
                }
            }
            .padding(.vertical, 9)
        }
        .padding(16)
        .foregroundStyle(.white)
        .metalWidgetBackground(artworkData: entry.artworkData)
    }
}

struct MetalSquareWidget: Widget {
    let kind = "MetalSquareWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetalTimelineProvider()) { entry in
            MetalSquareWidgetView(entry: entry)
        }
        .configurationDisplayName("Now Playing")
        .description("Your current track and its artwork.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(false)
    }
}

struct MetalWideWidget: Widget {
    let kind = "MetalWideWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetalTimelineProvider()) { entry in
            MetalWideWidgetView(entry: entry)
        }
        .configurationDisplayName("Now Playing Wide")
        .description("Artwork and current playback at a glance.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(false)
    }
}

@main
struct MetalWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MetalSquareWidget()
        MetalWideWidget()
    }
}
