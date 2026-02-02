"""
OffVeil Engine - Main Command Interface
Komut alan ve JSON döndüren basit motor
"""

import sys
import json
from datetime import datetime


def main():
    # Eğer argüman yoksa hata
    if len(sys.argv) < 2:
        error_response("No command provided")
        return
    
    command = sys.argv[1]
    
    # Komut işleme
    if command == "status":
        handle_status()
    elif command == "get_dns":
        handle_get_dns()
    elif command == "activate":
        handle_activate()
    elif command == "deactivate":
        handle_deactivate()
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
    response = {
        "success": True,
        "dns_servers": ["8.8.8.8", "8.8.4.4"],  # Placeholder
        "interface": "Wi-Fi",
        "timestamp": datetime.now().isoformat()
    }
    print(json.dumps(response))


def handle_activate():
    """DNS'i değiştir ve aktif et"""
    response = {
        "success": True,
        "message": "Activation started",
        "status": "active",
        "timestamp": datetime.now().isoformat()
    }
    print(json.dumps(response))


def handle_deactivate():
    """DNS'i geri yükle"""
    response = {
        "success": True,
        "message": "Deactivation started",
        "status": "inactive",
        "timestamp": datetime.now().isoformat()
    }
    print(json.dumps(response))


def error_response(message):
    """Hata mesajı döndür"""
    response = {
        "success": False,
        "error": message,
        "timestamp": datetime.now().isoformat()
    }
    print(json.dumps(response))


if __name__ == "__main__":
    main()
