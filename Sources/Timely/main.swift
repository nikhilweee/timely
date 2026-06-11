import AppKit

// 90 -> "1 min 30 sec", 3600 -> "1 hr": for menu items
func menuLabel(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    var parts: [String] = []
    if h > 0 { parts.append("\(h) hr") }
    if m > 0 { parts.append("\(m) min") }
    if s > 0 { parts.append("\(s) sec") }
    return parts.joined(separator: " ")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    enum State { case idle, running, paused, finished }

    var statusItem: NSStatusItem!
    var state: State = .idle
    var interval = 0
    var remaining = 0
    var endDate = Date()
    var tickTimer: Timer?
    var flashTimer: Timer?
    var flashOn = true

    let settings = SettingsController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.register()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        showIdle()
    }

    // MARK: - States

    func showIdle() {
        state = .idle
        stopTimers()
        statusItem.button?.title = ""
        statusItem.button?.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Timely")
    }

    func start(_ seconds: Int) {
        interval = seconds
        run(seconds)
    }

    func run(_ seconds: Int) {
        state = .running
        stopTimers()
        endDate = Date().addingTimeInterval(TimeInterval(seconds))
        statusItem.button?.image = nil
        updateCountdown()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    // Dim the countdown so a paused timer reads as paused
    @objc func pause() {
        state = .paused
        stopTimers()
        remaining = max(1, Int(endDate.timeIntervalSinceNow.rounded()))
        statusItem.button?.attributedTitle = NSAttributedString(
            string: format(remaining),
            attributes: [.foregroundColor: NSColor.secondaryLabelColor]
        )
    }

    @objc func resume() {
        run(remaining)
    }

    func updateCountdown() {
        let remaining = Int(endDate.timeIntervalSinceNow.rounded())
        if remaining <= 0 {
            finish()
        } else {
            statusItem.button?.title = format(remaining)
        }
    }

    func finish() {
        state = .finished
        stopTimers()
        statusItem.button?.image = nil
        startFlash()
    }

    func startFlash() {
        flashOn = true
        updateFlash()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.flashOn.toggle()
            self.updateFlash()
        }
        RunLoop.main.add(timer, forMode: .common)
        flashTimer = timer
    }

    func updateFlash() {
        guard let button = statusItem.button else { return }
        if Prefs.flashHighlight {
            // Invert: the background takes the text color and vice versa
            button.wantsLayer = true
            let dark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let textColor: NSColor = flashOn ? (dark ? .black : .white) : .controlTextColor
            button.layer?.cornerRadius = button.bounds.height / 2
            button.layer?.backgroundColor = flashOn ? (dark ? NSColor.white : NSColor.black).cgColor : nil
            button.attributedTitle = NSAttributedString(
                string: format(interval),
                attributes: [.foregroundColor: textColor]
            )
        } else {
            // Toggling text color instead of the text keeps the width stable
            button.layer?.backgroundColor = nil
            button.attributedTitle = NSAttributedString(
                string: format(interval),
                attributes: [.foregroundColor: flashOn ? NSColor.controlTextColor : .clear]
            )
        }
    }

    func stopTimers() {
        tickTimer?.invalidate()
        tickTimer = nil
        flashTimer?.invalidate()
        flashTimer = nil
        statusItem.button?.layer?.backgroundColor = nil
    }

    // MARK: - Clicks and menu

    @objc func clicked() {
        let rightClick = NSApp.currentEvent?.type == .rightMouseUp
        switch state {
        case .idle:
            showMenu(withCancel: false)
        case .running where rightClick, .paused where rightClick, .finished where rightClick:
            showMenu(withCancel: true)
        case .running:
            Prefs.clickToPause ? pause() : start(interval)
        case .paused:
            resume()
        case .finished:
            Prefs.finishOpensMenu ? showMenu(withCancel: true) : start(interval)
        }
    }

    func showMenu(withCancel: Bool) {
        let menu = NSMenu()
        if withCancel {
            if state == .running {
                addItem(menu, "Pause Timer", #selector(pause))
            } else if state == .paused {
                addItem(menu, "Resume Timer", #selector(resume))
            }
            addItem(menu, "Cancel Timer", #selector(cancelTimer))
            menu.addItem(.separator())
        }
        for seconds in Prefs.intervals {
            addItem(menu, menuLabel(seconds), #selector(pick(_:)), represents: seconds)
        }
        addItem(menu, "Custom…", #selector(customTimer))
        menu.addItem(.separator())
        addItem(menu, "Settings…", #selector(showSettings), key: ",")
        menu.addItem(.separator())
        // Custom selector instead of terminate(_:): keeps Tahoe from adding an icon
        addItem(menu, "Quit Timely", #selector(quit), key: "q")

        // Suspend the flash while the menu is open: the inverted background
        // fights the system's menu highlight
        let wasFlashing = flashTimer != nil
        if wasFlashing {
            flashTimer?.invalidate()
            flashTimer = nil
            statusItem.button?.layer?.backgroundColor = nil
            statusItem.button?.attributedTitle = NSAttributedString(
                string: format(interval),
                attributes: [.foregroundColor: NSColor.controlTextColor]
            )
        }

        // Temporarily attach the menu so a programmatic click opens it
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil

        if wasFlashing {
            // Async so a chosen menu action settles state first; resume the
            // flash only if the menu closed without one
            DispatchQueue.main.async { [weak self] in
                guard let self, self.state == .finished, self.flashTimer == nil else { return }
                self.startFlash()
            }
        }
    }

    private func addItem(_ menu: NSMenu, _ title: String, _ action: Selector,
                         key: String = "", represents: Any? = nil) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.representedObject = represents
        menu.addItem(item)
    }

    @objc func pick(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? Int else { return }
        start(seconds)
    }

    @objc func cancelTimer() {
        showIdle()
    }

    @objc func showSettings() {
        settings.show()
    }

    @objc func customTimer() {
        let alert = NSAlert()
        alert.messageText = "Custom Timer"
        alert.informativeText = "Examples: 25, 90s, 1:30, 1h 10m"
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        activateApp()
        if alert.runModal() == .alertFirstButtonReturn, let seconds = parseDuration(field.stringValue) {
            start(seconds)
        }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    func format(_ seconds: Int) -> String {
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
        }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)

// Accessory apps never show this menu, but cmd+C/V/X/A/Z only work for text
// inputs when an Edit menu exists to route the key equivalents
let editMenu = NSMenu(title: "Edit")
editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
editMenu.addItem(.separator())
editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
let editItem = NSMenuItem()
editItem.submenu = editMenu
let mainMenu = NSMenu()
mainMenu.addItem(editItem)
app.mainMenu = mainMenu

app.run()
