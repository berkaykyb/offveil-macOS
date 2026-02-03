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
    except Exception as e:
        print(f"Error setting proxy: {e}")
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
    except Exception as e:
        print(f"Error clearing proxy: {e}")
        return False


def get_proxy_status(interface):
    try:
        result = subprocess.run([
            'networksetup', '-getwebproxy', interface
        ], capture_output=True, text=True)
        
        lines = result.stdout.strip().split('\n')
        status = {}
        for line in lines:
            if ':' in line:
                key, value = line.split(':', 1)
                status[key.strip()] = value.strip()
        
        return status
    except Exception as e:
        print(f"Error getting proxy status: {e}")
        return {}
