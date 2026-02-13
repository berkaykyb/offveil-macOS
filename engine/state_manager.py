import json
import os

STATE_FILE = os.path.expanduser("~/.offveil_state.json")


def save_state(data):
    with open(STATE_FILE, 'w') as f:
        json.dump(data, f, indent=2)
    os.chmod(STATE_FILE, 0o600)  # Owner read/write only


def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, 'r') as f:
            return json.load(f)
    return None


def clear_state():
    if os.path.exists(STATE_FILE):
        os.remove(STATE_FILE)


def is_active():
    state = load_state()
    return state is not None and state.get('active', False)


def increment_restore_attempts():
    """Restore attempt sayısını artır"""
    state = load_state()
    if state:
        state['restore_attempts'] = state.get('restore_attempts', 0) + 1
        save_state(state)
        return state['restore_attempts']
    return 0


def get_restore_attempts():
    """Kaç kere restore denendiğini döndür"""
    state = load_state()
    if state:
        return state.get('restore_attempts', 0)
    return 0
