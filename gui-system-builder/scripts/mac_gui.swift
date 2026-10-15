// Profile-bound native GUI helper. macOS 14+, Swift 5 language mode, no third-party libraries.
// Build: xcrun swiftc -parse-as-library -swift-version 5 mac_gui.swift -o mac_gui
// Every call requires an explicit bundle identifier and profile fingerprint. It never requests privacy grants,
// injects code, sends network requests, or starts autonomous model jobs.
// Explicitly requested GUI actions can submit work or change app state.
// Snapshot paths are temporary addresses. Mutations require the saved snapshot,
// then re-read the current element and compare its identity before acting.
import AppKit
import ApplicationServices
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

// Set exactly once from required command arguments before any target lookup.
// Calls remain on the main actor. There is no persistent default application.
@MainActor var bundleID = ""
@MainActor var profileSHA256 = ""
@MainActor var requestedPID: pid_t? = nil
@MainActor var expectedAppPath: String? = nil
let snapshotMaxAgeSeconds: TimeInterval = 120

struct Failure: Error {
    let code: String
    let message: String
    let exit: Int32
}

func fail(_ code: String, _ message: String, _ exit: Int32 = 2) -> Failure {
    Failure(code: code, message: message, exit: exit)
}

func requireAccessibilityActionResult(_ result: AXError, _ operation: String, failureCode: String = "ACTION_FAILED") throws {
    if result == .success { return }
    if result == .cannotComplete {
        throw fail("ACTION_OUTCOME_UNKNOWN", "\(operation) returned accessibility messaging failure \(result.rawValue). The application may have performed the request. Inspect its current state before any repeat.", 8)
    }
    throw fail(failureCode, "\(operation) returned accessibility error \(result.rawValue). Inspect the application before retrying.", 8)
}

func emit(_ object: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
       let text = String(data: data, encoding: .utf8) { print(text) }
}

func attr(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func axElements(_ value: CFTypeRef?) -> [AXUIElement] {
    guard let value, CFGetTypeID(value) == CFArrayGetTypeID() else { return [] }
    return (value as! [AnyObject]).compactMap { object in
        CFGetTypeID(object) == AXUIElementGetTypeID() ? (object as! AXUIElement) : nil
    }
}

func axElement(_ value: CFTypeRef?) -> AXUIElement? {
    guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return (value as! AXUIElement)
}

func stringAttr(_ element: AXUIElement, _ name: String) -> String {
    guard let value = attr(element, name) else { return "" }
    if let string = value as? String { return string }
    if let number = value as? NSNumber { return number.stringValue }
    return ""
}

func digest(_ string: String) -> String {
    SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
}

func isSecure(_ element: AXUIElement) -> Bool {
    let role = stringAttr(element, kAXRoleAttribute)
    let subrole = stringAttr(element, kAXSubroleAttribute)
    return role == "AXSecureTextField" || subrole == "AXSecureTextField"
}

func safeValue(_ element: AXUIElement) -> String {
    // Do not call AXValue for a password field, even when macOS might mask it.
    isSecure(element) ? "[REDACTED_SECURE_FIELD]" : stringAttr(element, kAXValueAttribute)
}

func bounds(_ element: AXUIElement) -> CGRect {
    var point = CGPoint.zero, size = CGSize.zero
    if let raw = attr(element, kAXPositionAttribute), CFGetTypeID(raw) == AXValueGetTypeID() {
        AXValueGetValue(raw as! AXValue, .cgPoint, &point)
    }
    if let raw = attr(element, kAXSizeAttribute), CFGetTypeID(raw) == AXValueGetTypeID() {
        AXValueGetValue(raw as! AXValue, .cgSize, &size)
    }
    return CGRect(origin: point, size: size)
}

func rectJSON(_ rect: CGRect) -> [String: Double] {
    ["x": Double(rect.minX), "y": Double(rect.minY),
     "width": Double(rect.width), "height": Double(rect.height)]
}

func label(_ element: AXUIElement) -> String {
    for key in [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute] {
        let value = stringAttr(element, key)
        if !value.isEmpty { return value }
    }
    if let title = axElement(attr(element, kAXTitleUIElementAttribute)) {
        let value = stringAttr(title, kAXValueAttribute)
        if !value.isEmpty { return value }
    }
    return ""
}

func actions(_ element: AXUIElement) -> [String] {
    var names: CFArray?
    if AXUIElementCopyActionNames(element, &names) != .success { return [] }
    return names as? [String] ?? []
}

struct WindowContext {
    let app: NSRunningApplication
    let root: AXUIElement
    let main: AXUIElement
    let windowID: CGWindowID
    let rect: CGRect
}

@MainActor func runningApp() throws -> NSRunningApplication {
    let matching = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        .filter { !$0.isTerminated }
    let apps = requestedPID.map { wanted in matching.filter { $0.processIdentifier == wanted } } ?? matching
    guard apps.count == 1, let app = apps.first else {
        throw fail("APP_NOT_RUNNING", "Expected exactly one running application matching the explicit bundle identifier and optional process selector; found \(apps.count).", 3)
    }
    guard app.bundleIdentifier == bundleID, app.bundleURL != nil, app.launchDate != nil else {
        throw fail("APP_IDENTITY_UNAVAILABLE", "The selected application's bundle path or process launch date is unavailable. No target action was attempted.", 3)
    }
    if let expectedAppPath {
        guard app.bundleURL?.resolvingSymlinksInPath().standardizedFileURL.path == expectedAppPath else {
            throw fail("APP_PATH_MISMATCH", "The running application's resolved bundle path differs from the explicit expected path. No observation or action was attempted.", 3)
        }
    }
    return app
}

@MainActor func applicationIdentity(_ app: NSRunningApplication) -> [String: Any] {
    ["bundle_id": app.bundleIdentifier ?? "", "app_path": app.bundleURL?.resolvingSymlinksInPath().standardizedFileURL.path ?? "",
     "pid": app.processIdentifier, "process_launch_time": app.launchDate?.timeIntervalSince1970 ?? -1,
     "profile_sha256": profileSHA256]
}

func cgWindows(_ pid: pid_t) -> [[String: Any]] {
    let all = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    return all.filter { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid }
}

func cgRect(_ window: [String: Any]) -> CGRect {
    guard let value = window[kCGWindowBounds as String] as? NSDictionary,
          let rect = CGRect(dictionaryRepresentation: value) else { return .zero }
    return rect
}

@MainActor func context(_ enhance: Bool = false, selectedWindowID: CGWindowID? = nil) throws -> (WindowContext, [String: Any]) {
    let app = try runningApp()
    guard AXIsProcessTrusted() else {
        throw fail("ACCESSIBILITY_UNAVAILABLE", "macOS reports that this helper process cannot use accessibility. A different tool can have separate access, and a sandbox can also restrict this process. No permission request was made.", 4)
    }
    let root = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(root, 3)
    var enhancement: [String: Any] = ["requested": enhance]
    if enhance {
        // Ephemeral Electron accessibility-tree exposure, not a saved app setting.
        for key in ["AXEnhancedUserInterface", "AXManualAccessibility"] {
            let result = AXUIElementSetAttributeValue(root, key as CFString, kCFBooleanTrue)
            enhancement[key] = result.rawValue
        }
        Thread.sleep(forTimeInterval: 0.15)
    }
    let minimumWidth: CGFloat = selectedWindowID == nil ? 200 : 1
    let minimumHeight: CGFloat = selectedWindowID == nil ? 150 : 1
    let windows = axElements(attr(root, kAXWindowsAttribute))
        .filter { bounds($0).width >= minimumWidth && bounds($0).height >= minimumHeight }
    let nativeWindows = cgWindows(app.processIdentifier).filter {
        let rect = cgRect($0)
        return rect.width >= minimumWidth && rect.height >= minimumHeight &&
            ($0[kCGWindowLayer as String] as? NSNumber)?.intValue == 0 &&
            (selectedWindowID == nil || ($0[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue == true)
    }
    func rectsMatch(_ left: CGRect, _ right: CGRect) -> Bool {
        abs(left.minX - right.minX) <= 12 && abs(left.minY - right.minY) <= 12 &&
        abs(left.width - right.width) <= 12 && abs(left.height - right.height) <= 12
    }
    let main: AXUIElement
    if let selectedWindowID {
        let selected = nativeWindows.filter {
            ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == selectedWindowID
        }
        guard selected.count == 1 else {
            throw fail("SELECTED_WINDOW_UNAVAILABLE", "The requested window id does not identify an visible ordinary application-owned window at least one by one point.", 5)
        }
        let matches = windows.filter { rectsMatch(bounds($0), cgRect(selected[0])) }
        guard matches.count == 1 else {
            throw fail("SELECTED_WINDOW_UNAVAILABLE", "The requested selected application native window could not be matched to exactly one accessible window.", 5)
        }
        main = matches[0]
    } else {
        guard let largest = windows.max(by: {
            let left = bounds($0), right = bounds($1)
            return left.width * left.height < right.width * right.height
        }) else { throw fail("MAIN_WINDOW_UNAVAILABLE", "selected application did not expose a main window at least 200 by 150 points. Tiny overlay windows are excluded.", 5) }
        main = largest
    }
    let rect = bounds(main)
    let matches = nativeWindows.filter {
        let candidate = cgRect($0)
        let matchingID = selectedWindowID == nil || ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == selectedWindowID
        return matchingID && rectsMatch(candidate, rect)
    }
    guard matches.count == 1, let number = matches[0][kCGWindowNumber as String] as? NSNumber else {
        throw fail("WINDOW_ID_UNAVAILABLE", "Could not match the selected application main window to exactly one native window. No action or full-screen screenshot was attempted.", 5)
    }
    return (WindowContext(app: app, root: root, main: main, windowID: number.uint32Value, rect: rect), enhancement)
}

@MainActor func identity(_ element: AXUIElement, _ context: WindowContext, _ path: String) -> [String: Any] {
    ["pid": context.app.processIdentifier, "application_identity": applicationIdentity(context.app),
     "window_id": context.windowID, "path": path,
     "role": stringAttr(element, kAXRoleAttribute),
     "subrole": stringAttr(element, kAXSubroleAttribute),
     "label": label(element), "identifier": stringAttr(element, kAXIdentifierAttribute),
     "secure": isSecure(element), "value_sha256": digest(safeValue(element)),
     "bounds": rectJSON(bounds(element))]
}

func sameJSON(_ left: Any, _ right: Any) -> Bool {
    guard JSONSerialization.isValidJSONObject(left), JSONSerialization.isValidJSONObject(right),
          let a = try? JSONSerialization.data(withJSONObject: left, options: [.sortedKeys]),
          let b = try? JSONSerialization.data(withJSONObject: right, options: [.sortedKeys]) else { return false }
    return a == b
}

@MainActor func appInfo() throws -> [String: Any] {
    let app = try runningApp()
    let front = NSWorkspace.shared.frontmostApplication
    var result: [String: Any] = ["ok": true, "bundle_id": bundleID, "pid": app.processIdentifier,
        "app_path": app.bundleURL?.resolvingSymlinksInPath().standardizedFileURL.path ?? "", "application_identity": applicationIdentity(app),
        "version": app.bundleURL.flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String } as Any? ?? NSNull(),
        "build": app.bundleURL.flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleVersion") as? String } as Any? ?? NSNull(),
        "accessibility_trusted": AXIsProcessTrusted(),
        "screen_capture_available": CGPreflightScreenCaptureAccess(),
        "input_posting_available": CGPreflightPostEventAccess(),
        "is_frontmost": front?.processIdentifier == app.processIdentifier,
        "frontmost_bundle_id": front?.bundleIdentifier ?? "",
        "windows": cgWindows(app.processIdentifier).map { window in
            ["window_id": (window[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0,
             "bounds": rectJSON(cgRect(window)),
             "layer": (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -1,
             "on_screen": (window[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false] as [String: Any]
        }]
    if AXIsProcessTrusted(), let (ctx, _) = try? context(),
       let focused = axElement(attr(ctx.root, kAXFocusedUIElementAttribute)) {
        result["focused_element"] = identity(focused, ctx, "focused")
        result["main_window_id"] = ctx.windowID
    }
    return result
}

func parseArgs() throws -> (String, [String: String], Set<String>) {
    let raw = Array(CommandLine.arguments.dropFirst())
    guard let command = raw.first else { throw fail("USAGE", usage) }
    var options: [String: String] = [:], flags = Set<String>(), index = 1
    let flagNames: Set<String> = ["--enhance", "--screenshot", "--value-stdin"]
    while index < raw.count {
        let key = raw[index]
        guard key.hasPrefix("--"), options[key] == nil, !flags.contains(key) else {
            throw fail("INVALID_ARGUMENT", "Unknown positional or duplicate argument: \(key)")
        }
        if flagNames.contains(key) { flags.insert(key); index += 1; continue }
        guard index + 1 < raw.count else { throw fail("INVALID_ARGUMENT", "Missing value for \(key)") }
        options[key] = raw[index + 1]; index += 2
    }
    return (command, options, flags)
}

@MainActor func configureTarget(_ options: [String: String]) throws -> [String: String] {
    guard let suppliedBundle = options["--bundle-id"], suppliedBundle.count <= 255,
          suppliedBundle.range(of: "^[A-Za-z0-9][A-Za-z0-9.-]*$", options: .regularExpression) != nil,
          !suppliedBundle.contains(".."), !suppliedBundle.hasSuffix(".") else {
        throw fail("INVALID_TARGET", "Every call requires --bundle-id with an explicit application bundle identifier. There is no default target.")
    }
    guard let fingerprint = options["--profile-sha256"], fingerprint.count == 64,
          fingerprint.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
        throw fail("INVALID_PROFILE_FINGERPRINT", "Every call requires --profile-sha256 with the exact lowercase SHA-256 fingerprint of its profile.")
    }
    var pid: pid_t? = nil
    if let raw = options["--pid"] {
        guard let value = Int32(raw), value > 0 else {
            throw fail("INVALID_PROCESS_SELECTOR", "--pid requires a positive process number belonging to the supplied bundle identifier.")
        }
        pid = value
    }
    var expectedPath: String? = nil
    if let raw = options["--expected-app-path"] {
        guard raw.hasPrefix("/"), !raw.contains("\0") else {
            throw fail("INVALID_APP_PATH", "--expected-app-path requires an absolute application bundle path.")
        }
        expectedPath = URL(fileURLWithPath: raw).resolvingSymlinksInPath().standardizedFileURL.path
    }
    bundleID = suppliedBundle; profileSHA256 = fingerprint; requestedPID = pid; expectedAppPath = expectedPath
    var local = options
    for key in ["--bundle-id", "--profile-sha256", "--pid", "--expected-app-path"] { local.removeValue(forKey: key) }
    return local
}

func validateOptions(_ options: [String: String], _ flags: Set<String>, _ allowed: Set<String>) throws {
    for key in Set(options.keys).union(flags) where !allowed.contains(key) {
        throw fail("INVALID_ARGUMENT", "Unsupported option: \(key)")
    }
}

func integerOption(_ options: [String: String], _ key: String, _ fallback: Int, _ range: ClosedRange<Int>) throws -> Int {
    guard let raw = options[key] else { return fallback }
    guard let value = Int(raw), range.contains(value) else { throw fail("INVALID_ARGUMENT", "\(key) must be within \(range).") }
    return value
}

func selectedWindowOption(_ options: [String: String]) throws -> CGWindowID? {
    guard let raw = options["--window-id"] else { return nil }
    guard let number = UInt32(raw), number > 0 else { throw fail("INVALID_ARGUMENT", "--window-id requires a positive native window id from info.") }
    return number
}

func requiredPath(_ options: [String: String], _ key: String) throws -> String {
    guard let path = options[key], path.hasPrefix("/"), !path.contains("\0") else {
        throw fail("INVALID_ARGUMENT", "\(key) requires an absolute filesystem path.")
    }
    return path
}

func saveJSON(_ object: [String: Any], _ path: String) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    let descriptor = Darwin.open(path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, mode_t(0o600))
    guard descriptor >= 0 else { throw fail("OUTPUT_CREATE_FAILED", "Could not create a new owner-only snapshot file (error \(errno)).", 9) }
    let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    try handle.write(contentsOf: data)
    try handle.synchronize()
    try handle.close()
}

@MainActor func checkedCaptureWindow(_ expected: WindowContext) throws -> CGRect {
    let (current, _) = try context(false, selectedWindowID: expected.windowID)
    guard sameJSON(applicationIdentity(current.app), applicationIdentity(expected.app)),
          current.windowID == expected.windowID, CFEqual(current.main, expected.main),
          sameJSON(rectJSON(current.rect), rectJSON(expected.rect)) else {
        throw fail("CAPTURE_WINDOW_CHANGED", "The selected application's process generation, exact window, or window bounds changed. Observe again; no capture is accepted.", 11)
    }
    let native = cgWindows(current.app.processIdentifier).filter {
        ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == current.windowID
    }
    guard native.count == 1 else {
        throw fail("CAPTURE_WINDOW_UNAVAILABLE", "The exact selected native window is no longer uniquely owned by the selected process. No capture is accepted.", 11)
    }
    let rect = cgRect(native[0])
    guard rect.width > 0, rect.height > 0,
          abs(rect.minX - current.rect.minX) <= 2, abs(rect.minY - current.rect.minY) <= 2,
          abs(rect.width - current.rect.width) <= 2, abs(rect.height - current.rect.height) <= 2 else {
        throw fail("CAPTURE_GEOMETRY_CHANGED", "Native window bounds do not match the observed accessibility window closely enough for exact-window scale conversion. Observe again; no capture is accepted.", 11)
    }
    return rect
}

@MainActor func screenshot(_ ctx: WindowContext, _ path: String) throws -> [String: Any] {
    guard CGPreflightScreenCaptureAccess() else {
        throw fail("SCREEN_CAPTURE_UNAVAILABLE", "This helper process cannot capture the screen under its current permissions or sandbox. No privacy prompt was opened.", 10)
    }
    let nativeBefore = try checkedCaptureWindow(ctx)
    let descriptor = Darwin.open(path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
    guard descriptor >= 0 else {
        throw fail("CAPTURE_OUTPUT_FAILED", "Could not reserve a new owner-only capture file without replacing an existing path (error \(errno)).", 9)
    }
    Darwin.close(descriptor)
    // Restrict any file the owned child creates or atomically replaces during
    // capture. The helper handles one call, and restores its own process mask.
    let previousMask = Darwin.umask(mode_t(0o077))
    defer { _ = Darwin.umask(previousMask) }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    process.arguments = ["-x", "-o", "-a", "-l" + String(ctx.windowID), path]
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do { try process.run() }
    catch {
        throw fail("CAPTURE_LAUNCH_FAILED", "The fixed Apple exact-window capture program could not start: \(error.localizedDescription). The reserved file does not establish a capture.", 11)
    }
    let timeout: TimeInterval = 10
    let deadline = ProcessInfo.processInfo.systemUptime + timeout
    while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline {
        Thread.sleep(forTimeInterval: 0.02)
    }
    if process.isRunning {
        process.terminate()
        let terminationDeadline = ProcessInfo.processInfo.systemUptime + 0.75
        while process.isRunning && ProcessInfo.processInfo.systemUptime < terminationDeadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning {
            _ = Darwin.kill(process.processIdentifier, SIGKILL)
            let killDeadline = ProcessInfo.processInfo.systemUptime + 0.75
            while process.isRunning && ProcessInfo.processInfo.systemUptime < killDeadline {
                Thread.sleep(forTimeInterval: 0.02)
            }
        }
        throw fail("CAPTURE_TIMEOUT", "The owned exact-window capture child exceeded its ten-second deadline. It was asked to stop; a partial output is not accepted. No display-wide capture or input was attempted.", 11)
    }
    guard process.terminationReason == .exit, process.terminationStatus == 0 else {
        throw fail("CAPTURE_PROCESS_FAILED", "Apple's exact-window capture child ended with status \(process.terminationStatus) and termination reason \(process.terminationReason.rawValue). The reserved file does not establish a capture.", 11)
    }
    let nativeAfter = try checkedCaptureWindow(ctx)
    guard sameJSON(rectJSON(nativeBefore), rectJSON(nativeAfter)) else {
        throw fail("CAPTURE_GEOMETRY_CHANGED", "The exact native window's bounds changed while capture was running. The captured output is not accepted; observe again.", 11)
    }
    var fileInfo = stat()
    guard Darwin.lstat(path, &fileInfo) == 0,
          (fileInfo.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG), fileInfo.st_uid == Darwin.getuid(),
          fileInfo.st_size > 0 else {
        throw fail("CAPTURE_OUTPUT_FAILED", "The capture output is missing, empty, not a regular file, or not owned by this user. It is not accepted.", 11)
    }
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
          CGImageSourceGetType(source) as String? == UTType.png.identifier,
          CGImageSourceGetCount(source) == 1,
          let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary) else {
        throw fail("CAPTURE_FORMAT_INVALID", "The accepted exact-window child did not produce one readable PNG image. No alternate display capture was attempted.", 11)
    }
    let scaleX = Double(image.width) / Double(ctx.rect.width)
    let scaleY = Double(image.height) / Double(ctx.rect.height)
    let tolerance = max(1 / Double(ctx.rect.width), 1 / Double(ctx.rect.height)) + 0.000001
    guard image.width > 0, image.height > 0, scaleX.isFinite, scaleY.isFinite,
          scaleX > 0, scaleY > 0, abs(scaleX - scaleY) <= tolerance else {
        throw fail("CAPTURE_SIZE_MISMATCH", "PNG dimensions do not give compatible horizontal and vertical scales for the full selected window. The capture is not accepted.", 11)
    }
    return ["capture_backend": "apple-screencapture-exact-window", "capture_executable": "/usr/sbin/screencapture",
        "captured_window_id": ctx.windowID, "pixel_width": image.width, "pixel_height": image.height,
        "point_pixel_scale": (scaleX + scaleY) / 2,
        "content_rect_points": rectJSON(CGRect(x: 0, y: 0, width: ctx.rect.width, height: ctx.rect.height)),
        "window_to_image_scale_x": scaleX, "window_to_image_scale_y": scaleY,
        "shadows_excluded": true, "attached_windows_excluded": true,
        "window_generation_verified": true, "window_bounds_verified": true,
        "child_exit_verified": true, "capture_timeout_seconds": timeout]
}

@MainActor func snapshot(_ options: [String: String], _ flags: Set<String>) async throws -> [String: Any] {
    try validateOptions(options, flags, ["--output-dir", "--max-depth", "--max-nodes", "--max-value-chars", "--enhance", "--screenshot", "--window-id"])
    let outputDir = try requiredPath(options, "--output-dir")
    let maxDepth = try integerOption(options, "--max-depth", 50, 1...80)
    let maxNodes = try integerOption(options, "--max-nodes", 1600, 1...20000)
    let valueLimit = try integerOption(options, "--max-value-chars", 160, 0...4096)
    let chosenWindow = try selectedWindowOption(options)
    let (ctx, enhancement) = try context(flags.contains("--enhance"), selectedWindowID: chosenWindow)
    var nodes: [[String: Any]] = [], truncated = false, focusID: String?
    let focused = axElement(attr(ctx.root, kAXFocusedUIElementAttribute))
    func walk(_ element: AXUIElement, _ path: String, _ depth: Int, _ ancestors: [AXUIElement]) {
        if nodes.count >= maxNodes { truncated = true; return }
        if ancestors.contains(where: { CFEqual($0, element) }) { truncated = true; return }
        let secure = isSecure(element)
        let value = safeValue(element)
        let children = axElements(attr(element, kAXChildrenAttribute))
        var node: [String: Any] = ["id": path, "identity": identity(element, ctx, path),
            "role": stringAttr(element, kAXRoleAttribute), "label": label(element),
            "bounds": rectJSON(bounds(element)), "actions": actions(element), "child_count": children.count,
            "enabled": (attr(element, kAXEnabledAttribute) as? NSNumber)?.boolValue ?? true,
            "value": secure ? "[REDACTED_SECURE_FIELD]" : String(value.prefix(valueLimit)),
            "value_redacted": secure, "value_truncated": !secure && value.count > valueLimit]
        var settable: DarwinBoolean = false
        node["value_settable"] = !secure && AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success && settable.boolValue
        nodes.append(node)
        if let focused, CFEqual(focused, element) { focusID = path }
        if depth >= maxDepth { if !children.isEmpty { truncated = true }; return }
        for (index, child) in children.enumerated() { walk(child, "\(path)/\(index)", depth + 1, ancestors + [element]) }
    }
    walk(ctx.main, "main", 0, [])
    if let menu = axElement(attr(ctx.root, kAXMenuBarAttribute)) { walk(menu, "menu", 0, []) }
    try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let base = "gui-" + UUID().uuidString.lowercased()
    let jsonPath = URL(fileURLWithPath: outputDir).appendingPathComponent(base + ".json").path
    let imagePath = URL(fileURLWithPath: outputDir).appendingPathComponent(base + ".png").path
    var result: [String: Any] = ["schema_version": 2, "bundle_id": bundleID,
        "profile_sha256": profileSHA256, "application_identity": applicationIdentity(ctx.app),
        "captured_at": ISO8601DateFormatter().string(from: Date()), "snapshot_max_age_seconds": snapshotMaxAgeSeconds,
        "pid": ctx.app.processIdentifier,
        "window_id": ctx.windowID, "main_window_bounds": rectJSON(ctx.rect),
        "selected_window_id": ctx.windowID, "window_selection": chosenWindow == nil ? "largest" : "explicit",
        "frontmost_bundle_id": NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "",
        "enhancement": enhancement, "nodes": nodes, "node_count": nodes.count,
        "truncated": truncated, "focused_id": focusID as Any? ?? NSNull()]
    if flags.contains("--screenshot") {
        let geometry = try screenshot(ctx, imagePath)
        result["screenshot_geometry"] = geometry
        result["capture_backend"] = geometry["capture_backend"]
        result["screenshot_file"] = imagePath
    }
    try saveJSON(result, jsonPath)
    var summary: [String: Any] = ["ok": true, "snapshot_file": jsonPath,
        "node_count": nodes.count, "truncated": truncated, "window_id": ctx.windowID,
        "window_selection": chosenWindow == nil ? "largest" : "explicit",
        "main_window_bounds": rectJSON(ctx.rect), "enhancement": enhancement,
        "focused_id": focusID as Any? ?? NSNull()]
    if flags.contains("--screenshot") {
        summary["screenshot_file"] = imagePath
        summary["screenshot_geometry"] = result["screenshot_geometry"]
        summary["capture_backend"] = result["capture_backend"]
    }
    return summary
}

@MainActor func loadSnapshot(_ options: [String: String]) throws -> [String: Any] {
    let path = try requiredPath(options, "--snapshot")
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    guard let saved = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          (saved["schema_version"] as? NSNumber)?.intValue == 2,
          saved["bundle_id"] as? String == bundleID,
          saved["profile_sha256"] as? String == profileSHA256,
          saved["application_identity"] is [String: Any],
          saved["nodes"] is [[String: Any]],
          let windowID = saved["window_id"] as? NSNumber, windowID.uint32Value > 0 else {
        throw fail("INVALID_SNAPSHOT", "Snapshot is not a supported selected application snapshot.", 6)
    }
    guard let timestamp = saved["captured_at"] as? String,
          let captured = ISO8601DateFormatter().date(from: timestamp),
          Date().timeIntervalSince(captured) >= 0,
          Date().timeIntervalSince(captured) <= snapshotMaxAgeSeconds else {
        throw fail("SNAPSHOT_EXPIRED", "The saved snapshot is missing a valid capture time or is older than 120 seconds. Take a new snapshot; no action or input was performed.", 6)
    }
    return saved
}

@MainActor func checkedTarget(_ options: [String: String]) throws -> (AXUIElement, WindowContext, String) {
    let saved = try loadSnapshot(options)
    guard let id = options["--id"], let nodes = saved["nodes"] as? [[String: Any]],
          let expected = nodes.first(where: { $0["id"] as? String == id })?["identity"] as? [String: Any] else {
        throw fail("INVALID_ELEMENT_ID", "--id requires an element id from the saved snapshot.", 6)
    }
    let parts = id.split(separator: "/").map(String.init)
    guard let kind = parts.first, ["main", "menu"].contains(kind) else { throw fail("INVALID_ELEMENT_ID", "Element id must begin with main or menu.", 6) }
    let enhance = (saved["enhancement"] as? [String: Any])?["requested"] as? Bool ?? false
    let (ctx, _) = try context(enhance, selectedWindowID: (saved["window_id"] as? NSNumber)?.uint32Value)
    guard let savedIdentity = saved["application_identity"], sameJSON(savedIdentity, applicationIdentity(ctx.app)) else {
        throw fail("SNAPSHOT_STALE", "The application bundle path, process generation, or profile differs from the saved snapshot. Take a new snapshot; no action was performed.", 6)
    }
    var element: AXUIElement
    if kind == "main" { element = ctx.main }
    else if let menu = axElement(attr(ctx.root, kAXMenuBarAttribute)) { element = menu }
    else { throw fail("SNAPSHOT_STALE", "selected application's menu bar no longer matches the saved snapshot. Take a new snapshot.", 6) }
    for component in parts.dropFirst() {
        guard let index = Int(component), index >= 0 else { throw fail("INVALID_ELEMENT_ID", "Element path has an invalid child index.", 6) }
        let children = axElements(attr(element, kAXChildrenAttribute))
        guard index < children.count else { throw fail("SNAPSHOT_STALE", "The element path no longer exists. Take a new snapshot.", 6) }
        element = children[index]
    }
    guard sameJSON(expected, identity(element, ctx, id)) else {
        throw fail("SNAPSHOT_STALE", "The current element's app process, window, role, label, identifier, value, or bounds differ from the saved snapshot. Take a new snapshot; no action was performed.", 6)
    }
    return (element, ctx, id)
}

@MainActor func checkedInputWindow(_ options: [String: String]) throws -> WindowContext {
    let saved = try loadSnapshot(options)
    let enhance = (saved["enhancement"] as? [String: Any])?["requested"] as? Bool ?? false
    let (ctx, _) = try context(enhance, selectedWindowID: (saved["window_id"] as? NSNumber)?.uint32Value)
    guard let savedIdentity = saved["application_identity"], sameJSON(savedIdentity, applicationIdentity(ctx.app)),
          (saved["pid"] as? NSNumber)?.int32Value == ctx.app.processIdentifier,
          (saved["window_id"] as? NSNumber)?.uint32Value == ctx.windowID,
          let expectedBounds = saved["main_window_bounds"], sameJSON(expectedBounds, rectJSON(ctx.rect)),
          let nodes = saved["nodes"] as? [[String: Any]],
          let expected = nodes.first(where: { $0["id"] as? String == "main" })?["identity"],
          sameJSON(expected, identity(ctx.main, ctx, "main")) else {
        throw fail("SNAPSHOT_STALE", "The selected application process or main window changed. Take a new snapshot; no input was sent.", 6)
    }
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == ctx.app.processIdentifier else {
        throw fail("APP_NOT_FRONTMOST", "selected application must already be the frontmost app for mouse or keyboard input. Activate it, verify its focus, and take a new snapshot; no input was sent.", 8)
    }
    guard let focusedWindow = axElement(attr(ctx.root, kAXFocusedWindowAttribute)), CFEqual(focusedWindow, ctx.main) else {
        throw fail("SELECTED_WINDOW_NOT_FOCUSED", "The exact selected application window must have native window focus before mouse or keyboard input. Observe and select the current dialog or raise the intended window, then take a new snapshot; no input was sent.", 8)
    }
    guard cgWindows(ctx.app.processIdentifier).contains(where: {
        ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == ctx.windowID &&
        ($0[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue == true
    }) else {
        throw fail("WINDOW_NOT_VISIBLE", "The selected application window is not currently on screen. No input was sent.", 8)
    }
    guard CGPreflightPostEventAccess() else {
        throw fail("INPUT_POSTING_UNAVAILABLE", "This process cannot post native input under its current permissions or sandbox. No permission request or input was sent.", 4)
    }
    return ctx
}

func numberOption(_ options: [String: String], _ key: String) throws -> Double {
    guard let raw = options[key], let number = Double(raw), number.isFinite else {
        throw fail("INVALID_ARGUMENT", "\(key) requires a finite number.")
    }
    return number
}

func windowPoint(_ options: [String: String], _ xKey: String, _ yKey: String, _ ctx: WindowContext) throws -> CGPoint {
    let x = try numberOption(options, xKey), y = try numberOption(options, yKey)
    guard x >= 0, y >= 0, x < ctx.rect.width, y < ctx.rect.height else {
        throw fail("POINT_OUTSIDE_WINDOW", "Mouse coordinates must lie within the selected application main window, measured in window points. No input was sent.", 7)
    }
    return CGPoint(x: ctx.rect.minX + x, y: ctx.rect.minY + y)
}

func requirePointOnActiveDisplay(_ point: CGPoint) throws {
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
        throw fail("DISPLAY_GEOMETRY_UNAVAILABLE", "Could not establish current active display bounds. No further pointer input was sent.", 8)
    }
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    let result = ids.withUnsafeMutableBufferPointer { buffer in
        CGGetActiveDisplayList(count, buffer.baseAddress, &count)
    }
    guard result == .success else {
        throw fail("DISPLAY_GEOMETRY_UNAVAILABLE", "Could not read current active display bounds. No further pointer input was sent.", 8)
    }
    guard ids.prefix(Int(count)).contains(where: { CGDisplayIsOnline($0) != 0 && CGDisplayBounds($0).contains(point) }) else {
        throw fail("POINT_OUTSIDE_DISPLAY", "The intended pointer position lies outside every active display. A window snapshot can show off-screen content. Observe and place the intended window on a display before sending pointer input; no further input was sent.", 8)
    }
}

func requireSelectedWindowAtPoint(_ ctx: WindowContext, _ point: CGPoint) throws {
    try requirePointOnActiveDisplay(point)
    // Apple's system-wide accessibility point query performs window z-order
    // hit-testing. A rectangular native window bound is not proof that its
    // contents cover this particular point, especially for transparent overlays.
    let systemWide = AXUIElementCreateSystemWide()
    AXUIElementSetMessagingTimeout(systemWide, 3)
    var hit: AXUIElement?
    let hitResult = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &hit)
    guard hitResult == .success, let hit else {
        throw fail("POINT_OWNERSHIP_UNAVAILABLE", "The system-wide accessibility hit test did not identify the topmost element at the intended position (error \(hitResult.rawValue)). Observe the actual point and selected window before retrying. No further pointer input was sent to that position.", 8)
    }
    var hitPID: pid_t = 0
    guard AXUIElementGetPid(hit, &hitPID) == .success, hitPID == ctx.app.processIdentifier else {
        throw fail("WINDOW_OCCLUDED", "The topmost accessibility element at the intended position belongs to a different or unknown application process. Observe the actual point and selected window before retrying. No further pointer input was sent to that position.", 8)
    }
    let hitWindow: AXUIElement?
    if stringAttr(hit, kAXRoleAttribute) == kAXWindowRole { hitWindow = hit }
    else { hitWindow = axElement(attr(hit, kAXWindowAttribute)) }
    guard let hitWindow else {
        throw fail("POINT_WINDOW_UNAVAILABLE", "The topmost accessibility element did not expose its containing window. The exact selected window could not be verified. No further pointer input was sent to that position.", 8)
    }
    guard CFEqual(hitWindow, ctx.main) else {
        throw fail("WINDOW_OCCLUDED", "The topmost accessibility element at the intended position belongs to another window. Observe and select that exact window before retrying. No further pointer input was sent to that position.", 8)
    }
}

func inputSource() throws -> CGEventSource {
    guard let source = CGEventSource(stateID: .hidSystemState) else {
        throw fail("INPUT_CREATION_FAILED", "Could not create native input events; no input was sent.", 8)
    }
    return source
}

@MainActor func inputResult(_ command: String, _ ctx: WindowContext) -> [String: Any] {
    var result: [String: Any] = ["ok": true, "performed": command, "window_id": ctx.windowID,
     "application_identity": applicationIdentity(ctx.app), "verified": false,
     "next_step": "Take a new snapshot and verify the expected visible change. Posted input alone does not prove app behavior."]
    if ["click", "scroll", "drag"].contains(command) {
        result["point_ownership_method"] = "system-wide-accessibility-z-order"
    }
    return result
}

@MainActor func click(_ options: [String: String], _ flags: Set<String>) throws -> [String: Any] {
    try validateOptions(options, flags, ["--snapshot", "--x", "--y", "--button", "--count"])
    let count = try integerOption(options, "--count", 1, 1...2)
    let buttonName = options["--button"] ?? "left"
    guard ["left", "right"].contains(buttonName) else { throw fail("INVALID_ARGUMENT", "--button must be left or right.") }
    let ctx = try checkedInputWindow(options)
    let point = try windowPoint(options, "--x", "--y", ctx), source = try inputSource()
    try requireSelectedWindowAtPoint(ctx, point)
    let button: CGMouseButton = buttonName == "left" ? .left : .right
    let downType: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
    let upType: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp
    var events: [CGEvent] = []
    for index in 1...count {
        guard let down = CGEvent(mouseEventSource: source, mouseType: downType, mouseCursorPosition: point, mouseButton: button),
              let up = CGEvent(mouseEventSource: source, mouseType: upType, mouseCursorPosition: point, mouseButton: button) else {
            throw fail("INPUT_CREATION_FAILED", "Could not create the click; no input was sent.", 8)
        }
        down.setIntegerValueField(.mouseEventClickState, value: Int64(index))
        up.setIntegerValueField(.mouseEventClickState, value: Int64(index))
        events += [down, up]
    }
    for index in stride(from: 0, to: events.count, by: 2) {
        let current = try checkedInputWindow(options)
        guard sameJSON(applicationIdentity(current.app), applicationIdentity(ctx.app)) else {
            throw fail("SNAPSHOT_STALE", "The selected application process generation changed before the next click. No further input was sent.", 8)
        }
        try requireSelectedWindowAtPoint(current, point)
        // Always release a posted down event, even when the click changes focus.
        events[index].post(tap: .cghidEventTap)
        events[index + 1].post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.06)
    }
    return inputResult("click", ctx)
}

@MainActor func hotkey(_ options: [String: String], _ flags: Set<String>) throws -> [String: Any] {
    try validateOptions(options, flags, ["--snapshot", "--keys"])
    guard let raw = options["--keys"], raw == raw.lowercased(), raw.count <= 100 else {
        throw fail("INVALID_ARGUMENT", "--keys requires one lowercase chord, such as cmd+k or shift+enter.")
    }
    let pieces = raw.split(separator: "+", omittingEmptySubsequences: false).map(String.init)
    guard let key = pieces.last, !key.isEmpty else { throw fail("INVALID_ARGUMENT", "A hotkey requires a final key name.") }
    let modifiers: [String: CGEventFlags] = ["cmd": .maskCommand, "ctrl": .maskControl, "alt": .maskAlternate, "shift": .maskShift]
    let keyMap: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11,
        "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21,
        "6": 22, "5": 23, "equal": 24, "9": 25, "7": 26, "minus": 27, "8": 28, "0": 29, "rightbracket": 30,
        "o": 31, "u": 32, "leftbracket": 33, "i": 34, "p": 35, "enter": 36, "l": 37, "j": 38, "quote": 39,
        "k": 40, "semicolon": 41, "backslash": 42, "comma": 43, "slash": 44, "n": 45, "m": 46, "period": 47,
        "tab": 48, "space": 49, "backtick": 50, "backspace": 51, "escape": 53, "home": 115, "pageup": 116,
        "delete": 117, "end": 119, "pagedown": 121, "left": 123, "right": 124, "down": 125, "up": 126,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100,
        "f9": 101, "f10": 109, "f11": 103, "f12": 111]
    guard let code = keyMap[key] else { throw fail("UNSUPPORTED_KEY", "Unknown key name. Supported names are single letters, digits, named punctuation, navigation keys, and f1 through f12.", 7) }
    var eventFlags: CGEventFlags = [], seen = Set<String>()
    for name in pieces.dropLast() {
        guard let flag = modifiers[name], seen.insert(name).inserted else { throw fail("UNSUPPORTED_MODIFIER", "Modifiers may be cmd, ctrl, alt, and shift, each used once.", 7) }
        eventFlags.insert(flag)
    }
    let ctx = try checkedInputWindow(options), source = try inputSource()
    if let focused = axElement(attr(ctx.root, kAXFocusedUIElementAttribute)), isSecure(focused) {
        throw fail("SECURE_FOCUS_REJECTED", "The focused control is a password field. No keyboard input was sent.", 7)
    }
    let hardwareFlags = CGEventSource.flagsState(.hidSystemState)
    let modifierMask: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
    guard hardwareFlags.intersection(modifierMask).subtracting(eventFlags).isEmpty else {
        throw fail("MODIFIER_STATE_CONFLICT", "A held hardware modifier would change the requested shortcut. No keyboard input was sent or modifier released.", 8)
    }
    guard let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true),
          let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) else {
        throw fail("INPUT_CREATION_FAILED", "Could not create the hotkey; no input was sent.", 8)
    }
    let modifierCodes: [String: CGKeyCode] = ["cmd": 55, "shift": 56, "alt": 58, "ctrl": 59]
    var releases: [CGEvent] = []
    for name in pieces.dropLast().reversed() {
        guard let flag = modifiers[name], let keyCode = modifierCodes[name], !hardwareFlags.contains(flag) else { continue }
        guard let release = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            throw fail("INPUT_CREATION_FAILED", "Could not create all requested modifier releases; no input was sent.", 8)
        }
        release.flags = hardwareFlags
        releases.append(release)
    }
    down.flags = hardwareFlags.union(eventFlags)
    // Empty when no modifier was already held. Never leave our synthetic
    // modifier flags on the ordinary key-up event or release unrelated keys.
    up.flags = hardwareFlags
    down.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.03)
    up.post(tap: .cghidEventTap)
    for release in releases { release.post(tap: .cghidEventTap) }
    Thread.sleep(forTimeInterval: 0.03)
    var result = inputResult("hotkey", ctx)
    result["requested_keys"] = raw
    result["synthetic_modifiers_released"] = releases.count
    result["key_hold_ms"] = 30
    result["settle_ms"] = 30
    return result
}

@MainActor func scroll(_ options: [String: String], _ flags: Set<String>) throws -> [String: Any] {
    try validateOptions(options, flags, ["--snapshot", "--direction", "--lines", "--x", "--y"])
    let lines = try integerOption(options, "--lines", 3, 1...100)
    guard let direction = options["--direction"], ["up", "down", "left", "right"].contains(direction) else {
        throw fail("INVALID_ARGUMENT", "--direction must be up, down, left, or right.")
    }
    let ctx = try checkedInputWindow(options), source = try inputSource()
    let point: CGPoint
    if options["--x"] != nil || options["--y"] != nil { point = try windowPoint(options, "--x", "--y", ctx) }
    else { point = CGPoint(x: ctx.rect.midX, y: ctx.rect.midY) }
    try requireSelectedWindowAtPoint(ctx, point)
    let vertical = direction == "up" ? lines : direction == "down" ? -lines : 0
    let horizontal = direction == "left" ? lines : direction == "right" ? -lines : 0
    guard let event = CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 2,
        wheel1: Int32(vertical), wheel2: Int32(horizontal), wheel3: 0),
        let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) else {
        throw fail("INPUT_CREATION_FAILED", "Could not create the pointer move and scroll event; no input was sent.", 8)
    }
    move.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.03)
    var verifiedCursor = CGPoint.zero
    do {
        guard let observed = CGEvent(source: nil)?.location,
              abs(observed.x - point.x) <= 1, abs(observed.y - point.y) <= 1 else {
            throw fail("SCROLL_POINTER_NOT_VERIFIED", "The native cursor did not settle within one point of the requested scroll position.", 8)
        }
        let current = try checkedInputWindow(options)
        try requireSelectedWindowAtPoint(current, point)
        guard let observed = CGEvent(source: nil)?.location,
              abs(observed.x - point.x) <= 1, abs(observed.y - point.y) <= 1 else {
            throw fail("SCROLL_POINTER_CHANGED", "The native cursor moved away while the selected window was checked.", 8)
        }
        verifiedCursor = observed
    } catch let error as Failure {
        throw fail(error.code, "The pointer move was posted, then the pre-wheel check failed (\(error.code)). No wheel event was posted. Observe the current pointer and selected window before retrying.", error.exit)
    }
    event.location = point
    event.post(tap: .cghidEventTap)
    var result = inputResult("scroll", ctx)
    result["native_cursor_verified"] = true
    result["native_cursor_position"] = ["x": verifiedCursor.x, "y": verifiedCursor.y]
    result["wheel_events_posted"] = 1
    result["scroll_units"] = "line"
    result["requested_lines"] = lines
    result["direction"] = direction
    return result
}

@MainActor func drag(_ options: [String: String], _ flags: Set<String>) throws -> [String: Any] {
    try validateOptions(options, flags, ["--snapshot", "--from-x", "--from-y", "--to-x", "--to-y"])
    let ctx = try checkedInputWindow(options), source = try inputSource()
    let from = try windowPoint(options, "--from-x", "--from-y", ctx)
    let to = try windowPoint(options, "--to-x", "--to-y", ctx)
    try requireSelectedWindowAtPoint(ctx, from)
    try requireSelectedWindowAtPoint(ctx, to)
    guard let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: from, mouseButton: .left),
          let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: to, mouseButton: .left) else {
        throw fail("INPUT_CREATION_FAILED", "Could not create the drag; no input was sent.", 8)
    }
    var events = [down]
    for index in 1...12 {
        let amount = CGFloat(index) / 12
        let point = CGPoint(x: from.x + (to.x - from.x) * amount, y: from.y + (to.y - from.y) * amount)
        try requireSelectedWindowAtPoint(ctx, point)
        guard let event = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: point, mouseButton: .left) else {
            throw fail("INPUT_CREATION_FAILED", "Could not create all drag events; no input was sent.", 8)
        }
        events.append(event)
    }
    events.append(up)
    var lastPoint = from, postedDown = false
    do {
        for event in events {
            if event.type != .leftMouseUp {
                let current = try checkedInputWindow(options)
                guard sameJSON(applicationIdentity(current.app), applicationIdentity(ctx.app)) else {
                    throw fail("SNAPSHOT_STALE", "The selected application process generation changed during the drag. No further movement was sent.", 8)
                }
                try requireSelectedWindowAtPoint(current, event.location)
            }
            event.post(tap: .cghidEventTap)
            if event.type == .leftMouseDown { postedDown = true }
            if event.type == .leftMouseUp { postedDown = false }
            lastPoint = event.location
            Thread.sleep(forTimeInterval: 0.025)
        }
    } catch {
        if postedDown, let release = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: lastPoint, mouseButton: .left) {
            release.post(tap: .cghidEventTap)
        }
        throw error
    }
    return inputResult("drag", ctx)
}

@MainActor func press(_ options: [String: String], _ flags: Set<String>) throws -> [String: Any] {
    try validateOptions(options, flags, ["--snapshot", "--id", "--action"])
    let (element, ctx, id) = try checkedTarget(options)
    if (attr(element, kAXEnabledAttribute) as? NSNumber)?.boolValue == false {
        throw fail("ELEMENT_DISABLED", "The current control is disabled. No action was performed.", 7)
    }
    let action = options["--action"] ?? kAXPressAction
    let available = actions(element)
    guard available.contains(action) else { throw fail("UNSUPPORTED_ACTION", "This element does not expose \(action). Available actions: \(available.joined(separator: ", ")).", 7) }
    let result = AXUIElementPerformAction(element, action as CFString)
    try requireAccessibilityActionResult(result, "Performing the requested element action")
    return ["ok": true, "performed": action, "id": id, "window_id": ctx.windowID,
        "application_identity": applicationIdentity(ctx.app), "verified": false, "next_step": "Take a new snapshot and verify the expected visible change."]
}

func readText(_ maxBytes: Int) throws -> String {
    var data = Data()
    while data.count <= maxBytes {
        guard let chunk = try FileHandle.standardInput.read(upToCount: min(65_536, maxBytes + 1 - data.count)), !chunk.isEmpty else { break }
        data.append(chunk)
    }
    guard data.count <= maxBytes, let text = String(data: data, encoding: .utf8), !text.contains("\0") else {
        throw fail("INVALID_VALUE", "Text must be valid UTF-8, contain no zero byte, and be at most \(maxBytes) bytes.")
    }
    return text
}

@MainActor func typeText(_ options: [String: String], _ flags: Set<String>) throws -> [String: Any] {
    try validateOptions(options, flags, ["--snapshot", "--id", "--value-stdin"])
    guard flags.contains("--value-stdin") else { throw fail("INVALID_ARGUMENT", "type requires --value-stdin; supply exact UTF-8 text on stdin.") }
    let text = try readText(65_536)
    guard !text.isEmpty else { throw fail("INVALID_VALUE", "type requires nonempty text. It inserts text; set-value can replace a supported field with empty text.") }
    let (element, ctx, _) = try checkedTarget(options)
    guard !isSecure(element) else { throw fail("SECURE_VALUE_REJECTED", "This helper does not read or write password fields. No text was entered.", 7) }
    let role = stringAttr(element, kAXRoleAttribute)
    guard [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role),
          (attr(element, kAXEnabledAttribute) as? NSNumber)?.boolValue != false,
          (attr(element, "AXEditable") as? NSNumber)?.boolValue != false,
          (attr(element, "AXReadOnly") as? NSNumber)?.boolValue != true else {
        throw fail("UNSUPPORTED_TEXT_TARGET", "type requires an enabled editable text field, text area, or combo box. No text was entered.", 7)
    }
    _ = try checkedInputWindow(options)
    guard let focused = axElement(attr(ctx.root, kAXFocusedUIElementAttribute)), CFEqual(focused, element) else {
        throw fail("TEXT_TARGET_NOT_FOCUSED", "The exact observed text field must already have keyboard focus. No text was entered.", 8)
    }
    let hardwareModifierMask: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
    guard CGEventSource.flagsState(.hidSystemState).intersection(hardwareModifierMask).isEmpty else {
        throw fail("MODIFIER_STATE_CONFLICT", "A hardware modifier is held. Unicode typing would change human key state; no text was entered and no modifier was released.", 8)
    }
    let source = try inputSource(), units = Array(text.utf16)
    var pairs: [(CGEvent, CGEvent, Int)] = [], offset = 0
    while offset < units.count {
        var end = min(offset + 32, units.count)
        if end < units.count && (0xD800...0xDBFF).contains(units[end - 1]) { end -= 1 }
        let chunk = Array(units[offset..<end])
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            throw fail("INPUT_CREATION_FAILED", "Could not create all text events; no input was sent.", 8)
        }
        down.flags = []; up.flags = []
        chunk.withUnsafeBufferPointer { buffer in
            down.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: buffer.baseAddress!)
            up.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: buffer.baseAddress!)
        }
        pairs.append((down, up, chunk.count)); offset = end
    }
    var postedUnits = 0
    for (down, up, count) in pairs {
        do {
            let current = try checkedInputWindow(options)
            guard sameJSON(applicationIdentity(current.app), applicationIdentity(ctx.app)),
                  let focused = axElement(attr(current.root, kAXFocusedUIElementAttribute)), CFEqual(focused, element),
                  !isSecure(focused),
                  CGEventSource.flagsState(.hidSystemState).intersection(hardwareModifierMask).isEmpty else {
                throw fail("TEXT_TARGET_CHANGED", "The selected application, focused field, or held hardware modifiers changed.", 8)
            }
        } catch let error as Failure {
            throw fail(error.code, "The pre-chunk check failed after posting \(postedUnits) UTF-16 text units. Observe the current field before any retry; no further input was sent.", error.exit)
        }
        down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
        postedUnits += count
        Thread.sleep(forTimeInterval: 0.008)
    }
    var result = inputResult("type", ctx)
    result["requested_text_sha256"] = digest(text)
    result["posted_utf16_units"] = postedUnits
    return result
}

@MainActor func setValue(_ options: [String: String], _ flags: Set<String>) throws -> [String: Any] {
    try validateOptions(options, flags, ["--snapshot", "--id", "--value-stdin"])
    guard flags.contains("--value-stdin") else { throw fail("INVALID_ARGUMENT", "set-value requires --value-stdin; supply exact UTF-8 text on stdin.") }
    let text = try readText(1_048_576)
    let (element, ctx, id) = try checkedTarget(options)
    if (attr(element, kAXEnabledAttribute) as? NSNumber)?.boolValue == false {
        throw fail("ELEMENT_DISABLED", "The current text control is disabled. No text was entered.", 7)
    }
    guard !isSecure(element) else {
        throw fail("SECURE_VALUE_REJECTED", "This helper does not read or write password fields. No text was entered.", 7)
    }
    let role = stringAttr(element, kAXRoleAttribute)
    guard [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role) else {
        throw fail("UNSUPPORTED_VALUE_ROLE", "set-value accepts only editable text fields, text areas, and combo boxes; this element is \(role).", 7)
    }
    guard (attr(element, "AXEditable") as? NSNumber)?.boolValue != false,
          (attr(element, "AXReadOnly") as? NSNumber)?.boolValue != true else {
        throw fail("READ_ONLY_VALUE_REJECTED", "The current text control is marked read-only or not editable. No text was entered.", 7)
    }
    var settable: DarwinBoolean = false
    guard AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success,
          settable.boolValue else { throw fail("VALUE_NOT_SETTABLE", "This text element does not support setting its value through accessibility.", 7) }
    let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFString)
    try requireAccessibilityActionResult(result, "Setting the observed field value")
    return ["ok": true, "performed": "set-value", "id": id, "window_id": ctx.windowID,
        "application_identity": applicationIdentity(ctx.app), "expected_value_sha256": digest(text), "verified": false,
        "next_step": "Take a new snapshot and compare the value hash. Application behavior still needs a visible check."]
}

@MainActor func activate(_ options: [String: String], _ flags: Set<String>) throws -> [String: Any] {
    try validateOptions(options, flags, ["--window-id"])
    let app = try runningApp()
    guard app.activate(options: []) else { throw fail("ACTIVATION_FAILED", "macOS rejected activating the running application.", 8) }
    let chosen = try selectedWindowOption(options)
    let (ctx, _) = try context(false, selectedWindowID: chosen)
    let raise = AXUIElementPerformAction(ctx.main, kAXRaiseAction as CFString)
    try requireAccessibilityActionResult(raise, "Raising the selected application window", failureCode: "ACTIVATION_RAISE_FAILED")
    let deadline = Date().addingTimeInterval(2)
    repeat {
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
            let currentApp = try runningApp()
            guard sameJSON(applicationIdentity(currentApp), applicationIdentity(app)) else {
                throw fail("ACTIVATION_TARGET_CHANGED", "The selected application's process generation changed during activation. Observe its current state before retrying.", 8)
            }
            let main = axElement(attr(ctx.root, kAXMainWindowAttribute))
            let focused = axElement(attr(ctx.root, kAXFocusedWindowAttribute))
            let mainMatches = main.map { CFEqual($0, ctx.main) } ?? false
            let focusMatches = focused.map { CFEqual($0, ctx.main) } ?? false
            let focusKnown = main != nil || focused != nil
            let center = CGPoint(x: ctx.rect.midX, y: ctx.rect.midY)
            let exactCenterOwned = (try? requireSelectedWindowAtPoint(ctx, center)) != nil
            let visible = cgWindows(app.processIdentifier).contains(where: {
                ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == ctx.windowID &&
                ($0[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue == true
            })
            if focusMatches && visible && exactCenterOwned {
                return ["ok": true, "bundle_id": bundleID, "pid": app.processIdentifier, "is_frontmost": true,
                    "application_identity": applicationIdentity(app), "window_id": ctx.windowID, "window_raised": true, "main_window_verified": mainMatches,
                    "focused_window_verified": focusMatches, "focus_metadata_available": focusKnown,
                    "center_point_ownership_verified": true,
                    "point_ownership_method": "system-wide-accessibility-z-order", "exact_native_window_verified": true,
                    "center_on_active_display_verified": true]
            }
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    } while Date() < deadline
    throw fail("ACTIVATION_NOT_VERIFIED", "The exact selected window did not acquire verified native focus and visibility at its center on an active display within two seconds. An off-screen center, covering window, or missing focus prevents verification. Observe the current window and display before retrying; no mouse or keyboard input was sent.", 8)
}

let usage = """
gui-macos info
gui-macos snapshot --output-dir ABS_DIR [--window-id NATIVE_ID] [--max-depth 50] [--max-nodes 1600] [--max-value-chars 160] [--enhance] [--screenshot]
gui-macos activate [--window-id NATIVE_ID]
gui-macos press --snapshot ABS_JSON --id main/0/1 [--action AXPress]
gui-macos set-value --snapshot ABS_JSON --id main/0/1 --value-stdin
gui-macos type --snapshot ABS_JSON --id main/0/1 --value-stdin
gui-macos click --snapshot ABS_JSON --x POINTS --y POINTS [--button left|right] [--count 1|2]
gui-macos hotkey --snapshot ABS_JSON --keys cmd+k
gui-macos scroll --snapshot ABS_JSON --direction up|down|left|right [--lines 3] [--x POINTS --y POINTS]
gui-macos drag --snapshot ABS_JSON --from-x POINTS --from-y POINTS --to-x POINTS --to-y POINTS
Every call requires --bundle-id EXPLICIT_ID --profile-sha256 LOWERCASE_SHA256 [--pid MATCHING_PROCESS] [--expected-app-path ABS_APP_PATH].
No application is launched, and no privacy permission requests are made. Snapshot text may be private; files are saved with owner-only access.
Mouse and keyboard inputs require selected application already frontmost. Snapshots expire after 120 seconds. Coordinates are app-window points, not screenshot pixels.
Mouse and keyboard inputs require the exact selected native window focused. Mouse inputs also require that same window at each intended position; another selected application window or another app covering it causes WINDOW_OCCLUDED.
type inserts at the selected field's current selection, requires that exact field focused, and allows at most 65,536 UTF-8 bytes. It does not replace the whole field or use the clipboard.
"""

@main @MainActor struct ProfileNativeGUI {
    static func main() async {
        do {
            let (command, allOptions, flags) = try parseArgs()
            let options = try configureTarget(allOptions)
            let result: [String: Any]
            switch command {
            case "info": try validateOptions(options, flags, []); result = try appInfo()
            case "snapshot": result = try await snapshot(options, flags)
            case "activate": result = try activate(options, flags)
            case "press": result = try press(options, flags)
            case "set-value": result = try setValue(options, flags)
            case "type": result = try typeText(options, flags)
            case "click": result = try click(options, flags)
            case "hotkey": result = try hotkey(options, flags)
            case "scroll": result = try scroll(options, flags)
            case "drag": result = try drag(options, flags)
            case "help", "--help": try validateOptions(options, flags, []); result = ["ok": true, "usage": usage]
            default: throw fail("UNKNOWN_COMMAND", usage)
            }
            emit(result)
        } catch let error as Failure {
            emit(["ok": false, "error": error.code, "message": error.message])
            Darwin.exit(error.exit)
        } catch {
            emit(["ok": false, "error": "NATIVE_ERROR", "message": error.localizedDescription])
            Darwin.exit(9)
        }
    }
}
