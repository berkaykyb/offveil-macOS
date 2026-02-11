import os
import shlex
import signal
import socket
import subprocess
import time
from pathlib import Path


DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 18080
DEFAULT_DOH_URL = "https://cloudflare-dns.com/dns-query"
DEFAULT_DNS_MODE = "https"
DEFAULT_TIMEOUT_MS = 5000
DEFAULT_DNS_QTYPE = "ipv4"
DEFAULT_READY_TIMEOUT_MS = 5000
ALLOWED_DNS_MODES = {"udp", "https", "system"}


def _get_int_env(name, default_value):
    value = os.getenv(name)
    if not value:
        return default_value

    try:
        return int(value)
    except ValueError:
        return default_value


def get_default_host():
    return os.getenv("OFFVEIL_ACCESS_HOST", DEFAULT_HOST)


def get_default_port():
    return _get_int_env("OFFVEIL_ACCESS_PORT", DEFAULT_PORT)


def _binary_candidates():
    engine_dir = Path(__file__).resolve().parent

    candidates = [
        os.getenv("OFFVEIL_ACCESS_BINARY"),
        str(engine_dir / "bin" / "spoofdpi"),
        str(engine_dir / "bin" / "spoofdpi-arm64"),
        str(engine_dir / "bin" / "spoofdpi-x86_64"),
    ]

    return [candidate for candidate in candidates if candidate]


def _ensure_executable(path):
    try:
        mode = os.stat(path).st_mode
        if not os.access(path, os.X_OK):
            os.chmod(path, mode | 0o111)
        return os.access(path, os.X_OK)
    except Exception:
        return False


def find_access_binary():
    for candidate in _binary_candidates():
        if os.path.isfile(candidate) and _ensure_executable(candidate):
            return candidate
    return None


def _get_profile_value(profile, key):
    if not profile:
        return None
    value = profile.get(key)
    if isinstance(value, str):
        value = value.strip()
    return value if value not in (None, "") else None


def _resolve_dns_mode(profile):
    value = _get_profile_value(profile, "dns_mode")
    if value is None:
        value = os.getenv("OFFVEIL_ACCESS_DNS_MODE", DEFAULT_DNS_MODE)

    dns_mode = str(value).strip().lower()
    dns_mode_aliases = {
        "sys": "system",
        "doh": "https",
    }
    dns_mode = dns_mode_aliases.get(dns_mode, dns_mode)
    if dns_mode not in ALLOWED_DNS_MODES:
        return DEFAULT_DNS_MODE
    return dns_mode


def _resolve_timeout_ms(profile):
    value = _get_profile_value(profile, "timeout_ms")
    if value is None:
        return _get_int_env("OFFVEIL_ACCESS_TIMEOUT_MS", DEFAULT_TIMEOUT_MS)

    try:
        timeout_value = int(value)
        return timeout_value if timeout_value > 0 else DEFAULT_TIMEOUT_MS
    except Exception:
        return DEFAULT_TIMEOUT_MS


def _resolve_dns_qtype(profile):
    value = _get_profile_value(profile, "dns_qtype")
    if value is None:
        value = os.getenv("OFFVEIL_ACCESS_DNS_QTYPE", DEFAULT_DNS_QTYPE)
    return str(value).strip().lower()


def _resolve_doh_url(profile):
    value = _get_profile_value(profile, "doh_url")
    if value is None:
        value = os.getenv("OFFVEIL_ACCESS_DOH_URL", DEFAULT_DOH_URL)
    return str(value).strip()


def _build_runtime_profile(profile):
    dns_mode = _resolve_dns_mode(profile)
    timeout_ms = _resolve_timeout_ms(profile)
    dns_qtype = _resolve_dns_qtype(profile)
    doh_url = _resolve_doh_url(profile)
    return {
        "dns_mode": dns_mode,
        "timeout_ms": timeout_ms,
        "dns_qtype": dns_qtype,
        "doh_url": doh_url,
        "profile_id": _get_profile_value(profile, "id") or "default",
    }


def _build_command(host, port, profile=None):
    custom_command = os.getenv("OFFVEIL_ACCESS_COMMAND")
    if custom_command:
        return shlex.split(custom_command.format(host=host, port=port)), _build_runtime_profile(profile)

    binary = find_access_binary()
    if not binary:
        return None, None

    runtime_profile = _build_runtime_profile(profile)
    dns_mode = runtime_profile["dns_mode"]
    timeout_ms = str(runtime_profile["timeout_ms"])
    dns_qtype = runtime_profile["dns_qtype"]
    doh_url = runtime_profile["doh_url"]

    # Tuned defaults for faster app/site open with one-click usage.
    command = [
        binary,
        "--listen-addr",
        f"{host}:{port}",
        "--silent",
        "--dns-mode",
        dns_mode,
        "--dns-qtype",
        dns_qtype,
        "--timeout",
        timeout_ms,
        "--dns-cache",
    ]

    if dns_mode == "https":
        command.extend(["--dns-https-url", doh_url])

    return command, runtime_profile


def _tail_text(path, max_chars=800):
    try:
        content = Path(path).read_text(encoding="utf-8", errors="replace")
        return content[-max_chars:].strip()
    except Exception:
        return ""


def _is_port_ready(host, port):
    try:
        with socket.create_connection((host, int(port)), timeout=0.2):
            return True
    except Exception:
        return False


def _wait_for_process_ready(process, host, port, ready_timeout_ms):
    deadline = time.time() + (ready_timeout_ms / 1000.0)
    while time.time() < deadline:
        if process.poll() is not None:
            return False, "Access process terminated right after start"
        if _is_port_ready(host, port):
            return True, None
        time.sleep(0.1)
    return False, f"Access process did not become ready within {ready_timeout_ms}ms"


def start_access_process(host=None, port=None, profile=None):
    host = host or get_default_host()
    port = port or get_default_port()

    command, runtime_profile = _build_command(host, port, profile)
    if not command:
        return {
            "success": False,
            "error": "No access binary found. Set OFFVEIL_ACCESS_BINARY or OFFVEIL_ACCESS_COMMAND."
        }

    ready_timeout_ms = _get_int_env("OFFVEIL_ACCESS_READY_TIMEOUT_MS", DEFAULT_READY_TIMEOUT_MS)
    if ready_timeout_ms <= 0:
        ready_timeout_ms = DEFAULT_READY_TIMEOUT_MS

    try:
        log_path = f"/tmp/offveil-access-{int(time.time() * 1000)}.log"
        log_file = open(log_path, "ab")

        process = subprocess.Popen(
            command,
            stdout=log_file,
            stderr=log_file,
            start_new_session=True
        )
        log_file.close()

        ready, reason = _wait_for_process_ready(process, host, port, ready_timeout_ms)
        if not ready:
            stop_access_process(process.pid)
            log_tail = _tail_text(log_path)
            return {
                "success": False,
                "error": reason,
                "log_path": log_path,
                "log_tail": log_tail,
            }

        return {
            "success": True,
            "pid": process.pid,
            "host": host,
            "port": port,
            "command": command,
            "runtime_profile": runtime_profile,
            "log_path": log_path,
        }
    except Exception as e:
        return {
            "success": False,
            "error": f"Failed to start access process: {str(e)}"
        }


def is_process_running(pid):
    if not pid:
        return False

    try:
        os.kill(pid, 0)
        return True
    except Exception:
        return False


def stop_access_process(pid):
    if not pid:
        return True

    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        return True
    except Exception:
        return False

    deadline = time.time() + 2.0
    while time.time() < deadline:
        if not is_process_running(pid):
            return True
        time.sleep(0.1)

    try:
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        return True
    except Exception:
        return False

    return True
