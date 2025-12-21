# NotifiCLI

A lightweight, "headless" macOS command-line tool for sending actionable, persistent notifications.

Unlike `terminal-notifier`, NotifiCLI:
- 👻 **Invisible**: Has **no Dock icon** and no Menu Bar icon.
- ⚡️ **Interactive**: Supports customizable action buttons.
- 🐚 **Scriptable**: Prints the clicked action to `stdout` and waits for input.
- 🍎 **Native**: Uses the modern `UserNotifications` framework.

## Usage

```bash
/path/to/NotifiCLI -title "Job Complete" -message "The render finished successfully." -actions "Show,Dismiss"
```

### Arguments
| Flag | Description |
| :--- | :--- |
| `-title` | The bold title of the notification. |
| `-subtitle` | (Optional) Secondary text line below the title. |
| `-message` | The body text/subtitle. |
| `-actions` | (Optional) Comma-separated list of button labels (e.g., "Yes,No"). |
| `-image` | (Optional) Path to an image file to show as thumbnail on the right. |
| `-icon` | (Optional) Path to an `.app` to use its icon for the notification. |
| `-reply` | (Optional) Adds a "Reply" button with a placeholder text input. |
| `-url` | (Optional) Opens the specified URL when notification is clicked. |
| `-sound` | (Optional) Play a sound. System sound name (e.g. "Glass") or path to sound file. Silent by default. |
| `-persistent` | Uses the "Alert" style so the notification stays on screen. |

### Output Behavior
When using `-actions`, `-reply`, or `-url`, the command waits for user interaction and prints the result:
- **Action buttons**: Prints the clicked button label (e.g., `Yes`)
- **Reply**: Prints `User typed: <message>`
- **Dismiss**: Prints `dismissed`
- **Click notification**: Prints `default` (and opens URL if specified)


## Persistent Mode 📌
To use persistent alerts (notifications that don't disappear), use the `-persistent` flag.

**One-Time Setup Required:**
1. Run a persistent test once: `notificli -message "Setup" -persistent`
2. Open **System Settings > Notifications**.
3. Find **NotifiPersistent** in the list.
4. Change the **Alert Style** to **Persistent**.

Now, valid commands with `-persistent` will stay on screen until clicked.

## Scripting Example

NotifiCLI pauses execution until the user clicks a button. Capture the output to drive your logic:

```bash
RESPONSE=$(./build/NotifiCLI.app/Contents/MacOS/NotifiCLI \
  -title "Deploy?" \
  -message "Verify production deploy?" \
  -actions "Yes,No")

if [ "$RESPONSE" == "Yes" ]; then
  echo "🚀 Deploying..."
elif [ "$RESPONSE" == "No" ]; then
  echo "🛑 Aborted."
else
  echo "⚠️ Timed out or dismissed."
fi
```

## User Interaction 💬

### Reply Input
Capture user input directly from the notification:

```bash
OUTPUT=$(notificli -title "Status" -message "Update status?" -reply "Type 'Done' or 'Working'")
echo "You typed: $OUTPUT"
# Output: "You typed: User typed: Done"
```

### Open URL
Open a link when the user clicks the notification body:

```bash
notificli -title "Build Failed" -message "Click to view logs" -url "https://github.com/my/repo/actions"
```

## Installation & Build

1.  **Build**
    ```bash
    ./build.sh
    ```
    This compiles the app into `build/NotifiCLI.app`.

2.  **Permissions**
    On the first run, you must allow notifications. If running from a script/terminal, macOS may prompt you to allow "NotifiCLI" to send notifications.

3.  **Global Install (Optional)**
    You can alias it or link the binary to your path:
    ```bash
    ln -s $(pwd)/build/NotifiCLI.app/Contents/MacOS/NotifiCLI /usr/local/bin/notificli
    ```

## Custom Icons 🎨

Use any app's icon for your notifications with the `-icon` flag:

```bash
notificli -icon "/Applications/Slack.app" -title "Message" -message "New DM received"
```

The first time you use a new icon, it auto-creates a variant (takes ~1 second). Subsequent uses are instant.

**Examples:**
```bash
# Use Terminal's icon
notificli -icon "/System/Applications/Utilities/Terminal.app" -title "Build" -message "Complete"

# Use any installed app
notificli -icon "/Applications/Keyboard Maestro.app" -title "Macro" -message "Finished"
```

> **Note**: macOS caches app icons. After using a new icon for the first time, a **reboot is required** for the icon to appear correctly in Notification Center.

## Troubleshooting
**"Error requesting auth: Notifications are not allowed"**
If you see this error, macOS hasn't linked the binary to the bundle's permissions yet. Run the app once via `open` or Finder to fix it:
```bash
open build/NotifiCLI.app
open build/NotifiPersistent.app
```
Then try the command again.
