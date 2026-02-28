"""Tests for dns_manager module — all subprocess calls are mocked."""
from unittest.mock import patch, MagicMock
import subprocess

import pytest
import dns_manager


def _fake_run(stdout="", returncode=0):
    result = MagicMock(spec=subprocess.CompletedProcess)
    result.stdout = stdout
    result.returncode = returncode
    return result


# ---------- get_primary_service ----------

class TestGetPrimaryService:
    @patch("dns_manager.subprocess.run")
    def test_finds_wifi(self, mock_run):
        hardware_output = (
            "Hardware Port: USB 10/100 LAN\n"
            "Device: en5\n\n"
            "Hardware Port: Wi-Fi\n"
            "Device: en0\n\n"
            "Hardware Port: Thunderbolt Bridge\n"
            "Device: bridge0\n"
        )
        route_output = "   route to: default\n   interface: en0\n"

        mock_run.side_effect = [
            _fake_run(hardware_output),  # listallhardwareports
            _fake_run(route_output),     # route -n get default
        ]
        result = dns_manager.get_primary_service()
        assert result == "Wi-Fi"

    @patch("dns_manager.get_active_interfaces", return_value=["Ethernet"])
    @patch("dns_manager.subprocess.run", side_effect=subprocess.CalledProcessError(1, "route"))
    def test_fallback_to_active_interfaces(self, mock_run, mock_active):
        result = dns_manager.get_primary_service()
        assert result == "Ethernet"

    @patch("dns_manager.get_active_interfaces", return_value=[])
    @patch("dns_manager.subprocess.run", side_effect=subprocess.CalledProcessError(1, "route"))
    def test_returns_none_when_no_interfaces(self, mock_run, mock_active):
        result = dns_manager.get_primary_service()
        assert result is None


# ---------- get_active_interfaces ----------

class TestGetActiveInterfaces:
    @patch("dns_manager.subprocess.run")
    def test_filters_disabled(self, mock_run):
        output = (
            "An asterisk (*) denotes that a network service is disabled.\n"
            "Wi-Fi\n"
            "*Bluetooth PAN\n"
            "Thunderbolt Bridge\n"
        )
        mock_run.return_value = _fake_run(output)
        result = dns_manager.get_active_interfaces()
        assert result == ["Wi-Fi", "Thunderbolt Bridge"]
        assert "*Bluetooth PAN" not in result

    @patch("dns_manager.subprocess.run", side_effect=subprocess.CalledProcessError(1, "cmd"))
    def test_returns_empty_on_error(self, mock_run):
        assert dns_manager.get_active_interfaces() == []


# ---------- reset_dns_to_default ----------

class TestResetDnsToDefault:
    @patch("dns_manager.subprocess.run")
    def test_success(self, mock_run):
        mock_run.return_value = _fake_run()
        assert dns_manager.reset_dns_to_default("Wi-Fi") is True
        args = mock_run.call_args[0][0]
        assert args == ["networksetup", "-setdnsservers", "Wi-Fi", "Empty"]

    @patch("dns_manager.subprocess.run")
    def test_has_timeout(self, mock_run):
        """Verify our BUG-02 fix: timeout must be present."""
        mock_run.return_value = _fake_run()
        dns_manager.reset_dns_to_default("Wi-Fi")
        kwargs = mock_run.call_args[1]
        assert "timeout" in kwargs, "reset_dns_to_default must have a timeout (BUG-02 fix)"
        assert kwargs["timeout"] == 10

    @patch("dns_manager.subprocess.run", side_effect=subprocess.CalledProcessError(1, "cmd"))
    def test_failure(self, mock_run):
        assert dns_manager.reset_dns_to_default("Wi-Fi") is False
