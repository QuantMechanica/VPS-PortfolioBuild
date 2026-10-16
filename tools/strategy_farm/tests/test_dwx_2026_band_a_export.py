from __future__ import annotations

import datetime as dt
import importlib.util
import json
from pathlib import Path
import sys
from types import SimpleNamespace

import pytest

from framework.scripts.mt5_diagnostics import dwx_2026_band_a_export as exporter


def _write_raw_bundle(session_root: Path) -> tuple[dict, Path]:
    raw_root = session_root / "raw"
    raw_root.mkdir()
    raw_file = raw_root / "XAUUSD_bars.csv"
    raw_file.write_bytes(b"time,open,high,low,close,volume\n")
    files = [
        {
            "relative_path": raw_file.name,
            "bytes": raw_file.stat().st_size,
            "sha256": exporter.sha256_file(raw_file),
        }
    ]
    return (
        {
            "root": str(raw_root.resolve()),
            "files": files,
            "bundle_sha256": exporter._canonical_sha256(files),
        },
        raw_file,
    )


def test_mql_source_is_read_only_t1_band_a_bars_and_ticks() -> None:
    binding = exporter.validate_mql_source()
    assert binding["read_only"] is True
    assert tuple(binding["band_a"]) == exporter.BAND_A
    source = exporter.SOURCE.read_text(encoding="utf-8-sig")
    assert "CopyRates(" in source
    assert "CopyTicksRange(" in source
    assert "InpHardCeilingMinutes" in source
    assert '"CEILING"' in source
    assert "started_monotonic_ms" in source
    assert "output_bytes" in source
    assert "CustomRates" not in source
    assert "CustomTicks" not in source
    assert "OrderSend(" not in source
    assert 'root!="d:\\\\qm\\\\mt5\\\\t1"' in "".join(source.split()).lower()


def test_session_scope_and_c1_reservation_are_fail_closed() -> None:
    assert exporter.validate_symbols(["XAUUSD.DWX", "EURUSD"]) == (
        "XAUUSD",
        "EURUSD",
    )
    assert exporter.reservation_minutes(["XAUUSD", "EURUSD"]) == 135
    assert exporter.export_timeout_seconds(["XAUUSD", "EURUSD"]) == 125 * 60
    with pytest.raises(exporter.ExportRefused, match="rank order"):
        exporter.validate_symbols(["EURUSD", "XAUUSD"])
    with pytest.raises(exporter.ExportRefused, match="one or two"):
        exporter.validate_symbols(["XAUUSD", "NDX", "XTIUSD"])
    with pytest.raises(exporter.ExportRefused, match="Band A"):
        exporter.validate_symbols(["WS30"])


def test_export_timeout_preserves_cleanup_margin_before_reservation_expiry() -> None:
    now = dt.datetime(2026, 10, 12, 20, tzinfo=dt.UTC)
    until = now + dt.timedelta(minutes=20)
    assert exporter._effective_export_timeout_seconds(
        3600, until.isoformat(), now=now
    ) == 7 * 60
    with pytest.raises(exporter.ExportRefused, match="12-minute cleanup margin"):
        exporter._effective_export_timeout_seconds(
            3600,
            (now + dt.timedelta(minutes=12, seconds=59)).isoformat(),
            now=now,
        )


def test_reservation_heartbeat_renews_exact_live_holder(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    class Lock:
        def __init__(self, *_args, **_kwargs) -> None:
            pass

        def __enter__(self):
            return self

        def __exit__(self, *_args) -> None:
            pass

    reserved_by = f"dwx2026:{exporter.os.getpid()}:task"
    exporter.farmctl.set_terminal_reservation(
        tmp_path,
        exporter.TERMINAL_NAME,
        reserved_by,
        minutes=75,
        reason="test",
    )
    monkeypatch.setattr(exporter, "FARM_ROOT", tmp_path)
    monkeypatch.setattr(exporter, "FactoryMutationLock", Lock)
    event = exporter._maintain_terminal_reservation(reserved_by)
    assert event["status"] == "RENEWED"
    assert event["heartbeat_count"] == 1
    assert (
        exporter.farmctl.terminal_reservation(tmp_path, exporter.TERMINAL_NAME)[
            "reserved_by"
        ]
        == reserved_by
    )


def test_plan_is_non_mutating_and_xauusd_first_calibration_only() -> None:
    plan = exporter.run_session(
        session_tag="20261012T200000Z_xau_calibration",
        symbols=["XAUUSD"],
        cutoff_utc="2026-10-12T20:00:00Z",
        calibration=True,
        calibration_admission_gib=17.0,
        headroom_acceptance=None,
        apply=False,
    )
    assert plan["status"] == "PLAN_ONLY"
    assert plan["admissible"] is False
    assert plan["reservation_minutes"] == 75
    assert plan["export_timeout_seconds"] == 65 * 60
    assert plan["calibration_admission_gib"] == 17.0
    with pytest.raises(exporter.ExportRefused, match="calibration-admission"):
        exporter.run_session(
            session_tag="20261012T200005Z_missing_admission",
            symbols=["XAUUSD"],
            cutoff_utc="2026-10-12T20:00:00Z",
            calibration=True,
            calibration_admission_gib=None,
            headroom_acceptance=None,
            apply=False,
        )
    with pytest.raises(exporter.ExportRefused, match="XAUUSD only"):
        exporter.run_session(
            session_tag="20261012T200001Z_bad_calibration",
            symbols=["NDX"],
            cutoff_utc="2026-10-12T20:00:00Z",
            calibration=True,
            calibration_admission_gib=17.0,
            headroom_acceptance=None,
            apply=False,
        )
    with pytest.raises(exporter.ExportRefused, match="accepted headroom"):
        exporter.run_session(
            session_tag="20261012T200002Z_no_headroom",
            symbols=["XAUUSD"],
            cutoff_utc="2026-10-12T20:00:00Z",
            calibration=False,
            calibration_admission_gib=None,
            headroom_acceptance=None,
            apply=False,
        )


def test_headroom_acceptance_binds_fable_code_terminal_and_xau_calibration(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path,
) -> None:
    source_root = tmp_path / "source"
    session_root = source_root / "20261012T200000Z_xau_calibration"
    session_root.mkdir(parents=True)
    monkeypatch.setattr(exporter, "ARTIFACT_ROOT", source_root)
    monkeypatch.setattr(
        exporter,
        "_require_tracked_clean_acceptance",
        lambda _path: (
            "docs/ops/evidence/task_35eb350f-1fe2-4649-a349-58c38bd7e855/"
            "HEADROOM_ACCEPTANCE.json"
        ),
    )
    acceptance = tmp_path / "accepted.json"
    raw_bundle, raw_file = _write_raw_bundle(session_root)
    calibration = {
        "schema": exporter.CALIBRATION_SCHEMA,
        "task_id": exporter.TASK_ID,
        "admissible": False,
        "symbols": ["XAUUSD"],
        "wrapper_sha256": "a" * 64,
        "source_sha256": "b" * 64,
        "terminal_sha256": "c" * 64,
        "observed_peak_private_gib": 1.1,
        "measured_export_headroom_gib": 1.25,
        "raw_bundle_sha256": raw_bundle["bundle_sha256"],
        "session_receipt_path": str(session_root / "session_receipt.json"),
    }
    calibration["calibration_sha256"] = exporter._canonical_sha256(calibration)
    calibration_path = session_root / "headroom_calibration.json"
    calibration_path.write_text(json.dumps(calibration), encoding="utf-8")
    session_receipt = {
        "status": "CALIBRATION_REVIEW_REQUIRED",
        "v1_manifest_master_unchanged": True,
        "headroom_calibration": calibration,
        "export": {"error": None, "cleanup_errors": [], "raw": raw_bundle},
    }
    session_receipt_path = session_root / "session_receipt.json"
    session_receipt_path.write_text(json.dumps(session_receipt), encoding="utf-8")
    body = {
        "schema": exporter.HEADROOM_ACCEPTANCE_SCHEMA,
        "task_id": exporter.TASK_ID,
        "accepted_by": "Fable",
        "accepted_for_band_a": True,
        "wrapper_sha256": "a" * 64,
        "source_sha256": "b" * 64,
        "terminal_sha256": "c" * 64,
        "admission_gib": 18.0,
        "allowed_symbols": list(exporter.BAND_A),
        "calibration": calibration,
        "calibration_sha256": calibration["calibration_sha256"],
        "calibration_file_sha256": exporter.sha256_file(calibration_path),
        "session_receipt_sha256": exporter.sha256_file(session_receipt_path),
    }
    acceptance.write_text(json.dumps(body), encoding="utf-8")
    checked = exporter.validate_headroom_acceptance(
        acceptance,
        symbols=["NDX", "XTIUSD"],
        wrapper_sha256="a" * 64,
        source_sha256="b" * 64,
        terminal_sha256="c" * 64,
    )
    assert checked["headroom_gib"] == 1.25
    assert checked["admission_gib"] == 18.0
    assert exporter._required_free_gib(checked) == 18.0
    assert checked["raw_bundle"]["bundle_sha256"] == raw_bundle["bundle_sha256"]
    assert exporter._required_free_gib(
        {"admission_gib": 14.0, "headroom_gib": 8.0}
    ) == 22.0

    missing_admission = dict(body)
    missing_admission.pop("admission_gib")
    acceptance.write_text(json.dumps(missing_admission), encoding="utf-8")
    with pytest.raises(exporter.ExportRefused, match="admission_gib is absent"):
        exporter.validate_headroom_acceptance(
            acceptance,
            symbols=["NDX"],
            wrapper_sha256="a" * 64,
            source_sha256="b" * 64,
            terminal_sha256="c" * 64,
        )
    low_admission = {**body, "admission_gib": 13.99}
    acceptance.write_text(json.dumps(low_admission), encoding="utf-8")
    with pytest.raises(exporter.ExportRefused, match="at least 14.0"):
        exporter.validate_headroom_acceptance(
            acceptance,
            symbols=["NDX"],
            wrapper_sha256="a" * 64,
            source_sha256="b" * 64,
            terminal_sha256="c" * 64,
        )

    acceptance.write_text(json.dumps(body), encoding="utf-8")
    raw_file.write_bytes(b"tampered after acceptance\n")
    with pytest.raises(exporter.ExportRefused, match="raw file identity mismatch"):
        exporter.validate_headroom_acceptance(
            acceptance,
            symbols=["NDX"],
            wrapper_sha256="a" * 64,
            source_sha256="b" * 64,
            terminal_sha256="c" * 64,
        )
    raw_file.write_bytes(b"time,open,high,low,close,volume\n")

    body["accepted_by"] = "Codex"
    acceptance.write_text(json.dumps(body), encoding="utf-8")
    with pytest.raises(exporter.ExportRefused, match="binding mismatch"):
        exporter.validate_headroom_acceptance(
            acceptance,
            symbols=["NDX"],
            wrapper_sha256="a" * 64,
            source_sha256="b" * 64,
            terminal_sha256="c" * 64,
        )

    body["accepted_by"] = "Fable"
    body["calibration"]["source_sha256"] = "d" * 64
    acceptance.write_text(json.dumps(body), encoding="utf-8")
    with pytest.raises(exporter.ExportRefused, match="differs"):
        exporter.validate_headroom_acceptance(
            acceptance,
            symbols=["NDX"],
            wrapper_sha256="a" * 64,
            source_sha256="b" * 64,
            terminal_sha256="c" * 64,
        )


def test_forged_acceptance_cannot_replace_real_calibration_file(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    source_root = tmp_path / "source"
    session_root = source_root / "20261012T200000Z_xau_calibration"
    session_root.mkdir(parents=True)
    monkeypatch.setattr(exporter, "ARTIFACT_ROOT", source_root)
    monkeypatch.setattr(
        exporter,
        "_require_tracked_clean_acceptance",
        lambda _path: "docs/ops/evidence/task/HEADROOM_ACCEPTANCE.json",
    )
    raw_bundle, _raw_file = _write_raw_bundle(session_root)
    real = {
        "schema": exporter.CALIBRATION_SCHEMA,
        "task_id": exporter.TASK_ID,
        "admissible": False,
        "symbols": ["XAUUSD"],
        "wrapper_sha256": "a" * 64,
        "source_sha256": "b" * 64,
        "terminal_sha256": "c" * 64,
        "observed_peak_private_gib": 1.1,
        "measured_export_headroom_gib": 1.25,
        "raw_bundle_sha256": raw_bundle["bundle_sha256"],
        "session_receipt_path": str(session_root / "session_receipt.json"),
    }
    real["calibration_sha256"] = exporter._canonical_sha256(real)
    calibration_path = session_root / "headroom_calibration.json"
    calibration_path.write_text(json.dumps(real), encoding="utf-8")
    session_receipt_path = session_root / "session_receipt.json"
    session_receipt_path.write_text(
        json.dumps(
            {
                "status": "CALIBRATION_REVIEW_REQUIRED",
                "v1_manifest_master_unchanged": True,
                "headroom_calibration": real,
                "export": {"error": None, "cleanup_errors": [], "raw": raw_bundle},
            }
        ),
        encoding="utf-8",
    )
    forged = dict(real)
    forged["measured_export_headroom_gib"] = 0.25
    acceptance = tmp_path / "acceptance.json"
    acceptance.write_text(
        json.dumps(
            {
                "schema": exporter.HEADROOM_ACCEPTANCE_SCHEMA,
                "task_id": exporter.TASK_ID,
                "accepted_by": "Fable",
                "accepted_for_band_a": True,
                "wrapper_sha256": "a" * 64,
                "source_sha256": "b" * 64,
                "terminal_sha256": "c" * 64,
                "admission_gib": 18.0,
                "allowed_symbols": list(exporter.BAND_A),
                "calibration": forged,
                "calibration_sha256": real["calibration_sha256"],
                "calibration_file_sha256": exporter.sha256_file(calibration_path),
                "session_receipt_sha256": exporter.sha256_file(
                    session_receipt_path
                ),
            }
        ),
        encoding="utf-8",
    )
    with pytest.raises(exporter.ExportRefused, match="differs"):
        exporter.validate_headroom_acceptance(
            acceptance,
            symbols=["NDX"],
            wrapper_sha256="a" * 64,
            source_sha256="b" * 64,
            terminal_sha256="c" * 64,
        )


def test_acceptance_must_be_tracked_clean_and_under_task_evidence(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    canonical = tmp_path / "repo"
    evidence = canonical / "docs/ops/evidence" / f"task_{exporter.TASK_ID}"
    evidence.mkdir(parents=True)
    acceptance = evidence / "HEADROOM_ACCEPTANCE.json"
    acceptance.write_text("{}", encoding="utf-8")
    monkeypatch.setattr(exporter, "CANONICAL_REPO", canonical)
    monkeypatch.setattr(exporter, "TASK_EVIDENCE_ROOT", evidence)
    calls: list[tuple[str, ...]] = []

    def clean_git(*args: str) -> str:
        calls.append(args)
        return ""

    monkeypatch.setattr(exporter, "_git", clean_git)
    relative = exporter._require_tracked_clean_acceptance(acceptance)
    assert relative.endswith("HEADROOM_ACCEPTANCE.json")
    assert calls[0][0] == "ls-files"
    assert calls[1][0] == "status"

    monkeypatch.setattr(
        exporter,
        "_git",
        lambda *args: " M acceptance" if args[0] == "status" else "",
    )
    with pytest.raises(exporter.ExportRefused, match="not clean"):
        exporter._require_tracked_clean_acceptance(acceptance)


def test_disabled_purge_task_stays_disabled_on_restore(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    before = {
        "task_name": exporter.PURGE_TASK,
        "task_path": "\\",
        "state": "Disabled",
        "enabled": False,
        "running": False,
        "actions": [{"execute": "powershell.exe", "arguments": "purge"}],
    }
    scripts: list[str] = []

    def powershell(script: str, **_kwargs):
        scripts.append(script)
        return {"ok": True}

    monkeypatch.setattr(exporter.boot, "_powershell_json", powershell)
    monkeypatch.setattr(exporter, "_task_snapshot", lambda: dict(before))
    monkeypatch.setattr(exporter, "_purge_processes", lambda: [])
    restored = exporter._restore_purge(before)
    assert restored["after"]["enabled"] is False
    assert "$wasEnabled=$false" in scripts[0]


def test_restore_lock_retries_then_writes_standard_restart_receipt(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    attempts = {"count": 0}

    class BusyThenFree:
        def __init__(self, *_args, **_kwargs) -> None:
            self.entered = False

        def __enter__(self):
            attempts["count"] += 1
            if attempts["count"] < 3:
                raise RuntimeError("synthetic lock busy")
            self.entered = True
            return self

        def __exit__(self, *_args) -> None:
            self.entered = False

    reservation = {
        "reserved_by": "dwx2026:1:task",
        "until_utc": "2099-01-01T00:00:00+00:00",
    }
    monkeypatch.setattr(exporter, "FactoryMutationLock", BusyThenFree)
    monkeypatch.setattr(
        exporter.farmctl, "terminal_reservation", lambda *_args: reservation
    )
    monkeypatch.setattr(exporter.time, "sleep", lambda _seconds: None)
    monkeypatch.setattr(
        exporter,
        "_restore_worker",
        lambda *_args: {
            "new_pid": 202,
            "reservation_release": {"released": True},
            "restart_receipt": {
                "started_at": "2026-10-12T00:00:00Z",
                "apply": True,
                "worker_sha256": "a" * 64,
                "session_id": 1,
                "reloaded": [],
                "pending": [],
                "finished_at": "2026-10-12T00:00:01Z",
            },
        },
    )
    result = exporter._restore_worker_with_lock(
        environment={},
        reserved_by=reservation["reserved_by"],
        before_identity={"pid": 101, "created": 1.0},
        out=tmp_path,
        max_wait_seconds=10,
        backoff_seconds=0,
    )
    assert [row["result"] for row in result["lock_attempts"]] == [
        "LOCK_BUSY",
        "LOCK_BUSY",
        "LOCK_ACQUIRED",
    ]
    assert (tmp_path / "worker_restart_receipt.json").is_file()


def test_restore_lock_exhaustion_keeps_reservation_and_writes_no_strand_receipt(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    class AlwaysBusy:
        def __init__(self, *_args, **_kwargs) -> None:
            pass

        def __enter__(self):
            raise RuntimeError("synthetic lock busy")

        def __exit__(self, *_args) -> None:
            pass

    reservation = {
        "reserved_by": "dwx2026:1:task",
        "until_utc": "2099-01-01T00:00:00+00:00",
    }
    monkeypatch.setattr(exporter, "FactoryMutationLock", AlwaysBusy)
    monkeypatch.setattr(
        exporter.farmctl, "terminal_reservation", lambda *_args: reservation
    )
    monkeypatch.setattr(exporter, "_active_t1_rows", lambda: [])
    monkeypatch.setattr(exporter, "_t1_mt5_processes", lambda: [])
    monkeypatch.setattr(exporter.reload_idle_workers, "workers", lambda: {})
    monkeypatch.setattr(
        exporter.farmctl,
        "release_terminal_reservation",
        lambda *_args: (_ for _ in ()).throw(AssertionError("must not release")),
    )
    with pytest.raises(exporter.ExportRefused, match="remained busy"):
        exporter._restore_worker_with_lock(
            environment={},
            reserved_by=reservation["reserved_by"],
            before_identity={"pid": 101, "created": 1.0},
            out=tmp_path,
            max_wait_seconds=0,
            backoff_seconds=0,
        )
    receipt = json.loads(
        (tmp_path / "T1_WORKER_NOT_RESTORED.json").read_text(encoding="utf-8")
    )
    assert receipt["status"] == "T1_WORKER_NOT_RESTORED"
    assert receipt["reservation_retained_until_expiry"] is True


def test_restore_succeeds_after_own_reservation_lapses(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    worker = object()
    worker_scans = iter([{}, {exporter.TERMINAL_NAME: worker}])
    monkeypatch.setattr(exporter, "_active_t1_rows", lambda: [])
    monkeypatch.setattr(exporter, "_t1_mt5_processes", lambda: [])
    monkeypatch.setattr(
        exporter.farmctl, "terminal_reservation", lambda *_args: None
    )
    monkeypatch.setattr(
        exporter.reload_idle_workers, "workers", lambda: next(worker_scans)
    )
    monkeypatch.setattr(exporter.reload_idle_workers, "idle", lambda *_args: True)
    monkeypatch.setattr(
        exporter,
        "_worker_identity",
        lambda _worker: {
            "pid": 202,
            "created": 2.0,
            "executable_path": "C:/Python/python.exe",
            "command_line": ["python", "terminal_worker.py"],
            "session_id": 1,
        },
    )
    monkeypatch.setattr(
        exporter,
        "_process_environment_binding",
        lambda _worker: exporter._worker_environment_binding({}),
    )
    monkeypatch.setattr(
        exporter.subprocess,
        "run",
        lambda *_args, **_kwargs: SimpleNamespace(returncode=0),
    )
    monkeypatch.setattr(exporter.time, "sleep", lambda _seconds: None)
    monkeypatch.setattr(
        exporter.identity_hash, "identity_sha256", lambda *_args, **_kwargs: "a" * 64
    )
    monkeypatch.setattr(
        exporter,
        "_release_exact_reservation",
        lambda *_args: (_ for _ in ()).throw(AssertionError("lapsed reservation")),
    )
    result = exporter._restore_worker(
        {},
        "dwx2026:1:task",
        {
            "pid": 101,
            "created": 1.0,
            "executable_path": "C:/Python/python.exe",
            "command_line": ["python", "terminal_worker.py"],
        },
    )
    assert result["reservation_state_before_restore"] == "lapsed"
    assert result["reservation_release"] is None


def test_watchdog_respawn_is_accepted_only_with_matching_governance_environment(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    worker = object()
    environment = {
        "QM_RESEARCH_BACKTEST_MAX_ACTIVE": "2",
        "QM_RESEARCH_RAM_FLOOR_V1": "0",
        "QM_EXACT_TESTER_RSS_RESERVATIONS": "0",
        "QM_MULTISYMBOL_RAM_CANARY_V2": "1",
    }
    reservation = {
        "reserved_by": "dwx2026:1:task",
        "until_utc": "2099-01-01T00:00:00+00:00",
    }
    releases: list[str] = []
    monkeypatch.setattr(exporter, "_active_t1_rows", lambda: [])
    monkeypatch.setattr(exporter, "_t1_mt5_processes", lambda: [])
    monkeypatch.setattr(
        exporter.farmctl, "terminal_reservation", lambda *_args: reservation
    )
    monkeypatch.setattr(
        exporter.reload_idle_workers,
        "workers",
        lambda: {exporter.TERMINAL_NAME: worker},
    )
    monkeypatch.setattr(exporter.reload_idle_workers, "idle", lambda *_args: True)
    monkeypatch.setattr(
        exporter,
        "_worker_identity",
        lambda _worker: {
            "pid": 202,
            "created": 2.0,
            "executable_path": "C:/Python/python.exe",
            "command_line": ["python", "terminal_worker.py", "--terminal", "T1"],
            "session_id": 1,
        },
    )
    monkeypatch.setattr(
        exporter,
        "_process_environment_binding",
        lambda _worker: exporter._worker_environment_binding(environment),
    )
    monkeypatch.setattr(
        exporter,
        "_release_exact_reservation",
        lambda reserved_by: releases.append(reserved_by) or {"released": True},
    )
    monkeypatch.setattr(
        exporter.identity_hash, "identity_sha256", lambda *_args, **_kwargs: "a" * 64
    )
    monkeypatch.setattr(
        exporter.subprocess,
        "run",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError("watchdog-restored worker must not be relaunched")
        ),
    )

    result = exporter._restore_worker(
        environment,
        reservation["reserved_by"],
        {
            "pid": 101,
            "created": 1.0,
            "executable_path": "C:/Python/python.exe",
            "command_line": ["python", "terminal_worker.py", "--terminal", "T1"],
        },
    )
    assert result["restore_origin"] == "governed_watchdog_respawn"
    assert result["starter_exit"] is None
    assert releases == [reservation["reserved_by"]]

    drifted = dict(environment)
    drifted["QM_RESEARCH_BACKTEST_MAX_ACTIVE"] = "8"
    monkeypatch.setattr(
        exporter,
        "_process_environment_binding",
        lambda _worker: exporter._worker_environment_binding(drifted),
    )
    with pytest.raises(exporter.ExportRefused, match="environment differs"):
        exporter._restore_worker(
            environment,
            reservation["reserved_by"],
            {"pid": 101, "created": 1.0},
        )
    assert releases == [reservation["reserved_by"]]


def test_live_wrapper_reservation_real_starter_selection_restores_worker(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    starter_path = Path(__file__).resolve().parents[1] / "start_terminal_workers.py"
    starter_spec = importlib.util.spec_from_file_location(
        "dwx_2026_starter_under_test", starter_path
    )
    assert starter_spec is not None and starter_spec.loader is not None
    starter = importlib.util.module_from_spec(starter_spec)
    sys.modules[starter_spec.name] = starter
    starter_spec.loader.exec_module(starter)
    environment = {"QM_RESEARCH_BACKTEST_MAX_ACTIVE": "2"}
    reservation = {
        "reserved_by": "dwx2026:123:task",
        "until_utc": "2099-01-01T00:00:00+00:00",
    }
    worker = object()
    state: dict[str, object] = {}
    selected: list[str] = []
    releases: list[str] = []

    monkeypatch.setattr(exporter, "_active_t1_rows", lambda: [])
    monkeypatch.setattr(exporter, "_t1_mt5_processes", lambda: [])
    monkeypatch.setattr(
        exporter.farmctl, "terminal_reservation", lambda *_args: reservation
    )
    monkeypatch.setattr(exporter.reload_idle_workers, "workers", lambda: dict(state))
    monkeypatch.setattr(exporter.reload_idle_workers, "idle", lambda *_args: True)
    monkeypatch.setattr(
        exporter,
        "_worker_identity",
        lambda _worker: {
            "pid": 202,
            "created": 2.0,
            "executable_path": "C:/Python/python.exe",
            "command_line": ["python", "terminal_worker.py", "--terminal", "T1"],
            "session_id": 1,
        },
    )
    monkeypatch.setattr(
        exporter,
        "_process_environment_binding",
        lambda _worker: exporter._worker_environment_binding(environment),
    )
    monkeypatch.setattr(
        exporter.identity_hash, "identity_sha256", lambda *_args, **_kwargs: "a" * 64
    )
    monkeypatch.setattr(exporter.time, "sleep", lambda _seconds: None)
    monkeypatch.setattr(
        exporter,
        "_release_exact_reservation",
        lambda reserved_by: releases.append(reserved_by) or {"released": True},
    )

    def real_starter_selection(*_args, **_kwargs):
        governed = starter._governed_terminals(
            ("T1", "T2"),
            {"T2": [102]},
            {"max_workers": 2, "allow_new_workers": True},
        )
        selected.extend(governed)
        assert "T1" in governed
        state["T1"] = worker
        return SimpleNamespace(returncode=0)

    monkeypatch.setattr(exporter.subprocess, "run", real_starter_selection)
    try:
        result = exporter._restore_worker(
            environment,
            reservation["reserved_by"],
            {"pid": 101, "created": 1.0},
        )
    finally:
        sys.modules.pop(starter_spec.name, None)
    assert result["restore_origin"] == "governed_launcher"
    assert selected == ["T2", "T1"]
    assert releases == [reservation["reserved_by"]]


def test_watchdog_respawn_is_inert_while_wrapper_reservation_is_live(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    worker_path = (
        Path(__file__).resolve().parents[1] / "terminal_worker.py"
    )
    spec = importlib.util.spec_from_file_location(
        "dwx_2026_terminal_worker_under_test", worker_path
    )
    assert spec is not None and spec.loader is not None
    terminal_worker = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = terminal_worker
    spec.loader.exec_module(terminal_worker)
    reservation = {
        "reserved_by": "dwx2026:123:task",
        "until_utc": "2099-01-01T00:00:00+00:00",
        "heartbeat_count": 4,
    }
    terminal_worker._STOP = False
    monkeypatch.setattr(terminal_worker.signal, "signal", lambda *_args: None)
    monkeypatch.setattr(
        terminal_worker.farmctl,
        "terminal_reservation",
        lambda *_args: reservation,
    )

    def stop_after_wait(_seconds: float) -> None:
        terminal_worker._STOP = True

    monkeypatch.setattr(terminal_worker.time, "sleep", stop_after_wait)
    monkeypatch.setattr(
        terminal_worker,
        "release_stale_claims_for_terminal",
        lambda *_args: (_ for _ in ()).throw(
            AssertionError("reserved startup must perform no T1 mutation")
        ),
    )
    try:
        assert terminal_worker.run_loop(tmp_path, "T1", 60) == 0
    finally:
        terminal_worker._STOP = False
        sys.modules.pop(spec.name, None)


def test_quiesce_timeout_retains_reservation_and_writes_no_strand_receipt(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    class Worker:
        pid = 101

        def environ(self):
            return {"QM_RESEARCH_BACKTEST_MAX_ACTIVE": "2"}

        def terminate(self) -> None:
            pass

        def wait(self, timeout: float) -> None:
            raise exporter.psutil.TimeoutExpired(timeout, pid=self.pid)

        def is_running(self) -> bool:
            return True

    worker = Worker()
    reserved_by = "dwx2026:1:task"
    reservation = {
        "reserved_by": reserved_by,
        "until_utc": "2099-01-01T00:00:00+00:00",
    }
    monkeypatch.setattr(
        exporter,
        "_assert_t1_idle",
        lambda **_kwargs: {
            "worker_pid": worker.pid,
            "worker_created": 1.0,
            "worker_identity": {"pid": worker.pid, "created": 1.0},
        },
    )
    monkeypatch.setattr(
        exporter.reload_idle_workers,
        "workers",
        lambda: {exporter.TERMINAL_NAME: worker},
    )
    monkeypatch.setattr(
        exporter.farmctl,
        "set_terminal_reservation",
        lambda *_args, **_kwargs: reservation,
    )
    monkeypatch.setattr(
        exporter.farmctl, "terminal_reservation", lambda *_args: reservation
    )
    monkeypatch.setattr(exporter, "_active_t1_rows", lambda: [])
    monkeypatch.setattr(exporter, "_t1_mt5_processes", lambda: [])
    monkeypatch.setattr(
        exporter,
        "_release_exact_reservation",
        lambda *_args: (_ for _ in ()).throw(AssertionError("must retain reservation")),
    )
    with pytest.raises(exporter.ExportRefused, match="receipt="):
        exporter._quiesce_worker(reserved_by, 75, tmp_path)
    receipt = json.loads(
        (tmp_path / "T1_WORKER_NOT_RESTORED.json").read_text(encoding="utf-8")
    )
    assert receipt["reservation_retained_until_expiry"] is True
    assert receipt["worker_present"] is True


def _resource_stop_result(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    *,
    ram_values: list[float],
    disk_values: list[float],
    popen_hook=None,
    setup_terminal=None,
) -> dict:
    terminal_root = tmp_path / "T1"
    terminal_root.mkdir()
    if setup_terminal is not None:
        setup_terminal(terminal_root)
    terminal_binary = terminal_root / "terminal64.exe"
    metaeditor_binary = terminal_root / "MetaEditor64.exe"
    terminal_binary.write_bytes(b"terminal")
    metaeditor_binary.write_bytes(b"editor")
    source = tmp_path / "QM_DWX_2026_Band_A_Export.mq5"
    source.write_text("// synthetic", encoding="utf-8")
    out = tmp_path / "out"
    out.mkdir()
    monkeypatch.setattr(exporter, "TERMINAL_ROOT", terminal_root)
    monkeypatch.setattr(exporter, "TERMINAL_BINARY", terminal_binary)
    monkeypatch.setattr(exporter, "METAEDITOR_BINARY", metaeditor_binary)
    monkeypatch.setattr(exporter, "SOURCE", source)
    monkeypatch.setattr(
        exporter,
        "validate_mql_source",
        lambda *_args, **_kwargs: {"sha256": "b" * 64, "read_only": True},
    )
    monkeypatch.setattr(exporter, "_t1_mt5_processes", lambda: [])
    monkeypatch.setattr(exporter.boot, "scan_metaeditor_processes", lambda: [])
    monkeypatch.setattr(
        exporter.boot, "load_dxz_factory_login", lambda: (123, "Darwinex-Live")
    )

    def compile_run(args, **_kwargs):
        staged = Path(str(args[1]).split(":", 1)[1])
        compile_log = Path(str(args[2]).split(":", 1)[1])
        staged.with_suffix(".ex5").write_bytes(b"compiled")
        compile_log.write_text("0 errors, 0 warnings", encoding="utf-8")
        return SimpleNamespace(returncode=0)

    class Process:
        pid = 303
        returncode = None

        def poll(self):
            return self.returncode

        def terminate(self):
            self.returncode = 0

        def wait(self, **_kwargs):
            return self.returncode

    process = Process()

    def popen(args, **_kwargs):
        if popen_hook is not None:
            popen_hook(args, terminal_root)
        return process

    monkeypatch.setattr(exporter.subprocess, "run", compile_run)
    monkeypatch.setattr(exporter.subprocess, "Popen", popen)
    monkeypatch.setattr(exporter.boot, "scan_terminal_processes", lambda: [{}])
    monkeypatch.setattr(
        exporter.overlap_export,
        "_owned_match",
        lambda *_args: {"pid": process.pid},
    )
    monkeypatch.setattr(
        exporter.overlap_export,
        "_terminate_owned",
        lambda *_args: (
            process.terminate()
            or {"terminated": True, "pid": process.pid, "binding": "identity"}
        ),
    )
    monkeypatch.setattr(exporter, "_private_bytes_gib", lambda _pid: 1.0)
    ram = iter(ram_values)
    disk = iter(disk_values)
    monkeypatch.setattr(exporter, "_free_gib", lambda: next(ram))
    monkeypatch.setattr(exporter, "_disk_free_gib", lambda: next(disk))
    monkeypatch.setattr(
        exporter,
        "_maintain_terminal_reservation",
        lambda _reserved_by: {
            "status": "RENEWED",
            "heartbeat_count": 1,
            "until_after_utc": "2099-01-01T00:00:00+00:00",
        },
    )
    monkeypatch.setattr(
        exporter,
        "_copy_and_bind_raw",
        lambda *_args: {"bundle_sha256": "e" * 64, "files": [{}]},
    )
    return exporter._execute_export(
        out=out,
        session_tag="20261012T200006Z_resource_stop",
        symbols=["XAUUSD"],
        cutoff=dt.datetime(2026, 10, 12, 20, tzinfo=dt.UTC),
        timeout_seconds=60,
        reserved_by="dwx2026:123:task",
        reservation_until_utc=(
            dt.datetime.now(dt.UTC) + dt.timedelta(hours=1)
        ).isoformat(),
    )


def test_ram_hard_stop_terminates_only_owned_export_and_is_non_admissible(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    result = _resource_stop_result(
        monkeypatch,
        tmp_path,
        ram_values=[20.0, 13.5],
        disk_values=[100.0],
    )
    assert result["stop_reason"] == "physical_free_ram_below_14_gib"
    assert result["termination"]["terminated"] is True
    assert result["admissible"] is False
    assert result["error"]


def test_runtime_disk_hard_stop_terminates_owned_export(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    result = _resource_stop_result(
        monkeypatch,
        tmp_path,
        ram_values=[20.0, 20.0],
        disk_values=[100.0, 59.0],
    )
    assert result["stop_reason"] == "disk_free_below_60_gib"
    assert result["minimum_disk_free_gib"] == 59.0
    assert result["termination"]["terminated"] is True


class _Lock:
    held = False

    def __init__(self, *_args, **_kwargs) -> None:
        pass

    def __enter__(self):
        assert not _Lock.held
        _Lock.held = True
        return self

    def __exit__(self, *_args) -> None:
        assert _Lock.held
        _Lock.held = False


def _patch_apply_session(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> list[str]:
    events: list[str] = []
    task_root = tmp_path / "source"
    monkeypatch.setattr(exporter, "ARTIFACT_ROOT", task_root)
    monkeypatch.setattr(exporter, "FactoryMutationLock", _Lock)
    monkeypatch.setattr(
        exporter,
        "_maintain_terminal_reservation",
        lambda _reserved_by: {
            "status": "RENEWED",
            "heartbeat_count": 1,
            "until_after_utc": "2099-01-01T00:00:00+00:00",
        },
    )
    monkeypatch.setattr(
        exporter,
        "validate_canonical_runtime",
        lambda: {
            "head": "d" * 40,
            "wrapper": {"sha256": "a" * 64},
            "source": {"sha256": "b" * 64},
        },
    )
    monkeypatch.setattr(exporter, "validate_a2_authority", lambda: {"closure": "bound"})
    monkeypatch.setattr(
        exporter,
        "validate_mql_source",
        lambda: {"sha256": "b" * 64, "read_only": True},
    )
    monkeypatch.setattr(
        exporter,
        "_file_binding",
        lambda path: {"path": str(path), "bytes": 1, "sha256": "c" * 64},
    )
    monkeypatch.setattr(exporter, "_free_gib", lambda: 32.0)
    monkeypatch.setattr(exporter, "_disk_free_gib", lambda: 110.0)
    monkeypatch.setattr(
        exporter,
        "_task_snapshot",
        lambda: {
            "task_name": exporter.PURGE_TASK,
            "task_path": "\\",
            "state": "Ready",
            "enabled": True,
            "running": False,
            "actions": [{"execute": "powershell.exe", "arguments": "purge"}],
        },
    )

    def quiesce_purge(before):
        events.append("purge_off")
        return {"before": before, "quiesced": {"state": "Disabled"}}

    def restore_purge(before):
        events.append("purge_restore")
        return {"before": before, "after": {"enabled": True, "state": "Ready"}}

    monkeypatch.setattr(exporter, "_quiesce_purge", quiesce_purge)
    monkeypatch.setattr(exporter, "_restore_purge", restore_purge)
    monkeypatch.setattr(exporter, "_manifest_master_snapshot", lambda: {"v1": "same"})
    monkeypatch.setattr(
        exporter,
        "_assert_t1_idle",
        lambda **_kwargs: {
            "worker_pid": 101,
            "worker_created": 1.0,
            "worker_identity": {
                "pid": 101,
                "created": 1.0,
                "executable_path": "C:/Python/python.exe",
                "command_line": ["python", "terminal_worker.py"],
            },
        },
    )

    def quiesce_worker(_reserved_by, _minutes, _out):
        assert _Lock.held
        events.append("worker_off")
        return (
            {
                "before": {
                    "worker_identity": {
                        "pid": 101,
                        "created": 1.0,
                        "executable_path": "C:/Python/python.exe",
                        "command_line": ["python", "terminal_worker.py"],
                    }
                },
                "reservation": {"until_utc": "2026-10-12T22:00:00Z"},
                "stopped_pid": 101,
            },
            {"PATH": "test"},
        )

    def restore_worker_with_lock(**_kwargs):
        events.append("worker_restore")
        return {"new_pid": 202, "reservation_release": {"released": True}}

    monkeypatch.setattr(exporter, "_quiesce_worker", quiesce_worker)
    monkeypatch.setattr(
        exporter, "_restore_worker_with_lock", restore_worker_with_lock
    )
    return events


def test_apply_releases_global_lock_during_export_and_restores_everything(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    events = _patch_apply_session(monkeypatch, tmp_path)

    def execute_export(**kwargs):
        assert not _Lock.held
        events.append("export")
        # A successful export must now carry a verifiable tick-chunk journal.
        raw = _write_tick_raw(
            exporter.ARTIFACT_ROOT / kwargs["session_tag"],
            journal=[_tick_journal_row(_OPEN_CHUNK_MSC, 1, 1234, 0, "OK")],
            zero=[],
        )
        return {
            "completion": _tick_marker(status="SUCCESS", zero=0, closed=0, gap=0, retry=0),
            "raw": raw,
            "observed_peak_private_gib": 1.1,
            "minimum_physical_free_gib": 20.0,
        }

    monkeypatch.setattr(exporter, "_execute_export", execute_export)
    result = exporter.run_session(
        session_tag="20261012T200003Z_xau_calibration",
        symbols=["XAUUSD"],
        cutoff_utc="2026-10-12T20:00:00Z",
        calibration=True,
        calibration_admission_gib=17.0,
        headroom_acceptance=None,
        apply=True,
    )
    assert result["status"] == "CALIBRATION_REVIEW_REQUIRED"
    assert result["admissible"] is False
    assert result["v1_manifest_master_unchanged"] is True
    assert result["headroom_calibration"]["measured_export_headroom_gib"] == 1.25
    assert events == ["purge_off", "worker_off", "export", "worker_restore", "purge_restore"]
    assert not _Lock.held


def test_start_disk_floor_refuses_before_purge_quiesce(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    events = _patch_apply_session(monkeypatch, tmp_path)
    monkeypatch.setattr(exporter, "_disk_free_gib", lambda: 89.0)
    with pytest.raises(exporter.ExportRefused, match="disk gate failed"):
        exporter.run_session(
            session_tag="20261012T200007Z_disk_refusal",
            symbols=["XAUUSD"],
            cutoff_utc="2026-10-12T20:00:00Z",
            calibration=True,
            calibration_admission_gib=17.0,
            headroom_acceptance=None,
            apply=True,
        )
    assert events == []


def test_failed_export_still_takes_post_snapshot_and_restores_controls(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    events = _patch_apply_session(monkeypatch, tmp_path)

    def fail_export(**_kwargs):
        assert not _Lock.held
        events.append("export")
        raise exporter.ExportRefused("synthetic export failure")

    monkeypatch.setattr(exporter, "_execute_export", fail_export)
    result = exporter.run_session(
        session_tag="20261012T200004Z_xau_failure",
        symbols=["XAUUSD"],
        cutoff_utc="2026-10-12T20:00:00Z",
        calibration=True,
        calibration_admission_gib=17.0,
        headroom_acceptance=None,
        apply=True,
    )
    assert result["status"] == "FAIL"
    assert "synthetic export failure" in result["error"]
    assert result["v1_manifest_master_unchanged"] is True
    assert events[-2:] == ["worker_restore", "purge_restore"]
    assert not _Lock.held


# --- task 35eb350f probe/history-depth fix (2026-10-15) -----------------------

WINDOW_FROM_BROKER = 1759287600  # 2025-10-01 00:00Z as Darwinex broker epoch
CUTOFF_UTC = dt.datetime(2026, 10, 12, 20, tzinfo=dt.UTC)


def _cutoff_broker() -> int:
    return exporter.dukascopy_common.broker_epoch_seconds_for_utc(CUTOFF_UTC)


def _depth_row(
    symbol: str,
    phase: str,
    *,
    maxbars: int,
    server_first: int,
    series_first: int,
    bars: int,
    synced: int = 1,
    in_window: int = 0,
    status: str = "OK",
    reason: str = "NONE",
) -> list[str]:
    return [
        symbol,
        phase,
        str(maxbars),
        str(server_first),
        str(server_first),
        str(series_first),
        str(bars),
        str(synced),
        str(in_window),
        str(WINDOW_FROM_BROKER),
        str(_cutoff_broker()),
        "7",
        "1500",
        status,
        reason,
    ]


def _write_probe_raw(out: Path, rows: list[list[str]], extra: bool = False) -> dict:
    raw_root = out / "raw"
    raw_root.mkdir(parents=True)
    probe = raw_root / exporter.PROBE_CSV_NAME
    lines = [",".join(exporter.HISTORY_DEPTH_HEADER)] + [",".join(row) for row in rows]
    probe.write_text("\n".join(lines) + "\n", encoding="utf-8")
    files = [
        {
            "relative_path": probe.name,
            "bytes": probe.stat().st_size,
            "sha256": exporter.sha256_file(probe),
        }
    ]
    if extra:
        stray = raw_root / "stray.csv"
        stray.write_text("x\n", encoding="utf-8")
        files.append(
            {
                "relative_path": stray.name,
                "bytes": stray.stat().st_size,
                "sha256": exporter.sha256_file(stray),
            }
        )
    return {"root": str(raw_root), "files": files, "bundle_sha256": "e" * 64}


def _probe_marker(maxbars: int, probed: int = 1, covered: int = 1) -> str:
    return (
        f"probed={probed} covered={covered} write_failures=0 terminal=T1 "
        f"server=Darwinex-Live build=6230 terminal_maxbars={maxbars}"
    )


def test_probe_source_static_no_price_guard(tmp_path: Path) -> None:
    binding = exporter.validate_probe_source()
    assert binding["no_price_api"] is True and binding["read_only"] is True
    text = exporter.PROBE_SOURCE.read_text(encoding="utf-8-sig")
    for token in ("CopyRates", "CopyTicks", "MqlRates", "MqlTick", "SymbolInfoDouble"):
        assert token not in text
    assert "CopyTime(" in text and "TERMINAL_MAXBARS" in text
    for injected in (
        "double price=0;",
        "MqlRates rates[];",
        "MqlTick tick;",
        "int n=CopyRates(\"XAUUSD\",PERIOD_M1,0,1,r);",
        "int n=CopyTicksRange(\"XAUUSD\",t,COPY_TICKS_ALL,0,1);",
        "long v=(long)SymbolInfoDouble(\"XAUUSD\",SYMBOL_BID);",
        "string s=DoubleToString(1,2);",
        "OrderSend(r,s);",
    ):
        forged = tmp_path / "forged_probe.mq5"
        forged.write_text(
            text.replace("void OnStart()", injected + "\nvoid OnStart()"), encoding="utf-8"
        )
        with pytest.raises(exporter.ExportRefused, match="forbidden"):
            exporter.validate_probe_source(forged)


def test_export_source_warms_up_before_chunk_one_and_keeps_copyrates_fatal(
    tmp_path: Path,
) -> None:
    exporter.validate_mql_source()
    text = exporter.SOURCE.read_text(encoding="utf-8-sig")
    export_one = text[text.index("bool ExportOne(") :]
    assert export_one.index("WarmUpHistory(symbol") < export_one.index("ok=ExportBars(")
    assert '"HISTORY_DEPTH_SHORT"' in export_one
    assert "SymbolSelect(symbol,true)" in export_one
    assert "SERIES_SYNCHRONIZED" in text and "TERMINAL_MAXBARS" in text
    # The fail-closed CopyRates contract and the window guard are untouched.
    assert "if(copied<0) { ok=false; break; }" in text
    assert "InpFromBrokerEpoch!=1759287600" in text
    assert "InpWarmupSeconds<10 || InpWarmupSeconds>1800" in text
    # The probe must predict the export's warm-up: identical depth logic.
    probe_text = exporter.PROBE_SOURCE.read_text(encoding="utf-8-sig")

    def depth_block(source: str) -> str:
        block = source[source.index("void ResetDepth(") : source.index("bool WriteHistoryDepthRow(")]
        block = "\n".join(line for line in block.splitlines() if not line.strip().startswith("//"))
        return "".join(block.split())

    assert depth_block(text) == depth_block(probe_text)
    forged = tmp_path / "QM_DWX_2026_Band_A_Export.mq5"
    forged.write_text(
        text.replace("SERIES_SYNCHRONIZED", "SERIES_BARS_COUNT"), encoding="utf-8"
    )
    with pytest.raises(exporter.ExportRefused, match="SERIES_SYNCHRONIZED"):
        exporter.validate_mql_source(forged)


def test_startup_ini_maxbars_line() -> None:
    text = exporter._startup_ini_text(
        login=123,
        server="Darwinex-Live",
        script="QM\\dwx_2026_band_a\\tag\\QM_DWX_2026_Band_A_Export",
        preset_name="p.set",
        symbol="XAUUSD",
        max_bars=exporter.SESSION_MAX_BARS,
    )
    lines = text.splitlines()
    assert exporter.SESSION_MAX_BARS == 1_000_000
    assert lines[lines.index("[Charts]") + 1] == "MaxBars=1000000"
    assert lines.index("[Common]") < lines.index("[Charts]") < lines.index("[Experts]")
    assert "Enabled=0" in lines and "AllowLiveTrading=0" in lines
    plain = exporter._startup_ini_text(
        login=123,
        server="Darwinex-Live",
        script="s",
        preset_name="p.set",
        symbol="XAUUSD",
        max_bars=None,
    )
    assert "[Charts]" not in plain and "MaxBars" not in plain
    with pytest.raises(exporter.ExportRefused, match="exactly 1000000"):
        exporter._startup_ini_text(
            login=1,
            server="Darwinex-Live",
            script="s",
            preset_name="p",
            symbol="XAUUSD",
            max_bars=500_000,
        )


COMMON_INI = (
    "[Common]\r\nLogin=1\r\nServer=Darwinex-Live\r\n[Charts]\r\n"
    "ProfileLast=QMBacktest\r\nMaxBars=100000\r\nPrintColor=0\r\n"
)


def _seed_config(terminal_root: Path) -> Path:
    config = terminal_root / "Config"
    config.mkdir(parents=True, exist_ok=True)
    (config / "common.ini").write_bytes(COMMON_INI.encode("utf-8"))
    (config / "terminal.ini").write_bytes("[Window]\r\nA=1\r\n".encode("utf-16"))
    return config


def test_common_ini_restore_is_verified_and_backup_removed(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    root = tmp_path / "T1"
    config = _seed_config(root)
    monkeypatch.setattr(exporter, "TERMINAL_ROOT", root)
    monkeypatch.setattr(exporter, "_t1_mt5_processes", lambda: [])
    before, backups = exporter._snapshot_terminal_config("20261015T010000Z_t")
    assert before["files"]["common.ini"]["max_bars"] == 100000
    backup = Path(before["common_backup_path"])
    assert backup.is_file() and backup.parent == config
    # Simulate MT5 persisting the session override and rewriting terminal.ini.
    (config / "common.ini").write_bytes(
        COMMON_INI.replace("MaxBars=100000", "MaxBars=1000000").encode("utf-8")
    )
    (config / "terminal.ini").write_bytes("[Window]\r\nA=2\r\n".encode("utf-16"))
    result = exporter._restore_terminal_config(
        before, backups, tmp_path, terminal_terminated=True
    )
    assert result["verified"] is True
    common = result["files"]["common.ini"]
    assert common["changed_by_session"] is True
    assert common["observed_after_session_max_bars"] == 1000000
    assert common["action"] == "rewritten_from_snapshot"
    assert common["final_max_bars"] == 100000
    assert (
        exporter.sha256_file(config / "common.ini")
        == before["files"]["common.ini"]["sha256"]
    )
    assert result["files"]["terminal.ini"]["action"] == "observed_only"
    assert result["files"]["terminal.ini"]["changed_by_session"] is True
    assert not backup.exists()
    assert not (tmp_path / "T1_CONFIG_NOT_RESTORED.json").exists()
    # Receipts carry no common.ini content (Login/Server stay in T1\Config).
    assert "Login" not in json.dumps({"before": before, "restore": result})


def test_common_ini_restore_failure_fails_closed_with_receipt(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    root = tmp_path / "T1"
    config = _seed_config(root)
    monkeypatch.setattr(exporter, "TERMINAL_ROOT", root)
    monkeypatch.setattr(exporter, "_t1_mt5_processes", lambda: [])
    before, backups = exporter._snapshot_terminal_config("20261015T010001Z_t")
    (config / "common.ini").write_bytes(b"[Charts]\r\nMaxBars=1000000\r\n")
    monkeypatch.setattr(exporter, "_atomic_write_bytes", lambda *_args: None)
    with pytest.raises(exporter.ExportRefused, match="not verified"):
        exporter._restore_terminal_config(
            before, backups, tmp_path, terminal_terminated=True
        )
    receipt = json.loads(
        (tmp_path / "T1_CONFIG_NOT_RESTORED.json").read_text(encoding="utf-8")
    )
    assert receipt["status"] == "T1_CONFIG_NOT_RESTORED"
    assert receipt["expected_max_bars"] == 100000
    assert Path(receipt["common_backup_path"]).is_file()

    # A terminal that is not confirmed gone defers the restore (fail closed).
    other = tmp_path / "deferred"
    other.mkdir()
    with pytest.raises(exporter.ExportRefused, match="deferred"):
        exporter._restore_terminal_config(
            before, backups, other, terminal_terminated=False
        )
    assert (other / "T1_CONFIG_NOT_RESTORED.json").is_file()


def test_terminal_ini_maxbars_key_introduced_is_restored(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    root = tmp_path / "T1"
    config = _seed_config(root)
    monkeypatch.setattr(exporter, "TERMINAL_ROOT", root)
    monkeypatch.setattr(exporter, "_t1_mt5_processes", lambda: [])
    before, backups = exporter._snapshot_terminal_config("20261015T010002Z_t")
    (config / "terminal.ini").write_bytes(
        "[Window]\r\nA=1\r\n[Charts]\r\nMaxBars=1000000\r\n".encode("utf-16")
    )
    result = exporter._restore_terminal_config(
        before, backups, tmp_path, terminal_terminated=True
    )
    assert (
        result["files"]["terminal.ini"]["action"]
        == "restored_max_bars_key_introduced"
    )
    assert (
        exporter.sha256_file(config / "terminal.ini")
        == before["files"]["terminal.ini"]["sha256"]
    )


def test_execute_export_writes_maxbars_startup_and_restores_common_ini(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    captured: dict[str, str] = {}

    def popen_hook(args, terminal_root: Path) -> None:
        config_arg = next(
            str(value) for value in args if str(value).startswith("/config:")
        )
        captured["startup"] = Path(config_arg.split(":", 1)[1]).read_text(
            encoding="utf-8"
        )
        # MT5 persisting the start-config override into the terminal config.
        common = terminal_root / "Config" / "common.ini"
        common.write_bytes(
            COMMON_INI.replace("MaxBars=100000", "MaxBars=1000000").encode("utf-8")
        )
        marker = (
            terminal_root
            / "MQL5/Files"
            / "QM_DWX_2026_BAND_A_COMPLETE_20261012T200006Z_resource_stop.txt"
        )
        marker.parent.mkdir(parents=True, exist_ok=True)
        marker.write_text(
            "successes=1 failures=0 terminal=T1 server=Darwinex-Live build=6230 attempted=1\n",
            encoding="utf-8",
        )

    result = _resource_stop_result(
        monkeypatch,
        tmp_path,
        ram_values=[20.0] * 50,
        disk_values=[100.0] * 50,
        popen_hook=popen_hook,
        setup_terminal=_seed_config,
    )
    assert "[Charts]\nMaxBars=1000000\n" in captured["startup"]
    assert result["session_max_bars"] == 1_000_000
    assert result["startup_ini_removed"] is True
    assert result["error"] is None, result["error"]
    restore = result["terminal_config_restore"]
    assert restore["verified"] is True
    assert restore["files"]["common.ini"]["observed_after_session_max_bars"] == 1_000_000
    assert restore["files"]["common.ini"]["final_max_bars"] == 100_000
    common = tmp_path / "T1" / "Config" / "common.ini"
    assert common.read_bytes() == COMMON_INI.encode("utf-8")
    preset = next((tmp_path / "T1" / "MQL5/Presets").glob("*.set")).read_text(
        encoding="utf-8"
    )
    assert f"InpWarmupSeconds={exporter.WARMUP_SECONDS}" in preset


def test_config_snapshot_failure_still_removes_startup_ini(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    launched: list[object] = []

    def snapshot_fails(_session_tag: str):
        raise exporter.ExportRefused("synthetic snapshot failure")

    monkeypatch.setattr(exporter, "_snapshot_terminal_config", snapshot_fails)
    result = _resource_stop_result(
        monkeypatch,
        tmp_path,
        ram_values=[20.0] * 10,
        disk_values=[100.0] * 10,
        popen_hook=lambda args, _root: launched.append(args),
    )
    assert launched == []  # the terminal is never started without a snapshot
    assert not (tmp_path / "out" / "startup.ini").exists()
    assert result["startup_ini_removed"] is True
    assert "synthetic snapshot failure" in result["error"]
    assert result["terminal_config_restore"] is None


def test_history_depth_short_completion_sets_explicit_status(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    events = _patch_apply_session(monkeypatch, tmp_path)
    header = (
        "symbol,started_monotonic_ms,completed_monotonic_ms,bar_count,tick_count,"
        "zero_bar_chunks,zero_tick_chunks,retry_bar_chunks,retry_tick_chunks,"
        "output_bytes,capability,status,hard_ceiling_minutes,history_status,"
        "history_reason,terminal_maxbars,server_firstdate_broker_epoch,"
        "terminal_firstdate_broker_epoch,series_firstdate_broker_epoch,"
        "series_synchronized,bars_in_window"
    )
    series_first = 1781568000  # a mid-2026 broker epoch (timestamp only)
    completion = "\n".join(
        [
            "successes=0 failures=1 terminal=T1 server=Darwinex-Live build=6230 attempted=1",
            header,
            "XAUUSD,1,2,0,0,0,0,0,0,900,BARS_ONLY,HISTORY_DEPTH_SHORT,60,"
            "HISTORY_DEPTH_SHORT,MAXBARS_REACHED,100000,1500000000,1700000000,"
            f"{series_first},1,0",
        ]
    )
    calls: dict = {}

    def execute_export(**kwargs):
        calls.update(kwargs)
        events.append("export")
        return {"completion": completion, "observed_peak_private_gib": 1.0}

    monkeypatch.setattr(exporter, "_execute_export", execute_export)
    result = exporter.run_session(
        session_tag="20261015T010003Z_xau_calibration",
        symbols=["XAUUSD"],
        cutoff_utc="2026-10-12T20:00:00Z",
        calibration=True,
        calibration_admission_gib=17.0,
        headroom_acceptance=None,
        apply=True,
    )
    assert calls["mode"] == "export" and calls["max_bars"] == 1_000_000
    assert result["status"] == "HISTORY_DEPTH_SHORT"
    assert "HISTORY_DEPTH_SHORT" in result["error"]
    depth = result["history_depth"][0]
    assert depth["symbol"] == "XAUUSD"
    assert depth["history_reason"] == "MAXBARS_REACHED"
    assert depth["terminal_maxbars"] == 100000
    assert depth["series_firstdate_broker_epoch"] == series_first
    assert depth["first_available_broker_wall"].endswith(" broker")
    assert "headroom_calibration" not in result
    assert events[-2:] == ["worker_restore", "purge_restore"]


def _probe_session(monkeypatch, tmp_path, rows, *, marker_maxbars, max_bars):
    events = _patch_apply_session(monkeypatch, tmp_path)
    monkeypatch.setattr(
        exporter,
        "validate_probe_source",
        lambda *_a: {"sha256": "f" * 64, "no_price_api": True},
    )
    calls: dict = {}

    def execute_export(**kwargs):
        calls.update(kwargs)
        events.append("export")
        out = exporter.ARTIFACT_ROOT / kwargs["session_tag"]
        raw = _write_probe_raw(out, rows)
        return {
            "completion": _probe_marker(marker_maxbars),
            "raw": raw,
            "observed_peak_private_gib": 0.5,
        }

    monkeypatch.setattr(exporter, "_execute_export", execute_export)
    result = exporter.run_session(
        session_tag="20261015T010004Z_xau_probe_b",
        symbols=["XAUUSD"],
        cutoff_utc="2026-10-12T20:00:00Z",
        calibration=False,
        calibration_admission_gib=None,
        headroom_acceptance=None,
        apply=True,
        probe_history_depth=True,
        probe_max_bars=max_bars,
    )
    return result, calls, events


def test_probe_receipt_schema_variant_b_confirms_m1(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    rows = [
        _depth_row(
            "XAUUSD", "BEFORE_WARMUP", maxbars=1_000_000, server_first=1104537600,
            series_first=1781568000, bars=110_000, in_window=110_000,
            status="BEFORE_WARMUP",
        ),
        _depth_row(
            "XAUUSD", "AFTER_WARMUP", maxbars=1_000_000, server_first=1104537600,
            series_first=1756684800, bars=420_000, in_window=380_000,
        ),
    ]
    result, calls, events = _probe_session(
        monkeypatch, tmp_path, rows, marker_maxbars=1_000_000, max_bars=1_000_000
    )
    assert calls["mode"] == "probe" and calls["max_bars"] == 1_000_000
    assert result["status"] == "PROBE_REVIEW_REQUIRED"
    assert result["mode"] == "probe_history_depth"
    assert result["admissible"] is False
    assert result["reservation_minutes"] == exporter.PROBE_RESERVATION_MINUTES
    assert events == [
        "purge_off", "worker_off", "export", "worker_restore", "purge_restore"
    ]
    receipt = json.loads(
        Path(result["history_depth_probe_path"]).read_text(encoding="utf-8")
    )
    assert receipt["schema"] == exporter.PROBE_SCHEMA
    assert receipt["variant"] == "B_RAISED_MAXBARS"
    assert receipt["maxbars_override_honoured"] is True
    assert receipt["terminal_maxbars_readback"] == [1_000_000]
    assert receipt["window_start_broker_epoch"] == WINDOW_FROM_BROKER
    assert receipt["cutoff_broker_epoch_exclusive"] == _cutoff_broker()
    assert receipt["rerun_gate"] == "PROCEED_M1_CONFIRMED"
    xau = receipt["per_symbol"]["XAUUSD"]
    assert xau["classification"] == "DEPTH_OK_WITH_RAISED_MAXBARS"
    assert set(xau) == {
        "before_warmup",
        "after_warmup",
        "after_warmup_dates_broker_wall",
        "classification",
    }
    assert set(xau["after_warmup"]) == set(exporter.HISTORY_DEPTH_HEADER)
    assert receipt["no_price_output"] is True
    unsigned = dict(receipt)
    declared = unsigned.pop("receipt_sha256")
    assert exporter._canonical_sha256(unsigned) == declared


def test_probe_variant_a_maxbars_limit_and_m2_gate(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    rows = [
        _depth_row(
            "XAUUSD", "BEFORE_WARMUP", maxbars=100_000, server_first=1104537600,
            series_first=1781568000, bars=100_000, in_window=100_000,
            status="BEFORE_WARMUP",
        ),
        _depth_row(
            "XAUUSD", "AFTER_WARMUP", maxbars=100_000, server_first=1104537600,
            series_first=1781568000, bars=100_000, in_window=100_000,
            status="HISTORY_DEPTH_SHORT", reason="MAXBARS_REACHED",
        ),
    ]
    result, _calls, _events = _probe_session(
        monkeypatch, tmp_path, rows, marker_maxbars=100_000, max_bars=None
    )
    receipt = result["history_depth_probe"]
    assert receipt["variant"] == "A_CURRENT_MAXBARS"
    assert receipt["maxbars_override_honoured"] is None
    assert receipt["per_symbol"]["XAUUSD"]["classification"] == "M1_LOCAL_MAXBARS_LIMIT"
    assert receipt["rerun_gate"] == "RUN_VARIANT_B_RAISED_MAXBARS"

    after = {
        key: (value if key in exporter.HISTORY_DEPTH_TEXT_FIELDS else int(value))
        for key, value in zip(exporter.HISTORY_DEPTH_HEADER, rows[1])
    }
    after["server_firstdate_broker_epoch"] = 1767225600  # server starts in 2026
    assert exporter._classify_probe_symbol(
        after, window_from_broker=WINDOW_FROM_BROKER, requested_max_bars=1_000_000
    ) == "M2_SERVER_DEPTH_SHORT"
    # Variant B that reads back the old MaxBars is not M1-confirmed.
    ok_after = dict(after)
    ok_after.update(
        server_firstdate_broker_epoch=1104537600,
        series_firstdate_broker_epoch=1756684800,
        status="OK",
        reason="NONE",
    )
    assert exporter._classify_probe_symbol(
        ok_after, window_from_broker=WINDOW_FROM_BROKER, requested_max_bars=1_000_000
    ) == "DEPTH_OK_AT_CURRENT_MAXBARS"


def test_probe_runtime_no_price_output_guard(tmp_path: Path) -> None:
    good = _depth_row(
        "XAUUSD", "BEFORE_WARMUP", maxbars=100_000, server_first=1,
        series_first=2, bars=3, status="BEFORE_WARMUP",
    )
    after = _depth_row(
        "XAUUSD", "AFTER_WARMUP", maxbars=100_000, server_first=1, series_first=2, bars=3
    )
    priced = list(good)
    priced[5] = "2345.67"  # a price-shaped cell must refuse the whole output
    raw = _write_probe_raw(tmp_path / "priced", [priced, after])
    with pytest.raises(exporter.ExportRefused, match="no-price guard"):
        exporter._parse_history_depth_csv(
            Path(raw["root"]) / exporter.PROBE_CSV_NAME,
            symbols=["XAUUSD"],
            window_from_broker=WINDOW_FROM_BROKER,
            window_to_broker=_cutoff_broker(),
        )
    extra_out = tmp_path / "extra"
    raw_extra = _write_probe_raw(extra_out, [good, after], extra=True)
    with pytest.raises(exporter.ExportRefused, match="exactly probe.csv"):
        exporter._build_probe_receipt(
            out=extra_out,
            session_tag="20261015T010005Z_p",
            symbols=["XAUUSD"],
            cutoff=CUTOFF_UTC,
            export={"raw": raw_extra, "completion": _probe_marker(100_000)},
            requested_max_bars=None,
        )
    marker_out = tmp_path / "marker"
    raw_ok = _write_probe_raw(marker_out, [good, after])
    with pytest.raises(exporter.ExportRefused, match="did not authenticate"):
        exporter._build_probe_receipt(
            out=marker_out,
            session_tag="20261015T010006Z_p",
            symbols=["XAUUSD"],
            cutoff=CUTOFF_UTC,
            export={
                "raw": raw_ok,
                "completion": _probe_marker(100_000) + " close=2345.67",
            },
            requested_max_bars=None,
        )


def test_probe_plan_only_and_argument_exclusivity() -> None:
    plan = exporter.run_session(
        session_tag="20261015T010007Z_xau_probe_a",
        symbols=["XAUUSD"],
        cutoff_utc="2026-10-12T20:00:00Z",
        calibration=False,
        calibration_admission_gib=None,
        headroom_acceptance=None,
        apply=False,
        probe_history_depth=True,
    )
    assert plan["status"] == "PLAN_ONLY"
    assert plan["probe_variant"] == "A_CURRENT_MAXBARS"
    assert plan["session_max_bars"] is None
    assert plan["reservation_minutes"] == 45
    assert plan["export_timeout_seconds"] == 30 * 60
    # The probe timeout always leaves the 12-minute cleanup + 1-minute guard.
    assert (
        plan["reservation_minutes"] * 60 - plan["export_timeout_seconds"]
        >= exporter.RESERVATION_CLEANUP_MARGIN_SECONDS
        + exporter.RESERVATION_DEADLINE_GUARD_SECONDS
    )
    with pytest.raises(exporter.ExportRefused, match="excludes"):
        exporter.run_session(
            session_tag="20261015T010008Z_xau_probe_bad",
            symbols=["XAUUSD"],
            cutoff_utc="2026-10-12T20:00:00Z",
            calibration=True,
            calibration_admission_gib=17.0,
            headroom_acceptance=None,
            apply=False,
            probe_history_depth=True,
        )
    with pytest.raises(exporter.ExportRefused, match="accepts only"):
        exporter.run_session(
            session_tag="20261015T010009Z_xau_probe_bad",
            symbols=["XAUUSD"],
            cutoff_utc="2026-10-12T20:00:00Z",
            calibration=False,
            calibration_admission_gib=None,
            headroom_acceptance=None,
            apply=False,
            probe_history_depth=True,
            probe_max_bars=500_000,
        )
    with pytest.raises(exporter.ExportRefused, match="only with --probe-history-depth"):
        exporter.run_session(
            session_tag="20261015T010010Z_xau_cal",
            symbols=["XAUUSD"],
            cutoff_utc="2026-10-12T20:00:00Z",
            calibration=True,
            calibration_admission_gib=17.0,
            headroom_acceptance=None,
            apply=False,
            probe_max_bars=1_000_000,
        )
    assert exporter.main(
        [
            "--session-tag", "20261015T010011Z_xau_probe_b",
            "--symbols", "XAUUSD",
            "--cutoff-utc", "2026-10-12T20:00:00Z",
            "--probe-history-depth",
            "--probe-max-bars", "1000000",
        ]
    ) == 0


# --- Tick-leg empty-chunk classification (closed session vs data gap) -------
#
# Chunk bounds are broker (trade-server) epoch milliseconds, the timescale
# CopyTicksRange actually uses.  Timestamps and counts only; no prices.
_SIX_HOURS_MSC = 6 * 3600 * 1000
# Wed 2025-10-08 06:00 broker: an ordinary trading window.
_OPEN_CHUNK_MSC = 1759903200 * 1000
# Sat 2025-10-04 00:00 broker: inside the weekend close.
_CLOSED_CHUNK_MSC = 1759536000 * 1000

_TICK_MARKER_HEADER = (
    "symbol,started_monotonic_ms,completed_monotonic_ms,bar_count,tick_count,"
    "zero_bar_chunks,zero_tick_chunks,retry_bar_chunks,retry_tick_chunks,"
    "output_bytes,capability,status,hard_ceiling_minutes,history_status,"
    "history_reason,terminal_maxbars,server_firstdate_broker_epoch,"
    "terminal_firstdate_broker_epoch,series_firstdate_broker_epoch,"
    "series_synchronized,bars_in_window,zero_tick_closed_session_chunks,"
    "zero_tick_gap_chunks"
)


def _tick_marker(*, status: str, zero: int, closed: int, gap: int, retry: int) -> str:
    ok = status == "SUCCESS"
    return "\n".join(
        [
            f"successes={1 if ok else 0} failures={0 if ok else 1} terminal=T1 "
            "server=Darwinex-Live build=6230 attempted=1",
            _TICK_MARKER_HEADER,
            f"XAUUSD,1,2,365755,1234,0,{zero},0,{retry},900,TICKS,{status},60,"
            "OK,NONE,1000000,893203200,1759190400,1759194060,1,365755,"
            f"{closed},{gap}",
        ]
    )


def _tick_journal_row(
    start_msc: int, attempts: int, copied: int, error: int, status: str
) -> list[object]:
    return [
        "XAUUSD", "TICKS", start_msc, start_msc + _SIX_HOURS_MSC,
        attempts, copied, error, status,
    ]


def _tick_zero_row(
    start_msc: int, bars: int, attempts: int, error: int, classification: str
) -> list[object]:
    return [
        "XAUUSD", start_msc, start_msc + _SIX_HOURS_MSC, bars,
        attempts, 0, error, classification,
    ]


def _write_tick_raw(out: Path, *, journal: list, zero: list) -> dict:
    raw_root = out / "raw"
    raw_root.mkdir(parents=True)
    journal_path = raw_root / "XAUUSD.DWX.chunks.csv"
    zero_path = raw_root / "XAUUSD.DWX.tick_zero_chunks.csv"
    lines = [",".join(exporter.CHUNK_JOURNAL_HEADER)]
    lines.append("XAUUSD,BARS,1759287600,1759892400,1,9000,0,OK")
    lines += [",".join(str(value) for value in row) for row in journal]
    journal_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    zero_lines = [",".join(exporter.TICK_ZERO_HEADER)]
    zero_lines += [",".join(str(value) for value in row) for row in zero]
    zero_path.write_text("\n".join(zero_lines) + "\n", encoding="utf-8")
    files = [
        {
            "relative_path": path.name,
            "bytes": path.stat().st_size,
            "sha256": exporter.sha256_file(path),
        }
        for path in sorted((journal_path, zero_path))
    ]
    return {
        "root": str(raw_root.resolve()),
        "files": files,
        "bundle_sha256": exporter._canonical_sha256(files),
    }


def _tick_session(monkeypatch, tmp_path, *, journal, zero, marker, tag):
    events = _patch_apply_session(monkeypatch, tmp_path)

    def execute_export(**kwargs):
        events.append("export")
        raw = _write_tick_raw(
            exporter.ARTIFACT_ROOT / kwargs["session_tag"], journal=journal, zero=zero
        )
        return {"completion": marker, "raw": raw, "observed_peak_private_gib": 0.3}

    monkeypatch.setattr(exporter, "_execute_export", execute_export)
    result = exporter.run_session(
        session_tag=tag,
        symbols=["XAUUSD"],
        cutoff_utc="2026-10-14T00:00:00Z",
        calibration=True,
        calibration_admission_gib=17.0,
        headroom_acceptance=None,
        apply=True,
    )
    return result, events


def _export_ticks_retry_loop(text: str) -> str:
    body = text[text.index("bool ExportTicks(") : text.index("bool ExportOne(")]
    return body[body.index("for(int attempt=1;") : body.index("Sleep(500+attempt*250);")]


def test_closed_session_empty_tick_chunk_is_accepted_without_retry(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    # Static half: the closed-session exit sits inside the retry loop, before
    # the full-backoff exit and before the Sleep, so attempt 1 ends it.
    text = exporter.SOURCE.read_text(encoding="utf-8-sig")
    loop = _export_ticks_retry_loop(text)
    closed_exit = "if(copied==0 && !RetryableHistoryError(last_error) && closed_session) break;"
    backoff_exit = (
        "if(copied==0 && !RetryableHistoryError(last_error) && attempt==InpCopyAttempts) break;"
    )
    assert loop.index(closed_exit) < loop.index(backoff_exit)
    body = text[text.index("bool ExportTicks(") : text.index("bool ExportOne(")]
    # closed_session comes from the exported bars, fixed before the first copy.
    assert body.index("ExportedBarsInWindow(bar_times,window_from_s,window_to_s)") < body.index(
        "for(int attempt=1;"
    )
    assert "const bool closed_session=(bars_in_window==0);" in body
    assert "window_from_s>=InpFromBrokerEpoch" in body and "window_to_s<=InpToBrokerEpoch" in body
    export_one = text[text.index("bool ExportOne(") :]
    assert export_one.index("ok=ExportBars(") < export_one.index("ok=ExportTicks(")

    # Runtime half: the wrapper accepts a proven closed chunk and records it.
    result, events = _tick_session(
        monkeypatch,
        tmp_path,
        journal=[
            _tick_journal_row(_CLOSED_CHUNK_MSC, 1, 0, 0, "ZERO_CLOSED"),
            _tick_journal_row(_OPEN_CHUNK_MSC, 1, 1234, 0, "OK"),
        ],
        zero=[_tick_zero_row(_CLOSED_CHUNK_MSC, 0, 1, 0, "CLOSED_SESSION")],
        marker=_tick_marker(status="SUCCESS", zero=1, closed=1, gap=0, retry=0),
        tag="20261015T040001Z_xau_calibration",
    )
    assert result["status"] == "CALIBRATION_REVIEW_REQUIRED", result.get("error")
    counters = result["tick_chunk_verification"]["symbols"]["XAUUSD"]
    assert counters["zero_tick_chunks"] == 1
    assert counters["zero_tick_closed_session_chunks"] == 1
    assert counters["zero_tick_gap_chunks"] == 0
    assert counters["retry_tick_chunks"] == 0
    assert counters["gaps"] == []
    assert events[-2:] == ["worker_restore", "purge_restore"]


@pytest.mark.parametrize(
    ("journal_status", "attempts", "bars", "classification", "error"),
    [
        # A closed claim that needed retries is not "accepted immediately".
        ("ZERO_CLOSED", 3, 0, "CLOSED_SESSION", 0),
        # A closed claim over a window that has exported bars is false.
        ("ZERO_CLOSED", 1, 17, "CLOSED_SESSION", 0),
        # A closed claim with a still-retryable error is not clean.
        ("ZERO_CLOSED", 1, 0, "CLOSED_SESSION", 4401),
        # The legacy accept-after-30-tries status is no longer valid.
        ("ZERO", 30, 0, "CLOSED_SESSION", 0),
    ],
)
def test_unproven_closed_session_claims_fail_closed(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    journal_status: str,
    attempts: int,
    bars: int,
    classification: str,
    error: int,
) -> None:
    result, events = _tick_session(
        monkeypatch,
        tmp_path,
        journal=[_tick_journal_row(_CLOSED_CHUNK_MSC, attempts, 0, error, journal_status)],
        zero=[_tick_zero_row(_CLOSED_CHUNK_MSC, bars, attempts, error, classification)],
        marker=_tick_marker(
            status="SUCCESS", zero=1, closed=1, gap=0, retry=int(attempts > 1)
        ),
        tag="20261015T040002Z_xau_calibration",
    )
    assert result["status"] == "FAIL"
    assert "tick chunk verification" in result["error"]
    assert "headroom_calibration" not in result
    assert events[-2:] == ["worker_restore", "purge_restore"]


def test_open_market_empty_tick_chunk_retries_and_fails_closed(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    # Static half: an empty chunk that is not proven closed keeps the full
    # backoff and the symbol ends as TICK_GAP without finalising ticks.csv.
    text = exporter.SOURCE.read_text(encoding="utf-8-sig")
    body = text[text.index("bool ExportTicks(") : text.index("bool ExportOne(")]
    assert 'else if(bars_in_window<0) zero_class="UNPROVEN_WINDOW";' in body
    assert 'else zero_class="OPEN_MARKET_GAP";' in body
    assert "else { gap_chunks++; tick_gap=true; }" in body
    assert "if(!ok || tick_gap) return false;" in body
    assert '(tick_gap ? "TICK_GAP" : "FAIL")' in text
    assert exporter.EXPORT_COPY_ATTEMPTS == 30

    gap_start = _OPEN_CHUNK_MSC + _SIX_HOURS_MSC
    result, events = _tick_session(
        monkeypatch,
        tmp_path,
        journal=[
            _tick_journal_row(_OPEN_CHUNK_MSC, 1, 1234, 0, "OK"),
            _tick_journal_row(gap_start, 30, 0, 0, "ZERO_GAP"),
            _tick_journal_row(_CLOSED_CHUNK_MSC, 1, 0, 0, "ZERO_CLOSED"),
        ],
        zero=[
            _tick_zero_row(gap_start, 312, 30, 0, "OPEN_MARKET_GAP"),
            _tick_zero_row(_CLOSED_CHUNK_MSC, 0, 1, 0, "CLOSED_SESSION"),
        ],
        marker=_tick_marker(status="TICK_GAP", zero=2, closed=1, gap=1, retry=1),
        tag="20261015T040003Z_xau_calibration",
    )
    assert result["status"] == "TICK_GAP"
    assert result["admissible"] is False
    assert "headroom_calibration" not in result
    assert "TICK_GAP" in result["error"]
    (gap,) = result["tick_gaps"]
    assert gap["symbol"] == "XAUUSD"
    assert gap["classification"] == "OPEN_MARKET_GAP"
    assert gap["attempts"] == 30 and gap["bars_in_window"] == 312
    assert gap["from_broker_wall"] == "2025-10-08T12:00:00 broker"
    counters = result["tick_chunk_verification"]["symbols"]["XAUUSD"]
    assert counters["zero_tick_closed_session_chunks"] == 1
    assert counters["zero_tick_gap_chunks"] == 1
    assert events[-2:] == ["worker_restore", "purge_restore"]


def test_open_market_gap_without_full_backoff_is_refused(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    gap_start = _OPEN_CHUNK_MSC
    result, _events = _tick_session(
        monkeypatch,
        tmp_path,
        journal=[_tick_journal_row(gap_start, 1, 0, 0, "ZERO_GAP")],
        zero=[_tick_zero_row(gap_start, 312, 1, 0, "OPEN_MARKET_GAP")],
        marker=_tick_marker(status="TICK_GAP", zero=1, closed=0, gap=1, retry=0),
        tag="20261015T040004Z_xau_calibration",
    )
    assert result["status"] == "FAIL"
    assert "gap row inconsistent" in result["error"]


def test_negative_copy_still_retries_and_non_retryable_stays_fatal(
    tmp_path: Path,
) -> None:
    text = exporter.SOURCE.read_text(encoding="utf-8-sig")
    loop = _export_ticks_retry_loop(text)
    # -1 with a retryable history error (4401/4403) matches no break line, so
    # it falls through to the backoff Sleep; -1 with any other error is fatal.
    breaks = [line.strip() for line in loop.splitlines() if line.strip().endswith("break;")]
    assert breaks == [
        "if(copied>0 && !RetryableHistoryError(last_error)) break;",
        "if(copied==0 && !RetryableHistoryError(last_error) && closed_session) break;",
        "if(copied==0 && !RetryableHistoryError(last_error) && attempt==InpCopyAttempts) break;",
        "if(copied<0 && !RetryableHistoryError(last_error)) break;",
    ]
    assert "return error==4401 || error==4403;" in text
    body = text[text.index("bool ExportTicks(") : text.index("bool ExportOne(")]
    assert "if(copied<0) { ok=false; break; }" in body
    # The bars leg keeps its own unchanged fatal contract.
    bars = text[text.index("bool ExportBars(") : text.index("bool ExportTicks(")]
    assert "if(copied<0 && !RetryableHistoryError(last_error)) break;" in bars
    assert "if(copied<0) { ok=false; break; }" in bars
    # Removing the closed-session exit is caught by the static source gate.
    forged = tmp_path / "QM_DWX_2026_Band_A_Export.mq5"
    forged.write_text(
        text.replace(
            "if(copied==0 && !RetryableHistoryError(last_error) && closed_session) break;", ""
        ),
        encoding="utf-8",
    )
    with pytest.raises(exporter.ExportRefused, match="closed_session"):
        exporter.validate_mql_source(forged)


def test_tick_counters_are_recorded_and_must_match_the_journal(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    text = exporter.SOURCE.read_text(encoding="utf-8-sig")
    assert "zero_tick_closed_session_chunks,zero_tick_gap_chunks" in text
    assert "results[index].zero_tick_closed_chunks,results[index].zero_tick_gap_chunks" in text
    assert '"symbol","from_msc","to_msc_exclusive","bars_in_window"' in text
    # The marker claims two closed chunks but the journal holds one.
    result, _events = _tick_session(
        monkeypatch,
        tmp_path,
        journal=[_tick_journal_row(_CLOSED_CHUNK_MSC, 1, 0, 0, "ZERO_CLOSED")],
        zero=[_tick_zero_row(_CLOSED_CHUNK_MSC, 0, 1, 0, "CLOSED_SESSION")],
        marker=_tick_marker(status="SUCCESS", zero=2, closed=2, gap=0, retry=0),
        tag="20261015T040005Z_xau_calibration",
    )
    assert result["status"] == "FAIL"
    assert "marker counters differ" in result["error"]
    # A marker from the pre-fix exporter (no new counter columns) is refused.
    old_marker = _tick_marker(status="SUCCESS", zero=1, closed=1, gap=0, retry=0)
    old_marker = old_marker.replace(
        ",zero_tick_closed_session_chunks,zero_tick_gap_chunks", ""
    ).rsplit(",", 2)[0]
    result, _events = _tick_session(
        monkeypatch,
        tmp_path / "old",
        journal=[_tick_journal_row(_CLOSED_CHUNK_MSC, 1, 0, 0, "ZERO_CLOSED")],
        zero=[_tick_zero_row(_CLOSED_CHUNK_MSC, 0, 1, 0, "CLOSED_SESSION")],
        marker=old_marker,
        tag="20261015T040006Z_xau_calibration",
    )
    assert result["status"] == "FAIL"
    assert "lacks zero_tick_closed_session_chunks" in result["error"]
