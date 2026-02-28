"""Tests for state_manager module."""
import json
import os

import pytest

# Import after conftest adds engine to path
import state_manager


class TestSaveAndLoad:
    """save_state / load_state round-trip."""

    def test_save_and_load(self, tmp_state_file):
        data = {"active": True, "interface": "Wi-Fi", "access_pid": 1234}
        state_manager.save_state(data)

        loaded = state_manager.load_state()
        assert loaded is not None
        assert loaded["active"] is True
        assert loaded["interface"] == "Wi-Fi"
        assert loaded["access_pid"] == 1234

    def test_load_nonexistent(self, tmp_state_file):
        assert state_manager.load_state() is None

    def test_save_overwrites(self, tmp_state_file):
        state_manager.save_state({"version": 1})
        state_manager.save_state({"version": 2})

        loaded = state_manager.load_state()
        assert loaded["version"] == 2

    def test_save_creates_directory(self, tmp_path):
        nested = tmp_path / "deep" / "nested"
        state_manager._APP_SUPPORT = nested
        state_manager.STATE_FILE = str(nested / "state.json")

        state_manager.save_state({"test": True})
        assert nested.exists()
        assert (nested / "state.json").exists()

    def test_save_file_permissions(self, tmp_state_file):
        state_manager.save_state({"secret": "data"})
        mode = os.stat(str(tmp_state_file)).st_mode & 0o777
        assert mode == 0o600, f"State file should be 0600, got {oct(mode)}"


class TestClearState:
    def test_clear_existing(self, tmp_state_file):
        state_manager.save_state({"active": True})
        state_manager.clear_state()
        assert state_manager.load_state() is None

    def test_clear_nonexistent(self, tmp_state_file):
        # Should not raise
        state_manager.clear_state()


class TestIsActive:
    def test_active_true(self, tmp_state_file):
        state_manager.save_state({"active": True})
        assert state_manager.is_active() is True

    def test_active_false(self, tmp_state_file):
        state_manager.save_state({"active": False})
        assert state_manager.is_active() is False

    def test_no_state_file(self, tmp_state_file):
        assert state_manager.is_active() is False

    def test_missing_active_key(self, tmp_state_file):
        state_manager.save_state({"interface": "Wi-Fi"})
        assert state_manager.is_active() is False


class TestRestoreAttempts:
    def test_increment(self, tmp_state_file):
        state_manager.save_state({"active": True, "restore_attempts": 0})
        result = state_manager.increment_restore_attempts()
        assert result == 1

        result = state_manager.increment_restore_attempts()
        assert result == 2

    def test_get_attempts_default(self, tmp_state_file):
        state_manager.save_state({"active": True})
        assert state_manager.get_restore_attempts() == 0

    def test_increment_no_state(self, tmp_state_file):
        assert state_manager.increment_restore_attempts() == 0


class TestCorruptState:
    def test_invalid_json(self, tmp_state_file):
        tmp_state_file.write_text("NOT JSON {{{")
        assert state_manager.load_state() is None

    def test_empty_file(self, tmp_state_file):
        tmp_state_file.write_text("")
        assert state_manager.load_state() is None
