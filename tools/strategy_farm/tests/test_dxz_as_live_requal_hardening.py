from __future__ import annotations

import json
import os
import time
from pathlib import Path

import pytest

from tools.strategy_farm import dxz_as_live_requal as subject


def _trade(
    *,
    entry: int = 1_700_000_000,
    close: int = 1_700_003_600,
    symbol: str = "EURUSD.DWX",
    net: float = 10.0,
) -> dict:
    return {
        "event": "TRADE_CLOSED",
        "entry_time": entry,
        "time": close,
        "symbol": symbol,
        "net": net,
    }


def _write_stream(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "".join(json.dumps(row, sort_keys=True) + "\n" for row in rows),
        encoding="utf-8",
    )


def _job(
    tmp_path: Path,
    *,
    ordinal: int = 1,
    ea_id: int = 1,
    symbol: str = "EURUSD.DWX",
    trades: int | None = 1,
    reference: Path | None = None,
) -> subject.Job:
    ex5 = tmp_path / f"QM5_{ea_id}_test.ex5"
    preset = tmp_path / f"QM5_{ea_id}_{symbol}.set"
    ex5.write_bytes(b"ex5")
    preset.write_text(
        "; environment: live\nRISK_FIXED=0\nRISK_PERCENT=0.1\nPORTFOLIO_WEIGHT=1\n",
        encoding="utf-8",
    )
    return subject.Job(
        ordinal=ordinal,
        ea_id=ea_id,
        symbol=symbol,
        ea_label=f"QM5_{ea_id}_test",
        timeframe="H1",
        live_ex5=ex5,
        live_preset=preset,
        manifest_trades=trades,
        reference_stream=reference,
        set_file_expectation={
            "ENV": "live",
            "RISK_FIXED": 0,
            "RISK_PERCENT": 0.1,
            "PORTFOLIO_WEIGHT": 1,
        },
        manifest_risk_percent=0.1,
    )


def _snapshot(tmp_path: Path, job: subject.Job) -> tuple[Path, str]:
    root = tmp_path / "snapshot"
    streams = root / "streams"
    stream = streams / f"{job.ea_id}_{job.symbol.replace('.', '_')}.jsonl"
    _write_stream(stream, [_trade(symbol=job.symbol)])
    source_manifest_sha = "a" * 64
    payload = {
        "schema": "qm.dxz23.reference_stream_freeze.v1",
        "status": "PASS",
        "source_manifest": {"sha256": source_manifest_sha},
        "sleeves": [
            {
                "key": job.key,
                "selected": {
                    "frozen_relative_path": f"streams/{stream.name}",
                    "frozen_sha256": subject.sha256_file(stream),
                },
            }
        ],
    }
    manifest = root / "reference_stream_manifest.json"
    manifest.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    seal = root / "seal.sha256"
    seal.write_text(
        f"{subject.sha256_file(manifest)}  reference_stream_manifest.json\n"
        f"{subject.sha256_file(stream)}  streams/{stream.name}\n",
        encoding="ascii",
    )
    return streams, source_manifest_sha


def test_strict_stream_parser_accepts_payload_rows_and_rejects_bad_evidence(
    tmp_path: Path,
) -> None:
    stream = tmp_path / "mixed.jsonl"
    valid = _trade()
    payload = {"event": "TRADE_CLOSED", "payload": _trade(close=1_700_007_200)}
    stream.write_text(
        json.dumps(valid)
        + "\n"
        + json.dumps(payload)
        + "\n{broken\n"
        + json.dumps({**_trade(), "event": "ORDER_OPENED"})
        + "\n"
        + json.dumps({"event": "TRADE_CLOSED", "time": 1_700_000_000})
        + "\n",
        encoding="utf-8",
    )

    rows, errors = subject.load_trade_rows_strict(stream)

    assert len(rows) == 2
    assert rows[0]["symbol"] == "EURUSD.DWX"
    assert any("invalid JSON" in item for item in errors)
    assert any("unsupported event" in item for item in errors)
    assert any("missing/invalid entry_time,symbol" in item for item in errors)
    assert "STREAM_EMPTY" not in errors


def test_strict_stream_parser_fails_closed_for_missing_or_empty_stream(tmp_path: Path) -> None:
    assert subject.load_trade_rows_strict(None) == ([], ["STREAM_MISSING"])
    assert subject.load_trade_rows_strict(tmp_path / "missing.jsonl") == (
        [],
        ["STREAM_MISSING"],
    )
    empty = tmp_path / "empty.jsonl"
    empty.write_text("\n", encoding="utf-8")
    assert subject.load_trade_rows_strict(empty) == ([], ["STREAM_EMPTY"])


def test_signal_fingerprint_binds_order_entry_close_symbol_and_outcome_sign() -> None:
    base = [_trade(net=10), _trade(entry=2_000, close=3_000, net=-5)]
    same_signs_different_money = [
        _trade(net=1_000),
        _trade(entry=2_000, close=3_000, net=-0.01),
    ]
    reversed_rows = list(reversed(base))
    changed_entry = [_trade(entry=1_699_999_999, net=10), base[1]]
    changed_sign = [_trade(net=-10), base[1]]

    fingerprint = subject.signal_identity_stats(base)
    same = subject.signal_identity_stats(same_signs_different_money)

    assert fingerprint["complete"] is True
    assert fingerprint["identity_sha256"] == same["identity_sha256"]
    assert fingerprint["outcome_sign_sha256"] == same["outcome_sign_sha256"]
    assert fingerprint["identity_sha256"] != subject.signal_identity_stats(reversed_rows)["identity_sha256"]
    assert fingerprint["identity_sha256"] != subject.signal_identity_stats(changed_entry)["identity_sha256"]
    assert fingerprint["outcome_sign_sha256"] != subject.signal_identity_stats(changed_sign)["outcome_sign_sha256"]


def test_signal_fingerprint_marks_incomplete_rows_instead_of_hashing_them_as_complete() -> None:
    result = subject.signal_identity_stats([{"time": 1_700_000_000, "net": 1.0}])
    assert result["complete"] is False
    assert result["identity_count"] == 0
    assert result["outcome_sign_count"] == 0


def test_pre_run_common_stream_is_removed_captured_and_atomically_restored(
    tmp_path: Path,
) -> None:
    common = tmp_path / "common" / "1_EURUSD_DWX.jsonl"
    common.parent.mkdir(parents=True)
    original = b"old mutable stream\n"
    fresh = b"fresh isolated run\n"
    common.write_bytes(original)
    backup = common.with_name(".pre_run_backup")
    os.replace(common, backup)
    assert not common.exists()
    common.write_bytes(fresh)
    evidence = tmp_path / "evidence.jsonl"

    result = subject._capture_common_stream(common, evidence, original, backup)

    assert result["captured"] is True
    assert result["fresh_created"] is True
    assert result["restored"] is True
    assert evidence.read_bytes() == fresh
    assert common.read_bytes() == original
    assert not backup.exists()


def test_missing_fresh_common_stream_restores_pre_run_backup_and_blocks_freshness(
    tmp_path: Path,
) -> None:
    common = tmp_path / "common" / "1_EURUSD_DWX.jsonl"
    common.parent.mkdir(parents=True)
    original = b"old stream\n"
    backup = common.with_name(".pre_run_backup")
    backup.write_bytes(original)

    result = subject._capture_common_stream(
        common,
        tmp_path / "unused_evidence.jsonl",
        original,
        backup,
    )

    assert result == {
        "captured": False,
        "fresh_created": False,
        "restored": True,
        "reason": "missing_after_pre_run_removal",
    }
    assert common.read_bytes() == original
    assert not backup.exists()


def test_reference_snapshot_seal_validates_then_detects_stream_tamper(tmp_path: Path) -> None:
    provisional = _job(tmp_path)
    streams, manifest_sha = _snapshot(tmp_path, provisional)
    stream = next(streams.glob("*.jsonl"))

    valid, rows = subject.verify_reference_snapshot(
        streams,
        source_manifest_sha256=manifest_sha,
    )
    assert valid["seal_verified"] is True
    assert valid["errors"] == []
    assert provisional.key.upper() in rows

    stream.write_text(stream.read_text(encoding="utf-8") + "tamper\n", encoding="utf-8")
    tampered, _ = subject.verify_reference_snapshot(
        streams,
        source_manifest_sha256=manifest_sha,
    )
    assert tampered["seal_verified"] is False
    assert any(item.startswith("REFERENCE_SEAL_HASH_MISMATCH:streams/") for item in tampered["errors"])


def test_reference_snapshot_rejects_wrong_source_manifest_and_path_escape(tmp_path: Path) -> None:
    provisional = _job(tmp_path)
    streams, _manifest_sha = _snapshot(tmp_path, provisional)
    seal = streams.parent / "seal.sha256"
    seal.write_text(seal.read_text(encoding="ascii") + f"{'0' * 64}  ../escape.json\n", encoding="ascii")

    metadata, _ = subject.verify_reference_snapshot(
        streams,
        source_manifest_sha256="b" * 64,
    )

    assert "REFERENCE_SNAPSHOT_SOURCE_MANIFEST_MISMATCH" in metadata["errors"]
    assert "REFERENCE_SEAL_TARGET_INVALID:../escape.json" in metadata["errors"]


def test_missing_reference_is_blocked_before_mt5(tmp_path: Path) -> None:
    job = _job(tmp_path, reference=None)
    blockers = subject.reference_preflight_blockers(
        job,
        snapshot={"errors": []},
        snapshot_rows={},
    )
    assert blockers == ["REFERENCE_STREAM_MISSING_OR_INVALID"]


def test_reference_preflight_binds_count_and_frozen_hash(tmp_path: Path) -> None:
    provisional = _job(tmp_path)
    streams, manifest_sha = _snapshot(tmp_path, provisional)
    reference = next(streams.glob("*.jsonl"))
    job = _job(tmp_path, reference=reference)
    snapshot, rows = subject.verify_reference_snapshot(
        streams,
        source_manifest_sha256=manifest_sha,
    )
    assert subject.reference_preflight_blockers(job, snapshot=snapshot, snapshot_rows=rows) == []

    changed_count_job = _job(tmp_path, trades=2, reference=reference)
    assert "REFERENCE_MANIFEST_TRADE_COUNT_MISMATCH" in subject.reference_preflight_blockers(
        changed_count_job,
        snapshot=snapshot,
        snapshot_rows=rows,
    )


def test_duplicate_case_insensitive_common_paths_are_rejected_before_workers(
    tmp_path: Path,
) -> None:
    first = _job(tmp_path, ordinal=1, symbol="EURUSD.DWX")
    duplicate = _job(tmp_path, ordinal=2, symbol="eurusd.dwx")

    with pytest.raises(subject.RequalError, match="duplicate case-insensitive"):
        subject.execute_book(
            [first, duplicate],
            [tmp_path / "DXZ_Truth_1"],
            tmp_path / "out",
            tmp_path / "common",
        )


def test_execution_locks_are_exclusive_and_cleaned_up(tmp_path: Path) -> None:
    first = tmp_path / "one.lock"
    second = tmp_path / "nested" / "two.lock"

    with subject.execution_locks([second, first, first], token="run-a"):
        assert first.is_file() and second.is_file()
        payload = json.loads(first.read_text(encoding="utf-8"))
        assert payload["token"] == "run-a"
        with pytest.raises(subject.RequalError, match="execution lock already exists"):
            with subject.execution_locks([first], token="run-b"):
                raise AssertionError("unreachable")

    assert not first.exists()
    assert not second.exists()


def test_execution_lock_cleanup_does_not_delete_replaced_foreign_lock(tmp_path: Path) -> None:
    lock = tmp_path / "sweep.lock"
    with subject.execution_locks([lock], token="original"):
        lock.write_bytes(b"foreign replacement")
    assert lock.read_bytes() == b"foreign replacement"


def test_report_stability_requires_fresh_unchanged_large_file(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    report = tmp_path / "report.htm"
    report.write_bytes(b"x" * 2048)
    started = report.stat().st_mtime
    ticks = iter((0.0, 0.1, 0.2, 0.3))
    monkeypatch.setattr(subject.time, "monotonic", lambda: next(ticks))
    monkeypatch.setattr(subject.time, "sleep", lambda _seconds: None)

    result = subject._wait_for_stable_report(
        report,
        started_epoch=started,
        timeout_seconds=1,
    )

    assert result["stable"] is True
    assert result["fresh_mtime"] is True
    assert result["bytes"] == 2048
    assert result["sha256"] == subject.sha256_file(report)


def test_report_stability_rejects_stale_report(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    report = tmp_path / "stale.htm"
    report.write_bytes(b"x" * 2048)
    old = time.time() - 3600
    os.utime(report, (old, old))
    ticks = iter((0.0, 0.1, 1.1))
    monkeypatch.setattr(subject.time, "monotonic", lambda: next(ticks))
    monkeypatch.setattr(subject.time, "sleep", lambda _seconds: None)

    result = subject._wait_for_stable_report(
        report,
        started_epoch=time.time(),
        timeout_seconds=1,
    )

    assert result["exists"] is True
    assert result["stable"] is False
    assert result["fresh_mtime"] is False


@pytest.mark.parametrize(
    ("partial", "expected_status", "expected_scope", "expected_jobs"),
    [
        (False, "PASS", "FULL", 2),
        (True, "PASS_PARTIAL", "PARTIAL", 1),
    ],
)
def test_main_seals_full_and_partial_pass_summary_statuses(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    partial: bool,
    expected_status: str,
    expected_scope: str,
    expected_jobs: int,
) -> None:
    manifest_path = tmp_path / "manifest.json"
    manifest_path.write_text('{"n_sleeves": 2, "sleeves": []}', encoding="utf-8")
    jobs = [
        _job(tmp_path, ordinal=1, ea_id=1, symbol="EURUSD.DWX"),
        _job(tmp_path, ordinal=2, ea_id=2, symbol="XAUUSD.DWX"),
    ]
    output = tmp_path / ("partial" if partial else "full")
    sandbox = tmp_path / "DXZ_Truth_1"
    common = tmp_path / "common"
    live = tmp_path / "T_Live_source_only"

    monkeypatch.setattr(subject, "validate_sandbox_root", lambda path: Path(path).resolve())
    monkeypatch.setattr(subject, "validate_output_root", lambda path, _live: Path(path).resolve())
    monkeypatch.setattr(subject, "validate_common_root", lambda path, execute: Path(path).resolve())
    monkeypatch.setattr(subject, "validate_qualification_contract", lambda **_kwargs: None)
    monkeypatch.setattr(
        subject,
        "build_jobs",
        lambda *_args, **_kwargs: ({"status": "DRAFT"}, jobs),
    )
    monkeypatch.setattr(subject, "verify_reference_snapshot", lambda *_args, **_kwargs: ({"errors": []}, {}))
    monkeypatch.setattr(subject, "reference_preflight_blockers", lambda *_args, **_kwargs: [])
    monkeypatch.setattr(
        subject,
        "build_plan",
        lambda selected, _sandboxes: {
            "schema_version": 1,
            "mode": "PLAN",
            "jobs": [
                {"ordinal": job.ordinal, "ea_id": job.ea_id, "symbol": job.symbol}
                for job in selected
            ],
        },
    )

    def fake_execute(selected, *_args, **_kwargs):
        return [
            {
                "schema_version": 1,
                "status": "PASS",
                "blockers": [],
                "job": {"ordinal": job.ordinal, "ea_id": job.ea_id, "symbol": job.symbol},
            }
            for job in selected
        ]

    monkeypatch.setattr(subject, "execute_book", fake_execute)
    argv = [
        "--manifest",
        str(manifest_path),
        "--live-root",
        str(live),
        "--sandbox-root",
        str(sandbox),
        "--common-root",
        str(common),
        "--output-dir",
        str(output),
        "--execute",
    ]
    if partial:
        argv.extend(["--only", "1"])

    assert subject.main(argv) == 0
    summaries = list(output.glob("*/summary.json"))
    assert len(summaries) == 1
    summary = json.loads(summaries[0].read_text(encoding="utf-8"))
    assert summary["status"] == expected_status
    assert summary["scope"] == expected_scope
    assert summary["n_jobs"] == expected_jobs
    assert summary["manifest_jobs"] == 2
    unsigned = dict(summary)
    declared = unsigned.pop("summary_sha256")
    assert declared == subject.canonical_json_sha(unsigned)
