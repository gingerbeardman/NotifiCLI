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
| `-message` | The body text/subtitle. |
| `-actions` | (Optional) Comma-separated list of button labels (e.g., "Yes,No"). |
| `-persistent` | Uses the "Alert" style so the notification stays on screen. |


## Persistent Mode 📌
To use persistent alerts (notifications that don't disappear), use the `-persistent` flag.

**One-Time Setup Required:**
1. Run a persistent test once: `notificli -message "Setup" -persistent`
2. Open **System Settings > Notifications**.
3. Find **NotifiPersistent** in the list.
4. Change the alert style from "Banner" to **Alerts**.

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

You can create app variants with custom notification icons:

1. **Copy an icon** from any app:
   - Right-click any `.app` → **Get Info** (or ⌘I)
   - Click the icon in the top-left → **⌘C** to copy

2. **Save as PNG**:
   - Open **Preview** → File → **New from Clipboard**
   - File → **Export** → Format: **PNG**
   - Save to: `icons/HomeAssistant.png` (or any name)

3. **Rebuild**:
   ```bash
   ./build.sh
   ```

4. **Use**:
   ```bash
   notificli -app HomeAssistant -title "Motion" -message "Front door"
   ```

> **Note**: macOS caches app icons aggressively. After adding new icon variants, a **reboot is required** for the icons to appear correctly in Notification Center.

## Troubleshooting
**"Error requesting auth: Notifications are not allowed"**
If you see this error, macOS hasn't linked the binary to the bundle's permissions yet. Run the app once via `open` or Finder to fix it:
```bash
open build/NotifiCLI.app
open build/NotifiPersistent.app
```
Then try the command again.
