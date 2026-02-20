import subprocess
import time


def _run_networksetup(args):
    return subprocess.run(
        ["networksetup"] + args,
        check=True,
        capture_output=True,
        text=True
    )


def _parse_proxy_output(output):
    info = {
        "enabled": False,
        "server": "",
        "port": 0,
    }

    for raw_line in output.splitlines():
        line = raw_line.strip()
        if line.startswith("Enabled:"):
            info["enabled"] = line.split(":", 1)[1].strip().lower() == "yes"
        elif line.startswith("Server:"):
            info["server"] = line.split(":", 1)[1].strip()
        elif line.startswith("Port:"):
            port_text = line.split(":", 1)[1].strip()
            try:
                info["port"] = int(port_text)
            except ValueError:
                info["port"] = 0

    return info


def _get_single_proxy(interface, secure=False):
    try:
        command = "-getsecurewebproxy" if secure else "-getwebproxy"
        result = _run_networksetup([command, interface])
        return _parse_proxy_output(result.stdout)
    except Exception:
        return {
            "enabled": False,
            "server": "",
            "port": 0,
        }


def get_system_proxy_state(interface):
    return {
        "web": _get_single_proxy(interface, secure=False),
        "secure_web": _get_single_proxy(interface, secure=True),
    }


def _is_proxy_enabled_with_target(interface, proxy_host, proxy_port):
    state = get_system_proxy_state(interface)
    target_host = str(proxy_host).strip()
    target_port = int(proxy_port)
    web = state["web"]
    secure = state["secure_web"]
    return (
        web.get("enabled") is True and
        secure.get("enabled") is True and
        web.get("server") == target_host and
        secure.get("server") == target_host and
        int(web.get("port", 0) or 0) == target_port and
        int(secure.get("port", 0) or 0) == target_port
    )


def _is_proxy_disabled(interface):
    state = get_system_proxy_state(interface)
    web = state["web"]
    secure = state["secure_web"]
    return (web.get("enabled") is False) and (secure.get("enabled") is False)


def _wait_until(predicate, timeout_ms=2500, interval_ms=100):
    deadline = time.time() + (timeout_ms / 1000.0)
    while time.time() < deadline:
        if predicate():
            return True
        time.sleep(interval_ms / 1000.0)
    return predicate()


def get_proxy_bypass_domains(interface):
    try:
        result = _run_networksetup(["-getproxybypassdomains", interface])
        lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
        if not lines:
            return []
        if "aren't any" in lines[0].lower():
            return []
        return lines
    except Exception:
        return []


def capture_proxy_state(interface):
    try:
        web_result = _run_networksetup(["-getwebproxy", interface])
        secure_result = _run_networksetup(["-getsecurewebproxy", interface])

        return {
            "web": _parse_proxy_output(web_result.stdout),
            "secure_web": _parse_proxy_output(secure_result.stdout),
            "bypass_domains": get_proxy_bypass_domains(interface),
        }
    except Exception:
        return None


def _restore_single_proxy(interface, proxy_type, info):
    if proxy_type == "web":
        set_cmd = "-setwebproxy"
        state_cmd = "-setwebproxystate"
    else:
        set_cmd = "-setsecurewebproxy"
        state_cmd = "-setsecurewebproxystate"

    enabled = bool(info.get("enabled"))
    server = str(info.get("server", "")).strip()
    port = int(info.get("port", 0) or 0)

    if enabled and server and port > 0:
        _run_networksetup([set_cmd, interface, server, str(port)])
        _run_networksetup([state_cmd, interface, "on"])
    else:
        _run_networksetup([state_cmd, interface, "off"])


def restore_proxy_state(interface, state):
    try:
        if not state:
            return clear_system_proxy(interface)

        _restore_single_proxy(interface, "web", state.get("web", {}))
        _restore_single_proxy(interface, "secure_web", state.get("secure_web", {}))

        bypass_domains = state.get("bypass_domains", [])
        if bypass_domains:
            _run_networksetup(["-setproxybypassdomains", interface] + bypass_domains)
        else:
            _run_networksetup(["-setproxybypassdomains", interface, "Empty"])

        return True
    except Exception:
        return False


def set_system_proxy(interface, proxy_host, proxy_port):
    try:
        _run_networksetup([
            "-setwebproxy", interface, proxy_host, str(proxy_port)
        ])
        _run_networksetup(["-setwebproxystate", interface, "on"])

        _run_networksetup([
            "-setsecurewebproxy", interface, proxy_host, str(proxy_port)
        ])
        _run_networksetup(["-setsecurewebproxystate", interface, "on"])

        _run_networksetup([
            "-setproxybypassdomains", interface,
            '*.local', '169.254/16', '127.0.0.1', 'localhost'
        ])

        return _wait_until(
            lambda: _is_proxy_enabled_with_target(interface, proxy_host, proxy_port),
            timeout_ms=3000,
            interval_ms=100,
        )
    except Exception:
        # Partial failure — roll back to a clean disabled state.
        try:
            clear_system_proxy(interface)
        except Exception:
            pass
        return False



def clear_system_proxy(interface):
    try:
        _run_networksetup(["-setwebproxystate", interface, "off"])
        _run_networksetup(["-setsecurewebproxystate", interface, "off"])
        return _wait_until(
            lambda: _is_proxy_disabled(interface),
            timeout_ms=3000,
            interval_ms=100,
        )
    except Exception:
        return False
