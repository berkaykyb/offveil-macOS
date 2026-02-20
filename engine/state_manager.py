import fcntl
import json
import os
import tempfile
from pathlib import Path
from typing import Optional

_APP_SUPPORT = Path.home() / "Library" / "Application Support" / "OffVeil"
STATE_FILE = str(_APP_SUPPORT / "state.json")


def _ensure_dir():
    _APP_SUPPORT.mkdir(mode=0o700, parents=True, exist_ok=True)


def save_state(data: dict) -> None:
    _ensure_dir()

    target = Path(STATE_FILE)
    fd, tmp_path = tempfile.mkstemp(
        prefix=".offveil_state_",
        suffix=".tmp",
        dir=str(target.parent),
    )
    try:
        os.chmod(tmp_path, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp_path, STATE_FILE)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def _locked_load() -> Optional[dict]:
    if not os.path.exists(STATE_FILE):
        return None
    try:
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            fcntl.flock(f, fcntl.LOCK_SH)
            try:
                return json.load(f)
            finally:
                fcntl.flock(f, fcntl.LOCK_UN)
    except (json.JSONDecodeError, OSError):
        return None


def load_state() -> Optional[dict]:
    return _locked_load()


def clear_state() -> None:
    if not os.path.exists(STATE_FILE):
        return
    try:
        with open(STATE_FILE, "r+", encoding="utf-8") as f:
            fcntl.flock(f, fcntl.LOCK_EX)
            fcntl.flock(f, fcntl.LOCK_UN)
        os.remove(STATE_FILE)
    except OSError:
        pass


def is_active() -> bool:
    state = load_state()
    return state is not None and state.get("active", False)


def increment_restore_attempts() -> int:
    state = load_state()
    if state:
        state["restore_attempts"] = state.get("restore_attempts", 0) + 1
        save_state(state)
        return state["restore_attempts"]
    return 0


def get_restore_attempts() -> int:
    state = load_state()
    if state:
        return state.get("restore_attempts", 0)
    return 0
