import UIKit

final class LyricsView: UIView, UITableViewDataSource, UITableViewDelegate {
    let table = UITableView(frame: .zero, style: .plain)
    private let resume = LyricsFollowButton(type: .custom)
    private var resumeVisible = false
    let message = UILabel()
    let actions = UIStackView()
    var correctLine: ((Int) -> Void)?
    var cancelSync: (() -> Void)?
    var document: LyricsDocument?
    var syncEngine: LyricsSyncEngine?
    var active: Int?
    var manual = false
    var lastViewportSize = CGSize.zero
    private var scrollTargetOffset: CGFloat?
    private var scrollIssuedAt: CFTimeInterval = 0
    var restoring: Bool {
        guard let target = scrollTargetOffset else { return false }
        // Animation state is bounded; a missed UIKit completion cannot lock following.
        return abs(table.contentOffset.y - target) > 1 && CACurrentMediaTime() - scrollIssuedAt < 0.45
    }
    private(set) var lastPlaybackTime: Double = 0
    private(set) var playbackUpdates = 0
    private var followTarget: Int?
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
        actions.axis = .vertical; actions.alignment = .center; actions.spacing = 10
        addSubview(actions)
        actions.addArrangedSubview(emptyStateButton("Search Again", action: #selector(searchTapped), primary: true))
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Current line"
        configuration.baseForegroundColor = .systemBackground
        configuration.background.backgroundColor = .label
        configuration.background.cornerRadius = 16
        configuration.cornerStyle = .fixed
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for:
                UIFont(name: "DrukWide-Bold", size: 10.5) ?? UIFont.systemFont(ofSize: 12, weight: .heavy), maximumPointSize: 16)
            return updated
        }
        resume.configuration = configuration
        resume.accessibilityLabel = "Return to current lyric line"
        resume.addTarget(self, action: #selector(resumeTapped), for: .touchUpInside)
        resume.isHidden = true; addSubview(resume)

    }
    private func emptyStateButton(_ title: String, action: Selector, primary: Bool = false) -> UIButton {
        let button = UIButton(type: .custom)
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = primary ? .systemBackground : .label
        config.background.backgroundColor = primary ? .label : UIColor { $0.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.09) : UIColor.black.withAlphaComponent(0.06) }
        config.background.cornerRadius = 16; config.cornerStyle = .fixed
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: primary ? 20 : 12, bottom: 12, trailing: primary ? 20 : 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for:
                UIFont(name: "DrukWide-Bold", size: primary ? 11 : 9) ?? UIFont.systemFont(ofSize: primary ? 13 : 11, weight: .bold), maximumPointSize: primary ? 17 : 14)
            return updated
        }
        button.configuration = config
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        table.frame = CGRect(x: 12, y: 0, width: max(1, bounds.width - 24), height: max(1, bounds.height))
        let changed = lastViewportSize != table.bounds.size
        if changed {
            lastViewportSize = table.bounds.size
            table.contentInset = UIEdgeInsets(top: table.bounds.height * 0.5, left: 0, bottom: table.bounds.height * 0.5, right: 0)
        }
        let available = max(1, bounds.width - 40)
        let messageHeight = message.sizeThatFits(CGSize(width: available, height: .greatestFiniteMagnitude)).height
        let actionHeight = actions.isHidden ? 0 : actions.systemLayoutSizeFitting(CGSize(width: available, height: 0), withHorizontalFittingPriority: .fittingSizeLevel, verticalFittingPriority: .fittingSizeLevel).height
        let gap: CGFloat = actions.isHidden ? 0 : 20
        let top = max(0, bounds.midY - (messageHeight + gap + actionHeight) / 2)
        message.frame = CGRect(x: 20, y: top, width: available, height: messageHeight)
        actions.frame = CGRect(x: 20, y: top + messageHeight + gap, width: available, height: actionHeight)
        let width = min(bounds.width - 32, resume.sizeThatFits(CGSize(width: bounds.width, height: 40)).width)
        let height = max(36, resume.sizeThatFits(CGSize(width: width, height: 60)).height)
        resume.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        resume.center = CGPoint(x: bounds.midX, y: table.frame.maxY - 10 - height / 2)
        if changed && !manual && !table.isDragging && !table.isDecelerating { center(animated: false) }
    }
    func display(_ doc: LyricsDocument?, loading: Bool = false, state: LyricsLookupState = .missing) {
        stopCentering()
        table.setContentOffset(table.contentOffset, animated: false)
        document = doc; syncEngine = doc.flatMap(LyricsSyncEngine.init); active = nil; followTarget = nil; manual = false; resumeVisible = false; resume.layer.removeAllAnimations(); resume.alpha = 1; resume.transform = .identity; resume.isHidden = true
        let empty = doc?.lines.isEmpty ?? true
        table.isHidden = empty; message.isHidden = !empty; actions.isHidden = !empty || loading
        if loading { message.text = "Finding lyrics…" }
        else if doc?.instrumental == true { message.text = "Instrumental" }
        else if state == .unavailable { message.text = "Lyrics unavailable.\nTry again shortly." }
        else if state == .unreadable { message.text = "Audio file unavailable." }
        else { message.text = "No lyrics found." }
        setNeedsLayout()
        table.reloadData(); table.setContentOffset(CGPoint(x: 0, y: -table.adjustedContentInset.top), animated: false)
    }
    func update(time: Double) {
        lastPlaybackTime = time; playbackUpdates += 1
        let target = syncEngine?.focus(at: time)
        let targetChanged = target != followTarget
        followTarget = target
        let next = syncEngine?.active(at: time)
        guard next != active || targetChanged else {
            // Height estimation and interrupted scroll animations can move the target after it was selected.
            if !manual && !table.isDragging && !table.isDecelerating && !restoring, let active = followTarget,
               active < table.numberOfRows(inSection: 0) {
                let row = table.rectForRow(at: IndexPath(row: active, section: 0))
                if abs(row.midY - table.contentOffset.y - table.bounds.height * 0.5) > 12 { center(animated: false) }
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
    func playbackDiagnostics() -> [String: Any] {
        var state: [String: Any] = [:]
        state["viewPlaybackTime"] = lastPlaybackTime
        state["playbackUpdates"] = playbackUpdates
        state["activeRow"] = active.map { $0 as Any } ?? NSNull()
        state["focusRow"] = followTarget.map { $0 as Any } ?? NSNull()
        state["manualBrowsing"] = manual
        state["centering"] = restoring
        state["dragging"] = table.isDragging
        state["decelerating"] = table.isDecelerating
        state["viewportHeight"] = table.bounds.height
        state["offset"] = table.contentOffset.y
        state["synchronized"] = document?.synchronized ?? false
        state["timedRows"] = syncEngine?.starts.count ?? 0
        state["starts"] = syncEngine?.starts ?? []
        let ends: [Any] = (syncEngine?.ends ?? []).map { value in
            if let value { return NSNumber(value: value) }
            return NSNull()
        }
        state["ends"] = ends
        state["sourceOffset"] = document?.offset ?? 0
        return state
    }
    private func stopCentering() {
        scrollTargetOffset = nil
        table.setContentOffset(table.contentOffset, animated: false)
    }
    func center(animated: Bool) {
        guard let active = followTarget, active < table.numberOfRows(inSection: 0), table.bounds.height > 0 else { return }
        table.layoutIfNeeded()
        let row = table.rectForRow(at: IndexPath(row: active, section: 0))
        let top = -table.adjustedContentInset.top
        let bottom = max(top, table.contentSize.height - table.bounds.height + table.adjustedContentInset.bottom)
        let target = min(bottom, max(top, row.midY - table.bounds.height * 0.5))
        guard abs(table.contentOffset.y - target) > 1 else { return }
        scrollTargetOffset = animated ? target : nil
        scrollIssuedAt = CACurrentMediaTime()
        table.setContentOffset(CGPoint(x: table.contentOffset.x, y: target), animated: animated)
    }
    @objc func resumeTapped() { manual = false; center(animated: !UIAccessibility.isReduceMotionEnabled); updateResume() }
    func updateResume() {
        if restoring { return }
        let away: Bool
        if let active = followTarget, active < table.numberOfRows(inSection: 0) {
            let row = table.rectForRow(at: IndexPath(row: active, section: 0))
            away = LyricsFollowPolicy.awayFromCurrent(distance: Double(row.midY - (table.contentOffset.y + table.bounds.height * 0.5)), viewport: Double(table.bounds.height))
        } else { away = false }
        setResumeVisible(manual && away && document?.synchronized == true)
    }
    private func setResumeVisible(_ visible: Bool) {
        guard visible != resumeVisible else { return }
        resumeVisible = visible
        if visible {
            resume.isHidden = false
            resume.alpha = 0
            resume.transform = UIAccessibility.isReduceMotionEnabled ? .identity : CGAffineTransform(translationX: 0, y: 4)
        }
        let changes = {
            self.resume.alpha = visible ? 1 : 0
            self.resume.transform = visible || UIAccessibility.isReduceMotionEnabled ? .identity : CGAffineTransform(translationX: 0, y: 4)
        }
        let completion: (Bool) -> Void = { _ in
            if !self.resumeVisible { self.resume.isHidden = true }
        }
        if UIAccessibility.isReduceMotionEnabled { changes(); completion(true) }
        else { UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: changes, completion: completion) }
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) { if manual { updateResume() } }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool) {
        if !willDecelerate { finishBrowsingGesture() }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { finishBrowsingGesture() }
    func finishBrowsingGesture() {
        updateResume()
        if !LyricsFollowPolicy.intentionallyMoved(Double(table.contentOffset.y - dragStartY)) || (followTarget != nil && !resumeVisible) { manual = false }
        if !manual { center(animated: !UIAccessibility.isReduceMotionEnabled) }
        updateResume()
    }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollTargetOffset = nil
        if !manual { center(animated: false) }
        updateResume()
    }
    @objc func searchTapped() { search?() }
    @objc func importTapped() { imported?() }
    @objc func pasteTapped() { paste?() }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { stopCentering(); dragStartY = table.contentOffset.y; manual = true }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { document?.lines.count ?? 0 }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "line", for: indexPath)
        cell.backgroundColor = .clear; cell.selectionStyle = .none
        cell.textLabel?.numberOfLines = 0
        let size: CGFloat = bounds.width < 350 ? 26 : 29
        cell.textLabel?.font = UIFontMetrics(forTextStyle: .title2).scaledFont(for: Self.lyricsFont(text: document?.lines[indexPath.row].text ?? "", size: size), maximumPointSize: 42)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.textLabel?.text = document?.lines[indexPath.row].text
        cell.accessibilityHint = document?.synchronized == true && document?.lines[indexPath.row].time != nil ? "Double tap to play from this line" : nil
        style(cell, index: indexPath.row); return cell
    }
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard document?.onDeviceTiming != nil else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [UIAction(title: "Correct Line Timing", image: UIImage(systemName: "clock")) { [weak self] _ in
                self?.correctLine?(indexPath.row)
            }])
        }
    }
    static func lyricsFont(text: String, size: CGFloat) -> UIFont {
        let latin = UIFont(name: "Fraunces72pt-Bold", size: size) ?? UIFont(name: "Georgia-Bold", size: size)!
        let cyrillic = text.unicodeScalars.contains { (0x0400...0x052F).contains($0.value) || (0xA640...0xA69F).contains($0.value) }
        guard cyrillic, let font = UIFont(name: "Literata72pt-ExtraBold", size: size) else { return latin }
        return UIFont(name: "Literata72pt-ExtraBold", size: size * latin.capHeight / max(1, font.capHeight)) ?? font
    }
    func style(_ cell: UITableViewCell, index: Int) {
        let distance = active.map { abs(index - $0) } ?? 1
        let opacity: CGFloat = document?.synchronized != true ? 1 : (distance == 0 ? 1 : (distance < 3 ? 0.42 : 0.30))
        cell.textLabel?.textColor = UIColor.label.withAlphaComponent(opacity)
        let canSeek = document?.synchronized == true && document?.lines.indices.contains(index) == true && document?.lines[index].time != nil
        cell.accessibilityTraits = canSeek ? (index == active ? [.selected, .button] : [.button]) : [.staticText]
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
