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
