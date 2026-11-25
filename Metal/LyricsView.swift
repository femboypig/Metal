import UIKit

final class LyricsView: UIView, UITableViewDataSource, UITableViewDelegate {
    let table = UITableView(frame: .zero, style: .plain)
    private let resume = LyricsFollowButton(type: .system)
    let resumeMaterial = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    let message = UILabel()
    let actions = UIStackView()
    var document: LyricsDocument?
    var syncEngine: LyricsSyncEngine?
    var active: Int?
    var manual = false
    var lastViewportSize = CGSize.zero
    var restoring = false
    var dragStartY: CGFloat = 0
    var seek: ((Double) -> Void)?
    var search: (() -> Void)?
    var imported: (() -> Void)?
    var paste: (() -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        table.backgroundColor = .clear; table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension; table.estimatedRowHeight = 80
        table.dataSource = self; table.delegate = self; table.showsVerticalScrollIndicator = false
        table.register(UITableViewCell.self, forCellReuseIdentifier: "line")
        addSubview(table)
        message.textAlignment = .center; message.numberOfLines = 0; message.textColor = .label
        message.font = UIFont(name: "Fraunces72pt-Bold", size: 24)
        addSubview(message)
        actions.axis = .vertical; actions.spacing = 4; addSubview(actions)
        for (title, action) in [("Search Again", #selector(searchTapped)), ("Import Lyrics", #selector(importTapped)), ("Paste Lyrics", #selector(pasteTapped))] {
            let button = UIButton(type: .system); button.setTitle(title, for: .normal)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.addTarget(self, action: action, for: .touchUpInside); actions.addArrangedSubview(button)
        }
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Current line"
        configuration.image = UIImage(systemName: "location.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
        configuration.imagePadding = 7
        configuration.baseForegroundColor = .label
        configuration.baseBackgroundColor = .clear
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 15, bottom: 9, trailing: 15)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes; updated.font = UIFont.systemFont(ofSize: 13, weight: .semibold); return updated
        }
        resume.configuration = configuration
        resume.layer.shadowOpacity = 0.1; resume.layer.shadowRadius = 8
        resume.accessibilityLabel = "Return to current lyric line"
        resume.addTarget(self, action: #selector(resumeTapped), for: .touchUpInside)
        resumeMaterial.isUserInteractionEnabled = false; resumeMaterial.clipsToBounds = true
        resumeMaterial.layer.cornerRadius = 19; resumeMaterial.isHidden = true
        addSubview(resumeMaterial)
        resume.isHidden = true; addSubview(resume)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews(); table.frame = bounds.insetBy(dx: 12, dy: 0)
        let changed = lastViewportSize != bounds.size
        if changed {
            lastViewportSize = bounds.size
            table.contentInset = UIEdgeInsets(top: bounds.height * 0.5, left: 0, bottom: bounds.height * 0.5, right: 0)
        }
        message.frame = CGRect(x: 20, y: bounds.midY - 110, width: bounds.width - 40, height: 80)
        actions.frame = CGRect(x: 30, y: bounds.midY - 20, width: bounds.width - 60, height: 144)
        let width = min(bounds.width - 32, resume.sizeThatFits(CGSize(width: bounds.width, height: 40)).width)
        resume.frame = CGRect(x: (bounds.width - width) / 2, y: bounds.height - 48, width: width, height: 38)
        resumeMaterial.frame = resume.frame
        if changed && !manual && !table.isDragging && !table.isDecelerating { center(animated: false) }
    }
    func display(_ doc: LyricsDocument?, loading: Bool = false) {
        table.setContentOffset(table.contentOffset, animated: false)
        document = doc; syncEngine = doc.flatMap(LyricsSyncEngine.init); active = nil; manual = false; restoring = false; resume.isHidden = true; resumeMaterial.isHidden = true
        let empty = doc?.lines.isEmpty ?? true
        table.isHidden = empty; message.isHidden = !empty; actions.isHidden = !empty || loading
        message.text = loading ? "Finding lyrics…" : (doc?.instrumental == true ? "Instrumental" : "No lyrics found.")
        table.reloadData(); table.setContentOffset(CGPoint(x: 0, y: -table.adjustedContentInset.top), animated: false)
    }
    func update(time: Double) {
        let next = syncEngine?.active(at: time)
        guard next != active else {
            // Height estimation and interrupted scroll animations can move the target after it was selected.
            if !manual && !table.isDragging && !table.isDecelerating && !restoring, let active,
               active < table.numberOfRows(inSection: 0) {
                let row = table.rectForRow(at: IndexPath(row: active, section: 0))
                if LyricsFollowPolicy.awayFromCurrent(distance: Double(row.midY - table.contentOffset.y - table.bounds.midY), viewport: Double(table.bounds.height)) { center(animated: false) }
            }
            return
        }
        active = next
        let changes = { for cell in self.table.visibleCells { if let index = self.table.indexPath(for: cell) { self.style(cell, index: index.row) } } }
        if UIAccessibility.isReduceMotionEnabled { changes() }
        else { UIView.animate(withDuration: 0.18, animations: changes) }
        if !manual && !table.isDragging && !table.isDecelerating { center(animated: !UIAccessibility.isReduceMotionEnabled) }
        updateResume()
    }
    func center(animated: Bool) {
        guard let active else { return }
        guard active < table.numberOfRows(inSection: 0), table.bounds.height > 0 else { return }
        table.layoutIfNeeded()
        let row = table.rectForRow(at: IndexPath(row: active, section: 0))
        let top = -table.adjustedContentInset.top
        let bottom = max(top, table.contentSize.height - table.bounds.height + table.adjustedContentInset.bottom)
        let target = min(bottom, max(top, row.midY - table.bounds.height * 0.5))
        guard abs(table.contentOffset.y - target) > 1 else { restoring = false; return }
        restoring = animated
        table.setContentOffset(CGPoint(x: table.contentOffset.x, y: target), animated: animated)
        if !animated { restoring = false }
    }
    @objc func resumeTapped() { manual = false; center(animated: !UIAccessibility.isReduceMotionEnabled); updateResume() }
    func updateResume() {
        if restoring { return }
        let away: Bool
        if let active, active < table.numberOfRows(inSection: 0) {
            let row = table.rectForRow(at: IndexPath(row: active, section: 0))
            away = LyricsFollowPolicy.awayFromCurrent(distance: Double(row.midY - (table.contentOffset.y + table.bounds.midY)), viewport: Double(table.bounds.height))
        } else { away = false }
        resume.isHidden = !(manual && away && document?.synchronized == true)
        resumeMaterial.isHidden = resume.isHidden
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) { if manual { updateResume() } }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool) {
        if !willDecelerate { finishBrowsingGesture() }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { finishBrowsingGesture() }
    func finishBrowsingGesture() {
        updateResume()
        if !LyricsFollowPolicy.intentionallyMoved(Double(table.contentOffset.y - dragStartY)) || (active != nil && resume.isHidden) { manual = false }
        if !manual { center(animated: !UIAccessibility.isReduceMotionEnabled) }
        updateResume()
    }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        restoring = false
        if !manual { center(animated: false) }
        updateResume()
    }
    @objc func searchTapped() { search?() }
    @objc func importTapped() { imported?() }
    @objc func pasteTapped() { paste?() }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { dragStartY = table.contentOffset.y; manual = true; restoring = false }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { document?.lines.count ?? 0 }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "line", for: indexPath)
        cell.backgroundColor = .clear; cell.selectionStyle = .none
        cell.textLabel?.numberOfLines = 0
        let size: CGFloat = bounds.width < 350 ? 26 : 29
        cell.textLabel?.font = UIFontMetrics(forTextStyle: .title2).scaledFont(for: UIFont(name: "Fraunces72pt-Bold", size: size) ?? UIFont(name: "Georgia-Bold", size: size)!, maximumPointSize: 42)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.textLabel?.text = document?.lines[indexPath.row].text
        cell.accessibilityHint = document?.synchronized == true ? "Double tap to play from this line" : nil
        style(cell, index: indexPath.row); return cell
    }
    func style(_ cell: UITableViewCell, index: Int) {
        let distance = active.map { abs(index - $0) } ?? 1
        let opacity: CGFloat = document?.synchronized != true ? 1 : (distance == 0 ? 1 : (distance < 3 ? 0.42 : 0.30))
        cell.textLabel?.textColor = UIColor.label.withAlphaComponent(opacity)
        cell.accessibilityTraits = document?.synchronized == true ? (index == active ? [.selected, .button] : [.button]) : [.staticText]
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let doc = document, doc.synchronized, let time = doc.lines[indexPath.row].time else { return }
        seek?(max(0, time + doc.offset)); manual = false
        center(animated: !UIAccessibility.isReduceMotionEnabled); updateResume()
    }
}

private final class LyricsFollowButton: UIButton {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool { bounds.insetBy(dx: -4, dy: -4).contains(point) }
}
