import json
import os
import subprocess
import sys
import time
from pathlib import Path


POLL_INTERVAL_SECONDS = 1.0
STATE_FILE = os.path.expanduser("~/Library/Application Support/OffVeil/state.json")


def _load_state():
    try:
        with open(STATE_FILE, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except Exception:
        return None


def _is_pid_alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    except Exception:
        return False


def main():
    if len(sys.argv) < 3:
        return 1

    try:
        owner_pid = int(sys.argv[1])
    except ValueError:
        return 1

    watchdog_token = sys.argv[2].strip()
    if owner_pid <= 1 or not watchdog_token:
        return 1

    engine_main = Path(__file__).resolve().parent / "main.py"

    while True:
        state = _load_state()
        if not state or not state.get("active"):
            return 0

        if state.get("watchdog_token") != watchdog_token:
            return 0

        if _is_pid_alive(owner_pid):
            time.sleep(POLL_INTERVAL_SECONDS)
            continue

        try:
            subprocess.run(
                ["/usr/bin/python3", str(engine_main), "check_and_restore"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=30,
            )
        except Exception:
            pass
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
