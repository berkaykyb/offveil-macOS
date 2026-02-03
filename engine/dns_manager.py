import subprocess
import json
import re


def get_active_interfaces():
    """Aktif network interface'lerini bul"""
    try:
        # networksetup -listallnetworkservices komutu
        result = subprocess.run(
            ["networksetup", "-listallnetworkservices"],
            capture_output=True,
            text=True,
            check=True
        )
        
        # İlk satır "An asterisk (*) denotes..." şeklinde açıklama, onu atla
        lines = result.stdout.strip().split('\n')[1:]
        
        # Sadece aktif olanları al (başında * olmayanlar)
        interfaces = [line for line in lines if not line.startswith('*')]
        
        return interfaces
    
    except subprocess.CalledProcessError as e:
        print(f"Error getting interfaces: {e}")
        return []


def get_dns_servers(interface):
    """Belirtilen interface için DNS sunucularını al"""
    try:
        result = subprocess.run(
            ["networksetup", "-getdnsservers", interface],
            capture_output=True,
            text=True,
            check=True
        )
        
        output = result.stdout.strip()
        
        # Eğer "There aren't any DNS Servers" dönerse boş liste
        if "aren't any" in output.lower():
            return []
        
        # DNS sunucuları satır satır gelir
        dns_servers = [line.strip() for line in output.split('\n') if line.strip()]
        
        return dns_servers
    
    except subprocess.CalledProcessError as e:
        print(f"Error getting DNS for {interface}: {e}")
        return []


def get_all_dns():
    """Tüm aktif interface'lerin DNS ayarlarını al"""
    interfaces = get_active_interfaces()
    
    dns_config = {}
    
    for interface in interfaces:
        dns_servers = get_dns_servers(interface)
        dns_config[interface] = dns_servers
    
    return dns_config


def set_dns_servers(interface, dns_servers):
    """Belirtilen interface için DNS sunucularını ayarla"""
    try:
        # DNS sunucularını boşlukla ayırarak komut oluştur
        cmd = ["networksetup", "-setdnsservers", interface] + dns_servers
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True
        )
        
        return True
    
    except subprocess.CalledProcessError as e:
        print(f"Error setting DNS for {interface}: {e}")
        return False


def clear_dns_servers(interface):
    """Belirtilen interface için DNS sunucularını temizle (DHCP'ye dön)""" 
    try:
        result = subprocess.run(
            ["networksetup", "-setdnsservers", interface, "empty"],
            capture_output=True,
            text=True,
            check=True
        )
        
        return True
    
    except subprocess.CalledProcessError as e:
        print(f"Error clearing DNS for {interface}: {e}")
        return False


def get_current_dns():
    """Gerçekte kullanılan DNS'i al (DHCP dahil)"""
    try:
        result = subprocess.run(
            ["scutil", "--dns"],
            capture_output=True,
            text=True,
            check=True
        )
        
        output = result.stdout
        dns_servers = []
        
        # nameserver[0] : 8.8.8.8 formatını ara
        for line in output.split('\n'):
            if 'nameserver[0]' in line:
                match = re.search(r':\s*([\d\.]+)', line)
                if match:
                    dns = match.group(1)
                    if dns not in dns_servers:
                        dns_servers.append(dns)
        
        return dns_servers
    
    except subprocess.CalledProcessError as e:
        print(f"Error getting current DNS: {e}")
        return []


if __name__ == "__main__":
    # Test
    print("Active Interfaces:")
    interfaces = get_active_interfaces()
    print(json.dumps(interfaces, indent=2))
    
    print("\nAll DNS Configurations:")
    dns_config = get_all_dns()
    print(json.dumps(dns_config, indent=2))
    
    print("\nCurrent DNS (Including DHCP):")
    current_dns = get_current_dns()
    print(json.dumps(current_dns, indent=2))
