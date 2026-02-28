"""Tests for main.py engine commands — all side effects are mocked."""
import json
from unittest.mock import patch, MagicMock
from io import StringIO

import pytest

import main


def _capture_stdout(func, *args, **kwargs):
    """Run a function and capture its stdout JSON output."""
    import io
    import sys
    buf = io.StringIO()
    old_stdout = sys.stdout
    sys.stdout = buf
    try:
        func(*args, **kwargs)
    finally:
        sys.stdout = old_stdout
    raw = buf.getvalue().strip()
    if not raw:
        return None
    return json.loads(raw)


# ---------- error_response ----------

class TestErrorResponse:
    def test_format(self):
        result = _capture_stdout(main.error_response, "Something broke")
        assert result["success"] is False
        assert result["error"] == "Something broke"
        assert "timestamp" in result


# ---------- handle_status ----------

class TestHandleStatus:
    @patch("main.state_manager")
    def test_status_active(self, mock_sm):
        mock_sm.is_active.return_value = True
        mock_sm.load_state.return_value = {
            "active": True,
            "active_interface": "Wi-Fi",
            "access_pid": 9999,
        }
        result = _capture_stdout(main.handle_status)
        assert result["success"] is True
        assert result["status"] == "active"

    @patch("main.state_manager")
    def test_status_inactive(self, mock_sm):
        mock_sm.is_active.return_value = False
        mock_sm.load_state.return_value = None
        result = _capture_stdout(main.handle_status)
        assert result["success"] is True
        assert result["status"] == "inactive"


# ---------- handle_activate ----------

class TestHandleActivate:
    @patch("main._flush_dns_cache")
    @patch("main._start_exit_watchdog")
    @patch("main.state_manager")
    @patch("main.proxy_manager")
    @patch("main.access_manager")
    @patch("main.dns_manager")
    def test_already_active(self, mock_dns, mock_access, mock_proxy, mock_sm, mock_wd, mock_flush):
        mock_sm.is_active.return_value = True
        result = _capture_stdout(main.handle_activate)
        assert result["success"] is False
        assert "Already active" in result["error"]

    @patch("main._flush_dns_cache")
    @patch("main._start_exit_watchdog")
    @patch("main.state_manager")
    @patch("main.proxy_manager")
    @patch("main.access_manager")
    @patch("main.dns_manager")
    def test_no_network_service(self, mock_dns, mock_access, mock_proxy, mock_sm, mock_wd, mock_flush):
        mock_sm.is_active.return_value = False
        mock_dns.get_primary_service.return_value = None
        result = _capture_stdout(main.handle_activate)
        assert result["success"] is False
        assert "No active network service" in result["error"]

    @patch("main._flush_dns_cache")
    @patch("main._start_exit_watchdog", return_value=None)
    @patch("main._resolve_owner_pid", return_value=12345)
    @patch("main.state_manager")
    @patch("main.proxy_manager")
    @patch("main.access_manager")
    @patch("main.dns_manager")
    def test_successful_activation(self, mock_dns, mock_access, mock_proxy, mock_sm, mock_owner, mock_wd, mock_flush):
        mock_sm.is_active.return_value = False
        mock_dns.get_primary_service.return_value = "Wi-Fi"
        mock_proxy.capture_proxy_state.return_value = {"web": {}, "secure_web": {}}
        mock_access.start_access_process.return_value = {
            "success": True, "pid": 5555, "port": 8080,
            "host": "127.0.0.1", "log_path": "/tmp/test.log",
        }
        mock_proxy.set_system_proxy.return_value = True

        result = _capture_stdout(main.handle_activate)
        assert result["success"] is True
        assert result["status"] == "active"
        mock_sm.save_state.assert_called()


# ---------- handle_deactivate ----------

class TestHandleDeactivate:
    @patch("main.state_manager")
    def test_not_active(self, mock_sm):
        mock_sm.is_active.return_value = False
        result = _capture_stdout(main.handle_deactivate)
        assert result["success"] is False
        assert "Not active" in result["error"]

    @patch("main.state_manager")
    @patch("main.proxy_manager")
    @patch("main.access_manager")
    def test_successful_deactivation(self, mock_access, mock_proxy, mock_sm):
        mock_sm.is_active.return_value = True
        mock_sm.load_state.return_value = {
            "active_interface": "Wi-Fi",
            "access_pid": 5555,
            "original_proxy_state": {"web": {}, "secure_web": {}},
        }
        mock_proxy.restore_proxy_state.return_value = True
        mock_access.stop_access_process.return_value = True

        result = _capture_stdout(main.handle_deactivate)
        assert result["success"] is True
        assert result["status"] == "inactive"
        mock_sm.clear_state.assert_called_once()

    @patch("main.state_manager")
    @patch("main.proxy_manager")
    @patch("main.access_manager")
    def test_partial_failure_keeps_state(self, mock_access, mock_proxy, mock_sm):
        """BUG-03 regression: state must NOT be cleared on partial failure."""
        mock_sm.is_active.return_value = True
        mock_sm.load_state.return_value = {
            "active_interface": "Wi-Fi",
            "access_pid": 5555,
            "original_proxy_state": None,
        }
        mock_proxy.restore_proxy_state.return_value = False  # ← partial failure
        mock_access.stop_access_process.return_value = True

        result = _capture_stdout(main.handle_deactivate)
        assert result["success"] is False
        mock_sm.clear_state.assert_not_called()  # State must be preserved!


# ---------- handle_reset ----------

class TestHandleReset:
    @patch("main._flush_dns_cache")
    @patch("main._kill_all_dpi_processes", return_value=0)
    @patch("main.dns_manager")
    @patch("main.proxy_manager")
    @patch("main.access_manager")
    @patch("main.state_manager")
    def test_reset_clears_state(self, mock_sm, mock_access, mock_proxy, mock_dns, mock_kill, mock_flush):
        mock_sm.load_state.return_value = {
            "active_interface": "Wi-Fi",
            "access_pid": 1234,
        }
        mock_access.stop_access_process.return_value = True
        mock_dns.get_active_interfaces.return_value = ["Wi-Fi"]
        mock_proxy.clear_system_proxy.return_value = True
        mock_dns.reset_dns_to_default.return_value = True

        result = _capture_stdout(main.handle_reset)
        assert result["success"] is True
        mock_sm.clear_state.assert_called_once()
