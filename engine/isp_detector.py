import urllib.request
import json
import os
import time


CACHE_FILE = os.path.expanduser("~/.offveil_isp_cache.json")
CACHE_TTL_SECONDS = 6 * 60 * 60


def _read_cache(max_age_seconds):
    try:
        if not os.path.exists(CACHE_FILE):
            return None
        with open(CACHE_FILE, "r") as f:
            payload = json.load(f)
        timestamp = payload.get("timestamp")
        data = payload.get("data")
        if not isinstance(timestamp, (int, float)) or not isinstance(data, dict):
            return None
        if max_age_seconds is not None and (time.time() - timestamp) > max_age_seconds:
            return None
        return data
    except Exception:
        return None


def _write_cache(data):
    try:
        payload = {
            "timestamp": time.time(),
            "data": data,
        }
        with open(CACHE_FILE, "w") as f:
            json.dump(payload, f)
        os.chmod(CACHE_FILE, 0o600)  # Owner read/write only
    except Exception:
        pass


def detect_isp(force_refresh=False):
    if not force_refresh:
        cached = _read_cache(CACHE_TTL_SECONDS)
        if cached:
            cached["source"] = "cache"
            return cached

    try:
        # Use HTTPS API for privacy
        url = "https://ipwho.is/"
        
        with urllib.request.urlopen(url, timeout=5) as response:
            data = json.loads(response.read().decode())
            
            if data.get('success', False):
                isp_raw = data.get('connection', {}).get('isp', 'Unknown')
                result = {
                    'success': True,
                    'ip': data.get('ip', 'Unknown'),
                    'isp': isp_raw,
                    'normalized_isp': normalize_isp_name(isp_raw),
                    'org': data.get('connection', {}).get('org', 'Unknown'),
                    'asn': str(data.get('connection', {}).get('asn', 'Unknown')),
                    'country': data.get('country', 'Unknown'),
                    'source': 'api',
                }
                _write_cache(result)
                return result
            else:
                return {
                    'success': False,
                    'error': 'API returned failure status'
                }
    
    except urllib.error.URLError as e:
        stale_cache = _read_cache(None)
        if stale_cache:
            stale_cache["source"] = "stale_cache"
            stale_cache["cache_warning"] = f'Network error: {str(e)}'
            return stale_cache
        return {
            'success': False,
            'error': f'Network error: {str(e)}'
        }
    
    except Exception as e:
        stale_cache = _read_cache(None)
        if stale_cache:
            stale_cache["source"] = "stale_cache"
            stale_cache["cache_warning"] = f'Detection failed: {str(e)}'
            return stale_cache
        return {
            'success': False,
            'error': f'Detection failed: {str(e)}'
        }


def normalize_isp_name(isp_name):
    isp_lower = isp_name.lower()
    
    # Türk ISS'leri
    if (
        'turk telekom' in isp_lower
        or 'ttnet' in isp_lower
        or 'avea' in isp_lower
        or 'tt mobil' in isp_lower
        or 'turk telekom mobil' in isp_lower
    ):
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
