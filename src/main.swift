import Cocoa
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let args = CommandLine.arguments

        // Usage:
        //   ClaudeNotifier <subtitle> <message>                          (legacy, title = "Claude Code")
        //   ClaudeNotifier <title> <subtitle> <message> [iconPath]
        let title: String
        let subtitle: String
        let message: String
        let iconPath: String?

        switch args.count {
        case 3:
            title = "Claude Code"
            subtitle = args[1]
            message = args[2]
            iconPath = nil
        case 4:
            title = args[1]
            subtitle = args[2]
            message = args[3]
            iconPath = nil
        case 5...:
            title = args[1]
            subtitle = args[2]
            message = args[3]
            let raw = args[4]
            iconPath = raw.isEmpty ? nil : raw
        default:
            fputs("Usage: ClaudeNotifier <title> <subtitle> <message> [iconPath]\n", stderr)
            NSApp.terminate(nil)
            return
        }

        // Post unconditionally. macOS silently denies `requestAuthorization`
        // for new ad-hoc-signed bundles without prompting; the bundle won't
        // appear in System Settings → Notifications until it first tries to
        // post, so `add()` is what registers us with usernoted.
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            let content = UNMutableNotificationContent()
            content.title = title
            content.subtitle = subtitle
            content.body = message
            content.sound = .default

            if let iconPath, let attachment = Self.makeIconAttachment(from: iconPath) {
                content.attachments = [attachment]
            }

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            center.add(request) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    // UNNotificationAttachment requires a PNG/JPEG/GIF file. `.icns` is not
    // accepted directly — if one is passed, render it to a temp PNG first.
    private static func makeIconAttachment(from path: String) -> UNNotificationAttachment? {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let ext = url.pathExtension.lowercased()
        let finalURL: URL
        if ext == "png" || ext == "jpg" || ext == "jpeg" || ext == "gif" {
            finalURL = url
        } else {
            guard let png = renderPNG(from: url) else { return nil }
            finalURL = png
        }

        return try? UNNotificationAttachment(
            identifier: "icon",
            url: finalURL,
            options: [UNNotificationAttachmentOptionsThumbnailHiddenKey: false]
        )
    }

    private static func renderPNG(from source: URL) -> URL? {
        guard let image = NSImage(contentsOf: source) else { return nil }
        let size = NSSize(width: 256, height: 256)
        let target = NSImage(size: size)
        target.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: .zero,
                   operation: .sourceOver,
                   fraction: 1.0)
        target.unlockFocus()
        guard
            let tiff = target.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let png = rep.representation(using: .png, properties: [:])
        else { return nil }

        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ccn-\(UUID().uuidString).png")
        do {
            try png.write(to: tmp)
            return tmp
        } catch {
            return nil
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
