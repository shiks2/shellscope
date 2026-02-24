import sys
import json
import time
from typing import Any, Dict, List, Optional
from models import ProcessLog
from db import DatabaseHandler

# Handle optional dependencies for cross-platform dev/testing
try:
    import wmi  # type: ignore
    import pythoncom  # type: ignore
except ImportError:
    wmi = None
    pythoncom = None

# --- CONFIGURATION ---
TARGET_APPS = ["cmd.exe", "powershell.exe", "wt.exe", "conhost.exe"]
SUSPICIOUS_KEYWORDS = ["hidden", "-enc", "/c", "temp", "downloadstring", "bypass"]
RETENTION_DAYS = 7
MIN_POLL_INTERVAL = 0.5
MAX_POLL_INTERVAL = 2.0

# --- SETUP ---
db = DatabaseHandler("shellscope.db")


def get_parent_name(c_instance: Any, ppid: Optional[int]) -> str:
    """Retrieves the name of the parent process given its PID."""
    if ppid is None:
        return "N/A"
    try:
        # Optimization: Only select Name
        parent_query = c_instance.Win32_Process(ProcessId=ppid)
        if parent_query:
            return str(parent_query[0].Name)
    except Exception:
        pass
    return "Unknown (Exited)"


def send_json(payload: Dict[str, Any]) -> None:
    """Sends a JSON payload to stdout for the UI."""
    try:
        print(f"LOG::{json.dumps(payload)}")
        sys.stdout.flush()
    except Exception as e:
        sys.stderr.write(f"JSON ERROR: {e}\n")


# --- SNAPSHOT MONITOR ---


def get_running_targets(c_wmi: Any) -> Dict[str, Any]:
    """Returns a dict of {unique_key: process_object} for target apps.
    unique_key is 'pid:creation_date' to handle PID reuse.
    """
    targets = {}
    try:
        # Win32_Process has Name, ProcessId, ParentProcessId, CommandLine, CreationDate
        clauses = [f"Name = '{app}'" for app in TARGET_APPS]
        where_clause = " OR ".join(clauses)

        # Optimization: Select specific columns
        wql = f"SELECT Name, ProcessId, ParentProcessId, CommandLine, CreationDate FROM Win32_Process WHERE {where_clause}"

        results = c_wmi.query(wql)
        for proc in results:
            # Use PID + CreationDate as unique key
            # CreationDate might be None for some system processes.
            creation_date = proc.CreationDate or "0"
            unique_key = f"{proc.ProcessId}:{creation_date}"
            targets[unique_key] = proc

    except Exception as e:
        sys.stderr.write(f"POLLING ERROR: {e}\n")

    return targets


def monitor_loop() -> None:
    """Main Loop: Polls process list and diffs with previous state."""
    if wmi is None:
        sys.stderr.write("ERROR: WMI module not found. Is this Windows?\n")
        return

    pythoncom.CoInitialize()
    c = wmi.WMI()

    # Prune old logs at startup
    db.prune_old_logs(RETENTION_DAYS)

    print(f"ENGINE_STARTED")
    sys.stderr.write(f"DEBUG: Logging to {db.db_path}\n")
    sys.stdout.flush()

    print("Monitor loop started (Polling Mode)")
    sys.stdout.flush()

    # Initial Snapshot
    prev_snapshot = get_running_targets(c)

    poll_interval = MAX_POLL_INTERVAL

    while True:
        try:
            start_time = time.time()
            time.sleep(poll_interval)

            curr_snapshot = get_running_targets(c)

            new_logs = []
            activity_detected = False

            # 1. Detect CLOSED processes (in prev but not in curr)
            for key in prev_snapshot:
                if key not in curr_snapshot:
                    activity_detected = True
                    # Found CLOSED process
                    # Extract PID from key "pid:creation_date"
                    pid_str = key.split(":")[0]
                    pid = int(pid_str)

                    end_time_epoch = time.time()

                    start_time_proc = db.get_process_start_time(pid)
                    duration = 0.0
                    if start_time_proc > 0:
                        duration = end_time_epoch - start_time_proc

                    # If duration is negative (clock skew?), clamp to 0
                    duration = max(0.0, duration)

                    end_time_str = time.strftime("%H:%M:%S")
                    db.update_log_duration(pid, end_time_str, duration)

                    # Notify UI
                    payload = {
                        "pid": pid,
                        "status": "CLOSED",
                        "isRunning": False,
                        "duration": f"{duration:.2f}s",
                    }
                    send_json(payload)

            # 2. Detect NEW processes (in curr but not in prev)
            for key, proc in curr_snapshot.items():
                if key not in prev_snapshot:
                    activity_detected = True
                    # Found NEW process
                    parent_name = get_parent_name(c, proc.ParentProcessId)

                    log = ProcessLog.from_wmi_process(
                        proc,
                        parent_name,
                        status="NEW",
                        suspicious_keywords=SUSPICIOUS_KEYWORDS,
                    )

                    new_logs.append(log)

                    payload = {
                        "pid": log.pid,
                        "time": log.timestamp,
                        "child": log.child,
                        "parent": log.parent,
                        "args": log.args,
                        "suspicious": bool(log.suspicious),
                        "status": log.status,
                        "isRunning": True,
                        "duration": "Running",
                    }
                    send_json(payload)

            # Batch insert new logs
            if new_logs:
                db.insert_logs_batch(new_logs)

            # Update state
            prev_snapshot = curr_snapshot

            # Adaptive Polling
            if activity_detected:
                poll_interval = max(MIN_POLL_INTERVAL, poll_interval / 2)
            else:
                poll_interval = min(MAX_POLL_INTERVAL, poll_interval + 0.1)

        except Exception as e:
            sys.stderr.write(f"LOOP ERROR: {e}\n")
            # Fallback sleep
            time.sleep(1)


# --- MAIN ---
if __name__ == "__main__":
    monitor_loop()
