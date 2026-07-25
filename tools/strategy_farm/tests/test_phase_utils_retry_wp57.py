"""Unit tests for the shared bounded run_smoke retry classifier."""

from __future__ import annotations

import io
import json
import subprocess
from pathlib import Path

from framework.scripts import _phase_utils as utils


def test_cold_cache_failure_retries_then_succeeds() -> None:
    calls: list[int] = []
    delays: list[float] = []
    retry_log = io.StringIO()

    def fake_runner(args, **kwargs):
        calls.append(len(calls) + 1)
        if len(calls) == 1:
            return subprocess.CompletedProcess(args, 1, stdout="BARS_ZERO", stderr="")
        return subprocess.CompletedProcess(args, 0, stdout="run_smoke.result=PASS", stderr="")

    proc = utils.run_with_launch_fault_retry(
        ["pwsh.exe"],
        runner=fake_runner,
        attempts=3,
        backoff_sec=2.5,
        sleep_func=delays.append,
        retry_log=retry_log,
        capture_output=True,
        text=True,
    )

    assert proc.returncode == 0
    assert calls == [1, 2]
    assert delays == [2.5]
    assert "attempt=1/3" in retry_log.getvalue()
    assert "matched_signature=BARS_ZERO" in retry_log.getvalue()
    assert "next_attempt=2/3" in retry_log.getvalue()


def test_genuine_strategy_failure_with_old_invalid_warmup_is_not_retried(tmp_path: Path) -> None:
    summary = tmp_path / "summary.json"
    summary.write_text(
        json.dumps(
            {
                "result": "FAIL",
                "reason_classes": ["MIN_TRADES_NOT_MET"],
                "runs": [
                    {
                        "status": "INVALID",
                        "failure": "NO_HISTORY",
                        "invalid_report_reasons": ["BARS_ZERO", "M0_1970_PERIOD"],
                    },
                    {"status": "OK", "total_trades": 3, "profit_factor": 0.71},
                ],
            }
        ),
        encoding="utf-8",
    )
    calls = 0

    def fake_runner(args, **kwargs):
        nonlocal calls
        calls += 1
        return subprocess.CompletedProcess(
            args,
            1,
            stdout=f"run_smoke.result=FAIL\nrun_smoke.summary={summary}\nBARS_ZERO",
            stderr="",
        )

    proc = utils.run_with_launch_fault_retry(
        ["pwsh.exe"],
        runner=fake_runner,
        attempts=4,
        sleep_func=lambda _: None,
        capture_output=True,
        text=True,
    )

    assert proc.returncode == 1
    assert calls == 1


def test_retry_is_bounded_and_exhaustion_is_visible() -> None:
    calls = 0
    retry_log = io.StringIO()

    def fake_runner(args, **kwargs):
        nonlocal calls
        calls += 1
        return subprocess.CompletedProcess(args, 1, stdout="", stderr="EMPTY_SYMBOL")

    proc = utils.run_with_launch_fault_retry(
        ["pwsh.exe"],
        runner=fake_runner,
        attempts=2,
        backoff_sec=0,
        sleep_func=lambda _: None,
        retry_log=retry_log,
        capture_output=True,
        text=True,
    )

    assert proc.returncode == 1
    assert calls == 2
    assert "attempt=2/2" in retry_log.getvalue()
    assert "matched_signature=EMPTY_SYMBOL" in retry_log.getvalue()
    assert "action=exhausted" in retry_log.getvalue()


def test_strategy_failure_after_cold_retry_stops_without_third_attempt() -> None:
    calls = 0
    child_log = io.StringIO()

    def fake_runner(args, **kwargs):
        nonlocal calls
        calls += 1
        if calls == 1:
            kwargs["stdout"].write("BARS_ZERO\n")
        else:
            kwargs["stdout"].write(
                "run_smoke.result=FAIL\n"
                "run_smoke.reason_classes=MIN_TRADES_NOT_MET\n"
                "BARS_ZERO\n"
            )
        return subprocess.CompletedProcess(args, 1)

    proc = utils.run_with_launch_fault_retry(
        ["pwsh.exe"],
        runner=fake_runner,
        attempts=4,
        backoff_sec=0,
        sleep_func=lambda _: None,
        stdout=child_log,
        stderr=subprocess.STDOUT,
        text=True,
    )

    assert proc.returncode == 1
    assert calls == 2
    assert child_log.getvalue().count("launch_fault_retry") == 1


def test_summary_invalid_status_is_classified(tmp_path: Path) -> None:
    summary = tmp_path / "summary.json"
    summary.write_text(
        json.dumps(
            {
                "result": "FAIL",
                "reason_classes": [],
                "runs": [{"status": "INVALID", "failure": "INVALID_REPORT"}],
            }
        ),
        encoding="utf-8",
    )

    assert (
        utils.cold_cache_retry_signature(f"run_smoke.summary={summary}")
        == "RUN_STATUS_INVALID"
    )


def test_tester_history_synchronization_line_is_classified() -> None:
    text = "2026.07.24 05:40:22 EURUSD.DWX: history synchronization error\n"

    assert utils.cold_cache_retry_signature(text) == "HISTORY_SYNCHRONIZATION_ERROR"


def test_every_named_cold_cache_signature_is_classified() -> None:
    for signature in utils.COLD_CACHE_SIGNATURES:
        assert utils.cold_cache_retry_signature(signature) == signature


def test_signature_substring_inside_another_token_is_not_classified() -> None:
    assert utils.cold_cache_retry_signature("diagnostic=NOT_BARS_ZERO") is None
