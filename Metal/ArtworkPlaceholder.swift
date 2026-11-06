import UIKit

/// Shared by the app and widgets so an unknown album has a stable, restrained
/// color identity instead of changing hue on every launch.
struct ArtworkPlaceholderPalette {
    let top: UIColor
    let bottom: UIColor
    let accent: UIColor

    init(seed: String?, isDark: Bool) {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in (seed ?? "Metal").utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        hash ^= hash >> 32
        let hue = CGFloat(hash % 360) / 360
        top = UIColor(hue: hue, saturation: isDark ? 0.18 : 0.10,
                      brightness: isDark ? 0.24 : 0.95, alpha: 1)
        bottom = UIColor(hue: hue, saturation: isDark ? 0.14 : 0.12,
                         brightness: isDark ? 0.11 : 0.87, alpha: 1)
        accent = UIColor(hue: hue, saturation: 0.50, brightness: isDark ? 0.72 : 0.65, alpha: 1)
    }
}

/// Real backdrop blur in the app. The material stays transparent to its parent;
/// the small color wash keeps empty covers readable over both player palettes.
final class GlassArtworkImageView: UIImageView {
    private let material = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let wash = CAGradientLayer()
    private let star = UIImageView(image: UIImage(named: "MetalStar")?.withRenderingMode(.alwaysTemplate))
    private var seed: String?
    private var ready = false
    private var lastStyleKey: String?
    private var accessibilityObserver: NSObjectProtocol?

    override var image: UIImage? {
        didSet { if ready { updateMaterial() } }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        if let accessibilityObserver { NotificationCenter.default.removeObserver(accessibilityObserver) }
    }

    private func setup() {
        backgroundColor = .clear
        material.isUserInteractionEnabled = false
        material.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        material.contentView.layer.addSublayer(wash)
        addSubview(material)
        star.contentMode = .scaleAspectFit
        star.isUserInteractionEnabled = false
        star.isAccessibilityElement = false
        addSubview(star)
        ready = true
        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil, queue: .main) { [weak self] _ in self?.updateMaterial() }
        updateMaterial()
    }

    func setArtwork(_ artwork: UIImage?, seed: String?) {
        self.seed = seed
        image = artwork
    }

    private func updateMaterial() {
        material.isHidden = image != nil
        star.isHidden = image != nil
        guard image == nil else { return }
        let dark = traitCollection.userInterfaceStyle == .dark
        let opaque = UIAccessibility.isReduceTransparencyEnabled
        let key = "\(seed ?? "Metal")|\(dark)|\(opaque)"
        guard lastStyleKey != key else { return }
        lastStyleKey = key
        let colors = ArtworkPlaceholderPalette(seed: seed, isDark: dark)
        material.effect = opaque ? nil : UIBlurEffect(style: .systemUltraThinMaterial)
        wash.colors = [colors.top.withAlphaComponent(opaque ? 1 : 0.26).cgColor,
                       colors.bottom.withAlphaComponent(opaque ? 1 : 0.12).cgColor]
        wash.startPoint = CGPoint(x: 0, y: 0)
        wash.endPoint = CGPoint(x: 1, y: 1)
        star.tintColor = dark ? UIColor.white.withAlphaComponent(0.64) : UIColor.black.withAlphaComponent(0.48)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        material.frame = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        wash.frame = material.bounds
        CATransaction.commit()
        star.frame = bounds.insetBy(dx: bounds.width * 0.17, dy: bounds.height * 0.17)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) { updateMaterial() }
    }
}

/// Notification Center / Now Playing artwork requires an image rather than a
/// view. Render a matching opaque fallback only for those system-owned surfaces.
enum ArtworkPlaceholderRenderer {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(seed: String?, isDark: Bool, size: CGFloat = 512) -> UIImage {
        let key = "\(seed ?? "Metal")|\(isDark)|\(size)" as NSString
        if let existing = cache.object(forKey: key) { return existing }
        let palette = ArtworkPlaceholderPalette(seed: seed, isDark: isDark)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let result = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { context in
            let cg = context.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: [palette.top.cgColor, palette.bottom.cgColor] as CFArray, locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size, y: size), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            if let bloom = CGGradient(colorsSpace: space,
                colors: [palette.accent.withAlphaComponent(0.14).cgColor, palette.accent.withAlphaComponent(0).cgColor] as CFArray,
                locations: [0, 1]) {
                cg.drawRadialGradient(bloom, startCenter: CGPoint(x: size * 0.25, y: size * 0.2), startRadius: 0,
                    endCenter: CGPoint(x: size * 0.25, y: size * 0.2), endRadius: size * 0.85, options: [])
            }
            let tint = isDark ? UIColor.white.withAlphaComponent(0.64) : UIColor.black.withAlphaComponent(0.48)
            UIImage(named: "MetalStar")?.withTintColor(tint, renderingMode: .alwaysOriginal)
                .draw(in: CGRect(x: size * 0.17, y: size * 0.17, width: size * 0.66, height: size * 0.66))
        }
        cache.countLimit = 24
        cache.totalCostLimit = 12 * 1024 * 1024
        cache.setObject(result, forKey: key, cost: Int(size * size * 4))
        return result
    }
}
