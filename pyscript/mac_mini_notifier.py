import subprocess
import shlex
import uuid

# Storage for pending notifications
_pending_notifications = {}


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
    timeout=300,
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

    ssh_command = [
        "ssh", "-i", "/config/.ssh/id_rsa",
        "-o", "StrictHostKeyChecking=no",
        "-o", "ConnectTimeout=10",
        "USERNAME@IP-ADDRESS", ## Change this ##
        notifier_command
    ]

    is_interactive = actions_str or reply or url
    wait_timeout = timeout if is_interactive else 30

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
        result = task.executor(subprocess.run, ssh_command, capture_output=True, text=True, check=True, timeout=wait_timeout)
        response = result.stdout.strip() if result.stdout else None
        log.info(f"Raw response: '{response}'")
        
        action_response = None
        if response and response in action_map:
            action_response = action_map[response]
            log.info(f"Mapped '{response}' -> '{action_response}'")
        else:
            action_response = response
    except Exception as e:
        log.error(f"Notification error: {e}")
        action_response = "timeout" if "timeout" in str(e).lower() else None
    
    if action_response and action_response not in ["timeout", None, "dismissed"]:
        log.info(f"Firing ios.notification_action_fired: {action_response}")
        event.fire("ios.notification_action_fired",
            actionName=action_response,
            categoryName="DYNAMIC",
            sourceDeviceID="mac_mini",
            sourceDeviceName="Mac mini",
            sourceDevicePermanentID="MAC-MINI-HA-NOTIFIER",
            origin="REMOTE"
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
    
    log.warning(f"Action map: {action_map}")
    log.warning(f"SSH command: {' '.join(ssh_command)}")
    
    # Run subprocess.run directly via task.executor (it's a stdlib function, not pyscript)
    try:
        result = task.executor(subprocess.run, ssh_command, capture_output=True, text=True, check=True, timeout=wait_timeout)
        response = result.stdout.strip() if result.stdout else None
        log.warning(f"=== RAW RESPONSE: '{response}' ===")
        log.warning(f"Response repr: {repr(response)}")
        log.warning(f"Response in action_map? {response in action_map if response else 'N/A'}")
        
        action_response = None
        if response and response in action_map:
            action_response = action_map[response]
            log.warning(f"MAPPED: '{response}' -> '{action_response}'")
        else:
            action_response = response
            log.warning(f"NOT MAPPED, using raw: '{action_response}'")
    except Exception as e:
        log.warning(f"Background notification error: {e}")
        action_response = "timeout" if "timeout" in str(e).lower() else None
    
    log.warning(f"=== FINAL action_response: '{action_response}' ===")
    log.warning(f"Will fire event? {action_response and action_response not in ['timeout', None, 'dismissed']}")
    
    if action_response and action_response not in ["timeout", None, "dismissed"]:
        log.warning(f"=== FIRING ios.notification_action_fired with actionName='{action_response}' ===")
        event.fire("ios.notification_action_fired",
            actionName=action_response,
            categoryName="DYNAMIC",
            sourceDeviceID="mac_mini",
            sourceDeviceName="Mac mini",
            sourceDevicePermanentID="MAC-MINI-HA-NOTIFIER",
            origin="REMOTE"
        )
        log.warning("=== EVENT FIRED ===")
    else:
        log.warning(f"=== NOT FIRING EVENT (action_response={action_response}) ===")
    
    if response_variable and action_response:
        try:
            service.call("input_text", "set_value", entity_id=response_variable, value=action_response)
        except Exception as e:
            log.error(f"Failed to set response variable: {e}")


@service("notify.mac_mini_ask")
def mac_mini_ask(title="Question", message=None, actions=None, persistent=True, timeout=300, blocking=True):
    """Ask a question and wait for response."""
    if actions is None:
        actions = [{"action": "yes", "title": "Yes"}, {"action": "no", "title": "No"}]
    return mac_mini_notify(title=title, message=message, actions=actions, persistent=persistent, timeout=timeout, blocking=blocking)


@service("notify.mac_mini_prompt")
def mac_mini_prompt(title="Input", message=None, placeholder="Type here...", persistent=True, timeout=300, blocking=True):
    """Prompt for text input and return the response."""
    return mac_mini_notify(title=title, message=message, reply=placeholder, persistent=persistent, timeout=timeout, blocking=blocking)
