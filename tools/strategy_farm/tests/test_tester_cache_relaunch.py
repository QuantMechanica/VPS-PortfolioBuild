from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "strategy_farm" / "tester_cache_relaunch.ps1"


def _powershell_json(body: str) -> dict[str, object]:
    command = f". '{SCRIPT}'; {body}"
    result = subprocess.run(
        ("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", command),
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=20,
        check=False,
    )
    assert result.returncode == 0, result.stderr or result.stdout
    return json.loads(result.stdout)


@pytest.mark.skipif(os.name != "nt", reason="Windows PowerShell 5.1 only")
def test_exact_match_finishes_after_one_attempt() -> None:
    result = _powershell_json(
        "$script:launches=0; $script:journal=@(); "
        "$outcome=Invoke-VerifiedFactoryWorkerRelaunch "
        "-Expected @('t2','T1','T1') "
        "-Launch { $script:launches++; 'ok' } "
        "-Probe { @('T1','T2') } "
        "-Journal { param($row) $script:journal += $row } "
        "-SettleSeconds 0; "
        "[pscustomobject]@{ outcome=$outcome; launches=$script:launches; journal_count=$script:journal.Count } "
        "| ConvertTo-Json -Depth 6"
    )
    assert result["launches"] == 1
    assert result["journal_count"] == 1
    assert result["outcome"]["matched"] is True
    assert result["outcome"]["expected"] == ["T1", "T2"]


@pytest.mark.skipif(os.name != "nt", reason="Windows PowerShell 5.1 only")
def test_missing_worker_retries_once_then_verifies() -> None:
    result = _powershell_json(
        "$script:launches=0; $script:probes=0; $script:journal=@(); "
        "$outcome=Invoke-VerifiedFactoryWorkerRelaunch "
        "-Expected @('T1','T2') "
        "-Launch { $script:launches++; 'ok' } "
        "-Probe { $script:probes++; if($script:probes -eq 1){ @('T1') } else { @('T1','T2') } } "
        "-Journal { param($row) $script:journal += $row } "
        "-SettleSeconds 0; "
        "[pscustomobject]@{ outcome=$outcome; launches=$script:launches; journal_count=$script:journal.Count; first=$script:journal[0] } "
        "| ConvertTo-Json -Depth 6"
    )
    assert result["launches"] == 2
    assert result["journal_count"] == 2
    assert result["first"]["missing"] == ["T2"]
    assert result["outcome"]["attempt"] == 2
    assert result["outcome"]["matched"] is True


@pytest.mark.skipif(os.name != "nt", reason="Windows PowerShell 5.1 only")
def test_second_mismatch_is_returned_for_alarm() -> None:
    result = _powershell_json(
        "$script:launches=0; $script:journal=@(); "
        "$outcome=Invoke-VerifiedFactoryWorkerRelaunch "
        "-Expected @('T1','T2') "
        "-Launch { $script:launches++; 'ok' } "
        "-Probe { @('T1','T3') } "
        "-Journal { param($row) $script:journal += $row } "
        "-SettleSeconds 0; "
        "[pscustomobject]@{ outcome=$outcome; launches=$script:launches; journal_count=$script:journal.Count } "
        "| ConvertTo-Json -Depth 6"
    )
    assert result["launches"] == 2
    assert result["journal_count"] == 2
    assert result["outcome"]["matched"] is False
    assert result["outcome"]["missing"] == ["T2"]
    assert result["outcome"]["unexpected"] == ["T3"]
