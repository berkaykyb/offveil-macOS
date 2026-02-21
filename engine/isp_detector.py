import fcntl
import json
import os
import tempfile
import time
import urllib.request
from pathlib import Path


CACHE_FILE = os.path.expanduser("~/Library/Application Support/OffVeil/isp_cache.json")
CACHE_TTL_SECONDS = 6 * 60 * 60


def _read_cache(max_age_seconds):
    try:
        if not os.path.exists(CACHE_FILE):
            return None
        with open(CACHE_FILE, "r", encoding="utf-8") as f:
            fcntl.flock(f, fcntl.LOCK_SH)
            try:
                payload = json.load(f)
            finally:
                fcntl.flock(f, fcntl.LOCK_UN)
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
        cache_path = Path(CACHE_FILE)
        cache_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)

        payload = {"timestamp": time.time(), "data": data}
        fd, tmp_path = tempfile.mkstemp(
            prefix=".offveil_isp_",
            suffix=".tmp",
            dir=str(cache_path.parent),
        )
        try:
            os.chmod(tmp_path, 0o600)
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                json.dump(payload, f)
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp_path, CACHE_FILE)
        except Exception:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
    except Exception:
        pass


def _fetch_isp():
    # ip-api.com returns clean ISP names directly
    url = "http://ip-api.com/json/?fields=status,isp,org,as,query,country"

    # Bypass the system proxy so that ISP detection is
    # not routed through SpoofDPI (which would return the wrong ISP).
    no_proxy_handler = urllib.request.ProxyHandler({})
    opener = urllib.request.build_opener(no_proxy_handler)

    with opener.open(url, timeout=5) as response:
        return json.loads(response.read().decode())


def detect_isp(force_refresh=False):
    if not force_refresh:
        cached = _read_cache(CACHE_TTL_SECONDS)
        if cached:
            cached["source"] = "cache"
            return cached

    try:
        data = _fetch_isp()

        if data.get("status") == "success":
            isp_raw = data.get("isp", "Unknown")
            result = {
                "success": True,
                "ip": data.get("query", "Unknown"),
                "isp": isp_raw,
                "normalized_isp": normalize_isp_name(isp_raw),
                "org": data.get("org", "Unknown"),
                "asn": data.get("as", "Unknown"),
                "country": data.get("country", "Unknown"),
                "source": "api",
            }
            _write_cache(result)
            return result
        else:
            return {"success": False, "error": "API returned failure status"}

    except urllib.error.URLError as e:
        stale = _read_cache(None)
        if stale:
            stale["source"] = "stale_cache"
            stale["cache_warning"] = f"Network error: {e}"
            return stale
        return {"success": False, "error": f"Network error: {e}"}

    except Exception as e:
        stale = _read_cache(None)
        if stale:
            stale["source"] = "stale_cache"
            stale["cache_warning"] = f"Detection failed: {e}"
            return stale
        return {"success": False, "error": f"Detection failed: {e}"}


def normalize_isp_name(isp_name):
    """Clean ISP name for display. TR ISPs get short names, others get suffix cleanup."""
    isp_lower = isp_name.lower()

    # Turkish ISPs — short display names (API returns ugly corporate names)
    tr_map = {
        "turk telekom": "Türk Telekom",
        "ttnet": "Türk Telekom",
        "turksat": "Türksat",
        "superonline": "Superonline",
        "vodafone": "Vodafone TR",
        "turkcell": "Turkcell",
        "millenicom": "Millenicom",
        "pttcell": "PTTCell",
        "kablonet": "Kablonet",
        "turknet": "TurkNet",
    }
    for keyword, display_name in tr_map.items():
        if keyword in isp_lower:
            return display_name

    # Everyone else — strip corporate suffixes
    cleaned = isp_name.strip()
    for suffix in [
        " Telekomunikasyon Anonim Sirketi",
        " Iletisim Hizmetleri Anonim Sirketi",
        " Anonim Sirketi",
        " Telecommunications",
        " Communications",
        " Corporation",
        " Holdings",
        " A.S.", " Ltd.", " Inc.", " LLC", " GmbH", " S.A.",
    ]:
        if cleaned.endswith(suffix):
            candidate = cleaned[: -len(suffix)].strip()
            if len(candidate) >= 5:
                cleaned = candidate
            break

    return cleaned


