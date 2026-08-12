from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import terminal_worker  # noqa: E402


EX5_SHA = "1" * 64
SET_SHA = "2" * 64
MQ5_SHA = "3" * 64
INI_SHA = "4" * 64


def bound_payload() -> dict[str, object]:
    return {
        "evidence_binding_required": True,
        "expected_from_date": "2022.07.01",
        "expected_to_date": "2022.12.31",
        "expected_symbol": "WS30.DWX",
        "expected_period": "M15",
        "expected_expert": r"QM\QM5_20033_moc-imom",
        "expected_ex5_sha256": EX5_SHA,
        "expected_setfile_sha256": SET_SHA,
        "expected_mq5_sha256": MQ5_SHA,
    }


def bound_summary() -> dict[str, object]:
    return {
        "evidence_schema": "run_smoke/v2",
        "from_date": "2022.07.01",
        "to_date": "2022.12.31",
        "symbol": "WS30.DWX",
        "period": "M15",
        "expert": r"QM\QM5_20033_moc-imom",
        "test_window": {
            "from_date": "2022.07.01",
            "to_date": "2022.12.31",
            "source": "generated_tester_ini",
            "tester_ini_files": [
                {
                    "sha256": INI_SHA,
                    "from_date": "2022.07.01",
                    "to_date": "2022.12.31",
                    "symbol": "WS30.DWX",
                    "period": "M15",
                    "expert": r"QM\QM5_20033_moc-imom",
                }
            ],
        },
        "execution_identity": {
            "stable_during_run": True,
            "expert_binary": {
                "deployed": {"sha256": EX5_SHA},
                "stable_during_run": True,
            },
            "setfile": {
                "source": {"sha256": SET_SHA},
                "stable_during_run": True,
            },
            "mq5_source": {"sha256": MQ5_SHA},
        },
    }


def test_matching_window_and_artifacts_are_accepted() -> None:
    assert farmctl._summary_matches_expected_evidence(bound_summary(), bound_payload())


def test_different_window_or_binary_is_rejected() -> None:
    summary = bound_summary()
    summary["from_date"] = "2024.01.01"
    assert not farmctl._summary_matches_expected_evidence(summary, bound_payload())

    summary = bound_summary()
    summary["execution_identity"]["expert_binary"]["deployed"]["sha256"] = "f" * 64  # type: ignore[index]
    assert not farmctl._summary_matches_expected_evidence(summary, bound_payload())


def test_missing_v2_identity_is_fail_closed_for_new_claim() -> None:
    assert not farmctl._summary_matches_expected_evidence(
        {"result": "PASS", "year": 2024},
        bound_payload(),
    )


def test_legacy_claim_without_binding_marker_remains_readable() -> None:
    assert farmctl._summary_matches_expected_evidence(
        {"result": "PASS", "year": 2024},
        {},
    )


def test_summary_loader_rejects_fresh_but_misattributed_summary(tmp_path: Path) -> None:
    path = tmp_path / "summary.json"
    summary = bound_summary()
    summary["to_date"] = "2024.12.31"
    path.write_text(json.dumps(summary), encoding="utf-8")
    assert farmctl._load_summary_if_fresh(path, bound_payload()) is None
    assert terminal_worker._load_fresh_summary(path, bound_payload()) is None


def test_run_smoke_publishes_actual_window_and_hash_identity() -> None:
    script = (
        REPO / "framework" / "scripts" / "run_smoke.ps1"
    ).read_text(encoding="utf-8-sig")
    assert 'evidence_schema = "run_smoke/v2"' in script
    assert "from_date = $actualFromDate" in script
    assert "to_date = $actualToDate" in script
    assert "year = $actualYear" in script
    assert "requested_year = $Year" in script
    assert "expert_binary = $expertBinaryIdentity" in script
    assert "setfile = $setfileIdentity" in script
    assert "tester_ini_files = $testerIniEvidence.ToArray()" in script
    assert "tester_ini_files = @($testerIniEvidence)" not in script


def test_powershell_generic_evidence_list_serializes_as_object_array() -> None:
    powershell = shutil.which("pwsh") or shutil.which("powershell")
    if powershell is None:
        pytest.skip("PowerShell is unavailable")

    command = r"""
$items = New-Object System.Collections.Generic.List[object]
$items.Add([pscustomobject]@{ run = 'run_01'; from_date = '2022.07.01' })
$summary = [ordered]@{ tester_ini_files = $items.ToArray() }
$summary | ConvertTo-Json -Depth 4 -Compress
"""
    completed = subprocess.run(
        [powershell, "-NoProfile", "-NonInteractive", "-Command", command],
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode == 0, completed.stderr
    payload = json.loads(completed.stdout)
    assert payload["tester_ini_files"] == [
        {"run": "run_01", "from_date": "2022.07.01"}
    ]


def test_full_history_null_dates_are_unconstrained_not_fail_closed() -> None:
    """Regression (audit FB-02, 2026-07-24): full-history Q03 dispatch stamps
    evidence_binding_required=True with expected_from/to_date=None. The matcher
    fail-closed on the None dates and rejected every legitimate full-history
    summary -> the whole gate INFRA_FAILed from 2026-07-23 (root commit
    0edb2cf9d). None/empty expected DATE = unconstrained; identity fields
    (symbol/period/expert/hashes) stay fail-closed."""
    payload = bound_payload()
    payload["expected_from_date"] = None
    payload["expected_to_date"] = None
    assert farmctl._summary_matches_expected_evidence(bound_summary(), payload)

    # identity remains fail-closed even with unconstrained dates
    payload_bad_symbol = dict(payload)
    payload_bad_symbol["expected_symbol"] = None
    assert not farmctl._summary_matches_expected_evidence(bound_summary(), payload_bad_symbol)

    summary_wrong_symbol = bound_summary()
    summary_wrong_symbol["symbol"] = "EURUSD.DWX"
    assert not farmctl._summary_matches_expected_evidence(summary_wrong_symbol, payload)

    # windowed claims (non-None dates) still enforce the window strictly
    summary_wrong_window = bound_summary()
    summary_wrong_window["from_date"] = "2024.01.01"
    assert not farmctl._summary_matches_expected_evidence(summary_wrong_window, bound_payload())
