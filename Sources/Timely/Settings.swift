import AppKit

// Single home for UserDefaults keys, defaults, and fallbacks
enum Prefs {
    static let clickToPauseKey = "clickToPause"
    static let finishOpensMenuKey = "finishOpensMenu"
    static let flashHighlightKey = "flashHighlight"
    static let intervalsKey = "intervals"

    static let defaultIntervals = [60, 300, 900, 1800]

    static var clickToPause: Bool { UserDefaults.standard.bool(forKey: clickToPauseKey) }
    static var finishOpensMenu: Bool { UserDefaults.standard.bool(forKey: finishOpensMenuKey) }
    static var flashHighlight: Bool { UserDefaults.standard.bool(forKey: flashHighlightKey) }

    static var intervals: [Int] {
        get {
            if let saved = UserDefaults.standard.array(forKey: intervalsKey) as? [Int], !saved.isEmpty {
                return saved
            }
            return defaultIntervals
        }
        set { UserDefaults.standard.set(newValue, forKey: intervalsKey) }
    }

    static func register() {
        UserDefaults.standard.register(defaults: [flashHighlightKey: true])
    }
}

private let durationRegex = try! NSRegularExpression(
    pattern: #"(\d+)\s*(h(?:ours?|rs?)?|m(?:ins?|inutes?)?|s(?:ecs?|econds?)?)"#
)

// Parses "25" (minutes), "1:30", "1:02:03", "90s", "5m", "1h 10m"
func parseDuration(_ input: String) -> Int? {
    let s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !s.isEmpty else { return nil }
    if s.contains(":") {
        let parts = s.split(separator: ":", omittingEmptySubsequences: false).map { Int($0) }
        let nums = parts.compactMap { $0 }
        guard nums.count == parts.count else { return nil }
        let total: Int
        switch nums.count {
        case 2: total = nums[0] * 60 + nums[1]
        case 3: total = nums[0] * 3600 + nums[1] * 60 + nums[2]
        default: return nil
        }
        return total > 0 ? total : nil
    }
    if let minutes = Int(s) { return minutes > 0 ? minutes * 60 : nil }
    let range = NSRange(s.startIndex..., in: s)
    var total = 0
    for match in durationRegex.matches(in: s, range: range) {
        let value = Int((s as NSString).substring(with: match.range(at: 1)))!
        switch (s as NSString).substring(with: match.range(at: 2)).prefix(1) {
        case "h": total += value * 3600
        case "m": total += value * 60
        default: total += value
        }
    }
    let leftover = durationRegex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
        .replacingOccurrences(of: ",", with: "")
        .trimmingCharacters(in: .whitespaces)
    guard total > 0, leftover.isEmpty else { return nil }
    return total
}

// 90 -> "1m 30s", 3600 -> "1h": the inverse of parseDuration
func shortLabel(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    var parts: [String] = []
    if h > 0 { parts.append("\(h)h") }
    if m > 0 { parts.append("\(m)m") }
    if s > 0 { parts.append("\(s)s") }
    return parts.isEmpty ? "0s" : parts.joined(separator: " ")
}

func activateApp() {
    if #available(macOS 14.0, *) {
        NSApp.activate()
    } else {
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class SettingsController: NSObject {
    private var window: NSWindow?
    private var radioPairs: [(key: String, trueButton: NSButton, falseButton: NSButton)] = []
    private var firstColumn: [NSButton] = []
    private var intervalsView: NSTextView!
    private var hintLabel: NSTextField!
    private let defaultHint = "Comma-separated. Examples: 30s, 5m, 1:30, 1h"
    private let maxIntervals = 25

    func show() {
        if window == nil { build() }
        refresh()
        activateApp()
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let runningRadios = radioRow(key: Prefs.clickToPauseKey,
                                     trueTitle: "pause timer", falseTitle: "restart timer", trueFirst: false)
        let finishedRadios = radioRow(key: Prefs.finishOpensMenuKey,
                                      trueTitle: "open menu", falseTitle: "restart timer", trueFirst: false)
        let flashRadios = radioRow(key: Prefs.flashHighlightKey,
                                   trueTitle: "inverting colors", falseTitle: "blinking text", trueFirst: true)

        let scroll = NSScrollView()
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.widthAnchor.constraint(equalToConstant: 360).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 58).isActive = true

        intervalsView = NSTextView()
        intervalsView.isRichText = false
        intervalsView.font = .systemFont(ofSize: NSFont.systemFontSize)
        intervalsView.textContainerInset = NSSize(width: 2, height: 6)
        intervalsView.isVerticallyResizable = true
        intervalsView.isHorizontallyResizable = false
        intervalsView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                       height: CGFloat.greatestFiniteMagnitude)
        intervalsView.textContainer?.widthTracksTextView = true
        intervalsView.autoresizingMask = [.width]
        intervalsView.delegate = self
        scroll.documentView = intervalsView

        let hint = NSTextField(labelWithString: defaultHint)
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor
        hintLabel = hint

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        func footerLabel(_ text: String) -> NSTextField {
            let label = NSTextField(labelWithString: text)
            label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            label.textColor = .secondaryLabelColor
            return label
        }
        let repoLink = NSButton(title: "GitHub", target: self, action: #selector(openRepo))
        repoLink.isBordered = false
        repoLink.contentTintColor = .linkColor
        repoLink.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let footer = NSStackView(views: [
            footerLabel("Timely"), footerLabel("·"),
            footerLabel("Version \(version)"), footerLabel("·"),
            repoLink,
        ])
        footer.spacing = 6

        // Same width for the first radio of each row so the second column aligns
        let columnWidth = firstColumn.map { $0.intrinsicContentSize.width }.max() ?? 0
        firstColumn.forEach { $0.widthAnchor.constraint(equalToConstant: columnWidth).isActive = true }

        let settingsHeader = sectionHeader("Settings")
        let aboutHeader = sectionHeader("About")
        let content = NSStackView(views: [
            settingsHeader,
            NSTextField(labelWithString: "When a timer is running, click the menu bar icon to"),
            runningRadios,
            NSTextField(labelWithString: "When a timer finishes, click the menu bar icon to"),
            finishedRadios,
            NSTextField(labelWithString: "When a timer finishes, flash by"),
            flashRadios,
            NSTextField(labelWithString: "Default timer intervals"),
            scroll,
            hint,
            aboutHeader,
            footer,
        ])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 6
        content.setCustomSpacing(12, after: settingsHeader)
        content.setCustomSpacing(16, after: runningRadios)
        content.setCustomSpacing(16, after: finishedRadios)
        content.setCustomSpacing(16, after: flashRadios)
        content.setCustomSpacing(20, after: hint)
        content.setCustomSpacing(12, after: aboutHeader)
        content.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "Timely"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = content
        content.layoutSubtreeIfNeeded()
        // NSStackView's fittingSize drops the trailing inset; size explicitly
        let width = 360 + content.edgeInsets.left + content.edgeInsets.right
        window.setContentSize(NSSize(width: width, height: content.fittingSize.height))
        window.center()
        self.window = window
    }

    // One row per bool setting; radios group by sharing a superview and action
    private func radioRow(key: String, trueTitle: String, falseTitle: String, trueFirst: Bool) -> NSStackView {
        let trueButton = NSButton(radioButtonWithTitle: trueTitle, target: self, action: #selector(radioChanged(_:)))
        let falseButton = NSButton(radioButtonWithTitle: falseTitle, target: self, action: #selector(radioChanged(_:)))
        radioPairs.append((key, trueButton, falseButton))
        let ordered = trueFirst ? [trueButton, falseButton] : [falseButton, trueButton]
        firstColumn.append(ordered[0])
        return NSStackView(views: ordered)
    }

    @objc private func radioChanged(_ sender: NSButton) {
        guard let pair = radioPairs.first(where: { $0.trueButton == sender || $0.falseButton == sender }) else { return }
        UserDefaults.standard.set(pair.trueButton.state == .on, forKey: pair.key)
    }

    private func sectionHeader(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: NSFont.systemFontSize + 1)
        return label
    }

    private func refresh() {
        for pair in radioPairs {
            let value = UserDefaults.standard.bool(forKey: pair.key)
            pair.trueButton.state = value ? .on : .off
            pair.falseButton.state = value ? .off : .on
        }
        intervalsView.string = Prefs.intervals.map(shortLabel).joined(separator: ", ")
        updateValidationFeedback()
    }

    private func entryList() -> [String] {
        intervalsView.string
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    // nil if any entry fails to parse, the list is empty, or it exceeds the cap
    private func parsedIntervals() -> [Int]? {
        let entries = entryList()
        let parsed = entries.compactMap { parseDuration($0) }
        guard !parsed.isEmpty, parsed.count == entries.count, parsed.count <= maxIntervals else { return nil }
        return parsed
    }

    private func applyIntervals() {
        guard let parsed = parsedIntervals() else {
            NSSound.beep()
            refresh()
            return
        }
        Prefs.intervals = parsed
        refresh()
    }

    // Entries that fail to parse, with their ranges in the text view
    private func invalidEntries() -> [(range: NSRange, text: String)] {
        let text = intervalsView.string as NSString
        var results: [(NSRange, String)] = []
        var start = 0
        for i in 0...text.length {
            let isSeparator = i < text.length
                && (text.character(at: i) == 44 || text.character(at: i) == 10) // , or \n
            guard isSeparator || i == text.length else { continue }
            let range = NSRange(location: start, length: i - start)
            let entry = text.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            if !entry.isEmpty, parseDuration(entry) == nil {
                results.append((range, entry))
            }
            start = i + 1
        }
        return results
    }

    private func updateValidationFeedback() {
        guard let layoutManager = intervalsView.layoutManager else { return }
        let full = NSRange(location: 0, length: (intervalsView.string as NSString).length)
        layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
        let invalid = invalidEntries()
        for entry in invalid {
            layoutManager.addTemporaryAttribute(.foregroundColor, value: NSColor.systemRed,
                                                forCharacterRange: entry.range)
        }
        let entries = entryList()
        if let first = invalid.first {
            hintLabel.stringValue = "Unknown interval \"\(first.text)\""
            hintLabel.textColor = .systemRed
        } else if entries.isEmpty {
            hintLabel.stringValue = "Enter at least one interval"
            hintLabel.textColor = .systemRed
        } else if entries.count > maxIntervals {
            hintLabel.stringValue = "Keep it to \(maxIntervals) intervals or fewer"
            hintLabel.textColor = .systemRed
        } else {
            hintLabel.stringValue = defaultHint
            hintLabel.textColor = .secondaryLabelColor
        }
    }

    @objc private func openRepo() {
        NSWorkspace.shared.open(URL(string: "https://github.com/nikhilweee/timely")!)
    }
}

extension SettingsController: NSTextViewDelegate {
    // Live feedback: only the entries that fail to parse turn red
    func textDidChange(_ notification: Notification) {
        updateValidationFeedback()
    }

    func textDidEndEditing(_ notification: Notification) {
        applyIntervals()
    }

    // Return commits the edit instead of inserting a newline
    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.insertNewline(_:)) {
            textView.window?.makeFirstResponder(nil)
            return true
        }
        return false
    }
}

extension SettingsController: NSWindowDelegate {
    // Commit a pending intervals edit when the window closes
    func windowWillClose(_ notification: Notification) {
        window?.makeFirstResponder(nil)
    }
}
