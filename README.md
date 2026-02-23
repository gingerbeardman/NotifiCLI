# NotifiCLI

A lightweight, headless macOS command-line tool for sending actionable, persistent notifications.

Unlike `terminal-notifier`, NotifiCLI offers:
- **Reply input** — capture typed responses with `-reply` (removed from terminal-notifier in v1.7)
- **Per-notification persistence** — use the `-persistent` flag instead of a system-wide setting
- **Stdout scripting** — outputs clicked actions, reply text, or dismissals (terminal-notifier outputs nothing)
- **Custom icons** — use any app's icon via `-icon`, with automatic caching shorthand

## Usage

<table>
  <tr>
    <td align="center" valign="top" width="50%">
      <b>Action Buttons</b><br>
      <img src="images/actions.png?raw=true" width="100%"><br>
      <code>notificli -title "Deploy to Production?" -message "Version 1.1.0 is ready." -actions "Deploy Now,Schedule Later,Cancel"</code>
    </td>
    <td align="center" valign="top" width="50%">
      <b>Reply Input</b><br>
      <img src="images/reply.png?raw=true" width="100%"><br>
      <code>notificli -title "Weekend Trip" -message "What time do you want to leave on Friday?" -reply "Time you want to leave"</code>
    </td>
  </tr>
  <tr>
    <td align="center" valign="top" width="50%">
      <b>Notification Image</b><br>
      <img src="images/image.png?raw=true" width="100%"><br>
      <code>notificli -title "hi" -subtitle "hello" -message "what's up" -image "https://images.unsplash.com/photo..."</code>
    </td>
    <td align="center" valign="top" width="50%">
      <b>Open URL</b><br>
      <img src="images/url.png?raw=true" width="100%"><br>
      <code>notificli -title "Package Delivered" -subtitle "Your order has arrived at the front door." -message "Click to open website" -url "https://fedex.com/track"</code>
    </td>
  </tr>
</table>


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
| `-sound` | (Optional) System sound or file path. Sounds: Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink |
| `-persistent` | Notification stays on screen until dismissed. |

### Output Behavior
When using `-actions`, `-reply`, or `-url`, the command waits for user interaction and prints the result:
- **Action buttons**: Prints the clicked button label (e.g., `Yes`)
- **Reply**: Prints the user's typed text directly
- **Dismiss**: Prints `dismissed`
- **Click notification**: Prints `default` (and opens URL if specified)


## Persistent Mode
To use persistent alerts (notifications that don't disappear), use the `-persistent` flag.

**One-Time Setup Required:**
1. Run a persistent test once: `notificli -message 'Setup' -persistent`
2. Open **System Settings > Notifications**.
3. Find **NotifiPersistent** in the list.
4. Change the **Alert Style** to **Persistent**.

Now, valid commands with `-persistent` will stay on screen until clicked.

## Scripting Example

NotifiCLI pauses execution until the user clicks a button. Capture the output to drive your logic:

```bash
RESPONSE=$(notificli -persistent \
  -title 'Deploy?' \
  -message 'Verify production deploy?' \
  -actions 'Yes,No')

if [ "$RESPONSE" == "Yes" ]; then
  echo "Deploying..."
elif [ "$RESPONSE" == "No" ]; then
  echo "Aborted."
else
  echo "Dismissed."
fi
```

### Advanced: Multi-Step Workflow

Chain notifications for complex interactive scripts:

```bash
#!/bin/bash
RESPONSE=$(notificli -persistent \
  -title 'Deploy to Production?' \
  -message 'Version 1.1.0 is ready.' \
  -actions 'Deploy Now,Schedule Later,Cancel' \
  -icon 'Terminal' -sound 'Glass')

case "$RESPONSE" in
  'Deploy Now')
    notificli -title 'Deploying!' -message 'Pushing to production...'
    # ... run deploy script ...
    notificli -title 'Success!' -message 'v1.1.0 is now live!' -sound 'Glass'
    ;;
  'Schedule Later')
    WHEN=$(notificli -persistent -title 'Schedule Deploy' \
      -message 'When should we deploy?' -reply 'e.g., tomorrow 3am')
    notificli -title 'Scheduled' -message "Deploy set for: $WHEN"
    ;;
  'Cancel'|'dismissed')
    notificli -title 'Cancelled' -message 'Deployment aborted'
    ;;
esac
```

## User Interaction

### Reply Input
Capture user input directly from the notification:

```bash
OUTPUT=$(notificli -title 'Status' -message 'Update status?' -reply 'Type here')
echo "You typed: $OUTPUT"
```

### Open URL
Open a link when the user clicks the notification body:

```bash
notificli -title 'Build Failed' -message 'Click to view logs' -url 'https://github.com/my/repo/actions'
```



## Installation

### Quick Start (Homebrew)

The easiest way to install NotifiCLI and keep it updated is via the official Homebrew tap:

```bash
brew tap saihgupr/notificli
brew install --cask notificli
```

### Manual Installation

1. **Download** the latest release from [Releases](https://github.com/saihgupr/NotifiCLI/releases)
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

## Keyboard Maestro Plug-in

<img src="images/km.png?raw=true" width="600">

NotifiCLI includes a native **Keyboard Maestro Action** for easy integration into your macros.

### Installation
1. **Install the main app first**: Download `NotifiCLI.zip`, unzip it, and move `NotifiCLI.app` to your `/Applications` or `~/Applications` folder.
2. Download the folder contents from [here](https://github.com/saihgupr/NotifiCLI/tree/main/Keyboard-Maestro-Action/NotifiCLI).
3. Move the contents of the folder to:
   `~/Library/Application Support/Keyboard Maestro/Keyboard Maestro Actions/NotifiCLI`
   *(Tip: Press Command+Shift+G in Finder and paste that path)*
4. Restart the Keyboard Maestro Engine.

> [!IMPORTANT]
> **Security Warning (Gatekeeper)**
> macOS may block the embedded `NotifiCLI` app because it is not notarized. If you see a "malicious software" warning or it fails to run:
> 1. Go to the installed action folder: `~/Library/Application Support/Keyboard Maestro/Keyboard Maestro Actions/NotifiCLI`
> 2. Right-click `NotifiCLI.app` inside that folder and choose **Open**.
> 3. Click **Open** in the dialog to whitelist it.
> You only need to do this once.

### Usage in Keyboard Maestro
- Add the **"NotifiCLI"** action to your macro.
- Fill in the Title, Subtitle, Message.
- Use the **"Actions"** field to add comma-separated buttons.
- The action saves the clicked button name to a variable (or clipboard) so you can use it in "If Then Else" actions.


## Custom Icons

Use any app's icon for your notifications with the `-icon` flag:

```bash
notificli -icon '/Applications/Slack.app' -title 'Message' -message 'New DM received'
```

The first time you use a new icon, it auto-creates a variant (takes ~1 second). Subsequent uses are instant.

**Shorthand:** Once a variant is created, you can use just the name:
```bash
# First time - uses full path
notificli -icon '/System/Applications/Utilities/Terminal.app' -title 'Build' -message 'Complete'

# After that - shorthand works
notificli -icon 'Terminal' -title 'Build' -message 'Complete'
```

**More examples:**
```bash
notificli -icon '/Applications/Keyboard Maestro.app' -title 'Macro' -message 'Finished'
notificli -icon 'KeyboardMaestro' -title 'Macro' -message 'Finished'  # shorthand
```

> **Note**: macOS caches app icons. After using a new icon for the first time, a **reboot is required** for the icon to appear correctly in Notification Center.
>
> **Important (macOS Sequoia/Tahoe)**: On newer macOS versions, each custom icon variant acts as a unique app with its own security profile. The first time you use a new icon, it may be blocked from sending notifications.
>
> **The Fix**: To grant permission, you must perform a one-time "blessing":
> 1. Open Finder to `/Applications/NotifiCLI.app/Contents/Apps`
> 2. Right-click the new variant (e.g., `NotifiCLI-Calculator.app`) and choose **Open**.
> 3. If blocked, go to **System Settings > Privacy & Security** and click **Open Anyway**.
>
> Once trusted once, that icon will work forever.
>
>
> [!WARNING]
> **Notification Preferences Bloat**
> Each custom icon variant you create acts as a unique app bundle with its own settings. This means your **System Settings > Notifications** list will grow with an entry for every app icon you add (e.g., `NotifiCLI-Slack`, `NotifiCLI-Terminal`). Be selective with which icons you generate if you want to keep that list tidy!

## Troubleshooting

**"Notifications are not allowed"**
This happens when macOS blocks an ad-hoc signed variant from accessing system services.

1. **The Finder Trick**: This is the most reliable fix for Sequoia/Tahoe:
   - Navigate to `/Applications/NotifiCLI.app/Contents/Apps`
   - Right-click the failing variant (e.g., `NotifiCLI-Spotify.app`)
   - Choose **Open**, then **Open Anyway** if prompted.
2. **System Settings**: Check **System Settings > Notifications**. Look for the flat bundle name (e.g., `Calculator` or `Slack`) and ensure "Allow Notifications" is active.
3. **Verify Location**: Ensure the main `NotifiCLI.app` is in `/Applications/`. macOS security is much stricter for apps run from "Downloads" or "Desktop".

---

## Issues & Feedback

Found a bug or have a feature request? [Open an issue](https://github.com/saihgupr/NotifiCLI/issues)


If you like this project, please consider giving the repo a star!