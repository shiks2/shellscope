import sys
import os
from unittest.mock import MagicMock
import pytest

# Add backend to path so local imports in monitor.py (e.g. 'import models') work
backend_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if backend_path not in sys.path:
    sys.path.insert(0, backend_path)

# Pre-mock wmi and pythoncom before any test imports monitor
if 'wmi' not in sys.modules:
    sys.modules['wmi'] = MagicMock()
if 'pythoncom' not in sys.modules:
    sys.modules['pythoncom'] = MagicMock()

@pytest.fixture
def mock_wmi():
    return sys.modules['wmi']

@pytest.fixture
def mock_pythoncom():
    return sys.modules['pythoncom']
