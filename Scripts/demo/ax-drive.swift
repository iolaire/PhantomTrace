// Drives the PhantomTrace app through the macOS Accessibility API so an agent (or a person) can record
// demo clips without touching the keyboard or mouse.
//
//   swiftc -O Scripts/demo/ax-drive.swift -o <dir>/ax-drive     (record-flow.sh does this for you)
//   ax-drive <app> windows               list on-screen windows of <app>: id, title, bounds
//   ax-drive <app> dump [depth]          print the AX tree (role, title, description, value, enabled)
//   ax-drive <app> press <text> [role]   AXPress the first element whose title or description contains <text>
//   ax-drive <app> click <text> [role]   glide the real pointer to that element and post a real left click
//   ax-drive <app> wait <text> [role]    wait up to 20 s until that element exists and is enabled
//   ax-drive <app> move <title> <x> <y>  move the window with that exact title (top-left screen points)
//   ax-drive <app> screen                print the main screen's visible frame as "x y width height"
//   ax-drive <app> pointer <x> <y>       put the pointer at a screen point (no click)
//
// AXWIN=<window title> limits press/click to one window ("" is the untitled lock window).
// Needs Accessibility permission for the app that runs it (System Settings > Privacy & Security).
// Use `click` while recording with `screencapture -v -C -k`: AXPress moves no pointer and draws no
// click ring, a real click does. Demo use only, against the throwaway PhantomDemo drive.
import AppKit
import ApplicationServices
import CoreGraphics

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func children(_ element: AXUIElement) -> [AXUIElement] {
    attribute(element, "AXChildren") as? [AXUIElement] ?? []
}

func dump(_ element: AXUIElement, depth: Int, maxDepth: Int) {
    let role = attribute(element, "AXRole") as? String ?? "?"
    let title = attribute(element, "AXTitle") as? String ?? ""
    let description = attribute(element, "AXDescription") as? String ?? ""
    let value = attribute(element, "AXValue").map { "\($0)" } ?? ""
    let disabled = (attribute(element, "AXEnabled") as? Bool) == false ? " [disabled]" : ""
    let indent = String(repeating: "  ", count: depth)
    print("\(indent)\(role) title=\"\(title)\" desc=\"\(description)\" val=\"\(value.prefix(80))\"\(disabled)")
    guard depth < maxDepth else { return }
    for child in children(element) { dump(child, depth: depth + 1, maxDepth: maxDepth) }
}

/// Depth-capped search: some AX trees repeat themselves when the permission is half applied.
func find(_ element: AXUIElement, _ text: String, role: String?, depth: Int = 0) -> AXUIElement? {
    guard depth <= 14 else { return nil }
    let elementRole = attribute(element, "AXRole") as? String ?? ""
    let labels = [attribute(element, "AXTitle") as? String, attribute(element, "AXDescription") as? String]
        .compactMap { $0 }
    if role == nil || elementRole == role, labels.contains(where: { $0.contains(text) }) { return element }
    for child in children(element) {
        if let match = find(child, text, role: role, depth: depth + 1) { return match }
    }
    return nil
}

func window(of app: AXUIElement, titled title: String) -> AXUIElement? {
    let windows = attribute(app, "AXWindows") as? [AXUIElement] ?? []
    return windows.first { (attribute($0, "AXTitle") as? String ?? "") == title }
}

func frame(of element: AXUIElement) -> CGRect {
    var origin = CGPoint.zero
    var size = CGSize.zero
    if let raw = attribute(element, "AXPosition"), CFGetTypeID(raw) == AXValueGetTypeID() {
        // The type ID check above makes this cast safe.
        AXValueGetValue(raw as! AXValue, .cgPoint, &origin)  // swiftlint:disable:this force_cast
    }
    if let raw = attribute(element, "AXSize"), CFGetTypeID(raw) == AXValueGetTypeID() {
        AXValueGetValue(raw as! AXValue, .cgSize, &size)  // swiftlint:disable:this force_cast
    }
    return CGRect(origin: origin, size: size)
}

func postMouse(_ type: CGEventType, at point: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?
        .post(tap: .cghidEventTap)
}

/// Eased glide from the current pointer position, then a real click, so the recording shows motion.
func glideAndClick(to target: CGPoint) {
    let start = CGEvent(source: nil)?.location ?? target
    let steps = 24
    for step in 1...steps {
        let progress = Double(step) / Double(steps)
        let eased = progress < 0.5 ? 2 * progress * progress : 1 - pow(-2 * progress + 2, 2) / 2
        postMouse(.mouseMoved, at: CGPoint(x: start.x + (target.x - start.x) * eased,
                                           y: start.y + (target.y - start.y) * eased))
        usleep(16_000)
    }
    usleep(120_000)
    postMouse(.leftMouseDown, at: target)
    usleep(90_000)
    postMouse(.leftMouseUp, at: target)
}

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    fail("usage: ax-drive <app> windows | dump [depth] | press|click|wait <text> [role] | move <title> <x> <y> | screen",
         code: 2)
}
let appName = args[1]
let command = args[2]

switch command {
case "windows":
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    for info in list {
        let owner = info["kCGWindowOwnerName"] as? String ?? ""
        guard owner.localizedCaseInsensitiveContains(appName) else { continue }
        let bounds = info["kCGWindowBounds"] as? [String: Any] ?? [:]
        let id = info["kCGWindowNumber"] ?? "?"
        let name = info["kCGWindowName"] ?? ""
        print("id=\(id) owner=\(owner) name=\"\(name)\" bounds=\(bounds["X"] ?? 0),\(bounds["Y"] ?? 0) "
              + "\(bounds["Width"] ?? 0)x\(bounds["Height"] ?? 0)")
    }
    exit(0)
case "screen":
    guard let screen = NSScreen.main, let primary = NSScreen.screens.first else { fail("no screen") }
    // AppKit is bottom-left based; AX and CGEvent use top-left of the primary screen.
    let visible = screen.visibleFrame
    let top = primary.frame.maxY - visible.maxY
    print("\(Int(visible.minX)) \(Int(top)) \(Int(visible.width)) \(Int(visible.height))")
    exit(0)
case "pointer":
    guard args.count >= 5, let x = Double(args[3]), let y = Double(args[4]) else {
        fail("usage: ax-drive <app> pointer <x> <y>", code: 2)
    }
    CGWarpMouseCursorPosition(CGPoint(x: x, y: y))
    exit(0)
default:
    break
}

guard AXIsProcessTrusted() else { fail("Accessibility permission is not granted to this process's app") }
guard let running = NSWorkspace.shared.runningApplications.first(where: {
    ($0.localizedName ?? "").localizedCaseInsensitiveContains(appName)
}) else { fail("app not running: \(appName)") }
let app = AXUIElementCreateApplication(running.processIdentifier)
var root = app
if let scope = ProcessInfo.processInfo.environment["AXWIN"] {
    guard let scoped = window(of: app, titled: scope) else { fail("window not found: \"\(scope)\"") }
    root = scoped
}
let text = args.count > 3 ? args[3] : ""
let role = args.count > 4 ? args[4] : nil

switch command {
case "dump":
    dump(app, depth: 0, maxDepth: args.count > 3 ? Int(args[3]) ?? 8 : 8)
case "press":
    guard let element = find(root, text, role: role) else { fail("not found: \(text)") }
    print("press \(text): \(AXUIElementPerformAction(element, kAXPressAction as CFString).rawValue)")
case "click":
    guard let element = find(root, text, role: role) else { fail("not found: \(text)") }
    let box = frame(of: element)
    // Radio buttons: aim at the circle on the left, not the middle of the label.
    let isRadio = (attribute(element, "AXRole") as? String) == "AXRadioButton"
    let target = CGPoint(x: isRadio ? box.minX + 8 : box.midX, y: box.midY)
    glideAndClick(to: target)
    print("click \(text) at \(Int(target.x)),\(Int(target.y))")
case "wait":
    let deadline = Date().addingTimeInterval(20)
    while Date() < deadline {
        if let element = find(app, text, role: role), (attribute(element, "AXEnabled") as? Bool) ?? true {
            print("ready \(text)")
            exit(0)
        }
        usleep(100_000)
    }
    fail("timeout waiting for \(text)")
case "move":
    guard args.count >= 6, let x = Double(args[4]), let y = Double(args[5]) else {
        fail("usage: ax-drive <app> move <title> <x> <y>", code: 2)
    }
    guard let target = window(of: app, titled: text) else { fail("window not found: \"\(text)\"") }
    var point = CGPoint(x: x, y: y)
    guard let value = AXValueCreate(.cgPoint, &point) else { fail("could not build position") }
    print("move \(text): \(AXUIElementSetAttributeValue(target, "AXPosition" as CFString, value).rawValue)")
default:
    fail("unknown command: \(command)", code: 2)
}
