import shutil
import subprocess
from pathlib import Path
import pytest


def test_empty_tester_log_preserves_native_report_and_invalid_classification():
    pwsh = shutil.which('pwsh')
    if not pwsh:
        pytest.skip('PowerShell 7 required')
    script = Path(__file__).with_name('Test-RunSmokeEmptyTesterLog.ps1')
    result = subprocess.run([pwsh, '-NoProfile', '-File', str(script)],
                            capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stdout + result.stderr
    assert 'PASS:' in result.stdout
