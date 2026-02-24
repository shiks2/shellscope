import sqlite3
import os
import sys
import threading
from datetime import datetime, timedelta
from typing import Any, List, Optional

class DatabaseHandler:
    def __init__(self, db_name: str = "shellscope.db") -> None:
        self.db_path = self._get_db_path(db_name)
        self.conn: Optional[sqlite3.Connection] = None
        self.lock = threading.Lock()
        self.setup()

    def _get_db_path(self, db_name: str) -> str:
        if db_name == ":memory:":
            return ":memory:"
        if getattr(sys, "frozen", False):
            base_path = os.path.dirname(sys.executable)
        else:
            base_path = os.path.dirname(os.path.abspath(__file__))
        return os.path.join(base_path, db_name)

    def _get_connection(self) -> sqlite3.Connection:
        """Returns a persistent connection or creates one if closed."""
        if self.conn is None:
            try:
                self.conn = sqlite3.connect(self.db_path, check_same_thread=False)
                # Optimize: WAL mode is crucial for concurrency with the UI reader
                self.conn.execute("PRAGMA journal_mode=WAL;")
                # synchronous=NORMAL is faster and safe enough for WAL
                self.conn.execute("PRAGMA synchronous=NORMAL;")
            except sqlite3.Error as e:
                sys.stderr.write(f"DB CONNECT ERROR: {e}\n")
                raise
        return self.conn

    def setup(self) -> None:
        """Initialize DB with Lifecycle columns."""
        with self.lock:
            try:
                conn = self._get_connection()
                cursor = conn.cursor()

                # Check for migration
                cursor.execute(
                    "SELECT name FROM sqlite_master WHERE type='table' AND name='logs';"
                )
                table_exists = cursor.fetchone()

                needs_migration = False
                if table_exists:
                    cursor.execute("PRAGMA table_info(logs)")
                    columns = [info[1] for info in cursor.fetchall()]
                    if "duration" not in columns:
                        needs_migration = True

                if needs_migration:
                    sys.stderr.write("MIGRATION: Dropping old table to update schema.\n")
                    cursor.execute("DROP TABLE logs")

                cursor.execute(
                    """
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
                """
                )
                conn.commit()
                # Do not close the persistent connection here
            except sqlite3.Error as e:
                sys.stderr.write(f"DB SETUP ERROR: {e}\n")

    def insert_log(self, log_obj: Any) -> None:
        """Inserts a single log entry."""
        try:
            with self.lock:
                conn = self._get_connection()
                with conn:
                    conn.execute(
                        """
                        INSERT INTO logs (pid, date, time, child, parent, args, suspicious, status, start_time_epoch, is_running)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                        log_obj.to_tuple(),
                    )
        except Exception as e:
            sys.stderr.write(f"DB INSERT ERROR: {e}\n")

    def insert_logs_batch(self, log_objs: List[Any]) -> None:
        """Inserts multiple log entries in a single transaction."""
        if not log_objs:
            return
        try:
            data = [log.to_tuple() for log in log_objs]
            with self.lock:
                conn = self._get_connection()
                with conn:
                    conn.executemany(
                        """
                        INSERT INTO logs (pid, date, time, child, parent, args, suspicious, status, start_time_epoch, is_running)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                        data,
                    )
        except Exception as e:
            sys.stderr.write(f"DB BATCH INSERT ERROR: {e}\n")

    def get_process_start_time(self, pid: int) -> float:
        """Retrieves the start time epoch for a running process."""
        try:
            with self.lock:
                conn = self._get_connection()
                # Optimization: Use indexed query (pid, is_running)
                # We assume is_running=1 for active processes.
                cursor = conn.execute(
                    "SELECT start_time_epoch FROM logs WHERE pid = ? AND is_running = 1 ORDER BY id DESC LIMIT 1",
                    (pid,),
                )
                row = cursor.fetchone()
                if row:
                    return float(row[0])
        except Exception as e:
            sys.stderr.write(f"DB GET START TIME ERROR: {e}\n")
        return 0.0

    def update_log_duration(self, pid: int, end_time_str: str, duration: float) -> None:
        """Updates a process entry when it stops."""
        try:
            with self.lock:
                conn = self._get_connection()
                with conn:
                    cursor = conn.execute(
                        """
                        UPDATE logs
                        SET is_running = 0, end_time = ?, duration = ?
                        WHERE pid = ? AND is_running = 1
                    """,
                        (end_time_str, duration, pid),
                    )
                    if cursor.rowcount == 0:
                        pass
        except Exception as e:
            sys.stderr.write(f"DB UPDATE ERROR: {e}\n")

    def prune_old_logs(self, days_to_keep: int = 7) -> None:
        try:
            cutoff_date = (datetime.now() - timedelta(days=days_to_keep)).strftime(
                "%Y-%m-%d"
            )
            with self.lock:
                conn = self._get_connection()
                with conn:
                    cursor = conn.execute("DELETE FROM logs WHERE date < ?", (cutoff_date,))
                    count = cursor.rowcount
            if count > 0:
                sys.stderr.write(f"MAINTENANCE: Pruned {count} old logs.\n")
        except Exception as e:
            sys.stderr.write(f"DB PRUNE ERROR: {e}\n")

    def close(self) -> None:
        """Closes the persistent connection."""
        with self.lock:
            if self.conn:
                try:
                    self.conn.close()
                except Exception:
                    pass
                self.conn = None
