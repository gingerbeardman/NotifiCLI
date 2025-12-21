# NotifiCLI

A lightweight, headless macOS command-line tool for sending actionable, persistent notifications.

Unlike `terminal-notifier`, NotifiCLI:
- 💬 **Reply Input**: Capture typed responses (`-reply`) — removed from terminal-notifier in v1.7
- 📌 **Per-Notification Persistence**: Use `-persistent` flag — terminal-notifier requires system-wide setting
- 🐚 **Stdout Scripting**: Prints clicked action, reply text, or `dismissed` — terminal-notifier has no stdout output
- 🎨 **Custom Icons**: Use any app's icon with `-icon` and auto-cached shorthand

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
- **Reply**: Prints the user's typed text directly
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
RESPONSE=$(notificli -persistent \
  -title "Deploy?" \
  -message "Verify production deploy?" \
  -actions "Yes,No")

if [ "$RESPONSE" == "Yes" ]; then
  echo "🚀 Deploying..."
elif [ "$RESPONSE" == "No" ]; then
  echo "🛑 Aborted."
else
  echo "⚠️ Dismissed."
fi
```

### Advanced: Multi-Step Workflow

Chain notifications for complex interactive scripts:

```bash
#!/bin/bash
RESPONSE=$(notificli -persistent \
  -title "Deploy to Production?" \
  -message "Version 2.1.0 is ready." \
  -actions "Deploy Now,Schedule Later,Cancel" \
  -icon "Terminal" -sound "Glass")

case "$RESPONSE" in
  "Deploy Now")
    notificli -title "🚀 Deploying!" -message "Pushing to production..."
    # ... run deploy script ...
    notificli -title "✅ Success!" -message "v2.1.0 is now live!" -sound "Glass"
    ;;
  "Schedule Later")
    WHEN=$(notificli -persistent -title "Schedule Deploy" \
      -message "When should we deploy?" -reply "e.g., tomorrow 3am")
    notificli -title "📅 Scheduled" -message "Deploy set for: ${WHEN#User typed: }"
    ;;
  "Cancel"|"dismissed")
    notificli -title "❌ Cancelled" -message "Deployment aborted"
    ;;
esac
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

## Installation

### Quick Start (Recommended)

1. **Download** the latest release from [Releases](https://github.com/DiggingForDinos/NotifiCLI/releases)
2. **Unzip** and move `NotifiCLI.app` to `~/Applications/` (NotifiPersistent is embedded inside)
3. **Grant permissions**:
   - Double-click `NotifiCLI.app` to allow notifications
   - For persistent alerts, also open `NotifiCLI.app/Contents/Apps/NotifiPersistent.app`
4. **Add to PATH** (optional):
   ```bash
   ln -s ~/Applications/NotifiCLI.app/Contents/MacOS/NotifiCLI /usr/local/bin/notificli
   ```

### Build from Source

```bash
./build.sh
```
This compiles apps into the `build/` directory.

## Custom Icons 🎨

Use any app's icon for your notifications with the `-icon` flag:

```bash
notificli -icon "/Applications/Slack.app" -title "Message" -message "New DM received"
```

The first time you use a new icon, it auto-creates a variant (takes ~1 second). Subsequent uses are instant.

**Shorthand:** Once a variant is created, you can use just the name:
```bash
# First time - uses full path
notificli -icon "/System/Applications/Utilities/Terminal.app" -title "Build" -message "Complete"

# After that - shorthand works
notificli -icon "Terminal" -title "Build" -message "Complete"
```

**More examples:**
```bash
notificli -icon "/Applications/Keyboard Maestro.app" -title "Macro" -message "Finished"
notificli -icon "KeyboardMaestro" -title "Macro" -message "Finished"  # shorthand
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

---

## Issues & Feedback

Found a bug or have a feature request? [Open an issue](https://github.com/DiggingForDinos/NotifiCLI/issues)

---

If you like this project, please consider giving the repo a ⭐ star!
