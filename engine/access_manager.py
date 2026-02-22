"""
OffVeil Access Manager — Universal Configuration

Manages the SpoofDPI process lifecycle with a single, zero-config setup.
No ISP-specific tuning. Works across all ISPs with one configuration:

  - DoH (DNS-over-HTTPS) via Cloudflare → no system DNS changes needed
  - TCP fragmentation of TLS ClientHello → handled by SpoofDPI internally
  - DNS cache → faster repeated lookups
  - QUIC is implicitly blocked → system proxy forces browsers to use TCP

This mirrors the Windows version's "Universal Profile" philosophy:
one config, every ISP, zero user intervention.
"""

import os
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path


_LOG_DIR = Path.home() / "Library" / "Logs" / "OffVeil"


def _ensure_log_dir():
    _LOG_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)


DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 18080
READY_TIMEOUT_MS = 5000

# Universal DPI bypass configuration — single config for all ISPs
UNIVERSAL_CONFIG = {
    "dns_mode": "https",
    "dns_qtype": "ipv4",
    "doh_url": "https://cloudflare-dns.com/dns-query",
    # Chunk-based ClientHello splitting to bypass SNI inspection
    # "chunk" mode splits the entire TLS ClientHello into N-byte pieces
    # (unlike "sni" which only splits at the SNI boundary — insufficient for aggressive DPI)
    "https_split_mode": "chunk",
    "https_chunk_size": 2,
    # Auto-detect blocked sites and apply bypass only where needed
    # Adapts to any ISP's DPI without manual configuration
    "policy_auto": True,
    "timeout": 5000,
}


def _binary_candidates():
    if getattr(sys, 'frozen', False):
        # PyInstaller bundle: sys.executable = engine/bin/offveil-engine/offveil-engine
        # spoofdpi lives at engine/bin/spoofdpi (sibling of offveil-engine dir)
        bin_dir = Path(sys.executable).resolve().parent.parent
    else:
        # Normal Python: access_manager.py is in engine/
        bin_dir = Path(__file__).resolve().parent / "bin"

    return [
        str(bin_dir / "spoofdpi"),
        str(bin_dir / "spoofdpi-arm64"),
        str(bin_dir / "spoofdpi-x86_64"),
    ]


def _ensure_executable(path):
    try:
        if not os.access(path, os.X_OK):
            os.chmod(path, os.stat(path).st_mode | 0o111)
        return os.access(path, os.X_OK)
    except Exception:
        return False


def find_access_binary():
    for candidate in _binary_candidates():
        if os.path.isfile(candidate) and _ensure_executable(candidate):
            return candidate
    return None


def _build_command(host, port):
    binary = find_access_binary()
    if not binary:
        return None

    command = [
        binary,
        "--listen-addr", f"{host}:{port}",
        "--silent",
        "--dns-mode", UNIVERSAL_CONFIG["dns_mode"],
        "--dns-qtype", UNIVERSAL_CONFIG["dns_qtype"],
        "--dns-cache",
        "--dns-https-url", UNIVERSAL_CONFIG["doh_url"],
        "--https-split-mode", UNIVERSAL_CONFIG["https_split_mode"],
        "--https-chunk-size", str(UNIVERSAL_CONFIG["https_chunk_size"]),
        "--policy-auto",
        "--timeout", str(UNIVERSAL_CONFIG["timeout"]),
    ]
    return command


def _tail_text(path, max_chars=800):
    try:
        content = Path(path).read_text(encoding="utf-8", errors="replace")
        return content[-max_chars:].strip()
    except Exception:
        return ""


def _rotate_logs(keep=5):
    """Delete oldest log files, keeping only the most recent `keep` files."""
    try:
        logs = sorted(_LOG_DIR.glob("access-*.log"), key=lambda p: p.stat().st_mtime)
        for old_log in logs[:-keep]:
            try:
                old_log.unlink()
            except OSError:
                pass
    except Exception:
        pass


def _is_port_in_use(host, port):
    try:
        with socket.create_connection((host, int(port)), timeout=0.3):
            return True
    except Exception:
        return False


def _is_port_ready(host, port):
    try:
        with socket.create_connection((host, int(port)), timeout=0.2):
            return True
    except Exception:
        return False


def _wait_for_process_ready(process, host, port):
    deadline = time.time() + (READY_TIMEOUT_MS / 1000.0)
    while time.time() < deadline:
        if process.poll() is not None:
            return False, "Access process terminated right after start"
        if _is_port_ready(host, port):
            return True, None

        time.sleep(0.1)
    return False, f"Access process did not become ready within {READY_TIMEOUT_MS}ms"


def start_access_process(host=None, port=None):
    host = host or DEFAULT_HOST
    port = port or DEFAULT_PORT

    if _is_port_in_use(host, port):
        return {
            "success": False,
            "error": f"Port {port} is already in use by another process. Close it and try again.",
        }

    command = _build_command(host, port)
    if not command:
        return {
            "success": False,
            "error": "No access binary found. Place spoofdpi in engine/bin/.",
        }

    try:
        _ensure_log_dir()
        _rotate_logs()
        log_path = str(_LOG_DIR / f"access-{int(time.time() * 1000)}.log")

        with open(log_path, "ab") as log_file:
            os.chmod(log_path, 0o600)
            process = subprocess.Popen(
                command,
                stdout=log_file,
                stderr=log_file,
                start_new_session=True,
            )

        ready, reason = _wait_for_process_ready(process, host, port)
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
            "log_path": log_path,
        }
    except Exception as e:
        return {
            "success": False,
            "error": f"Failed to start access process: {str(e)}",
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

    # Verify the process is actually dead after SIGKILL.
    kill_deadline = time.time() + 1.0
    while time.time() < kill_deadline:
        if not is_process_running(pid):
            return True
        time.sleep(0.1)

    return not is_process_running(pid)
