import urllib.request
import json


def detect_isp():
    try:
        # IP-API.com kullan (günde 45 istek limiti var ama cache yapacağız)
        url = "http://ip-api.com/json/?fields=status,country,isp,as,org,query"
        
        with urllib.request.urlopen(url, timeout=5) as response:
            data = json.loads(response.read().decode())
            
            if data.get('status') == 'success':
                isp_raw = data.get('isp', 'Unknown')
                return {
                    'success': True,
                    'ip': data.get('query', 'Unknown'),
                    'isp': isp_raw,
                    'normalized_isp': normalize_isp_name(isp_raw),
                    'org': data.get('org', 'Unknown'),
                    'asn': data.get('as', 'Unknown'),
                    'country': data.get('country', 'Unknown')
                }
            else:
                return {
                    'success': False,
                    'error': 'API returned failure status'
                }
    
    except urllib.error.URLError as e:
        return {
            'success': False,
            'error': f'Network error: {str(e)}'
        }
    
    except Exception as e:
        return {
            'success': False,
            'error': f'Detection failed: {str(e)}'
        }


def normalize_isp_name(isp_name):
    isp_lower = isp_name.lower()
    
    # Türk ISS'leri
    if 'turk telekom' in isp_lower or 'ttnet' in isp_lower:
        return 'Türk Telekom'
    elif 'turksat' in isp_lower:
        return 'Türksat'
    elif 'superonline' in isp_lower:
        return 'Superonline'
    elif 'vodafone' in isp_lower:
        return 'Vodafone'
    elif 'turkcell' in isp_lower:
        return 'Turkcell'
    else:
        return isp_name
