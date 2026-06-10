import AppKit

let defaultIntervals = [60, 300, 900, 1800]

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

    var clickToPause: Bool {
        UserDefaults.standard.bool(forKey: "clickToPause")
    }

    var finishOpensMenu: Bool {
        UserDefaults.standard.bool(forKey: "finishOpensMenu")
    }

    var intervals: [Int] {
        if let saved = UserDefaults.standard.array(forKey: "intervals") as? [Int], !saved.isEmpty {
            return saved
        }
        return defaultIntervals
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
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
    func pause() {
        state = .paused
        stopTimers()
        remaining = max(1, Int(endDate.timeIntervalSinceNow.rounded()))
        statusItem.button?.attributedTitle = NSAttributedString(
            string: format(remaining),
            attributes: [.foregroundColor: NSColor.secondaryLabelColor]
        )
    }

    func resume() {
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
        flashOn = true
        setFlashTitle()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.flashOn.toggle()
            self.setFlashTitle()
        }
        RunLoop.main.add(timer, forMode: .common)
        flashTimer = timer
    }

    // Flash by toggling text color: keeps the status item width stable
    func setFlashTitle() {
        let color: NSColor = flashOn ? .controlTextColor : .clear
        statusItem.button?.attributedTitle = NSAttributedString(
            string: format(interval),
            attributes: [.foregroundColor: color]
        )
    }

    func stopTimers() {
        tickTimer?.invalidate()
        tickTimer = nil
        flashTimer?.invalidate()
        flashTimer = nil
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
            clickToPause ? pause() : start(interval)
        case .paused:
            resume()
        case .finished:
            // The flash keeps going behind the menu until an action is picked
            if finishOpensMenu {
                showMenu(withCancel: true)
            } else {
                start(interval)
            }
        }
    }

    func showMenu(withCancel: Bool) {
        let menu = NSMenu()
        if withCancel {
            let cancel = NSMenuItem(title: "Cancel Timer", action: #selector(cancelTimer), keyEquivalent: "")
            cancel.target = self
            menu.addItem(cancel)
            menu.addItem(.separator())
        }
        for seconds in intervals {
            let item = NSMenuItem(title: menuLabel(seconds), action: #selector(pick(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = seconds
            menu.addItem(item)
        }
        let custom = NSMenuItem(title: "Custom…", action: #selector(customTimer), keyEquivalent: "")
        custom.target = self
        menu.addItem(custom)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        // Custom selector instead of terminate(_:): keeps Tahoe from adding an icon
        let quit = NSMenuItem(title: "Quit Timely", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        // Temporarily attach the menu so a programmatic click opens it
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
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
