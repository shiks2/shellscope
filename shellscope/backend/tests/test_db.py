import pytest
import sqlite3
import os
from unittest.mock import patch
from db import DatabaseHandler
from models import ProcessLog

@pytest.fixture
def memory_db():
    # Use in-memory DB for testing
    handler = DatabaseHandler(":memory:")
    yield handler
    handler.close()

def test_db_setup(memory_db):
    conn = memory_db._get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='logs'")
    assert cursor.fetchone() is not None

    # Check columns
    cursor.execute("PRAGMA table_info(logs)")
    columns = [info[1] for info in cursor.fetchall()]
    assert "duration" in columns
    assert "start_time_epoch" in columns

def test_insert_log(memory_db):
    log = ProcessLog(100, "child", "parent", "args", False)
    memory_db.insert_log(log)

    conn = memory_db._get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT pid, child FROM logs")
    row = cursor.fetchone()
    assert row[0] == 100
    assert row[1] == "child"

def test_insert_logs_batch(memory_db):
    logs = [
        ProcessLog(101, "c1", "p1", "a1", False),
        ProcessLog(102, "c2", "p2", "a2", True)
    ]
    memory_db.insert_logs_batch(logs)

    conn = memory_db._get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT count(*) FROM logs")
    assert cursor.fetchone()[0] == 2

def test_update_log_duration(memory_db):
    log = ProcessLog(100, "child", "parent", "args", False)
    memory_db.insert_log(log)

    # Update
    memory_db.update_log_duration(100, "12:00:00", 5.5)

    conn = memory_db._get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT duration, is_running, end_time FROM logs WHERE pid=100")
    row = cursor.fetchone()
    assert row[0] == 5.5
    assert row[1] == 0
    assert row[2] == "12:00:00"

def test_get_process_start_time(memory_db):
    log = ProcessLog(100, "child", "parent", "args", False)
    memory_db.insert_log(log)

    start = memory_db.get_process_start_time(100)
    assert start == log.start_time_epoch

    # Test non-existent
    assert memory_db.get_process_start_time(999) == 0.0

def test_prune_old_logs(memory_db):
    # Insert old log manually
    conn = memory_db._get_connection()
    conn.execute("INSERT INTO logs (date) VALUES ('2020-01-01')")
    conn.execute("INSERT INTO logs (date) VALUES ('2099-01-01')")
    conn.commit()

    memory_db.prune_old_logs(7)

    cursor = conn.cursor()
    cursor.execute("SELECT count(*) FROM logs")
    # Should only have the future one
    assert cursor.fetchone()[0] == 1

def test_db_exceptions(memory_db):
    # Test insert_log exception
    with patch.object(memory_db, '_get_connection', side_effect=Exception("insert error")):
        # Should catch exception and not crash
        memory_db.insert_log(None)

    # Test update_log_duration exception
    with patch.object(memory_db, '_get_connection', side_effect=Exception("update error")):
        memory_db.update_log_duration(1, "time", 1.0)

    # Test prune_old_logs exception
    with patch.object(memory_db, '_get_connection', side_effect=Exception("prune error")):
        memory_db.prune_old_logs(1)

    # Test get_process_start_time exception
    with patch.object(memory_db, '_get_connection', side_effect=Exception("get error")):
        assert memory_db.get_process_start_time(1) == 0.0
