import Cocoa
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let args = CommandLine.arguments

        guard args.count >= 3 else {
            fputs("Usage: ClaudeNotifier <subtitle> <message>\n", stderr)
            NSApp.terminate(nil)
            return
        }

        let subtitle = args[1]
        let message = args[2]

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else {
                NSApp.terminate(nil)
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Claude Code"
            content.subtitle = subtitle
            content.body = message
            content.sound = .default

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
