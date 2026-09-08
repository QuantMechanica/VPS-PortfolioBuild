import shutil
import subprocess
from pathlib import Path

import pytest


def test_logger_capture_schema_freshness_and_legacy_regressions():
    pwsh = shutil.which('pwsh')
    if not pwsh:
        pytest.skip('PowerShell 7 required')
    result = subprocess.run([pwsh, '-NoProfile', '-File', str(
        Path(__file__).with_name('Test-RunSmokeLoggerSample.ps1'))],
        capture_output=True, text=True, timeout=45)
    assert result.returncode == 0, result.stdout + result.stderr
    assert 'Test-RunSmokeLoggerSample.result=PASS' in result.stdout
