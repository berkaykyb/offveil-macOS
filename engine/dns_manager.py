import subprocess


def get_primary_service():
    """Aktif olarak internet bağlantısı sağlayan servis"""
    service_result = None
    try:
        service_result = subprocess.run(
            ["networksetup", "-listallhardwareports"],
            capture_output=True,
            text=True,
            check=True,
            timeout=10,
        )
    except subprocess.CalledProcessError:
        service_result = None

    try:
        result = subprocess.run(
            ["route", "-n", "get", "default"],
            capture_output=True,
            text=True,
            check=True,
            timeout=10,
        )

        interface_id = None
        for line in result.stdout.split('\n'):
            if 'interface:' in line:
                interface_id = line.split(':', 1)[1].strip()
                break

        if interface_id and service_result:
            lines = service_result.stdout.split('\n')
            for i, line in enumerate(lines):
                if f"Device: {interface_id}" in line:
                    for j in range(i - 1, max(0, i - 5), -1):
                        if "Hardware Port:" in lines[j]:
                            return lines[j].split(':', 1)[1].strip()
    except subprocess.CalledProcessError:
        pass

    # Fallback: route ile tespit başarısızsa ilk aktif servisi kullan.
    active_services = get_active_interfaces()
    if active_services:
        return active_services[0]

    return None


def get_active_interfaces():
    """Aktif network interface'lerini bul"""
    try:
        # networksetup -listallnetworkservices komutu
        result = subprocess.run(
            ["networksetup", "-listallnetworkservices"],
            capture_output=True,
            text=True,
            check=True,
            timeout=10,
        )
        
        # İlk satır "An asterisk (*) denotes..." şeklinde açıklama, onu atla
        lines = result.stdout.strip().split('\n')[1:]
        
        # Sadece aktif olanları al (başında * olmayanlar)
        interfaces = [line for line in lines if not line.startswith('*')]
        
        return interfaces
    
    except subprocess.CalledProcessError:
        return []


def reset_dns_to_default(interface):
    """Reset DNS servers to default (DHCP/automatic) for given interface."""
    try:
        subprocess.run(
            ["networksetup", "-setdnsservers", interface, "Empty"],
            capture_output=True,
            text=True,
            check=True,
            timeout=10,
        )
        return True
    except subprocess.CalledProcessError:
        return False



