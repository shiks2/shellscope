import time
from typing import Tuple, Any

class ProcessLog:
    def __init__(self, pid: int, child: str, parent: str, args: str, suspicious: bool, status: str = "NEW", is_running: bool = True):
        self.pid = pid
        self.child = child
        self.parent = parent
        self.args = args
        self.suspicious = 1 if suspicious else 0
        self.status = status
        self.timestamp = time.strftime("%H:%M:%S")
        self.date = time.strftime("%Y-%m-%d")
        self.start_time_epoch = time.time()
        self.is_running = 1 if is_running else 0

    def to_tuple(self) -> Tuple[int, str, str, str, str, str, int, str, float, int]:
        return (self.pid, self.date, self.timestamp, self.child, self.parent, self.args, self.suspicious, self.status, self.start_time_epoch, self.is_running)

    def __str__(self) -> str:
        return f"[{self.timestamp}] {self.parent} -> {self.child} (PID: {self.pid})"

    @classmethod
    def from_wmi_process(cls, process: Any, parent_name: str, status: str = "NEW", suspicious_keywords: list = None) -> 'ProcessLog':
        if suspicious_keywords is None:
            suspicious_keywords = []

        try:
            cmd_line = process.CommandLine or ""
        except Exception:
            cmd_line = "N/A"

        cmd_lower = str(cmd_line).lower()
        is_suspicious = any(k in cmd_lower for k in suspicious_keywords)
        
        return cls(
            pid=process.ProcessId,
            child=process.Name,
            parent=parent_name,
            args=cmd_line,
            suspicious=is_suspicious,
            status=status,
            is_running=True
        )