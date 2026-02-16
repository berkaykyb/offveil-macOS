"""
OffVeil Engine - Main Command Interface

Universal DPI bypass engine for macOS.
Single configuration, zero ISP-specific tuning.

Architecture:
  1. Start SpoofDPI (handles DPI bypass + DoH DNS internally)
  2. Set system proxy -> SpoofDPI (127.0.0.1:18080)
  3. QUIC is implicitly blocked (browsers use TCP through proxy)
  4. No system DNS changes needed

This mirrors the Windows version approach:
  - Zero-config universal bypass
  - DNS handled by the engine (DoH), not system settings
  - QUIC blocked (proxy forces TCP fallback)
  - Simple on/off lifecycle
"""

import sys
import json
import os
import subprocess
import uuid
from datetime import datetime
from pathlib import Path

import dns_manager
import state_manager
import isp_detector
import proxy_manager
import access_manager


def _resolve_owner_pid():
    raw_owner_pid = os.getenv("OFFVEIL_OWNER_PID", "").strip()
    if raw_owner_pid:
        try:
            owner_pid = int(raw_owner_pid)
            if owner_pid > 1:
                return owner_pid
        except ValueError:
            pass

    fallback_pid = os.getppid()
    return fallback_pid if fallback_pid > 1 else None


def _start_exit_watchdog(owner_pid, watchdog_token):
    if not owner_pid or not watchdog_token:
        return None

    try:
        watchdog_script = Path(__file__).resolve().parent / "app_watchdog.py"
        if not watchdog_script.exists():
            return None

        process = subprocess.Popen(
            ["/usr/bin/python3", str(watchdog_script), str(owner_pid), watchdog_token],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        return process.pid
    except Exception:
        return None


def main():
    if len(sys.argv) < 2:
        error_response("No command provided")
        return

    command = sys.argv[1]

    if command == "status":
        handle_status()
    elif command == "activate":
        handle_activate()
    elif command == "deactivate":
        handle_deactivate()
    elif command == "cleanup":
        handle_cleanup()
    elif command == "check_and_restore":
        handle_check_and_restore()
    elif command == "rebind_proxy":
        handle_rebind_proxy()
    elif command == "detect_isp":
        handle_detect_isp()
    else:
        error_response(f"Unknown command: {command}")


def handle_status():
    """Return current protection status."""
    is_active = state_manager.is_active()
    state = state_manager.load_state() if is_active else None

    response = {
        "success": True,
        "status": "active" if is_active else "inactive",
        "interface": state.get("active_interface") if state else None,
        "timestamp": datetime.now().isoformat(),
    }
    print(json.dumps(response))


def handle_activate():
    """
    Single-toggle activation:
      1. Detect active network service
      2. Save current proxy state
      3. Start SpoofDPI (universal config)
      4. Set system proxy -> SpoofDPI
      5. Start crash watchdog
    """
    if state_manager.is_active():
        error_response("Already active")
        return

    try:
        # 1. Detect primary network service
        primary_service = dns_manager.get_primary_service()
        if not primary_service:
            error_response("No active network service found")
            return

        # 2. Capture current proxy state (for restore on deactivate)
        original_proxy_state = proxy_manager.capture_proxy_state(primary_service)

        # 3. Start SpoofDPI with universal config
        start_result = access_manager.start_access_process()
        if not start_result["success"]:
            error = start_result.get("error", "Failed to start access process")
            log_tail = start_result.get("log_tail")
            if log_tail:
                last_line = log_tail.strip().splitlines()[-1]
                error = f"{error}. {last_line}"
            error_response(error)
            return

        proxy_host = start_result["host"]
        proxy_port = start_result["port"]
        proxy_pid = start_result["pid"]
        proxy_log_path = start_result.get("log_path")

        # 4. Set system proxy -> SpoofDPI
        proxy_success = proxy_manager.set_system_proxy(
            primary_service, proxy_host, proxy_port
        )
        if not proxy_success:
            access_manager.stop_access_process(proxy_pid)
            error_response("Failed to set system proxy")
            return

        # 5. Save state + start crash watchdog
        owner_pid = _resolve_owner_pid()
        watchdog_token = str(uuid.uuid4())

        state_data = {
            "active": True,
            "active_interface": primary_service,
            "original_proxy_state": original_proxy_state,
            "proxy_host": proxy_host,
            "proxy_port": proxy_port,
            "access_pid": proxy_pid,
            "access_log_path": proxy_log_path,
            "owner_pid": owner_pid,
            "watchdog_token": watchdog_token,
            "restore_attempts": 0,
            "timestamp": datetime.now().isoformat(),
        }
        state_manager.save_state(state_data)

        watchdog_pid = _start_exit_watchdog(owner_pid, watchdog_token)
        if watchdog_pid:
            state_data["watchdog_pid"] = watchdog_pid
            state_manager.save_state(state_data)

        # 6. Best-effort ISP detection (for display only, does not affect bypass)
        isp_name = None
        try:
            isp_result = isp_detector.detect_isp()
            if isp_result.get("success"):
                isp_name = isp_result.get("normalized_isp")
        except Exception:
            pass

        response = {
            "success": True,
            "message": "Activated successfully",
            "status": "active",
            "interface": primary_service,
            "proxy_host": proxy_host,
            "proxy_port": proxy_port,
            "access_pid": proxy_pid,
            "owner_pid": owner_pid,
            "watchdog_pid": watchdog_pid,
            "isp_normalized": isp_name,
            "timestamp": datetime.now().isoformat(),
        }
        print(json.dumps(response))

    except Exception as e:
        error_response(f"Activation failed: {str(e)}")


def handle_deactivate():
    """
    Single-toggle deactivation:
      1. Restore original proxy state
      2. Stop SpoofDPI process
      3. Clear state file
    No DNS restore needed - we never touch system DNS.
    """
    try:
        if not state_manager.is_active():
            error_response("Not active")
            return

        state = state_manager.load_state()
        if not state:
            error_response("No state found")
            return

        interface = state.get("active_interface")
        access_pid = state.get("access_pid")
        original_proxy_state = state.get("original_proxy_state")

        # 1. Restore proxy state
        proxy_restored = True
        if interface:
            proxy_restored = proxy_manager.restore_proxy_state(
                interface, original_proxy_state
            )

        # 2. Stop SpoofDPI process
        process_stopped = True
        if access_pid:
            process_stopped = access_manager.stop_access_process(access_pid)

        # 3. Clear state
        state_manager.clear_state()

        if not proxy_restored:
            error_response("Failed to restore system proxy")
            return

        if not process_stopped:
            error_response(f"Failed to stop access process pid={access_pid}")
            return

        response = {
            "success": True,
            "message": "Deactivated successfully",
            "status": "inactive",
            "interface": interface,
            "proxy_restored": proxy_restored,
            "process_stopped": process_stopped,
            "timestamp": datetime.now().isoformat(),
        }
        print(json.dumps(response))

    except Exception as e:
        error_response(f"Deactivation failed: {str(e)}")


def handle_cleanup():
    """
    Full system cleanup:
      1. Stop any running SpoofDPI / DPI bypass processes
      2. Reset all proxy settings on all active interfaces
      3. Reset DNS settings to default on all active interfaces
      4. Kill any orphaned spoofdpi/dpi processes
      5. Clear state file
    
    This is a nuclear option - resets everything to factory defaults.
    """
    try:
        errors = []
        actions_taken = []

        # 1. If we have saved state, restore from it first
        if state_manager.is_active():
            state = state_manager.load_state()
            if state:
                access_pid = state.get("access_pid")
                interface = state.get("active_interface")
                original_proxy_state = state.get("original_proxy_state")

                if access_pid:
                    try:
                        access_manager.stop_access_process(access_pid)
                        actions_taken.append(f"stopped_saved_process_{access_pid}")
                    except Exception as e:
                        errors.append(f"stop saved process: {e}")

                if interface and original_proxy_state:
                    try:
                        proxy_manager.restore_proxy_state(interface, original_proxy_state)
                        actions_taken.append(f"restored_proxy_{interface}")
                    except Exception as e:
                        errors.append(f"restore proxy: {e}")

        # 2. Kill ALL spoofdpi-related processes (catches orphans from other tools too)
        try:
            killed = _kill_all_dpi_processes()
            if killed:
                actions_taken.append(f"killed_orphan_processes_{killed}")
        except Exception as e:
            errors.append(f"kill orphans: {e}")

        # 3. Reset proxy on ALL active interfaces
        active_interfaces = dns_manager.get_active_interfaces()
        for iface in active_interfaces:
            try:
                proxy_manager.clear_system_proxy(iface)
                actions_taken.append(f"cleared_proxy_{iface}")
            except Exception as e:
                errors.append(f"clear proxy {iface}: {e}")

        # 4. Reset DNS to default (empty = DHCP/auto) on all active interfaces
        for iface in active_interfaces:
            try:
                dns_manager.reset_dns_to_default(iface)
                actions_taken.append(f"reset_dns_{iface}")
            except Exception as e:
                errors.append(f"reset dns {iface}: {e}")

        # 5. Clear state file
        state_manager.clear_state()
        actions_taken.append("cleared_state")

        # 6. Flush DNS cache
        try:
            _flush_dns_cache()
            actions_taken.append("flushed_dns_cache")
        except Exception:
            pass  # non-critical

        success = len(errors) == 0
        response = {
            "success": success,
            "message": "Cleanup completed" if success else f"Cleanup completed with errors: {'; '.join(errors)}",
            "actions": actions_taken,
            "errors": errors,
            "timestamp": datetime.now().isoformat(),
        }
        print(json.dumps(response))

    except Exception as e:
        error_response(f"Cleanup failed: {str(e)}")


def _kill_all_dpi_processes():
    """Kill any running spoofdpi or similar DPI bypass processes."""
    killed_count = 0
    process_names = ["spoofdpi", "spoofDPI", "SpoofDPI", "goodbyedpi", "GoodbyeDPI"]
    
    for proc_name in process_names:
        try:
            result = subprocess.run(
                ["pgrep", "-f", proc_name],
                capture_output=True, text=True
            )
            if result.returncode == 0:
                pids = result.stdout.strip().split("\n")
                for pid_str in pids:
                    pid_str = pid_str.strip()
                    if not pid_str:
                        continue
                    try:
                        pid = int(pid_str)
                        # Don't kill ourselves
                        if pid == os.getpid():
                            continue
                        os.kill(pid, 9)
                        killed_count += 1
                    except (ValueError, ProcessLookupError, PermissionError):
                        pass
        except Exception:
            pass

    return killed_count


def _flush_dns_cache():
    """Flush macOS DNS cache."""
    try:
        subprocess.run(
            ["dscacheutil", "-flushcache"],
            capture_output=True, check=False, timeout=5
        )
        # killall -HUP mDNSResponder without sudo — works if the process
        # allows the signal from the current user; silently ignored otherwise.
        subprocess.run(
            ["killall", "-HUP", "mDNSResponder"],
            capture_output=True, check=False, timeout=5
        )
    except Exception:
        pass


def handle_detect_isp():
    """ISP detection - for display only, does not affect bypass config."""
    try:
        result = isp_detector.detect_isp(force_refresh=True)

        if result["success"]:
            response = {
                "success": True,
                "isp": result["isp"],
                "normalized_isp": result["normalized_isp"],
                "country": result.get("country"),
                "timestamp": datetime.now().isoformat(),
            }
        else:
            response = {
                "success": False,
                "error": result.get("error", "Unknown error"),
            }

        print(json.dumps(response))

    except Exception as e:
        error_response(f"ISP detection failed: {str(e)}")


def handle_check_and_restore():
    """
    Fail-safe: restore system settings from orphaned state.
    Called on app launch and by the crash watchdog.
    Only needs to restore proxy + stop SpoofDPI (no DNS to restore).
    """
    try:
        if not state_manager.is_active():
            response = {
                "success": True,
                "message": "No active state, nothing to restore",
                "action": "none",
            }
            print(json.dumps(response))
            return

        state = state_manager.load_state()
        if not state:
            state_manager.clear_state()
            response = {
                "success": True,
                "message": "State file exists but empty, clearing",
                "action": "cleared",
            }
            print(json.dumps(response))
            return

        interface = state.get("active_interface")
        access_pid = state.get("access_pid")
        original_proxy_state = state.get("original_proxy_state")
        attempts = state_manager.get_restore_attempts()

        if not interface and not access_pid:
            state_manager.clear_state()
            error_response("Invalid state, cleared")
            return

        # Max 3 restore attempts
        if attempts >= 3:
            print(
                f"Warning: Restore failed after {attempts} attempts, giving up",
                file=sys.stderr,
            )
            state_manager.clear_state()
            error_response(f"Restore failed after {attempts} attempts")
            return

        # Restore system settings
        success = True
        try:
            if interface:
                success = proxy_manager.restore_proxy_state(
                    interface, original_proxy_state
                ) and success
            if access_pid:
                success = access_manager.stop_access_process(access_pid) and success
        except Exception as e:
            print(f"Restore error: {e}", file=sys.stderr)
            success = False

        if success:
            state_manager.clear_state()
            response = {
                "success": True,
                "message": "Restored system settings from orphaned state",
                "action": "restored",
                "interface": interface,
                "attempts": attempts + 1,
            }
            print(json.dumps(response))
        else:
            state_manager.increment_restore_attempts()
            response = {
                "success": False,
                "message": f"Restore failed (attempt {attempts + 1}/3)",
                "action": "retry",
                "attempts": attempts + 1,
            }
            print(json.dumps(response))

    except Exception as e:
        error_response(f"Check and restore failed: {str(e)}")


def handle_rebind_proxy():
    """
    Re-apply active proxy binding after network transitions (sleep/wake, Wi-Fi switch).
    Keeps protection active; does NOT stop SpoofDPI or clear state.
    """
    try:
        if not state_manager.is_active():
            response = {
                "success": True,
                "message": "Protection is inactive, nothing to rebind",
                "action": "none",
            }
            print(json.dumps(response))
            return

        state = state_manager.load_state()
        if not state:
            error_response("Active state missing")
            return

        old_interface = state.get("active_interface")
        access_pid = state.get("access_pid")
        proxy_host = state.get("proxy_host")
        proxy_port = state.get("proxy_port")

        if not access_pid or not access_manager.is_process_running(access_pid):
            error_response("Access process is not running")
            return

        if not proxy_host or not proxy_port:
            error_response("Invalid active state: proxy host/port missing")
            return

        new_interface = dns_manager.get_primary_service()
        if not new_interface:
            error_response("No active network service found")
            return

        interface_changed = old_interface != new_interface
        restore_old_success = True
        warning = None

        original_proxy_state = state.get("original_proxy_state")
        if interface_changed:
            new_original_proxy_state = proxy_manager.capture_proxy_state(new_interface)
            if new_original_proxy_state is None:
                error_response(
                    f"Failed to capture proxy state for new interface {new_interface}"
                )
                return

            if old_interface:
                restore_old_success = proxy_manager.restore_proxy_state(
                    old_interface, original_proxy_state
                )

            original_proxy_state = new_original_proxy_state

        proxy_applied = proxy_manager.set_system_proxy(
            new_interface, proxy_host, proxy_port
        )
        if not proxy_applied:
            error_response(f"Failed to apply proxy on {new_interface}")
            return

        if interface_changed:
            state["active_interface"] = new_interface
            state["original_proxy_state"] = original_proxy_state
            state["timestamp"] = datetime.now().isoformat()
            state_manager.save_state(state)

        if not restore_old_success and interface_changed:
            warning = f"Could not restore previous interface {old_interface}"

        response = {
            "success": True,
            "message": "Proxy rebound successfully" if interface_changed else "Proxy already bound",
            "action": "rebound" if interface_changed else "verified",
            "interface": new_interface,
            "previous_interface": old_interface,
            "warning": warning,
            "timestamp": datetime.now().isoformat(),
        }
        print(json.dumps(response))

    except Exception as e:
        error_response(f"Rebind proxy failed: {str(e)}")


def error_response(message):
    response = {
        "success": False,
        "error": message,
        "timestamp": datetime.now().isoformat(),
    }
    print(json.dumps(response))


if __name__ == "__main__":
    main()
