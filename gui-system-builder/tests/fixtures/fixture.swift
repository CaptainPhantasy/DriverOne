import AppKit
import Foundation

final class FlippedRows: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class FixtureDelegate: NSObject, NSApplicationDelegate {
    private let destination: URL
    private var mainWindow: NSWindow!
    private var smallWindow: NSWindow?
    private var input: NSTextField!
    private var status: NSTextField!
    private var scrollingView: NSScrollView!
    private var savedScrollOrigin: NSPoint?

    init(destination: URL) { self.destination = destination; super.init() }

    private func identify(_ view: NSView, _ identifier: String, _ label: String? = nil) {
        view.setAccessibilityIdentifier(identifier)
        if let label { view.setAccessibilityLabel(label) }
    }

    private func label(_ text: String, _ frame: NSRect, _ identifier: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.frame = frame
        identify(field, identifier)
        return field
    }

    private func button(_ text: String, _ frame: NSRect, _ identifier: String, _ action: Selector) -> NSButton {
        let control = NSButton(title: text, target: self, action: action)
        control.frame = frame
        control.bezelStyle = .rounded
        identify(control, identifier)
        return control
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit GUI Fixture", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApp.mainMenu = menu

        mainWindow = NSWindow(contentRect: NSRect(x: 80, y: 120, width: 800, height: 650),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        mainWindow.title = "GUI Operation Test Fixture"
        mainWindow.isRestorable = false
        mainWindow.tabbingMode = .disallowed
        mainWindow.setAccessibilityIdentifier("fixture.main")
        mainWindow.isReleasedWhenClosed = false
        mainWindow.contentMinSize = NSSize(width: 800, height: 650)
        guard let content = mainWindow.contentView else { fatalError("No fixture content view") }
        content.addSubview(label("Local GUI test. No accounts, network, or model calls.",
                                 NSRect(x: 40, y: 602, width: 700, height: 28), "fixture.title"))
        input = NSTextField(frame: NSRect(x: 40, y: 542, width: 700, height: 32))
        input.stringValue = ""
        input.isEditable = true
        input.isSelectable = true
        identify(input, "fixture.input", "Fixture input")
        content.addSubview(input)
        content.addSubview(button("Apply", NSRect(x: 40, y: 486, width: 95, height: 34), "fixture.apply", #selector(apply(_:))))
        content.addSubview(button("Save scratch", NSRect(x: 145, y: 486, width: 145, height: 34), "fixture.save", #selector(saveScratch(_:))))
        content.addSubview(button("Open small dialog", NSRect(x: 300, y: 486, width: 175, height: 34), "fixture.open-dialog", #selector(openDialog(_:))))
        content.addSubview(button("Quit fixture", NSRect(x: 580, y: 486, width: 160, height: 34), "fixture.quit", #selector(quit(_:))))
        status = label("Status: Ready", NSRect(x: 40, y: 432, width: 700, height: 32), "fixture.status")
        content.addSubview(status)
        let secure = NSSecureTextField(frame: NSRect(x: 40, y: 370, width: 400, height: 30))
        secure.stringValue = ""
        identify(secure, "fixture.secure", "Secure fixture field")
        content.addSubview(secure)
        content.addSubview(label("Secure field for refusal tests; leave empty.",
                                 NSRect(x: 450, y: 370, width: 300, height: 28), "fixture.secure-description"))

        let scroll = NSScrollView(frame: NSRect(x: 40, y: 48, width: 710, height: 280))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = false
        scroll.borderType = .bezelBorder
        identify(scroll, "fixture.scroll", "Fixture scrolling rows")
        let rows = FlippedRows(frame: NSRect(x: 0, y: 0, width: 680, height: 800))
        for index in 0..<20 {
            rows.addSubview(label("Fixture row \(index + 1)", NSRect(x: 12, y: CGFloat(index * 40 + 8), width: 600, height: 28), "fixture.row.\(index + 1)"))
        }
        scroll.documentView = rows
        content.addSubview(scroll)
        scrollingView = scroll
        content.addSubview(button("Remember view", NSRect(x: 40, y: 334, width: 145, height: 30), "fixture.remember-view", #selector(rememberView(_:))))
        content.addSubview(button("Restore view", NSRect(x: 195, y: 334, width: 145, height: 30), "fixture.restore-view", #selector(restoreView(_:))))
        if let screen = NSScreen.screens.first {
            let visible = screen.visibleFrame
            let frame = mainWindow.frame
            mainWindow.setFrameOrigin(NSPoint(x: visible.minX + max(0, (visible.width - frame.width) / 2),
                                             y: visible.minY + max(0, (visible.height - frame.height) / 2)))
        }
        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func apply(_ sender: Any?) {
        status.stringValue = "Applied: " + input.stringValue
    }

    @objc private func rememberView(_ sender: Any?) {
        savedScrollOrigin = scrollingView.contentView.bounds.origin
    }

    @objc private func restoreView(_ sender: Any?) {
        guard let origin = savedScrollOrigin else { status.stringValue = "No remembered view"; return }
        scrollingView.contentView.scroll(to: origin)
        scrollingView.reflectScrolledClipView(scrollingView.contentView)
    }

    @objc private func saveScratch(_ sender: Any?) {
        do {
            // This destination is fixed by the launch argument. No GUI field can choose a path.
            try input.stringValue.write(to: destination, atomically: true, encoding: .utf8)
            status.stringValue = "Saved scratch: " + input.stringValue
        } catch {
            status.stringValue = "Save failed: " + error.localizedDescription
        }
    }

    @objc private func openDialog(_ sender: Any?) {
        if let smallWindow { smallWindow.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(x: 560, y: 470, width: 180, height: 120),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Fixture small dialog"
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.setAccessibilityIdentifier("fixture.small")
        window.isReleasedWhenClosed = false
        let field = NSTextField(frame: NSRect(x: 15, y: 65, width: 150, height: 26))
        field.stringValue = ""
        identify(field, "fixture.dialog-input", "Dialog input")
        window.contentView?.addSubview(field)
        window.contentView?.addSubview(button("Close dialog", NSRect(x: 15, y: 16, width: 150, height: 30), "fixture.close-dialog", #selector(closeDialog(_:))))
        smallWindow = window
        window.setFrameOrigin(NSPoint(x: mainWindow.frame.midX - window.frame.width / 2,
                                      y: mainWindow.frame.midY - window.frame.height / 2))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func closeDialog(_ sender: Any?) {
        smallWindow?.close()
        smallWindow = nil
        mainWindow.makeKeyAndOrderFront(nil)
    }

    @objc private func quit(_ sender: Any?) { NSApp.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct FixtureMain {
    @MainActor static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count == 2, arguments[0] == "--scratch-file",
              arguments[1].hasPrefix("/"), !arguments[1].contains("\0") else {
            fputs("Use --scratch-file ABSOLUTE_TEST_FILE\n", stderr)
            exit(2)
        }
        let destination = URL(fileURLWithPath: arguments[1]).standardizedFileURL
        guard FileManager.default.fileExists(atPath: destination.deletingLastPathComponent().path) else {
            fputs("Scratch parent directory must exist\n", stderr)
            exit(2)
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = FixtureDelegate(destination: destination)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
