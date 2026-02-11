import subprocess


def set_system_proxy(interface, proxy_host, proxy_port):
    try:
        subprocess.run([
            'networksetup', '-setwebproxy', interface, 
            proxy_host, str(proxy_port)
        ], check=True, capture_output=True)
        
        subprocess.run([
            'networksetup', '-setsecurewebproxy', interface, 
            proxy_host, str(proxy_port)
        ], check=True, capture_output=True)
        
        subprocess.run([
            'networksetup', '-setproxybypassdomains', interface,
            '*.local', '169.254/16', '127.0.0.1', 'localhost'
        ], check=True, capture_output=True)
        
        return True
    except Exception:
        return False


def clear_system_proxy(interface):
    try:
        subprocess.run([
            'networksetup', '-setwebproxystate', interface, 'off'
        ], check=True, capture_output=True)
        
        subprocess.run([
            'networksetup', '-setsecurewebproxystate', interface, 'off'
        ], check=True, capture_output=True)
        
        return True
    except Exception:
        return False
