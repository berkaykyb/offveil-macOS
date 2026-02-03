"""
OffVeil Engine - Main Command Interface
Komut alan ve JSON döndüren basit motor
"""

import sys
import json
from datetime import datetime
import dns_manager
import state_manager
import proxy_manager
import threading
from dpi_bypass import DPIBypass

proxy_server = None


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
    elif command == "start_proxy":
        handle_start_proxy()
    elif command == "stop_proxy":
        handle_stop_proxy()
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
        
        # Mevcut DNS'leri kaydet
        interfaces = dns_manager.get_active_interfaces()
        current_dns_config = dns_manager.get_all_dns()
        actual_dns = dns_manager.get_current_dns()
        
        # Cloudflare DNS
        cloudflare_dns = ["1.1.1.1", "1.0.0.1"]
        
        # Wi-Fi'yi bul ve DNS değiştir
        wifi_interface = None
        for interface in interfaces:
            if "Wi-Fi" in interface:
                wifi_interface = interface
                break
        
        if not wifi_interface:
            error_response("Wi-Fi interface not found")
            return
        
        # DNS'i değiştir
        success = dns_manager.set_dns_servers(wifi_interface, cloudflare_dns)
        
        if not success:
            error_response("Failed to set DNS")
            return
        
        # Durumu kaydet
        state_data = {
            "active": True,
            "original_dns_config": current_dns_config,
            "actual_dns": actual_dns,
            "active_interface": wifi_interface,
            "timestamp": datetime.now().isoformat()
        }
        state_manager.save_state(state_data)
        
        response = {
            "success": True,
            "message": "Activated successfully",
            "status": "active",
            "interface": wifi_interface,
            "dns": cloudflare_dns,
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
        original_dns = state.get("original_dns_config", {}).get(interface, [])
        
        if not interface:
            error_response("No interface info in state")
            return
        
        # DNS'i geri yükle (boşa çevir = DHCP'ye dön)
        if len(original_dns) == 0:
            # DHCP'ye dön
            success = dns_manager.clear_dns_servers(interface)
        else:
            # Manuel DNS'e dön
            success = dns_manager.set_dns_servers(interface, original_dns)
        
        if not success:
            error_response("Failed to restore DNS")
            return
        
        # State'i temizle
        state_manager.clear_state()
        
        response = {
            "success": True,
            "message": "Deactivated successfully",
            "status": "inactive",
            "interface": interface,
            "timestamp": datetime.now().isoformat()
        }
        print(json.dumps(response))
        
    except Exception as e:
        error_response(f"Deactivation failed: {str(e)}")


def handle_start_proxy():
    global proxy_server
    try:
        if proxy_server and proxy_server.running:
            error_response("Proxy already running")
            return
        
        wifi_interface = None
        for interface in dns_manager.get_active_interfaces():
            if "Wi-Fi" in interface:
                wifi_interface = interface
                break
        
        if not wifi_interface:
            error_response("Wi-Fi interface not found")
            return
        
        proxy_server = DPIBypass()
        proxy_thread = threading.Thread(target=proxy_server.start, daemon=True)
        proxy_thread.start()
        
        import time
        time.sleep(0.5)
        
        proxy_manager.set_system_proxy(wifi_interface, '127.0.0.1', 8080)
        
        response = {
            "success": True,
            "message": "DPI Bypass proxy started",
            "proxy": "127.0.0.1:8080",
            "interface": wifi_interface,
            "timestamp": datetime.now().isoformat()
        }
        print(json.dumps(response))
        
    except Exception as e:
        error_response(f"Failed to start proxy: {str(e)}")


def handle_stop_proxy():
    global proxy_server
    try:
        wifi_interface = None
        for interface in dns_manager.get_active_interfaces():
            if "Wi-Fi" in interface:
                wifi_interface = interface
                break
        
        if wifi_interface:
            proxy_manager.clear_system_proxy(wifi_interface)
        
        if proxy_server:
            proxy_server.stop()
            proxy_server = None
        
        response = {
            "success": True,
            "message": "DPI Bypass proxy stopped",
            "interface": wifi_interface,
            "timestamp": datetime.now().isoformat()
        }
        print(json.dumps(response))
        
    except Exception as e:
        error_response(f"Failed to stop proxy: {str(e)}")


def error_response(message):
    response = {
        "success": False,
        "error": message,
        "timestamp": datetime.now().isoformat()
    }
    print(json.dumps(response))


if __name__ == "__main__":
    main()
