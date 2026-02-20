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
    url = "https://ipwho.is/"

    # Build a request that bypasses the system proxy so that ISP detection is
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

        if data.get("success", False):
            isp_raw = data.get("connection", {}).get("isp", "Unknown")
            result = {
                "success": True,
                "ip": data.get("ip", "Unknown"),
                "isp": isp_raw,
                "normalized_isp": normalize_isp_name(isp_raw),
                "org": data.get("connection", {}).get("org", "Unknown"),
                "asn": str(data.get("connection", {}).get("asn", "Unknown")),
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
    isp_lower = isp_name.lower()

    if (
        "turk telekom" in isp_lower
        or "ttnet" in isp_lower
        or "avea" in isp_lower
        or "tt mobil" in isp_lower
        or "turk telekom mobil" in isp_lower
    ):
        return "Türk Telekom"
    elif "turksat" in isp_lower:
        return "Türksat"
    elif "superonline" in isp_lower:
        return "Superonline"
    elif "vodafone" in isp_lower:
        return "Vodafone"
    elif "turkcell" in isp_lower:
        return "Turkcell"
    else:
        return isp_name
