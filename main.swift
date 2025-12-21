import Foundation
import UserNotifications
import AppKit

// MARK: - Argument Parsing
var title: String?
var subtitle: String?
var message: String?
var actions: [String] = []
var imagePath: String?
var soundName: String?
var replyPlaceholder: String?
var openUrl: String?


var args = CommandLine.arguments.dropFirst()
while let arg = args.popFirst() {
    switch arg {
    case "-title":
        title = args.popFirst()
    case "-subtitle":
        subtitle = args.popFirst()
    case "-message":
        message = args.popFirst()
    case "-actions":
        if let actionStr = args.popFirst() {
            actions = actionStr.split(separator: ",").map { String($0) }
        }
    case "-image":
        imagePath = args.popFirst()
    case "-sound":
        soundName = args.popFirst()
    case "-reply":
        replyPlaceholder = args.popFirst()
    case "-url":
        openUrl = args.popFirst()

    default:
        break
    }
}

guard let notificationTitle = title, let notificationMessage = message else {
    print("Usage: NotifiCLI -title \"Title\" -message \"Message\" [-subtitle \"Subtitle\"] [-actions \"Yes,No\"] [-reply \"Placeholder\"] [-url \"https://...\"] [-image \"/path/to/image.png\"] [-sound \"Name\"] [-silent]")
    exit(1)
}

// MARK: - Notification
let center = UNUserNotificationCenter.current()

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    var selectedAction: String?
    let semaphore = DispatchSemaphore(value: 0)
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        // Handle Text Input
        if let textResponse = response as? UNTextInputNotificationResponse {
            selectedAction = "User typed: \(textResponse.userText)"
        } 
        // Handle Default Click (Open URL)
        else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            selectedAction = "default"
            if let openUrl = openUrl, let url = URL(string: openUrl) {
                NSWorkspace.shared.open(url)
            }
        } else if response.actionIdentifier == UNNotificationDismissActionIdentifier {
            selectedAction = "dismissed"
        } else {
            selectedAction = response.actionIdentifier
        }
        
        completionHandler()
        // No need to signal semaphore anymore, assuming we poll selectedAction
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        var options: UNNotificationPresentationOptions = [.banner]
        if notification.request.content.sound != nil {
            options.insert(.sound)
        }
        completionHandler(options)
    }
}

let delegate = NotificationDelegate()
center.delegate = delegate

// Request authorization
center.requestAuthorization(options: [.alert, .sound]) { granted, error in
    if let error = error {
        print("Error requesting auth: \(error.localizedDescription)")
    }
}

// Register action category if needed
var notificationActions: [UNNotificationAction] = []

if let replyPlaceholder = replyPlaceholder {
    let replyAction = UNTextInputNotificationAction(
        identifier: "REPLY_ACTION",
        title: "Reply",
        options: [.foreground],  // Foreground required to receive response from Notification Center
        textInputButtonTitle: "Send",
        textInputPlaceholder: replyPlaceholder
    )
    notificationActions.append(replyAction)
}

if !actions.isEmpty {
    let customActions = actions.map { actionTitle in
        UNNotificationAction(identifier: actionTitle, title: actionTitle, options: [.foreground])
    }
    notificationActions.append(contentsOf: customActions)
}

if !notificationActions.isEmpty {
    let category = UNNotificationCategory(identifier: "ACTIONS_CATEGORY",
                                           actions: notificationActions,
                                           intentIdentifiers: [],
                                           options: [])
    center.setNotificationCategories([category])
}

// Create notification content
let content = UNMutableNotificationContent()
content.title = notificationTitle
if let notificationSubtitle = subtitle {
    content.subtitle = notificationSubtitle
}
content.body = notificationMessage

// Sound configuration - silent by default, only play if -sound is specified
content.sound = nil

if let soundName = soundName {
    // Try file in bundle first
    if let soundPath = Bundle.main.path(forResource: soundName, ofType: nil) {
        if let sound = NSSound(contentsOfFile: soundPath, byReference: true) {
            sound.play()
        }
    } 
    // Try system sound by name
    else if let sound = NSSound(named: NSSound.Name(soundName)) {
        sound.play()
    }
    // Try absolute path (if passed directly)
    else if FileManager.default.fileExists(atPath: soundName) {
        if let sound = NSSound(contentsOfFile: soundName, byReference: true) {
            sound.play()
        }
    }
}

if !notificationActions.isEmpty {
    content.categoryIdentifier = "ACTIONS_CATEGORY"
}

// Add image attachment if specified
if let imagePath = imagePath {
    let imageURL = URL(fileURLWithPath: imagePath)
    if FileManager.default.fileExists(atPath: imagePath) {
        do {
            let attachment = try UNNotificationAttachment(identifier: "image", url: imageURL, options: nil)
            content.attachments = [attachment]
        } catch {
            print("Warning: Could not attach image: \(error.localizedDescription)")
        }
    } else {
        print("Warning: Image not found at \(imagePath)")
    }
}

// Schedule notification
let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

center.add(request) { error in
    if let error = error {
        print("Error scheduling notification: \(error.localizedDescription)")
        exit(1)
    }
}

// Wait for user response if actions exist or reply is requested
if !actions.isEmpty || replyPlaceholder != nil || openUrl != nil {
    // Run the run loop until action is received
    while delegate.selectedAction == nil {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
    }
    
    if let action = delegate.selectedAction {
        print(action)
    }
}
