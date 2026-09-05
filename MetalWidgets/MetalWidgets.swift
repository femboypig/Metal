import SwiftUI
import WidgetKit
import UIKit

private let originalSharedSuiteName = "group.ru.femboypig.Metal"
private let recommendationsKey = "widget.recommendations.v1"
private let recommendationsFilename = "widget-recommendations.json"

private var sharedSuiteName: String {
    let resignedGroups = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String]
    return resignedGroups?.first(where: { $0.contains(originalSharedSuiteName) })
        ?? resignedGroups?.first
        ?? originalSharedSuiteName
}

struct MetalWidgetRecommendation: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let artworkData: Data?

    var deepLinkURL: URL {
        var components = URLComponents()
        components.scheme = "metal"
        components.host = "play"
        components.queryItems = [URLQueryItem(name: "track", value: id)]
        return components.url ?? URL(string: "metal://play")!
    }
}

struct MetalWidgetEntry: TimelineEntry {
    let date: Date
    let recommendations: [MetalWidgetRecommendation]

    static func placeholder(at date: Date = Date()) -> MetalWidgetEntry {
        MetalWidgetEntry(
            date: date,
            recommendations: [
                MetalWidgetRecommendation(
                    id: "lovely-1",
                    title: "Lovely Mix",
                    artist: "Made from the music you love",
                    artworkData: nil
                ),
                MetalWidgetRecommendation(
                    id: "lovely-2",
                    title: "Your next favorite",
                    artist: "Chosen from your listening taste",
                    artworkData: nil
                ),
                MetalWidgetRecommendation(
                    id: "lovely-3",
                    title: "Picked for you",
                    artist: "Metal",
                    artworkData: nil
                )
            ]
        )
    }

    var primary: MetalWidgetRecommendation {
        recommendations.first ?? Self.placeholder(at: date).recommendations[0]
    }
}

struct MetalTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MetalWidgetEntry {
        .placeholder()
    }

    func getSnapshot(in context: Context, completion: @escaping (MetalWidgetEntry) -> Void) {
        completion(context.isPreview ? .placeholder() : entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MetalWidgetEntry>) -> Void) {
        let start = Date()
        let entries = (0..<8).map { offset in
            entry(at: start.addingTimeInterval(TimeInterval(offset) * 30 * 60))
        }
        completion(Timeline(entries: entries, policy: .after(start.addingTimeInterval(4 * 60 * 60))))
    }

    private func entry(at date: Date) -> MetalWidgetEntry {
        guard let encoded = recommendationsData(),
              let stored = try? JSONDecoder().decode([MetalWidgetRecommendation].self, from: encoded),
              !stored.isEmpty else {
            return .placeholder(at: date)
        }

        let offset = Int(date.timeIntervalSince1970 / (30 * 60)) % stored.count
        let rotated = Array(stored[offset...]) + Array(stored[..<offset])
        return MetalWidgetEntry(date: date, recommendations: rotated)
    }

    private func recommendationsData() -> Data? {
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: sharedSuiteName
        ) {
            let fileURL = containerURL.appendingPathComponent(recommendationsFilename)
            if let data = try? Data(contentsOf: fileURL) {
                return data
            }
        }

        return UserDefaults(suiteName: sharedSuiteName)?.data(forKey: recommendationsKey)
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
    let artworkData: Data?

    var body: some View {
        ZStack {
            Color.black
            MetalArtwork(data: artworkData, cornerRadius: 0)
                .scaleEffect(1.2)
                .blur(radius: 32)
                .opacity(0.34)
            Color.black.opacity(0.48)
        }
    }
}

private extension View {
    @ViewBuilder
    func metalWidgetBackground(artworkData: Data?) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) {
                MetalWidgetBackdrop(artworkData: artworkData)
            }
        } else {
            background(MetalWidgetBackdrop(artworkData: artworkData))
        }
    }
}

private struct MetalRecommendationHero: View {
    let recommendation: MetalWidgetRecommendation
    var cornerRadius: CGFloat = 0
    @Environment(\.widgetFamily) private var family

    private var titleFont: Font {
        family == .systemSmall
            ? .system(size: 15, weight: .bold)
            : .system(size: 12, weight: .bold)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MetalArtwork(data: recommendation.artworkData, cornerRadius: cornerRadius)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LinearGradient(
                colors: [.clear, .black.opacity(0.08), .black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.title)
                    .font(titleFont)
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)
                    .allowsTightening(true)
                Text(recommendation.artist.isEmpty ? "Metal" : recommendation.artist)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(13)
        }
        .foregroundStyle(.white)
    }
}

private struct MetalRecommendationRow: View {
    let recommendation: MetalWidgetRecommendation

    var body: some View {
        HStack(spacing: 9) {
            MetalArtwork(data: recommendation.artworkData, cornerRadius: 9)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(recommendation.title)
                    .font(.caption.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                Text(recommendation.artist.isEmpty ? "Metal" : recommendation.artist)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

struct MetalSquareWidgetView: View {
    let entry: MetalWidgetEntry

    var body: some View {
        MetalRecommendationHero(recommendation: entry.primary)
            .widgetURL(entry.primary.deepLinkURL)
            .metalWidgetBackground(artworkData: entry.primary.artworkData)
    }
}

struct MetalWideWidgetView: View {
    let entry: MetalWidgetEntry

    var body: some View {
        HStack(spacing: 14) {
            Link(destination: entry.primary.deepLinkURL) {
                MetalArtwork(data: entry.primary.artworkData, cornerRadius: 14)
                    .frame(width: 88, height: 112)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 6) {
                Text("DAILY MIX")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.65))
                Link(destination: entry.primary.deepLinkURL) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.primary.title)
                            .font(.system(size: 19, weight: .bold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.65)
                            .allowsTightening(true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(entry.primary.artist.isEmpty ? "Picked for you" : entry.primary.artist)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                Link(destination: URL(string: "metal://daily-mix?autoplay=1")!) {
                    Label("Play your mix", systemImage: "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .padding(16)
        .foregroundStyle(.white)
        .metalWidgetBackground(artworkData: entry.primary.artworkData)
    }
}

struct MetalSquareWidget: Widget {
    let kind = "MetalSquareWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetalTimelineProvider()) { entry in
            MetalSquareWidgetView(entry: entry)
        }
        .configurationDisplayName("Lovely Pick")
        .description("A track picked from the music you love.")
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
        .configurationDisplayName("Daily Mix")
        .description("Your personal soundtrack. Tap to start your mix.")
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
