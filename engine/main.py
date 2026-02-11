"""
OffVeil Engine - Main Command Interface
Komut alan ve JSON döndüren basit motor
"""

import sys
import json
from datetime import datetime
import dns_manager
import state_manager
import isp_detector
import proxy_manager
import access_manager


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


def handle_status():
    """Mevcut durum bilgisi döndür"""
    is_active = state_manager.is_active()
    state = state_manager.load_state() if is_active else None

    response = {
        "success": True,
        "status": "active" if is_active else "inactive",
        "interface": state.get("active_interface") if state else None,
        "mode": _resolve_mode(state),
        "timestamp": datetime.now().isoformat()
    }
    print(json.dumps(response))


def _activate_access_mode():
    """Erişim modunu (lokal proxy) aktive et"""
    try:
        primary_service = dns_manager.get_primary_service()
        if not primary_service:
            return False, "No active network service found"

        start_result = access_manager.start_access_process()
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

        proxy_success = proxy_manager.set_system_proxy(primary_service, proxy_host, proxy_port)
        if not proxy_success:
            access_manager.stop_access_process(proxy_pid)
            return False, "Failed to set system proxy"

        state_data = {
            "active": True,
            "mode": "access",
            "active_interface": primary_service,
            "proxy_host": proxy_host,
            "proxy_port": proxy_port,
            "access_pid": proxy_pid,
            "access_log_path": proxy_log_path,
            "restore_attempts": 0,
            "timestamp": datetime.now().isoformat()
        }
        state_manager.save_state(state_data)
        
        response = {
            "success": True,
            "message": "Activated successfully",
            "status": "active",
            "mode": "access",
            "interface": primary_service,
            "proxy_host": proxy_host,
            "proxy_port": proxy_port,
            "access_pid": proxy_pid,
            "access_log_path": proxy_log_path,
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

    if not interface and not access_pid:
        return False, "No access mode state found"

    proxy_cleared = True
    if interface:
        proxy_cleared = proxy_manager.clear_system_proxy(interface)

    process_stopped = True
    if access_pid:
        process_stopped = access_manager.stop_access_process(access_pid)

    if not proxy_cleared:
        return False, "Failed to clear system proxy"

    if not process_stopped:
        return False, f"Failed to stop access process pid={access_pid}"

    response = {
        "success": True,
        "message": "Deactivated successfully",
        "status": "inactive",
        "mode": "access",
        "interface": interface,
        "proxy_cleared": proxy_cleared,
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
        result = isp_detector.detect_isp()
        
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
    """Fail-safe: Uygulama başlangıcında state kontrol et, gerekirse DNS'i geri yükle"""
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
        
        # DNS'i geri yükle
        success = True
        try:
            if mode == "access":
                if interface:
                    success = proxy_manager.clear_system_proxy(interface) and success
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
