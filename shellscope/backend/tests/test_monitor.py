import pytest
from unittest.mock import MagicMock, patch
import sys
import time
import os

# Ensure backend path is set (conftest handles it, but explicit here doesn't hurt)
# Importing monitor after sys.path fix in conftest
from monitor import get_running_targets, monitor_loop, get_parent_name
from models import ProcessLog
from db import DatabaseHandler

class MockProcess:
    def __init__(self, pid, name, ppid, cmd, date):
        self.ProcessId = pid
        self.Name = name
        self.ParentProcessId = ppid
        self.CommandLine = cmd
        self.CreationDate = date

def test_get_running_targets(mock_wmi):
    """Test parsing of WMI results."""
    # Setup mock WMI query return
    c_wmi = MagicMock()
    mock_wmi.WMI.return_value = c_wmi

    p1 = MockProcess(101, "cmd.exe", 100, "cmd.exe /c echo hi", "20230101000000.000000+000")
    p2 = MockProcess(102, "powershell.exe", 101, "powershell", None) # No creation date

    c_wmi.query.return_value = [p1, p2]

    targets = get_running_targets(c_wmi)

    assert len(targets) == 2
    assert "101:20230101000000.000000+000" in targets
    assert "102:0" in targets
    assert targets["101:20230101000000.000000+000"].Name == "cmd.exe"

def test_get_parent_name():
    c_wmi = MagicMock()
    parent = MockProcess(100, "explorer.exe", 0, "", "")
    c_wmi.Win32_Process.return_value = [parent]

    name = get_parent_name(c_wmi, 100)
    assert name == "explorer.exe"

    # Test None
    assert get_parent_name(c_wmi, None) == "N/A"

    # Test Exception
    c_wmi.Win32_Process.side_effect = Exception("error")
    assert get_parent_name(c_wmi, 100) == "Unknown (Exited)"

@patch('monitor.db')
@patch('monitor.send_json')
@patch('monitor.time')
def test_monitor_loop_logic(mock_time, mock_send_json, mock_db, mock_wmi):
    """Test the monitoring loop logic (detect new/closed)."""

    # Mock time.sleep to raise exception to break the infinite loop
    # We allow a few iterations. Raising KeyboardInterrupt to bypass the
    # 'except Exception' block in monitor_loop
    # Iterations: 1 (NEW pA), 2 (Reuse: CLOSE pA, NEW pA'), 3 (Break)
    mock_time.sleep.side_effect = [None, None, KeyboardInterrupt("Break Loop")]
    mock_time.time.return_value = 1000.0

    c_wmi = MagicMock()
    mock_wmi.WMI.return_value = c_wmi

    pA = MockProcess(101, "cmd.exe", 100, "cmd", "D1")
    pA_new = MockProcess(101, "cmd.exe", 100, "cmd", "D2")

    # Sequence of snapshots:
    # 1. Initial: Empty
    # 2. Loop 1: Process A starts
    # 3. Loop 2: Process A stops AND Process A' starts (PID reuse)

    c_wmi.query.side_effect = [
        [],        # Initial
        [pA],      # Loop 1
        [pA_new]   # Loop 2
    ]

    # Mock parent name query
    c_wmi.Win32_Process.return_value = [MockProcess(100, "explorer.exe", 0, "", "")]

    # Mock DB insert/update
    mock_db.insert_logs_batch = MagicMock()
    mock_db.update_log_duration = MagicMock()
    mock_db.get_process_start_time.return_value = 900.0 # Started at 900

    try:
        monitor_loop()
    except KeyboardInterrupt:
        pass

    # Verification

    # Check calls
    # Expected:
    # Loop 1: NEW pA
    # Loop 2: CLOSED pA, NEW pA_new

    assert mock_send_json.call_count >= 3

    # 1. NEW pA
    args, _ = mock_send_json.call_args_list[0]
    assert args[0]['status'] == "NEW"
    assert args[0]['pid'] == 101

    # 2. CLOSED pA (Must be before NEW pA_new if in same loop iteration)
    # But wait, send_json is called sequentially.
    # In monitor logic:
    #   Detect CLOSED -> send_json(CLOSED)
    #   Detect NEW -> send_json(NEW)
    # So call 2 should be CLOSED.

    args, _ = mock_send_json.call_args_list[1]
    assert args[0]['status'] == "CLOSED"
    assert args[0]['pid'] == 101
    assert args[0]['duration'] == "100.00s"

    # 3. NEW pA_new
    args, _ = mock_send_json.call_args_list[2]
    assert args[0]['status'] == "NEW"
    assert args[0]['pid'] == 101

    # Check DB calls
    # insert_logs_batch called twice (Loop 1, Loop 2)
    assert mock_db.insert_logs_batch.call_count == 2

    # update_log_duration called once (Loop 2 for pA)
    mock_db.update_log_duration.assert_called_once()
    assert mock_db.update_log_duration.call_args[0][0] == 101
