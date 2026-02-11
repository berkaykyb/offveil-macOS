import os
import shlex
import signal
import subprocess
import time
from pathlib import Path


DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 18080
DEFAULT_DOH_URL = "https://cloudflare-dns.com/dns-query"
DEFAULT_DNS_MODE = "https"
DEFAULT_TIMEOUT_MS = 5000
DEFAULT_DNS_QTYPE = "ipv4"


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


def _build_command(host, port):
    custom_command = os.getenv("OFFVEIL_ACCESS_COMMAND")
    if custom_command:
        return shlex.split(custom_command.format(host=host, port=port))

    binary = find_access_binary()
    if not binary:
        return None

    dns_mode = os.getenv("OFFVEIL_ACCESS_DNS_MODE", DEFAULT_DNS_MODE).strip().lower()
    # Keep backward compatibility with previous mode names.
    dns_mode_aliases = {
        "sys": "system",
        "doh": "https",
    }
    dns_mode = dns_mode_aliases.get(dns_mode, dns_mode)
    doh_url = os.getenv("OFFVEIL_ACCESS_DOH_URL", DEFAULT_DOH_URL)
    timeout_ms = str(_get_int_env("OFFVEIL_ACCESS_TIMEOUT_MS", DEFAULT_TIMEOUT_MS))
    dns_qtype = os.getenv("OFFVEIL_ACCESS_DNS_QTYPE", DEFAULT_DNS_QTYPE).strip().lower()

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

    return command


def _tail_text(path, max_chars=800):
    try:
        content = Path(path).read_text(encoding="utf-8", errors="replace")
        return content[-max_chars:].strip()
    except Exception:
        return ""


def start_access_process(host=None, port=None):
    host = host or get_default_host()
    port = port or get_default_port()

    command = _build_command(host, port)
    if not command:
        return {
            "success": False,
            "error": "No access binary found. Set OFFVEIL_ACCESS_BINARY or OFFVEIL_ACCESS_COMMAND."
        }

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

        time.sleep(0.4)
        if process.poll() is not None:
            log_tail = _tail_text(log_path)
            return {
                "success": False,
                "error": "Access process terminated right after start",
                "log_path": log_path,
                "log_tail": log_tail,
            }

        return {
            "success": True,
            "pid": process.pid,
            "host": host,
            "port": port,
            "command": command,
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
