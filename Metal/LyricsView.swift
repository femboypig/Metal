import UIKit

final class LyricsView: UIView, UITableViewDataSource, UITableViewDelegate {
    let table = UITableView(frame: .zero, style: .plain)
    let resume = UIButton(type: .system)
    let message = UILabel()
    let actions = UIStackView()
    var document: LyricsDocument?
    var active: Int?
    var manual = false
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
        resume.setTitle("Back to current line", for: .normal)
        resume.addTarget(self, action: #selector(resumeTapped), for: .touchUpInside)
        resume.isHidden = true; addSubview(resume)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews(); table.frame = bounds.insetBy(dx: 12, dy: 0)
        table.contentInset = UIEdgeInsets(top: bounds.height * 0.38, left: 0, bottom: bounds.height * 0.38, right: 0)
        message.frame = CGRect(x: 20, y: bounds.midY - 110, width: bounds.width - 40, height: 80)
        actions.frame = CGRect(x: 30, y: bounds.midY - 20, width: bounds.width - 60, height: 144)
        resume.frame = CGRect(x: 30, y: bounds.height - 44, width: bounds.width - 60, height: 44)
    }
    func display(_ doc: LyricsDocument?, loading: Bool = false) {
        document = doc; active = nil; manual = false; resume.isHidden = true
        let empty = doc?.lines.isEmpty ?? true
        table.isHidden = empty; message.isHidden = !empty; actions.isHidden = !empty || loading
        message.text = loading ? "Finding lyrics…" : (doc?.instrumental == true ? "Instrumental" : "No lyrics found.")
        table.reloadData(); table.setContentOffset(CGPoint(x: 0, y: -table.adjustedContentInset.top), animated: false)
    }
    func update(time: Double) {
        let next = document?.active(at: time)
        guard next != active else { return }
        active = next
        for cell in table.visibleCells { if let index = table.indexPath(for: cell) { style(cell, index: index.row) } }
        if !manual { center(animated: !UIAccessibility.isReduceMotionEnabled) }
    }
    func center(animated: Bool) {
        guard let active else { return }
        table.scrollToRow(at: IndexPath(row: active, section: 0), at: .middle, animated: animated)
    }
    @objc func resumeTapped() { manual = false; resume.isHidden = true; center(animated: !UIAccessibility.isReduceMotionEnabled) }
    @objc func searchTapped() { search?() }
    @objc func importTapped() { imported?() }
    @objc func pasteTapped() { paste?() }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { manual = true; resume.isHidden = document?.synchronized != true }
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
        cell.accessibilityTraits = index == active ? [.selected, .button] : [.button]
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let doc = document, let time = doc.lines[indexPath.row].time else { return }
        seek?(max(0, time + doc.offset)); manual = false; resume.isHidden = true
    }
}
