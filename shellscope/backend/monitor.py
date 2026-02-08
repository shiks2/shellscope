import wmi
import pythoncom
import sys
import json
import time
import threading
import sqlite3
from typing import Any
from models import ProcessLog
from db import DatabaseHandler

# --- CONFIGURATION ---
TARGET_APPS = ["cmd.exe", "powershell.exe", "wt.exe", "conhost.exe"]
SUSPICIOUS_KEYWORDS = ['hidden', '-enc', '/c', 'temp', 'downloadstring', 'bypass']
RETENTION_DAYS = 7

# --- SETUP ---
db = DatabaseHandler("shellscope.db")
db.prune_old_logs(RETENTION_DAYS)

print(f"ENGINE_STARTED")
sys.stderr.write(f"DEBUG: Logging to {db.db_path}\n")
sys.stdout.flush()

# --- HELPER FUNCTIONS ---
def get_parent_name(c_instance, ppid):
    try:
        if ppid is None: return "N/A"
        parent_query = c_instance.Win32_Process(ProcessId=ppid)
        if parent_query:
            return parent_query[0].Name
    except:
        pass
    return "Unknown (Exited)"

def send_json(payload):
    try:
        print(f"LOG::{json.dumps(payload)}")
        sys.stdout.flush()
    except Exception as e:
        sys.stderr.write(f"JSON ERROR: {e}\n")

# --- SNAPSHOT MONITOR ---

def get_running_targets(c_wmi) -> dict:
    """Returns a dict of {pid: process_object} for target apps"""
    targets = {}
    try:
        # Querying all processes is cheap enough every 2 seconds
        # Or we can filter in WQL: Select * from Win32_Process Where Name='cmd.exe' OR ...
        # Constructing WQL for specific names is better
        
        # Win32_Process has Name, ProcessId, ParentProcessId, CommandLine, CreationDate
        
        # Build query clause
        # Name = 'cmd.exe' OR Name = 'powershell.exe' ...
        clauses = [f"Name = '{app}'" for app in TARGET_APPS]
        where_clause = " OR ".join(clauses)
        wql = f"SELECT Name, ProcessId, ParentProcessId, CommandLine, CreationDate FROM Win32_Process WHERE {where_clause}"
        
        results = c_wmi.query(wql)
        for proc in results:
            targets[proc.ProcessId] = proc
            
    except Exception as e:
        sys.stderr.write(f"POLLING ERROR: {e}\n")
        
    return targets

def monitor_loop():
    """Main Loop: Polls process list and diffs with previous state"""
    pythoncom.CoInitialize() 
    c = wmi.WMI()
    print("Monitor loop started (Polling Mode)")
    sys.stdout.flush()
    
    # Initial Snapshot
    prev_snapshot = get_running_targets(c)
    
    while True:
        try:
            time.sleep(2)
            
            curr_snapshot = get_running_targets(c)
            
            # 1. Detect NEW processes (in curr but not in prev)
            for pid, proc in curr_snapshot.items():
                if pid not in prev_snapshot:
                    # Found NEW process
                    parent_name = get_parent_name(c, proc.ParentProcessId)
                    
                    log = ProcessLog.from_wmi_process(
                        proc, 
                        parent_name, 
                        status="NEW",
                        suspicious_keywords=SUSPICIOUS_KEYWORDS
                    )
                    
                    db.insert_log(log)
                    
                    payload = {
                        "pid": log.pid,
                        "time": log.timestamp,
                        "child": log.child,
                        "parent": log.parent,
                        "args": log.args,
                        "suspicious": bool(log.suspicious),
                        "status": log.status,
                        "isRunning": True,
                        "duration": "Running"
                    }
                    send_json(payload)
            
            # 2. Detect CLOSED processes (in prev but not in curr)
            for pid in prev_snapshot:
                if pid not in curr_snapshot:
                    # Found CLOSED process
                    
                    conn = sqlite3.connect(db.db_path)
                    cursor = conn.cursor()
                    cursor.execute("SELECT start_time_epoch FROM logs WHERE pid = ? AND is_running = 1", (pid,))
                    row = cursor.fetchone()
                    duration = 0.0
                    
                    if row:
                        start_time = row[0]
                        end_time = time.time()
                        duration = end_time - start_time
                        end_time_str = time.strftime("%H:%M:%S")
                        
                        cursor.close()
                        conn.close()
                        
                        # Update DB
                        db.update_log_duration(pid, end_time_str, duration)
                        
                        # Notify UI
                        payload = {
                            "pid": pid,
                            "status": "CLOSED",
                            "isRunning": False,
                            "duration": f"{duration:.2f}s"
                        }
                        send_json(payload)
                    else:
                        cursor.close()
                        conn.close()
            
            # Update state
            prev_snapshot = curr_snapshot
            
        except Exception as e:
            sys.stderr.write(f"LOOP ERROR: {e}\n")
            time.sleep(1)

# --- MAIN ---
if __name__ == "__main__":
    # No threads needed for sequential polling
    monitor_loop()