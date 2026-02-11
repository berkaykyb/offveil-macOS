"""
OffVeil Engine - Main Command Interface
Komut alan ve JSON döndüren basit motor
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


DEFAULT_ACCESS_PROFILE = {
    "id": "default",
    "dns_mode": "https",
    "dns_qtype": "ipv4",
    "timeout_ms": 5000,
    "doh_url": "https://cloudflare-dns.com/dns-query",
}

# Tek tuş akışında kullanıcıya mod göstermeden ISP'ye göre ayar seçimi.
ISP_PROFILE_RULES = [
    ("superonline", {"id": "superonline", "timeout_ms": 7000}),
    (
        "avea",
        {
            "id": "turk_telekom_mobile",
            "timeout_ms": 8500,
            "dns_qtype": "ipv4",
            "doh_url": "https://dns.google/dns-query",
        },
    ),
    (
        "tt mobil",
        {
            "id": "turk_telekom_mobile",
            "timeout_ms": 8500,
            "dns_qtype": "ipv4",
            "doh_url": "https://dns.google/dns-query",
        },
    ),
    (
        "turk telekom mobil",
        {
            "id": "turk_telekom_mobile",
            "timeout_ms": 8500,
            "dns_qtype": "ipv4",
            "doh_url": "https://dns.google/dns-query",
        },
    ),
    ("turk telekom", {"id": "turk_telekom", "timeout_ms": 5500}),
    ("ttnet", {"id": "turk_telekom", "timeout_ms": 5500}),
    ("turksat", {"id": "turksat", "timeout_ms": 6500}),
    ("vodafone", {"id": "vodafone", "timeout_ms": 4500}),
    ("turkcell", {"id": "turkcell", "timeout_ms": 5000}),
    ("turknet", {"id": "turknet", "timeout_ms": 4000}),
]


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
    elif command == "check_and_restore":
        handle_check_and_restore()
    elif command == "detect_isp":
        handle_detect_isp()
    else:
        error_response(f"Unknown command: {command}")


def _resolve_mode(state):
    if not state:
        return None
    if state.get("mode"):
        return state.get("mode")
    # Backward compatibility with old state files.
    if state.get("access_pid") or state.get("proxy_port"):
        return "access"
    return "dns"


def _normalize_isp_key(value):
    if not value:
        return ""
    normalized = str(value).strip().lower()
    translation = str.maketrans({
        "ç": "c",
        "ğ": "g",
        "ı": "i",
        "ö": "o",
        "ş": "s",
        "ü": "u",
    })
    normalized = normalized.translate(translation)
    return " ".join(normalized.split())


def _resolve_access_profile():
    profile = dict(DEFAULT_ACCESS_PROFILE)
    isp_details = {
        "detected_isp": None,
        "normalized_isp": None,
        "source": None,
        "profile_id": profile["id"],
        "detection_error": None,
    }

    try:
        forced_profile_id = os.getenv("OFFVEIL_FORCE_PROFILE", "").strip().lower()
        forced_isp = os.getenv("OFFVEIL_FORCE_ISP", "").strip()
        detected_org = None
        detected_asn = None

        if forced_isp:
            detected_isp = forced_isp
            normalized_isp = isp_detector.normalize_isp_name(forced_isp)
            isp_details["source"] = "forced"
            isp_details["detection_error"] = "forced_isp_override"
        else:
            result = isp_detector.detect_isp(force_refresh=True)
            if not result.get("success"):
                isp_details["detection_error"] = result.get("error", "ISP detection failed")
                return profile, isp_details
            detected_isp = result.get("isp")
            normalized_isp = result.get("normalized_isp") or detected_isp
            detected_org = result.get("org")
            detected_asn = result.get("asn")
            isp_details["source"] = result.get("source")

        normalized_key = _normalize_isp_key(normalized_isp)
        raw_key = _normalize_isp_key(detected_isp)
        org_key = _normalize_isp_key(detected_org)
        asn_key = _normalize_isp_key(detected_asn)
        matched_profile = None

        if forced_profile_id:
            matched_profile = {"id": forced_profile_id}
        else:
            for needle, candidate_profile in ISP_PROFILE_RULES:
                if (
                    needle in normalized_key
                    or needle in raw_key
                    or needle in org_key
                    or needle in asn_key
                ):
                    matched_profile = candidate_profile
                    break

        if matched_profile:
            profile.update(matched_profile)

        isp_details["detected_isp"] = detected_isp
        isp_details["normalized_isp"] = normalized_isp
        isp_details["profile_id"] = profile["id"]
        return profile, isp_details
    except Exception as e:
        isp_details["detection_error"] = str(e)
        return profile, isp_details


def handle_status():
    """Mevcut durum bilgisi döndür"""
    is_active = state_manager.is_active()
    state = state_manager.load_state() if is_active else None

    response = {
        "success": True,
        "status": "active" if is_active else "inactive",
        "interface": state.get("active_interface") if state else None,
        "mode": _resolve_mode(state),
        "isp_profile_id": state.get("isp_profile_id") if state else None,
        "timestamp": datetime.now().isoformat()
    }
    print(json.dumps(response))


def _activate_access_mode():
    """Erişim modunu (lokal proxy) aktive et"""
    try:
        primary_service = dns_manager.get_primary_service()
        if not primary_service:
            return False, "No active network service found"

        selected_profile, isp_details = _resolve_access_profile()
        original_proxy_state = proxy_manager.capture_proxy_state(primary_service)

        start_result = access_manager.start_access_process(profile=selected_profile)
        if not start_result["success"]:
            error = start_result.get("error", "Failed to start access process")
            log_tail = start_result.get("log_tail")
            if log_tail:
                last_line = log_tail.strip().splitlines()[-1]
                error = f"{error}. {last_line}"
            return False, error

        proxy_host = start_result["host"]
        proxy_port = start_result["port"]
        proxy_pid = start_result["pid"]
        proxy_log_path = start_result.get("log_path")
        runtime_profile = start_result.get("runtime_profile", {})
        owner_pid = _resolve_owner_pid()
        watchdog_token = str(uuid.uuid4())

        proxy_success = proxy_manager.set_system_proxy(primary_service, proxy_host, proxy_port)
        if not proxy_success:
            access_manager.stop_access_process(proxy_pid)
            return False, "Failed to set system proxy"

        state_data = {
            "active": True,
            "mode": "access",
            "active_interface": primary_service,
            "original_proxy_state": original_proxy_state,
            "isp_profile_id": runtime_profile.get("profile_id", selected_profile["id"]),
            "isp_detected": isp_details.get("detected_isp"),
            "isp_normalized": isp_details.get("normalized_isp"),
            "isp_source": isp_details.get("source"),
            "isp_detection_error": isp_details.get("detection_error"),
            "access_runtime_profile": runtime_profile,
            "proxy_host": proxy_host,
            "proxy_port": proxy_port,
            "access_pid": proxy_pid,
            "access_log_path": proxy_log_path,
            "owner_pid": owner_pid,
            "watchdog_token": watchdog_token,
            "restore_attempts": 0,
            "timestamp": datetime.now().isoformat()
        }
        state_manager.save_state(state_data)

        watchdog_pid = _start_exit_watchdog(owner_pid, watchdog_token)
        if watchdog_pid:
            state_data["watchdog_pid"] = watchdog_pid
            state_manager.save_state(state_data)
        
        response = {
            "success": True,
            "message": "Activated successfully",
            "status": "active",
            "mode": "access",
            "interface": primary_service,
            "isp_profile_id": runtime_profile.get("profile_id", selected_profile["id"]),
            "isp_detected": isp_details.get("detected_isp"),
            "isp_normalized": isp_details.get("normalized_isp"),
            "isp_source": isp_details.get("source"),
            "isp_detection_error": isp_details.get("detection_error"),
            "proxy_host": proxy_host,
            "proxy_port": proxy_port,
            "access_pid": proxy_pid,
            "access_log_path": proxy_log_path,
            "owner_pid": owner_pid,
            "watchdog_pid": watchdog_pid,
            "timestamp": datetime.now().isoformat()
        }
        return True, response

    except Exception as e:
        return False, f"Access activation failed: {str(e)}"


def handle_activate():
    """
    Tek tuş aktivasyon:
    1) Erişim modunu dener
    2) Başarısızsa kullanıcıya net hata döner
    """
    if state_manager.is_active():
        error_response("Already active")
        return

    access_success, access_result = _activate_access_mode()
    if access_success:
        print(json.dumps(access_result))
        return

    error_response(f"Activation failed. {access_result}")


def _deactivate_dns_mode(state):
    interface = state.get("active_interface")
    original_dns = state.get("original_dns", [])
    was_dhcp = state.get("was_dhcp", False)

    if not interface:
        return False, "No interface info in state"

    if was_dhcp or len(original_dns) == 0:
        success = dns_manager.clear_dns_servers(interface)
    else:
        success = dns_manager.set_dns_servers(interface, original_dns)

    if not success:
        return False, f"Failed to restore DNS for {interface}"

    response = {
        "success": True,
        "message": "Deactivated successfully",
        "status": "inactive",
        "mode": "dns",
        "interface": interface,
        "restored_dhcp": was_dhcp,
        "timestamp": datetime.now().isoformat()
    }
    return True, response


def _deactivate_access_mode(state):
    interface = state.get("active_interface")
    access_pid = state.get("access_pid")
    original_proxy_state = state.get("original_proxy_state")
    original_dns = state.get("original_dns", [])
    was_dhcp = state.get("was_dhcp", False)

    if not interface and not access_pid:
        return False, "No access mode state found"

    proxy_cleared = True
    if interface:
        proxy_cleared = proxy_manager.restore_proxy_state(interface, original_proxy_state)

    process_stopped = True
    if access_pid:
        process_stopped = access_manager.stop_access_process(access_pid)

    if not proxy_cleared:
        return False, "Failed to clear system proxy"

    if not process_stopped:
        return False, f"Failed to stop access process pid={access_pid}"

    # Legacy compatibility: older builds could also change DNS.
    dns_restored = True
    if interface and (was_dhcp or len(original_dns) > 0):
        if was_dhcp or len(original_dns) == 0:
            dns_restored = dns_manager.clear_dns_servers(interface)
        else:
            dns_restored = dns_manager.set_dns_servers(interface, original_dns)

    if not dns_restored:
        return False, f"Failed to restore DNS for {interface}"

    response = {
        "success": True,
        "message": "Deactivated successfully",
        "status": "inactive",
        "mode": "access",
        "interface": interface,
        "proxy_cleared": proxy_cleared,
        "dns_restored": dns_restored,
        "process_stopped": process_stopped,
        "timestamp": datetime.now().isoformat()
    }
    return True, response


def handle_deactivate():
    try:
        if not state_manager.is_active():
            error_response("Not active")
            return

        state = state_manager.load_state()
        if not state:
            error_response("No state found")
            return

        mode = _resolve_mode(state) or "access"
        if mode == "access":
            success, result = _deactivate_access_mode(state)
        else:
            success, result = _deactivate_dns_mode(state)

        if not success:
            error_response(result)
            return

        state_manager.clear_state()
        print(json.dumps(result))

    except Exception as e:
        error_response(f"Deactivation failed: {str(e)}")


def handle_detect_isp():
    """ISS algılama - IP-API.com kullanarak"""
    try:
        result = isp_detector.detect_isp(force_refresh=True)
        
        if result["success"]:
            response = {
                "success": True,
                "isp": result["isp"],
                "normalized_isp": result["normalized_isp"],
                "country": result.get("country"),
                "timestamp": datetime.now().isoformat()
            }
        else:
            response = {
                "success": False,
                "error": result.get("error", "Unknown error")
            }
        
        print(json.dumps(response))
        
    except Exception as e:
        error_response(f"ISP detection failed: {str(e)}")


def handle_check_and_restore():
    """Fail-safe: Uygulama başlangıcında state kontrol et, gerekirse ayarları geri yükle"""
    try:
        if not state_manager.is_active():
            response = {
                "success": True,
                "message": "No active state, nothing to restore",
                "action": "none"
            }
            print(json.dumps(response))
            return
        
        state = state_manager.load_state()
        if not state:
            response = {
                "success": True,
                "message": "State file exists but empty, clearing",
                "action": "cleared"
            }
            state_manager.clear_state()
            print(json.dumps(response))
            return
        
        mode = _resolve_mode(state) or "access"
        interface = state.get("active_interface")
        original_dns = state.get("original_dns", [])
        was_dhcp = state.get("was_dhcp", False)
        access_pid = state.get("access_pid")
        attempts = state_manager.get_restore_attempts()
        
        if mode == "dns" and not interface:
            state_manager.clear_state()
            error_response("Invalid state, cleared")
            return

        if mode == "access" and not interface and not access_pid:
            state_manager.clear_state()
            error_response("Invalid access state, cleared")
            return
        
        # Max 3 deneme yap
        if attempts >= 3:
            print(f"Warning: Restore failed after {attempts} attempts, giving up", file=sys.stderr)
            state_manager.clear_state()
            error_response(f"Restore failed after {attempts} attempts")
            return
        
        # Ayarları geri yükle
        success = True
        try:
            if mode == "access":
                if interface:
                    success = proxy_manager.restore_proxy_state(
                        interface,
                        state.get("original_proxy_state")
                    ) and success
                    original_dns = state.get("original_dns", [])
                    was_dhcp = state.get("was_dhcp", False)
                    if was_dhcp or len(original_dns) > 0:
                        if was_dhcp or len(original_dns) == 0:
                            success = dns_manager.clear_dns_servers(interface) and success
                        else:
                            success = dns_manager.set_dns_servers(interface, original_dns) and success
                if access_pid:
                    success = access_manager.stop_access_process(access_pid) and success
            else:
                if was_dhcp or len(original_dns) == 0:
                    success = dns_manager.clear_dns_servers(interface)
                else:
                    success = dns_manager.set_dns_servers(interface, original_dns)
        except Exception as e:
            print(f"Restore error: {e}", file=sys.stderr)
            success = False
        
        if success:
            state_manager.clear_state()
            response = {
                "success": True,
                "message": "Restored system settings from orphaned state",
                "action": "restored",
                "mode": mode,
                "interface": interface,
                "restored_dhcp": was_dhcp,
                "attempts": attempts + 1
            }
            print(json.dumps(response))
        else:
            state_manager.increment_restore_attempts()
            response = {
                "success": False,
                "message": f"Restore failed (attempt {attempts + 1}/3)",
                "action": "retry",
                "attempts": attempts + 1
            }
            print(json.dumps(response))
        
    except Exception as e:
        error_response(f"Check and restore failed: {str(e)}")


def error_response(message):
    response = {
        "success": False,
        "error": message,
        "timestamp": datetime.now().isoformat()
    }
    print(json.dumps(response))


if __name__ == "__main__":
    main()
