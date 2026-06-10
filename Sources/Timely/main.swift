import AppKit

let intervals: [(label: String, seconds: Int)] = [
    ("15 sec", 15), ("30 sec", 30),
    ("1 min", 60), ("2 min", 120), ("5 min", 300),
    ("10 min", 600), ("15 min", 900), ("20 min", 1200),
    ("30 min", 1800), ("1 hour", 3600),
]

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

    var clickToPause: Bool {
        get { UserDefaults.standard.bool(forKey: "clickToPause") }
        set { UserDefaults.standard.set(newValue, forKey: "clickToPause") }
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
            start(interval)
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
        for (label, seconds) in intervals {
            let item = NSMenuItem(title: label, action: #selector(pick(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = seconds
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let clickTo = NSMenuItem(title: "Click to", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for (title, pauses) in [("Pause", true), ("Restart", false)] {
            let item = NSMenuItem(title: title, action: #selector(setClickAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pauses
            item.state = clickToPause == pauses ? .on : .off
            submenu.addItem(item)
        }
        clickTo.submenu = submenu
        menu.addItem(clickTo)
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

    @objc func setClickAction(_ sender: NSMenuItem) {
        clickToPause = sender.representedObject as? Bool ?? false
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
app.run()
