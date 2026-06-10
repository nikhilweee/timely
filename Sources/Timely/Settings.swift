import AppKit

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
    let pattern = #"(\d+)\s*(h(?:ours?|rs?)?|m(?:ins?|inutes?)?|s(?:ecs?|econds?)?)"#
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(s.startIndex..., in: s)
    var total = 0
    for match in regex.matches(in: s, range: range) {
        let value = Int((s as NSString).substring(with: match.range(at: 1)))!
        switch (s as NSString).substring(with: match.range(at: 2)).prefix(1) {
        case "h": total += value * 3600
        case "m": total += value * 60
        default: total += value
        }
    }
    let leftover = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
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
    private var runningRestart: NSButton!
    private var runningPause: NSButton!
    private var finishedRestart: NSButton!
    private var finishedMenu: NSButton!
    private var intervalsView: NSTextView!
    private var hintLabel: NSTextField!
    private let defaultHint = "Comma-separated. Examples: 30s, 5m, 1:30, 1h"

    private var defaults: UserDefaults { .standard }

    func show() {
        if window == nil { build() }
        refresh()
        activateApp()
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        runningRestart = NSButton(radioButtonWithTitle: "restart timer", target: self, action: #selector(runningChanged))
        runningPause = NSButton(radioButtonWithTitle: "pause timer", target: self, action: #selector(runningChanged))
        finishedRestart = NSButton(radioButtonWithTitle: "restart timer", target: self, action: #selector(finishedChanged))
        finishedMenu = NSButton(radioButtonWithTitle: "open menu", target: self, action: #selector(finishedChanged))

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

        let runningRadios = radioRow(runningRestart, runningPause)
        let finishedRadios = radioRow(finishedRestart, finishedMenu)
        let content = NSStackView(views: [
            NSTextField(labelWithString: "When a timer is running, click the menu bar icon to"),
            runningRadios,
            NSTextField(labelWithString: "When a timer finishes, click the menu bar icon to"),
            finishedRadios,
            NSTextField(labelWithString: "Intervals"),
            scroll,
            hint,
        ])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 6
        content.setCustomSpacing(16, after: runningRadios)
        content.setCustomSpacing(16, after: finishedRadios)
        content.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "Timely Settings"
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

    // Radios group themselves by sharing a superview and action
    private func radioRow(_ buttons: NSButton...) -> NSStackView {
        NSStackView(views: buttons)
    }

    private func refresh() {
        let pause = defaults.bool(forKey: "clickToPause")
        runningPause.state = pause ? .on : .off
        runningRestart.state = pause ? .off : .on
        let openMenu = defaults.bool(forKey: "finishOpensMenu")
        finishedMenu.state = openMenu ? .on : .off
        finishedRestart.state = openMenu ? .off : .on
        intervalsView.string = currentIntervals().map(shortLabel).joined(separator: ", ")
        updateValidationFeedback()
    }

    private func currentIntervals() -> [Int] {
        if let saved = defaults.array(forKey: "intervals") as? [Int], !saved.isEmpty {
            return saved
        }
        return defaultIntervals
    }

    @objc private func runningChanged() {
        defaults.set(runningPause.state == .on, forKey: "clickToPause")
    }

    @objc private func finishedChanged() {
        defaults.set(finishedMenu.state == .on, forKey: "finishOpensMenu")
    }

    // nil if any entry fails to parse
    private func parsedIntervals() -> [Int]? {
        let entries = intervalsView.string
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let parsed = entries.compactMap { parseDuration($0) }
        guard !parsed.isEmpty, parsed.count == entries.count else { return nil }
        return parsed
    }

    private func applyIntervals() {
        guard let parsed = parsedIntervals() else {
            NSSound.beep()
            refresh()
            return
        }
        defaults.set(parsed, forKey: "intervals")
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
        if let first = invalid.first {
            hintLabel.stringValue = "Unknown interval \"\(first.text)\""
            hintLabel.textColor = .systemRed
        } else if parsedIntervals() == nil {
            hintLabel.stringValue = "Enter at least one interval"
            hintLabel.textColor = .systemRed
        } else {
            hintLabel.stringValue = defaultHint
            hintLabel.textColor = .secondaryLabelColor
        }
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
