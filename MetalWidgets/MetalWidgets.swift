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

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
            } else {
                Image("PlaceholderArtwork")
                    .resizable()
            }
        }
        .scaledToFill()
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.13), lineWidth: 0.8)
        }
    }
}

private struct MetalWidgetBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.09), Color(red: 0.17, green: 0.12, blue: 0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image("PlaceholderArtwork")
                .resizable()
                .scaledToFill()
                .scaleEffect(1.18)
                .blur(radius: 24)
                .opacity(0.24)

            RadialGradient(
                colors: [Color(red: 0.85, green: 0.36, blue: 0.22).opacity(0.18), .clear],
                center: .bottomTrailing,
                startRadius: 4,
                endRadius: 180
            )
        }
    }
}

private extension View {
    @ViewBuilder
    func metalWidgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) {
                MetalWidgetBackdrop()
            }
        } else {
            background(MetalWidgetBackdrop())
        }
    }
}

struct MetalSquareWidgetView: View {
    let entry: MetalWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: entry.isPlaying ? "waveform" : "waveform.path")
                    .foregroundStyle(Color(red: 0.93, green: 0.47, blue: 0.31))
                Text("METAL")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.2)
                Spacer(minLength: 0)
            }

            MetalArtwork(data: entry.artworkData)
                .frame(width: 72, height: 72)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .lineLimit(1)
                Text(entry.artist.isEmpty ? (entry.isPlaying ? "Now playing" : "Paused") : entry.artist)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .metalWidgetBackground()
    }
}

struct MetalWideWidgetView: View {
    let entry: MetalWidgetEntry

    var body: some View {
        HStack(spacing: 15) {
            MetalArtwork(data: entry.artworkData)
                .frame(width: 116, height: 116)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.isPlaying ? Color(red: 0.93, green: 0.47, blue: 0.31) : .white.opacity(0.35))
                        .frame(width: 6, height: 6)
                    Text(entry.isPlaying ? "NOW PLAYING" : "METAL LIBRARY")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1.1)
                }

                Text(entry.title)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text(entry.artist.isEmpty ? "Your auditory shelf." : entry.artist)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.14))
                        Capsule()
                            .fill(Color(red: 0.93, green: 0.47, blue: 0.31))
                            .frame(width: proxy.size.width * entry.progress)
                    }
                }
                .frame(height: 3)
            }
            .padding(.vertical, 3)
        }
        .foregroundStyle(.white)
        .metalWidgetBackground()
    }
}

struct MetalSquareWidget: Widget {
    let kind = "MetalSquareWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetalTimelineProvider()) { entry in
            MetalSquareWidgetView(entry: entry)
        }
        .configurationDisplayName("Metal Cover")
        .description("Your current track in a compact square.")
        .supportedFamilies([.systemSmall])
    }
}

struct MetalWideWidget: Widget {
    let kind = "MetalWideWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetalTimelineProvider()) { entry in
            MetalWideWidgetView(entry: entry)
        }
        .configurationDisplayName("Metal Shelf")
        .description("Current track, artist, and listening progress.")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct MetalWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MetalSquareWidget()
        MetalWideWidget()
    }
}
