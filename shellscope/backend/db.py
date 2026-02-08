import sqlite3
import os
import sys
import time
from datetime import datetime, timedelta

class DatabaseHandler:
    def __init__(self, db_name: str = "shellscope.db"):
        self.db_path = self._get_db_path(db_name)
        self.setup()

    def _get_db_path(self, db_name: str) -> str:
        if getattr(sys, 'frozen', False):
            base_path = os.path.dirname(sys.executable)
        else:
            base_path = os.path.dirname(os.path.abspath(__file__))
            
        return os.path.join(base_path, db_name)

    def setup(self) -> None:
        """Initialize DB with Lifecycle columns"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute("PRAGMA journal_mode=WAL;")
            
            # Check if table exists to see if we need to migrate (drop/recreate for dev)
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='logs';")
            table_exists = cursor.fetchone()

            # For simplicity in this dev phase, if we are changing schema, we might need to recreate.
            # But let's check columns or just try to create with IF NOT EXISTS and hope for best or ALTER.
            # Given the prompt instruction: "drop the table if it exists or create a new one"
            # We will DROP to ensure schema match.
            # WARNING: This wipes history on update. Acceptable for this "dev -> prod" transition step.
            
            # Simple migration flag/check: check for 'duration' column.
            needs_migration = False
            if table_exists:
                cursor.execute("PRAGMA table_info(logs)")
                columns = [info[1] for info in cursor.fetchall()]
                if 'duration' not in columns:
                    needs_migration = True
            
            if needs_migration:
                 sys.stderr.write("MIGRATION: Dropping old table to update schema.\n")
                 cursor.execute("DROP TABLE logs")

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS logs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    pid INTEGER,
                    date TEXT,
                    time TEXT,
                    child TEXT,
                    parent TEXT,
                    args TEXT,
                    suspicious INTEGER,
                    status TEXT,
                    start_time_epoch REAL,
                    end_time TEXT,
                    duration REAL,
                    is_running INTEGER DEFAULT 1
                )
            """)
            conn.commit()
            conn.close()
        except sqlite3.Error as e:
            sys.stderr.write(f"DB SETUP ERROR: {e}\n")

    def insert_log(self, log_obj) -> None:
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO logs (pid, date, time, child, parent, args, suspicious, status, start_time_epoch, is_running)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, log_obj.to_tuple())
            conn.commit()
            conn.close()
        except Exception as e:
            sys.stderr.write(f"DB INSERT ERROR: {e}\n")

    def update_log_duration(self, pid: int, end_time_str: str, duration: float) -> None:
        """Updates a process entry when it stops."""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # Update the most recent running entry for this PID
            # We use is_running=1 to target the active session. 
            # If PID reuse happens very fast, we assume the latest one.
            # We order by id DESC to get the latest.
            
            cursor.execute("""
                UPDATE logs 
                SET is_running = 0, end_time = ?, duration = ?
                WHERE pid = ? AND is_running = 1
            """, (end_time_str, duration, pid))
            
            if cursor.rowcount == 0:
                # This might happen if we missed the start event or it was already closed.
                # Just ignore or log debug.
                pass
                
            conn.commit()
            conn.close()
        except Exception as e:
            sys.stderr.write(f"DB UPDATE ERROR: {e}\n")

    def prune_old_logs(self, days_to_keep: int = 7) -> None:
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            cutoff_date = (datetime.now() - timedelta(days=days_to_keep)).strftime("%Y-%m-%d")
            cursor.execute("DELETE FROM logs WHERE date < ?", (cutoff_date,))
            count = cursor.rowcount
            conn.commit()
            conn.close()
            if count > 0:
                sys.stderr.write(f"MAINTENANCE: Pruned {count} old logs.\n")
        except Exception as e:
            sys.stderr.write(f"DB PRUNE ERROR: {e}\n")