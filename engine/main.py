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


def main():
    if len(sys.argv) < 2:
        error_response("No command provided")
        return
    
    command = sys.argv[1]
    
    if command == "status":
        handle_status()
    elif command == "get_dns":
        handle_get_dns()
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


def handle_status():
    """Mevcut durum bilgisi döndür"""
    response = {
        "success": True,
        "status": "inactive",
        "timestamp": datetime.now().isoformat()
    }
    print(json.dumps(response))


def handle_get_dns():
    """Mevcut DNS ayarlarını oku"""
    try:
        dns_config = dns_manager.get_all_dns()
        
        response = {
            "success": True,
            "dns_config": dns_config,
            "timestamp": datetime.now().isoformat()
        }
        print(json.dumps(response))
    except Exception as e:
        error_response(f"Failed to get DNS: {str(e)}")


def handle_activate():
    """DNS'i değiştir ve aktif et"""
    try:
        # Zaten aktifse hata
        if state_manager.is_active():
            error_response("Already active")
            return
        
        # Aktif servisi otomatik tespit et
        primary_service = dns_manager.get_primary_service()
        
        if not primary_service:
            error_response("No active network service found")
            return
        
        # Mevcut DNS'leri kaydet
        current_dns_config = dns_manager.get_all_dns()
        actual_dns = dns_manager.get_current_dns()
        original_dns = dns_manager.get_dns_servers(primary_service)
        
        # DNS'i 1.1.1.1 ve 8.8.8.8 olarak ayarla
        new_dns = ["1.1.1.1", "8.8.8.8"]
        
        # DNS'i değiştir
        success = dns_manager.set_dns_servers(primary_service, new_dns)
        
        if not success:
            error_response("Failed to set DNS")
            return
        
        # Durumu kaydet (birebir geri yükleme için)
        state_data = {
            "active": True,
            "active_interface": primary_service,
            "original_dns": original_dns,
            "original_dns_config": current_dns_config,
            "actual_dns_before": actual_dns,
            "was_dhcp": len(original_dns) == 0,
            "restore_attempts": 0,
            "timestamp": datetime.now().isoformat()
        }
        state_manager.save_state(state_data)
        
        response = {
            "success": True,
            "message": "Activated successfully",
            "status": "active",
            "interface": primary_service,
            "dns": new_dns,
            "timestamp": datetime.now().isoformat()
        }
        print(json.dumps(response))
        
    except Exception as e:
        error_response(f"Activation failed: {str(e)}")


def handle_deactivate():
    try:
        # Aktif değilse hata
        if not state_manager.is_active():
            error_response("Not active")
            return
        
        # State'i oku
        state = state_manager.load_state()
        if not state:
            error_response("No state found")
            return
        
        interface = state.get("active_interface")
        original_dns = state.get("original_dns", [])
        was_dhcp = state.get("was_dhcp", False)
        
        if not interface:
            error_response("No interface info in state")
            return
        
        # DNS'i AYNEN geri yükle
        if was_dhcp or len(original_dns) == 0:
            # DHCP'ye dön
            success = dns_manager.clear_dns_servers(interface)
        else:
            # Manuel DNS'e dön
            success = dns_manager.set_dns_servers(interface, original_dns)
        
        if not success:
            print(f"Warning: Failed to restore DNS for {interface}")
        
        # State'i temizle
        state_manager.clear_state()
        
        response = {
            "success": True,
            "message": "Deactivated successfully",
            "status": "inactive",
            "interface": interface,
            "restored_dhcp": was_dhcp,
            "timestamp": datetime.now().isoformat()
        }
        print(json.dumps(response))
        
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
        
        interface = state.get("active_interface")
        original_dns = state.get("original_dns", [])
        was_dhcp = state.get("was_dhcp", False)
        attempts = state_manager.get_restore_attempts()
        
        if not interface:
            state_manager.clear_state()
            error_response("Invalid state, cleared")
            return
        
        # Max 3 deneme yap
        if attempts >= 3:
            print(f"Warning: Restore failed after {attempts} attempts, giving up")
            state_manager.clear_state()
            error_response(f"Restore failed after {attempts} attempts")
            return
        
        # DNS'i geri yükle
        success = False
        try:
            if was_dhcp or len(original_dns) == 0:
                success = dns_manager.clear_dns_servers(interface)
            else:
                success = dns_manager.set_dns_servers(interface, original_dns)
        except Exception as e:
            print(f"DNS restore error: {e}")
            success = False
        
        if success:
            state_manager.clear_state()
            response = {
                "success": True,
                "message": "Restored DNS from orphaned state",
                "action": "restored",
                "interface": interface,
                "restored_dhcp": was_dhcp,
                "attempts": attempts + 1
            }
            print(json.dumps(response))
        else:
            state_manager.increment_restore_attempts()
            response = {
                "success": False,
                "message": f"DNS restore failed (attempt {attempts + 1}/3)",
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
