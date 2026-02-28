"""Shared fixtures for engine tests."""
import sys
from pathlib import Path

import pytest

# Add engine directory to sys.path so we can import modules directly
ENGINE_DIR = Path(__file__).resolve().parent.parent
if str(ENGINE_DIR) not in sys.path:
    sys.path.insert(0, str(ENGINE_DIR))


@pytest.fixture
def tmp_state_file(tmp_path):
    """Provide a temporary state file path and patch state_manager to use it."""
    import state_manager

    original_file = state_manager.STATE_FILE
    original_app_support = state_manager._APP_SUPPORT

    state_file = tmp_path / "state.json"
    state_manager.STATE_FILE = str(state_file)
    state_manager._APP_SUPPORT = tmp_path

    yield state_file

    # Restore originals
    state_manager.STATE_FILE = original_file
    state_manager._APP_SUPPORT = original_app_support
