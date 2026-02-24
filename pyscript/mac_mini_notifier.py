import subprocess
import shlex
import uuid
import datetime

# Storage for pending notifications
_pending_notifications = {}

# Configuration - update these for your environment
# Using Home Assistant secrets is recommended: SSH_USER = secrets.get("mac_mini_user")
SSH_USER = "ENTER_USERNAME_HERE"
SSH_HOST = "ENTER_IP_HERE"
SSH_KEY_PATH = "/config/.ssh/id_rsa"


@service("notify.mac_mini")
def mac_mini_notify(
    title=None,
    subtitle=None,
    message=None,
    image=None,
    actions=None,
    reply=None,
    url=None,
    sound=None,
    persistent=False,
    timeout=120,
    blocking=False,
    response_variable=None,
    data=None
):
    """
    Sends a notification to macOS using NotifiCLI over SSH.
    Non-blocking by default (like iOS) - returns immediately, fires event when user responds.
    """
    
    log.info(f"mac_mini_notify service called (blocking={blocking})")

    # Support HA notify format via data dictionary
    if data:
        title = data.get("title", title)
        message = data.get("message", message)
        subtitle = data.get("subtitle", subtitle)
        
        if "attachment" in data:
            image = data["attachment"].get("url", image)
        
        nested_data = data.get("data", {})
        
        if not actions:
            actions = nested_data.get("actions") or data.get("actions")
        
        reply = nested_data.get("reply", reply) or data.get("reply", reply)
        url = nested_data.get("url", url) or data.get("url", url)
        sound = nested_data.get("sound", sound) or data.get("sound", sound)
        persistent = nested_data.get("persistent", persistent) if "persistent" in nested_data else data.get("persistent", persistent)
        timeout = nested_data.get("timeout", timeout) or data.get("timeout", timeout)
        blocking = nested_data.get("blocking", blocking) if "blocking" in nested_data else data.get("blocking", blocking)
        response_variable = nested_data.get("response_variable", response_variable) or data.get("response_variable", response_variable)
        
        if not image:
            image = nested_data.get("image") or data.get("image")

    if not title:
        title = "Home Assistant"
    if not message:
        log.error("Message is required for notification")
        return None

    # Parse actions
    action_map = {}
    action_titles = []
    
    if actions:
        if isinstance(actions, list) and len(actions) > 0:
            if isinstance(actions[0], dict):
                for item in actions:
                    action_id = item.get("action", item.get("title", "unknown"))
                    action_title = item.get("title", action_id)
                    action_map[action_title] = action_id
                    action_titles.append(action_title)
            else:
                for item in actions:
                    action_map[item] = item
                    action_titles.append(item)
        elif isinstance(actions, str):
            for item in actions.split(","):
                item = item.strip()
                action_map[item] = item
                action_titles.append(item)
    
    actions_str = ",".join(action_titles) if action_titles else None
    log.info(f"Parsed actions: {action_titles}")

    # Build command
    notificli_base = "/Applications/NotifiCLI.app"
    variant_name = "HomeAssistant"
    
    if persistent:
        notifier_path = f"{notificli_base}/Contents/Apps/NotifiPersistent-{variant_name}.app/Contents/MacOS/NotifiPersistent-{variant_name}"
    else:
        notifier_path = f"{notificli_base}/Contents/Apps/NotifiCLI-{variant_name}.app/Contents/MacOS/NotifiCLI-{variant_name}"
    
    cmd_parts = [notifier_path, "-title", shlex.quote(title), "-message", shlex.quote(message)]
    
    if subtitle:
        cmd_parts.extend(["-subtitle", shlex.quote(subtitle)])
    if image:
        cmd_parts.extend(["-image", shlex.quote(image)])
    if actions_str:
        cmd_parts.extend(["-actions", shlex.quote(actions_str)])
    if reply:
        cmd_parts.extend(["-reply", shlex.quote(reply)])
    if url:
        cmd_parts.extend(["-url", shlex.quote(url)])
    if sound:
        cmd_parts.extend(["-sound", shlex.quote(sound)])

    notifier_command = " ".join(cmd_parts)
    log.info(f"NotifiCLI command: {notifier_command}")

    # Variable initialization correctly ordered
    is_interactive = actions_str or reply or url
    wait_timeout = timeout if is_interactive else 30

    # Proactively kill any hanging SSH processes for this specific destination
    # This prevents thread pool depletion from zombie/hanging sessions
    try:
        # We need to import subprocess inside task.executor sometimes, but here we use it as an arg
        kill_cmd = ["pkill", "-f", f"ssh.*{SSH_USER}@{SSH_HOST}.*{variant_name}"]
        task.executor(subprocess.run, kill_cmd, capture_output=True, timeout=5)
        log.info(f"Proactively cleared stale SSH sessions for {SSH_USER}@{SSH_HOST}")
    except Exception as e:
        # Ignore errors if pkill fails or finds no processes
        pass

    # Build the final SSH command with an OS-level timeout
    # We add 2 seconds to the wait_timeout to give subprocess.run a chance to catch it first if it can
    os_timeout = wait_timeout + 2
    ssh_command = [
        "timeout", str(os_timeout),
        "ssh", "-i", SSH_KEY_PATH,
        "-o", "StrictHostKeyChecking=no",
        "-o", "ConnectTimeout=10",
        f"{SSH_USER}@{SSH_HOST}",
        notifier_command
    ]

    if not blocking and is_interactive:
        # Non-blocking: queue notification for background processing
        notification_id = str(uuid.uuid4())[:8]
        _pending_notifications[notification_id] = {
            "ssh_command": ssh_command,
            "action_map": action_map,
            "wait_timeout": wait_timeout,
            "response_variable": response_variable
        }
        # Fire event to trigger background processing
        event.fire("mac_mini_notification_queued", notification_id=notification_id)
        log.info(f"Queued notification {notification_id} for background processing")
        return None
    
    # Blocking mode - run synchronously using task.executor with subprocess.run directly
    try:
        # Capture stdout and stderr
        result = task.executor(subprocess.run, ssh_command, capture_output=True, text=True, check=True, timeout=wait_timeout)
        stdout = result.stdout if result.stdout else ""
        stderr = result.stderr if result.stderr else ""
        
        log.warning(f"=== SSH STDOUT: {repr(stdout)}")
        log.warning(f"=== SSH STDERR: {repr(stderr)}")
        
        # Split by lines and take the last non-empty line to ignore SSH banners
        lines = [line.strip() for line in stdout.split('\n') if line.strip()]
        response = lines[-1] if lines else None
        
        log.warning(f"=== BLOCKING RESPONSE: '{response}' (from raw: {repr(stdout)}) ===")
        log.warning(f"=== PARSED LINES: {lines} ===")
        
        action_response = None
        if response:
            # Try case-insensitive match in action_map
            for title, action_id in action_map.items():
                if response.lower() == title.lower():
                    action_response = action_id
                    log.warning(f"=== MATCHED title '{title}' -> '{action_id}' ===")
                    break
                if response.lower() == action_id.lower():
                    action_response = action_id
                    log.warning(f"=== MATCHED action_id directly -> '{action_id}' ===")
                    break
            
            if not action_response:
                action_response = response
                log.warning(f"=== NO MAP MATCH, using extracted: '{action_response}' ===")
    except Exception as e:
        log.warning(f"!!! Notification error: {e}")
        # Try to capture stderr from the exception if available
        stderr = getattr(e, 'stderr', 'No stderr available')
        stdout = getattr(e, 'stdout', 'No stdout available')
        log.warning(f"!!! Error stdout: {repr(stdout)}")
        log.warning(f"!!! Error stderr: {repr(stderr)}")
        action_response = "timeout" if "timeout" in str(e).lower() else None
    
    if action_response and action_response not in ["timeout", None, "dismissed"]:
        log.warning(f"=== FIRING ios.notification_action_fired: actionName='{action_response}' ===")
        event.fire("ios.notification_action_fired",
            actionName=action_response,
            categoryName="DYNAMIC",
            sourceDeviceID="mac_mini",
            sourceDeviceName="Mac mini",
            sourceDevicePermanentID="MAC-MINI-HA-NOTIFIER",
            origin="REMOTE"
        )
        log.warning("=== EVENT FIRED ===")
        event.fire("pyscript_notification_success", action=action_response)
    else:
        log.warning(f"=== NOT FIRING ACTION EVENT (response={action_response}) ===")
        event.fire("pyscript_notification_failure", 
            response=action_response, 
            stdout=stdout,
            stderr=stderr,
            timestamp=str(task.datetime())
        )
    
    return action_response


@event_trigger("mac_mini_notification_queued")
def process_queued_notification(notification_id=None, **kwargs):
    """Background processor for queued notifications."""
    log.warning(f"=== BACKGROUND PROCESSOR STARTED for {notification_id} ===")
    
    if not notification_id or notification_id not in _pending_notifications:
        log.error(f"Unknown notification_id: {notification_id}")
        return
    
    ctx = _pending_notifications.pop(notification_id)
    ssh_command = ctx["ssh_command"]
    action_map = ctx["action_map"]
    wait_timeout = ctx["wait_timeout"]
    response_variable = ctx["response_variable"]
    
    response = None
    action_response = None
    stdout = ""
    stderr = ""
    
    log.warning(f"Action map: {action_map}")
    log.warning(f"SSH command: {' '.join(ssh_command)}")
    
    # Run subprocess.run directly via task.executor (it's a stdlib function, not pyscript)
    try:
        result = task.executor(subprocess.run, ssh_command, capture_output=True, text=True, check=True, timeout=wait_timeout)
        stdout = result.stdout if result.stdout else ""
        stderr = result.stderr if result.stderr else ""
        
        log.warning(f"=== BG SSH STDOUT: {repr(stdout)}")
        log.warning(f"=== BG SSH STDERR: {repr(stderr)}")
        
        # Split by lines and take the last non-empty line to ignore SSH banners
        lines = [line.strip() for line in stdout.split('\n') if line.strip()]
        response = lines[-1] if lines else None
        
        log.warning(f"=== BG RESPONSE: '{response}' (from raw: {repr(stdout)}) ===")
        
        action_response = None
        if response:
            # Try case-insensitive match in action_map
            for title, action_id in action_map.items():
                if response.lower() == title.lower():
                    action_response = action_id
                    log.warning(f"=== BG MATCHED title '{title}' -> '{action_id}' ===")
                    break
                if response.lower() == action_id.lower():
                    action_response = action_id
                    log.warning(f"=== BG MATCHED action_id directly -> '{action_id}' ===")
                    break
            
            if not action_response:
                # If No match, check if it's the identifier/action_id itself
                # (Some versions of NotifiCLI might return the id instead of the label)
                action_response = response
                log.warning(f"=== BG NO MAP MATCH, using extracted: '{action_response}' ===")
    except Exception as e:
        log.warning(f"!!! BG Notification error: {e}")
        # Try to capture stderr from the exception if available
        stderr = getattr(e, 'stderr', 'No stderr available')
        stdout = getattr(e, 'stdout', 'No stdout available')
        log.warning(f"!!! BG Error stdout: {repr(stdout)}")
        log.warning(f"!!! BG Error stderr: {repr(stderr)}")
        action_response = "timeout" if "timeout" in str(e).lower() else None

    # Fire event for HA to catch
    if action_response and action_response not in ["timeout", None, "dismissed"]:
        log.warning(f"=== BG FIRING ios.notification_action_fired: actionName='{action_response}' ===")
        event.fire("ios.notification_action_fired",
            actionName=action_response,
            categoryName="DYNAMIC",
            sourceDeviceID="mac_mini",
            sourceDeviceName="Mac mini",
            sourceDevicePermanentID="MAC-MINI-HA-NOTIFIER",
            origin="REMOTE"
        )
        log.warning("=== BG EVENT FIRED ===")
        event.fire("pyscript_notification_success", action=action_response)
    else:
        log.warning(f"=== BG NOT FIRING ACTION EVENT (response={action_response}) ===")
        event.fire("pyscript_notification_failure", 
            response=action_response, 
            stdout=stdout,
            stderr=stderr,
            timestamp=str(task.datetime())
        )
