# ShellScope

A local flight recorder for Windows terminal activity and transient process logging.

ShellScope uses Windows Management Instrumentation (WMI) to capture process creation events, including short-lived "flash" processes (under 100ms). It logs command-line arguments to a local SQLite database, providing a comprehensive audit trail of system activity without external dependencies.

## Key Features

- **Transient Process Capture**: Detects and logs processes with lifespans under 100ms.
- **Argument Logging**: Captures full command-line arguments for detailed analysis.
- **Local-First Architecture**: All data is stored locally in SQLite with no cloud uploads.
- **Low Resource Usage**: Efficient Python backend combined with a performant Flutter UI.

## Tech Stack

- **Frontend**: Flutter (Desktop)
- **Backend**: Python (WMI, SQLite)
- **Inter-Process Communication**: JSON over stdout/pipes

## Installation & Setup (Dev Environment)

### Prerequisites

- Python 3.8 or higher
- Flutter SDK
- Windows OS

### Steps

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/shellscope.git
   cd shellscope
   ```

2. Install Python requirements:

   ```bash
   pip install wmi pywin32
   ```

3. Run the Flutter application:

   ```bash
   cd shellscope
   flutter run -d windows
   ```

## Usage Guide

The ShellScope dashboard provides a real-time view of system activity.

- **Process List**: Displays all captured processes.
    - **Green**: Safe or standard processes.
    - **Red**: Suspicious activity (e.g., commands using `-enc`).
- **Status Indicator**: Shows whether a process is currently "Running" or "Closed".

## Roadmap / Future Work

- **Linux Support**: Implementation via Netlink.
- **macOS Support**: Implementation via Endpoint Security or psutil.
- **ETW Integration**: Integration with Event Tracing for Windows for lower latency event capture.

## License

MIT License
