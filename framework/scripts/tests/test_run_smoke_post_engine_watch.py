"""Exercise native PowerShell bounded journal and post-engine stall helpers."""
from pathlib import Path
import shutil
import subprocess

import pytest


def test_post_engine_watch():
    shell = shutil.which('pwsh') or shutil.which('powershell')
    if not shell:
        pytest.skip('PowerShell unavailable')
    test = Path(__file__).with_name('Test-RunSmokePostEngineWatch.ps1')
    result = subprocess.run([shell, '-NoProfile', '-File', str(test)], capture_output=True, text=True, timeout=60)
    assert result.returncode == 0, result.stdout + result.stderr
    assert 'PASS Test-RunSmokePostEngineWatch' in result.stdout
