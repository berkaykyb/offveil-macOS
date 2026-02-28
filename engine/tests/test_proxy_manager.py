"""Tests for proxy_manager module — all subprocess calls are mocked."""
from unittest.mock import patch, MagicMock
import subprocess

import pytest
import proxy_manager


# ---------- helpers ----------

def _fake_run(stdout="", returncode=0):
    """Create a mock CompletedProcess."""
    result = MagicMock(spec=subprocess.CompletedProcess)
    result.stdout = stdout
    result.returncode = returncode
    return result


# ---------- parse_proxy_output ----------

class TestParseProxyOutput:
    def test_enabled(self):
        output = "Enabled: Yes\nServer: 127.0.0.1\nPort: 8080\n"
        info = proxy_manager._parse_proxy_output(output)
        assert info["enabled"] is True
        assert info["server"] == "127.0.0.1"
        assert info["port"] == 8080

    def test_disabled(self):
        output = "Enabled: No\nServer: \nPort: 0\n"
        info = proxy_manager._parse_proxy_output(output)
        assert info["enabled"] is False
        assert info["server"] == ""
        assert info["port"] == 0

    def test_bad_port(self):
        output = "Enabled: Yes\nServer: localhost\nPort: abc\n"
        info = proxy_manager._parse_proxy_output(output)
        assert info["port"] == 0

    def test_empty_output(self):
        info = proxy_manager._parse_proxy_output("")
        assert info == {"enabled": False, "server": "", "port": 0}


# ---------- get_system_proxy_state ----------

class TestGetSystemProxyState:
    @patch("proxy_manager._run_networksetup")
    def test_returns_web_and_secure(self, mock_run):
        mock_run.return_value = _fake_run("Enabled: Yes\nServer: 127.0.0.1\nPort: 8080\n")
        state = proxy_manager.get_system_proxy_state("Wi-Fi")
        assert "web" in state
        assert "secure_web" in state
        assert state["web"]["enabled"] is True


# ---------- capture_proxy_state ----------

class TestCaptureProxyState:
    @patch("proxy_manager._run_networksetup")
    def test_captures_with_bypass(self, mock_run):
        mock_run.side_effect = [
            _fake_run("Enabled: Yes\nServer: 127.0.0.1\nPort: 8080"),  # web
            _fake_run("Enabled: No\nServer: \nPort: 0"),                # secure
            _fake_run("*.local\n169.254/16"),                           # bypass
        ]
        state = proxy_manager.capture_proxy_state("Wi-Fi")
        assert state is not None
        assert state["web"]["enabled"] is True
        assert state["secure_web"]["enabled"] is False
        assert "*.local" in state["bypass_domains"]

    @patch("proxy_manager._run_networksetup", side_effect=Exception("error"))
    def test_returns_none_on_failure(self, mock_run):
        assert proxy_manager.capture_proxy_state("Wi-Fi") is None


# ---------- set_system_proxy ----------

class TestSetSystemProxy:
    @patch("proxy_manager._wait_until", return_value=True)
    @patch("proxy_manager._run_networksetup")
    def test_success(self, mock_run, mock_wait):
        result = proxy_manager.set_system_proxy("Wi-Fi", "127.0.0.1", 8080)
        assert result is True
        # 5 networksetup calls: setwebproxy, setwebproxystate on,
        # setsecurewebproxy, setsecurewebproxystate on, setproxybypassdomains
        assert mock_run.call_count == 5

    @patch("proxy_manager._run_networksetup", side_effect=Exception("fail"))
    def test_failure_rolls_back(self, mock_run):
        result = proxy_manager.set_system_proxy("Wi-Fi", "127.0.0.1", 8080)
        assert result is False


# ---------- clear_system_proxy ----------

class TestClearSystemProxy:
    @patch("proxy_manager._wait_until", return_value=True)
    @patch("proxy_manager._run_networksetup")
    def test_success(self, mock_run, mock_wait):
        result = proxy_manager.clear_system_proxy("Wi-Fi")
        assert result is True
        assert mock_run.call_count == 2  # web off + secure off


# ---------- restore_proxy_state ----------

class TestRestoreProxyState:
    @patch("proxy_manager._run_networksetup")
    def test_restore_enabled_proxy(self, mock_run):
        state = {
            "web": {"enabled": True, "server": "10.0.0.1", "port": 3128},
            "secure_web": {"enabled": False, "server": "", "port": 0},
            "bypass_domains": ["*.local"],
        }
        result = proxy_manager.restore_proxy_state("Wi-Fi", state)
        assert result is True

    @patch("proxy_manager.clear_system_proxy", return_value=True)
    def test_restore_none_clears(self, mock_clear):
        result = proxy_manager.restore_proxy_state("Wi-Fi", None)
        assert result is True
        mock_clear.assert_called_once()

    @patch("proxy_manager._run_networksetup", side_effect=Exception("err"))
    def test_restore_failure(self, mock_run):
        state = {"web": {}, "secure_web": {}, "bypass_domains": []}
        result = proxy_manager.restore_proxy_state("Wi-Fi", state)
        assert result is False


# ---------- is_proxy_enabled_with_target ----------

class TestIsProxyEnabledWithTarget:
    @patch("proxy_manager.get_system_proxy_state")
    def test_matching(self, mock_state):
        mock_state.return_value = {
            "web": {"enabled": True, "server": "127.0.0.1", "port": 8080},
            "secure_web": {"enabled": True, "server": "127.0.0.1", "port": 8080},
        }
        assert proxy_manager._is_proxy_enabled_with_target("Wi-Fi", "127.0.0.1", 8080) is True

    @patch("proxy_manager.get_system_proxy_state")
    def test_wrong_port(self, mock_state):
        mock_state.return_value = {
            "web": {"enabled": True, "server": "127.0.0.1", "port": 9999},
            "secure_web": {"enabled": True, "server": "127.0.0.1", "port": 8080},
        }
        assert proxy_manager._is_proxy_enabled_with_target("Wi-Fi", "127.0.0.1", 8080) is False
