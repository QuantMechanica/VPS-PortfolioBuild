from __future__ import annotations

import dataclasses
import hashlib
import json
import os
from pathlib import Path

import pytest

from tools.strategy_farm import dxz_as_live_requal as subject
from tools.strategy_farm import dxz_target_binary_repro_gate as pair_gate


def _trade(
    *,
    entry: int = 1_700_000_000,
    close: int = 1_700_003_600,
    symbol: str = "EURUSD.DWX",
    profit: float = 10.0,
    net: float | None = None,
) -> dict:
    return {
        "event": "TRADE_CLOSED",
        "entry_time": entry,
        "time": close,
        "symbol": symbol,
        "profit": profit,
        "net": profit if net is None else net,
    }


def _write_stream(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "".join(json.dumps(row, sort_keys=True) + "\n" for row in rows),
        encoding="utf-8",
    )


def test_target_single_run_never_self_promotes_to_qualified() -> None:
    assert subject.qualification_status(
        subject.TARGET_BINARY_REQUAL,
        technical_pass=True,
        cost_certified=True,
    ) == "REPRODUCIBILITY_PENDING"
    assert subject.qualification_status(
        subject.AS_LIVE_REQUAL,
        technical_pass=True,
        cost_certified=True,
    ) == "QUALIFIED"
    assert subject.qualification_status(
        subject.TARGET_BINARY_REQUAL,
        technical_pass=True,
        cost_certified=False,
    ) == "COST_UNCERTIFIED"


def test_target_reproducibility_identity_is_explicit_and_fail_closed() -> None:
    current_q08_row = {
        "event": "TRADE_CLOSED",
        "entry_time": 1_700_000_000,
        "time": 1_700_003_600,
        "symbol": "EURUSD.DWX",
        "volume": "0.10",
        "net": "12.50",
        "profit": 13.0,
    }

    identity = subject.target_reproducibility_identity([current_q08_row])

    assert identity["schema_version"] == 1
    assert set(identity) - {"schema_version"} == set(
        pair_gate.REQUIRED_IDENTITY_AXES
    )
    assert identity["trades"]["complete"] is True
    assert identity["signals"]["complete"] is True
    assert identity["lots"]["complete"] is True
    assert identity["outcome_signs"]["complete"] is True
    assert identity["pnl"]["complete"] is True
    assert identity["entries"]["complete"] is False
    assert identity["exits"]["complete"] is False
    assert identity["exits"]["reasons"] == ["EXIT_REASON_MISSING_AT_ROW:0"]
    assert identity["mtm"]["complete"] is False
    assert identity["daily_mtm"]["complete"] is False
    assert identity["margin"]["complete"] is False
    assert identity["mtm"]["count"] == 0
    assert identity["mtm"]["reasons"] == [
        "INTRADAY_MTM_STREAM_NOT_EMITTED_BY_CURRENT_RUNNER_CONTRACT"
    ]

    enriched = dict(
        current_q08_row,
        side="BUY",
        entry_price="1.07500",
        exit_reason="TAKE_PROFIT",
    )
    complete_trade_axes = subject.target_reproducibility_identity([enriched])
    assert all(
        complete_trade_axes[axis]["complete"] is True
        for axis in (
            "trades",
            "signals",
            "entries",
            "exits",
            "lots",
            "outcome_signs",
            "pnl",
        )
    )
    assert complete_trade_axes["mtm"]["complete"] is False


def test_target_reproducibility_identity_rejects_partial_or_invalid_rows() -> None:
    row = {
        "entry_time": 1_700_000_000,
        "time": 1_700_003_600,
        "symbol": "EURUSD.DWX",
        "volume": "NaN",
        "net": "Infinity",
        "exit_reason": "STOP_LOSS",
    }

    identity = subject.target_reproducibility_identity(
        [row],
        parse_errors=["line 2: invalid JSON"],
    )

    assert identity["trades"]["complete"] is False
    assert identity["signals"]["complete"] is False
    assert identity["lots"]["complete"] is False
    assert identity["pnl"]["complete"] is False
    assert "VOLUME_INVALID_AT_ROW:0" in identity["lots"]["reasons"]
    assert "NET_PNL_INVALID_AT_ROW:0" in identity["pnl"]["reasons"]


def _job(
    tmp_path: Path,
    *,
    ordinal: int = 1,
    ea_id: int = 1,
    symbol: str = "EURUSD.DWX",
    reference: Path | None = None,
    trades: int | None = 1,
) -> subject.Job:
    ex5 = tmp_path / "live" / f"QM5_{ea_id}_test.ex5"
    preset = tmp_path / "live" / f"QM5_{ea_id}_{symbol}.set"
    ex5.parent.mkdir(parents=True, exist_ok=True)
    ex5.write_bytes(b"test-ex5")
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


def _snapshot(tmp_path: Path, job: subject.Job) -> tuple[Path, str, Path]:
    root = tmp_path / "snapshot"
    streams = root / "streams"
    stream = streams / f"{job.ea_id}_{job.symbol.replace('.', '_')}.jsonl"
    _write_stream(stream, [_trade(symbol=job.symbol)])
    source_manifest_sha = "a" * 64
    manifest_payload = {
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
    manifest.write_text(json.dumps(manifest_payload, indent=2), encoding="utf-8")
    (root / "seal.sha256").write_text(
        f"{subject.sha256_file(manifest)}  reference_stream_manifest.json\n"
        f"{subject.sha256_file(stream)}  streams/{stream.name}\n",
        encoding="ascii",
    )
    return streams, source_manifest_sha, stream


@pytest.mark.parametrize("had_previous", [True, False])
def test_exception_transaction_marker_restores_previous_state_or_absence(
    tmp_path: Path,
    had_previous: bool,
) -> None:
    job = _job(tmp_path)
    common_root = tmp_path / "common"
    common_path = subject._common_stream_path(common_root, job)
    common_path.parent.mkdir(parents=True, exist_ok=True)
    fresh = b"fresh stream created before runner exception\n"
    common_path.write_bytes(fresh)
    run_dir = tmp_path / "run"
    run_dir.mkdir()

    previous = b"pre-run stream\n" if had_previous else None
    backup = common_path.with_name(".transaction-backup") if had_previous else None
    if backup is not None and previous is not None:
        backup.write_bytes(previous)
    marker = {
        "status": "PREPARED",
        "common_path": str(common_path),
        "backup_path": str(backup) if backup is not None else None,
        "had_previous": had_previous,
        "previous_sha256": (
            hashlib.sha256(previous).hexdigest() if previous is not None else None
        ),
    }
    transaction_path = run_dir / "common_stream_transaction.json"
    transaction_path.write_text(json.dumps(marker), encoding="utf-8")

    recovery = subject._recover_common_transaction(common_root, job, run_dir)

    assert recovery["transaction_started"] is True
    assert recovery["recovery_required"] is True
    assert recovery["recovered"] is True
    assert (run_dir / "q08_stream_uncaptured_on_error.jsonl").read_bytes() == fresh
    if had_previous:
        assert recovery["method"] == "backup_restore"
        assert common_path.read_bytes() == previous
        assert backup is not None and not backup.exists()
    else:
        assert recovery["method"] == "restore_absence"
        assert not common_path.exists()
    persisted = json.loads(transaction_path.read_text(encoding="utf-8"))
    assert persisted["status"] == "RECOVERED_AFTER_ERROR"
    assert persisted["recovery"]["recovered"] is True


def test_empty_reference_seal_is_rejected_fail_closed(tmp_path: Path) -> None:
    provisional = _job(tmp_path)
    streams, source_manifest_sha, _stream = _snapshot(tmp_path, provisional)
    (streams.parent / "seal.sha256").write_text("\n", encoding="ascii")

    metadata, _rows = subject.verify_reference_snapshot(
        streams,
        source_manifest_sha256=source_manifest_sha,
    )

    assert metadata.get("seal_verified", False) is False
    assert "REFERENCE_SEAL_EMPTY" in metadata["errors"]
    assert "REFERENCE_MANIFEST_NOT_SEALED" in metadata["errors"]


@pytest.mark.parametrize(
    ("sealed_target", "expected_error"),
    [
        ("stream", "REFERENCE_MANIFEST_NOT_SEALED"),
        ("manifest", "REFERENCE_SELECTED_STREAM_NOT_SEALED:"),
    ],
)
def test_snapshot_requires_both_manifest_and_selected_stream_to_be_sealed(
    tmp_path: Path,
    sealed_target: str,
    expected_error: str,
) -> None:
    provisional = _job(tmp_path)
    streams, source_manifest_sha, stream = _snapshot(tmp_path, provisional)
    manifest = streams.parent / "reference_stream_manifest.json"
    seal = streams.parent / "seal.sha256"
    if sealed_target == "stream":
        seal.write_text(
            f"{subject.sha256_file(stream)}  streams/{stream.name}\n",
            encoding="ascii",
        )
    else:
        seal.write_text(
            f"{subject.sha256_file(manifest)}  reference_stream_manifest.json\n",
            encoding="ascii",
        )

    metadata, _rows = subject.verify_reference_snapshot(
        streams,
        source_manifest_sha256=source_manifest_sha,
    )

    assert metadata["seal_verified"] is False
    assert any(error.startswith(expected_error) for error in metadata["errors"])


def test_invalid_utf8_stream_and_seal_fail_closed(tmp_path: Path) -> None:
    stream = tmp_path / "invalid.jsonl"
    stream.write_bytes(b'\xff{"event":"TRADE_CLOSED"}\n')
    rows, errors = subject.load_trade_rows_strict(stream)
    assert rows == []
    assert len(errors) == 1 and errors[0].startswith("STREAM_READ_ERROR:")

    provisional = _job(tmp_path)
    streams, source_manifest_sha, _valid_stream = _snapshot(tmp_path, provisional)
    (streams.parent / "seal.sha256").write_bytes(b"\xff\xfe")
    metadata, _rows = subject.verify_reference_snapshot(
        streams,
        source_manifest_sha256=source_manifest_sha,
    )
    assert metadata.get("seal_verified", False) is False
    assert any(
        error.startswith("REFERENCE_SEAL_READ_ERROR:")
        for error in metadata["errors"]
    )


def test_preflight_honors_explicit_expected_reference_sha(tmp_path: Path) -> None:
    provisional = _job(tmp_path)
    streams, source_manifest_sha, stream = _snapshot(tmp_path, provisional)
    snapshot, snapshot_rows = subject.verify_reference_snapshot(
        streams,
        source_manifest_sha256=source_manifest_sha,
    )
    job = dataclasses.replace(
        provisional,
        reference_stream=stream,
        reference_expected_sha256="0" * 64,
    )

    blockers = subject.reference_preflight_blockers(
        job,
        snapshot=snapshot,
        snapshot_rows=snapshot_rows,
    )

    assert "REFERENCE_STREAM_SNAPSHOT_HASH_MISMATCH" in blockers


def test_run_job_rechecks_bound_reference_sha_before_mt5(tmp_path: Path) -> None:
    reference = tmp_path / "reference.jsonl"
    _write_stream(reference, [_trade()])
    expected_sha = subject.sha256_file(reference)
    job = dataclasses.replace(
        _job(tmp_path, reference=reference),
        reference_expected_sha256=expected_sha,
    )
    _write_stream(reference, [_trade(close=1_700_007_200)])

    with pytest.raises(subject.RequalError, match="reference hash changed after preflight"):
        subject.run_job(
            job,
            tmp_path / "sandbox",
            tmp_path / "output",
            tmp_path / "common",
            from_date="2020.01.01",
            to_date="2020.12.31",
            currency="EUR",
            deposit=100_000,
            timeout_seconds=1,
        )

    assert not (tmp_path / "sandbox" / "MQL5").exists()


def test_outcome_sign_uses_gross_profit_when_net_commission_flips_sign() -> None:
    gross_winner_net_loser = [_trade(profit=0.25, net=-1.75)]
    gross_winner_net_winner = [_trade(profit=0.25, net=100.0)]

    flipped = subject.signal_identity_stats(gross_winner_net_loser)
    control = subject.signal_identity_stats(gross_winner_net_winner)

    assert flipped["outcome_sign_basis"] == "gross_profit_fallback_net"
    assert flipped["outcome_sign_complete"] is True
    assert flipped["outcome_sign_sha256"] == control["outcome_sign_sha256"]


@pytest.mark.parametrize("valid_report_contract", [True, False])
def test_run_job_records_report_copy_window_and_count_contracts(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    valid_report_contract: bool,
) -> None:
    row = _trade()
    reference = tmp_path / "reference.jsonl"
    _write_stream(reference, [row])
    job = dataclasses.replace(
        _job(tmp_path, reference=reference),
        reference_expected_sha256=subject.sha256_file(reference),
    )
    sandbox = tmp_path / "sandbox"
    sandbox.mkdir()
    common_root = tmp_path / "common"
    report_source = sandbox / f"DXZ_TRUTH_{job.slug}.htm"
    common_path = subject._common_stream_path(common_root, job)

    class CompletedProcess:
        returncode = 0

        def __init__(self, *_args, **_kwargs) -> None:
            report_source.write_bytes(b"<html>" + b"x" * 2048 + b"</html>")
            _write_stream(common_path, [row])

        def poll(self) -> int:
            return self.returncode

    monkeypatch.setattr(subject.subprocess, "Popen", CompletedProcess)

    def fake_stability(path: Path, **_kwargs) -> dict:
        actual_sha = subject.sha256_file(path)
        return {
            "stable": True,
            "exists": True,
            "sha256": actual_sha if valid_report_contract else "f" * 64,
        }

    monkeypatch.setattr(subject, "_wait_for_stable_report", fake_stability)
    monkeypatch.setattr(
        subject,
        "_parse_native_report",
        lambda _path, _symbol: (
            {
                "start_date": "2020-01-01" if valid_report_contract else "2019-01-01",
                "end_date": "2020-12-31",
                "closed_trades": 1 if valid_report_contract else 2,
            },
            [row],
        ),
    )

    receipt = subject.run_job(
        job,
        sandbox,
        tmp_path / "output",
        common_root,
        from_date="2020.01.01",
        to_date="2020.12.31",
        currency="EUR",
        deposit=100_000,
        timeout_seconds=1,
    )

    assert receipt["native_report_copy_hash_match"] is valid_report_contract
    runtime_transaction = Path(receipt["identity"]["runtime_log_transaction_path"])
    assert runtime_transaction.is_file()
    assert receipt["identity"]["runtime_log_transaction_sha256"] == subject.sha256_file(
        runtime_transaction
    )
    assert receipt["native_report_window_match"] is valid_report_contract
    assert receipt["native_report_trade_count_match"] is valid_report_contract
    expected_blockers = {
        "NATIVE_REPORT_COPY_HASH_MISMATCH",
        "NATIVE_REPORT_WINDOW_MISMATCH",
        "NATIVE_REPORT_TRADE_COUNT_MISMATCH",
    }
    if valid_report_contract:
        assert expected_blockers.isdisjoint(receipt["blockers"])
    else:
        assert expected_blockers.issubset(receipt["blockers"])


@pytest.mark.parametrize(
    ("drift", "expected_blocker", "unchanged_field"),
    [
        ("runner", "RUNNER_CHANGED_DURING_SWEEP", "runner_unchanged"),
        (
            "snapshot",
            "REFERENCE_SNAPSHOT_CHANGED_DURING_SWEEP",
            "reference_snapshot_unchanged",
        ),
    ],
)
def test_global_runner_or_snapshot_drift_forces_failed_summary(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    drift: str,
    expected_blocker: str,
    unchanged_field: str,
) -> None:
    manifest_path = tmp_path / "manifest.json"
    manifest_path.write_text('{"n_sleeves": 1, "sleeves": []}', encoding="utf-8")
    job = _job(tmp_path)
    output = tmp_path / "output"
    sandbox = tmp_path / "DXZ_Truth_1"
    common = tmp_path / "common"
    live = tmp_path / "T_Live_source_only"

    monkeypatch.setattr(subject, "validate_sandbox_root", lambda path: Path(path).resolve())
    monkeypatch.setattr(
        subject,
        "validate_output_root",
        lambda path, _live: Path(path).resolve(),
    )
    monkeypatch.setattr(
        subject,
        "validate_common_root",
        lambda path, execute: Path(path).resolve(),
    )
    monkeypatch.setattr(subject, "validate_qualification_contract", lambda **_kwargs: None)
    monkeypatch.setattr(
        subject,
        "build_jobs",
        lambda *_args, **_kwargs: ({"status": "DRAFT"}, [job]),
    )
    snapshot_calls = 0

    def fake_snapshot(*_args, **_kwargs):
        nonlocal snapshot_calls
        snapshot_calls += 1
        revision = snapshot_calls if drift == "snapshot" else 1
        return {"errors": [], "revision": revision}, {}

    monkeypatch.setattr(subject, "verify_reference_snapshot", fake_snapshot)
    monkeypatch.setattr(subject, "reference_preflight_blockers", lambda *_args, **_kwargs: [])
    monkeypatch.setattr(
        subject,
        "build_plan",
        lambda selected, _sandboxes: {
            "schema_version": 1,
            "mode": "PLAN",
            "jobs": [
                {"ordinal": item.ordinal, "ea_id": item.ea_id, "symbol": item.symbol}
                for item in selected
            ],
        },
    )
    monkeypatch.setattr(
        subject,
        "execute_book",
        lambda selected, *_args, **_kwargs: [
            {
                "schema_version": 1,
                "status": "PASS",
                "blockers": [],
                "job": {
                    "ordinal": item.ordinal,
                    "ea_id": item.ea_id,
                    "symbol": item.symbol,
                },
            }
            for item in selected
        ],
    )

    if drift == "runner":
        real_sha256_file = subject.sha256_file
        runner_path = Path(subject.__file__).resolve()
        runner_reads = 0

        def drifting_runner_sha(path: Path) -> str:
            nonlocal runner_reads
            if Path(path).resolve() == runner_path:
                runner_reads += 1
                return "1" * 64 if runner_reads == 1 else "2" * 64
            return real_sha256_file(Path(path))

        monkeypatch.setattr(subject, "sha256_file", drifting_runner_sha)

    return_code = subject.main(
        [
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
    )

    assert return_code == 2
    summaries = list(output.glob("*/summary.json"))
    assert len(summaries) == 1
    summary_sidecar = summaries[0].with_name(summaries[0].name + ".sha256")
    assert summary_sidecar.is_file()
    assert summary_sidecar.read_text(encoding="ascii").split()[0] == subject.sha256_file(
        summaries[0]
    )
    summary = json.loads(summaries[0].read_text(encoding="utf-8"))
    assert summary["status"] == "FAIL"
    assert summary["counts"] == {"PASS": 1}
    assert expected_blocker in summary["global_blockers"]
    assert summary[unchanged_field] is False


def _runtime_log_line(
    job: subject.Job,
    *,
    event: str,
    timestamp: str,
    payload: dict,
    symbol: str | None = None,
    magic: int = 10001,
) -> str:
    return json.dumps(
        {
            "ts_utc": f"{timestamp}.000Z",
            "ts_broker": timestamp,
            "level": "INFO",
            "ea_id": job.ea_id,
            "slug": f"ea-{job.ea_id}",
            "symbol": symbol or job.symbol,
            "tf": job.timeframe,
            "magic": magic,
            "event": event,
            "payload": payload,
        },
        sort_keys=True,
    )


def _write_runtime_log(path: Path, lines: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def test_runtime_log_capture_is_sandbox_only_hashed_and_restores_prestate(
    tmp_path: Path,
) -> None:
    job = _job(tmp_path, ea_id=1556)
    sandbox = tmp_path / "DXZ_Truth_1"
    log = (
        sandbox
        / "Tester"
        / "Agent-127.0.0.1-3003"
        / "MQL5"
        / "Files"
        / "QM"
        / "QM5_1556_ea-1556.log"
    )
    old = b"old append-contaminated state\n"
    log.parent.mkdir(parents=True)
    log.write_bytes(old)
    run_dir = tmp_path / "run"
    run_dir.mkdir()

    transaction = subject._prepare_runtime_log_transaction(sandbox, job, run_dir)
    assert not log.exists()
    fresh = b'{"fresh":true}\n'
    log.write_bytes(fresh)
    capture = subject._capture_runtime_log_transaction(
        sandbox, job, run_dir, transaction
    )

    assert capture["status"] == "PASS"
    assert capture["sha256"] == hashlib.sha256(fresh).hexdigest()
    assert Path(capture["evidence_path"]).read_bytes() == fresh
    assert log.read_bytes() == old
    assert capture["restored"] is True


def test_runtime_log_capture_rejects_fresh_plus_stale_candidate_and_restores_absence(
    tmp_path: Path,
) -> None:
    job = _job(tmp_path, ea_id=1556)
    sandbox = tmp_path / "DXZ_Truth_1"
    run_dir = tmp_path / "run"
    run_dir.mkdir()
    transaction = subject._prepare_runtime_log_transaction(sandbox, job, run_dir)
    first = sandbox / "MQL5" / "Files" / "QM" / "QM5_1556_one.log"
    second = (
        sandbox
        / "Tester"
        / "Agent-local"
        / "MQL5"
        / "Files"
        / "QM"
        / "QM5_1556_two.log"
    )
    first.parent.mkdir(parents=True)
    second.parent.mkdir(parents=True)
    first.write_text("fresh\n", encoding="utf-8")
    second.write_text("stale\n", encoding="utf-8")
    stale_ns = transaction["prepared_epoch_ns"] - 1
    os.utime(second, ns=(stale_ns, stale_ns))

    capture = subject._capture_runtime_log_transaction(
        sandbox, job, run_dir, transaction
    )

    assert capture["status"] == "FAIL"
    assert capture["ambiguous"] is True
    assert "RUNTIME_LOG_MULTIPLE_CANDIDATES" in capture["blockers"]
    assert capture["restored"] is True
    assert not first.exists() and not second.exists()


def test_runtime_log_prepare_partial_exception_restores_moved_and_unmoved_files(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    job = _job(tmp_path, ea_id=1556)
    sandbox = tmp_path / "DXZ_Truth_1"
    root = sandbox / "MQL5" / "Files" / "QM"
    root.mkdir(parents=True)
    first = root / "QM5_1556_first.log"
    second = root / "QM5_1556_second.log"
    first.write_bytes(b"first-old")
    second.write_bytes(b"second-old")
    run_dir = tmp_path / "run"
    run_dir.mkdir()
    real_replace = subject.os.replace
    calls = 0

    def fail_second_move(source, target):
        nonlocal calls
        if Path(source).name.startswith("QM5_1556_"):
            calls += 1
            if calls == 2:
                raise OSError("simulated prepare interruption")
        return real_replace(source, target)

    monkeypatch.setattr(subject.os, "replace", fail_second_move)

    with pytest.raises(OSError, match="simulated prepare interruption"):
        subject._prepare_runtime_log_transaction(sandbox, job, run_dir)

    assert first.read_bytes() == b"first-old"
    assert second.read_bytes() == b"second-old"
    marker = json.loads(
        (run_dir / "runtime_log_transaction.json").read_text(encoding="utf-8")
    )
    assert marker["status"] == "PREPARE_FAILED_RESTORED"
    assert marker["recovery"]["restored"] is True


def test_runtime_log_exception_recovery_preserves_fresh_and_restores_old(
    tmp_path: Path,
) -> None:
    job = _job(tmp_path, ea_id=1556)
    sandbox = tmp_path / "DXZ_Truth_1"
    log = sandbox / "MQL5" / "Files" / "QM" / "QM5_1556_test.log"
    log.parent.mkdir(parents=True)
    log.write_bytes(b"old")
    run_dir = tmp_path / "run"
    run_dir.mkdir()
    subject._prepare_runtime_log_transaction(sandbox, job, run_dir)
    log.write_bytes(b"fresh-before-exception")

    recovery = subject._recover_runtime_log_transaction(sandbox, job, run_dir)

    assert recovery["recovered"] is True
    assert log.read_bytes() == b"old"
    preserved = list((run_dir / "runtime_log_uncaptured_on_error").glob("*.log"))
    assert len(preserved) == 1
    assert preserved[0].read_bytes() == b"fresh-before-exception"


def test_run_job_popen_exception_always_restores_pre_run_runtime_log(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    reference = tmp_path / "reference.jsonl"
    _write_stream(reference, [_trade()])
    job = dataclasses.replace(
        _job(tmp_path, ea_id=1556, reference=reference),
        reference_expected_sha256=subject.sha256_file(reference),
    )
    sandbox = tmp_path / "DXZ_Truth_1"
    sandbox.mkdir()
    log = sandbox / "MQL5" / "Files" / "QM" / "QM5_1556_test.log"
    log.parent.mkdir(parents=True)
    old = b"old-runtime-log"
    log.write_bytes(old)

    def fail_popen(*_args, **_kwargs):
        raise OSError("simulated Popen failure")

    monkeypatch.setattr(subject.subprocess, "Popen", fail_popen)

    with pytest.raises(OSError, match="simulated Popen failure"):
        subject.run_job(
            job,
            sandbox,
            tmp_path / "output",
            tmp_path / "common",
            from_date="2020.01.01",
            to_date="2020.12.31",
            currency="EUR",
            deposit=100_000,
            timeout_seconds=1,
        )

    assert log.read_bytes() == old
    marker = json.loads(
        next((tmp_path / "output" / "runs").glob("*/runtime_log_transaction.json")).read_text(
            encoding="utf-8"
        )
    )
    assert marker["status"] == "CAPTURE_FAILED_RESTORED"
    assert marker["capture"]["restored"] is True


def test_runtime_log_recovery_detects_crash_after_move_before_marker_update(
    tmp_path: Path,
) -> None:
    job = _job(tmp_path, ea_id=1556)
    sandbox = tmp_path / "DXZ_Truth_1"
    original = sandbox / "MQL5" / "Files" / "QM" / "QM5_1556_test.log"
    original.parent.mkdir(parents=True)
    previous = b"pre-run"
    original.write_bytes(previous)
    run_dir = tmp_path / "run"
    run_dir.mkdir()
    marker = {
        "schema_version": 1,
        "status": "PREPARE_INTENT",
        "sandbox": str(sandbox.resolve()),
        "ea_id": job.ea_id,
        "job_identity": job.key,
        "prepared_epoch_ns": None,
        "pre_run_logs": [
            {
                "path": str(original.resolve()),
                "backup_path": str(original.with_name(".crash-backup").resolve()),
                "sha256": hashlib.sha256(previous).hexdigest(),
                "size": len(previous),
                "moved": False,
            }
        ],
    }
    backup = Path(marker["pre_run_logs"][0]["backup_path"])
    os.replace(original, backup)
    (run_dir / "runtime_log_transaction.json").write_text(
        json.dumps(marker), encoding="utf-8"
    )

    recovery = subject._recover_runtime_log_transaction(sandbox, job, run_dir)

    assert recovery["recovered"] is True
    assert original.read_bytes() == previous
    assert not backup.exists()


def test_runtime_log_capture_rejects_late_writer(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    job = _job(tmp_path, ea_id=1556)
    sandbox = tmp_path / "DXZ_Truth_1"
    first = sandbox / "MQL5" / "Files" / "QM" / "QM5_1556_first.log"
    late = (
        sandbox
        / "Tester"
        / "Agent-late"
        / "MQL5"
        / "Files"
        / "QM"
        / "QM5_1556_late.log"
    )
    run_dir = tmp_path / "run"
    run_dir.mkdir()
    transaction = subject._prepare_runtime_log_transaction(sandbox, job, run_dir)
    first.parent.mkdir(parents=True)
    first.write_bytes(b"first")
    wrote_late = False

    def create_late_writer(_seconds: float) -> None:
        nonlocal wrote_late
        if not wrote_late:
            wrote_late = True
            late.parent.mkdir(parents=True)
            late.write_bytes(b"late")

    monkeypatch.setattr(subject.time, "sleep", create_late_writer)

    capture = subject._capture_runtime_log_transaction(
        sandbox, job, run_dir, transaction
    )

    assert capture["status"] == "FAIL"
    assert "RUNTIME_LOG_LATE_WRITER_DETECTED" in capture["blockers"]
    assert len(capture["preserved_post_run_logs"]) == 2
    assert capture["restored"] is True
    assert not first.exists() and not late.exists()


def test_runtime_log_capture_rejects_writer_after_first_late_rescan(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    job = _job(tmp_path, ea_id=1556)
    sandbox = tmp_path / "DXZ_Truth_1"
    first = sandbox / "MQL5" / "Files" / "QM" / "QM5_1556_first.log"
    late = sandbox / "MQL5" / "Files" / "QM" / "QM5_1556_late.log"
    run_dir = tmp_path / "run"
    run_dir.mkdir()
    transaction = subject._prepare_runtime_log_transaction(sandbox, job, run_dir)
    first.parent.mkdir(parents=True)
    first.write_bytes(b"first")
    sleep_calls = 0

    def create_after_first_rescan(_seconds: float) -> None:
        nonlocal sleep_calls
        sleep_calls += 1
        if sleep_calls == subject.RUNTIME_LOG_STABILITY_OBSERVATIONS + 2:
            late.write_bytes(b"late-after-first-rescan")

    monkeypatch.setattr(subject.time, "sleep", create_after_first_rescan)

    capture = subject._capture_runtime_log_transaction(
        sandbox, job, run_dir, transaction
    )

    assert capture["status"] == "FAIL"
    assert "RUNTIME_LOG_LATE_WRITER_DETECTED" in capture["blockers"]
    assert any(row.get("late_rescan") == 2 for row in capture["candidates"])
    assert capture["restored"] is True
    assert not first.exists() and not late.exists()


def test_runtime_log_capture_rejects_writer_changing_restored_prestate(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    job = _job(tmp_path, ea_id=1556)
    sandbox = tmp_path / "DXZ_Truth_1"
    log = sandbox / "MQL5" / "Files" / "QM" / "QM5_1556_test.log"
    log.parent.mkdir(parents=True)
    old = b"pre-run"
    log.write_bytes(old)
    run_dir = tmp_path / "run"
    run_dir.mkdir()
    transaction = subject._prepare_runtime_log_transaction(sandbox, job, run_dir)
    log.write_bytes(b"fresh")
    sleep_calls = 0

    def change_after_first_post_restore_scan(_seconds: float) -> None:
        nonlocal sleep_calls
        sleep_calls += 1
        post_restore_second_scan = (
            subject.RUNTIME_LOG_STABILITY_OBSERVATIONS
            + subject.RUNTIME_LOG_LATE_RESCANS
            + 2
        )
        if sleep_calls == post_restore_second_scan:
            log.write_bytes(b"concurrent-writer-corruption")

    monkeypatch.setattr(
        subject.time, "sleep", change_after_first_post_restore_scan
    )

    capture = subject._capture_runtime_log_transaction(
        sandbox, job, run_dir, transaction
    )

    assert capture["status"] == "FAIL"
    assert "RUNTIME_LOG_POST_RESTORE_WRITER_DETECTED" in capture["blockers"]
    assert capture["post_restore_quiescence"]["confirmed"] is True
    assert capture["restored"] is True
    assert log.read_bytes() == old
    assert any(
        row.get("reason") == "POST_RESTORE_PRESTATE_CHANGED"
        for row in capture["preserved_post_run_logs"]
    )


def test_runtime_log_parser_rejects_identity_mismatch_and_append_contamination(
    tmp_path: Path,
) -> None:
    job = _job(tmp_path, ea_id=1556, symbol="XAUUSD.DWX")
    log = tmp_path / "runtime.log"
    lines = [
        _runtime_log_line(
            job,
            event="EQUITY_SNAPSHOT",
            timestamp="2020-01-03T00:00:00",
            symbol="XNGUSD.DWX",
            payload={
                "day_key": 20200102,
                "month_key": 202001,
                "equity": 100000,
                "day_pnl": 0,
                "month_pnl": 0,
                "atr_regime": "normal",
                "symbol": "XNGUSD.DWX",
            },
        ),
        _runtime_log_line(
            job,
            event="EQUITY_SNAPSHOT",
            timestamp="2020-01-02T00:00:00",
            payload={
                "day_key": 20200101,
                "month_key": 202001,
                "equity": 100000,
                "day_pnl": 0,
                "month_pnl": 0,
                "atr_regime": "normal",
                "symbol": job.symbol,
            },
        ),
    ]
    _write_runtime_log(log, lines)

    parsed = subject.parse_runtime_log_strict(log, job)

    assert parsed["status"] == "FAIL"
    assert any("SYMBOL_IDENTITY_MISMATCH" in item for item in parsed["errors"])
    assert "RUNTIME_LOG_EVENT_TIME_NOT_MONOTONIC_APPEND_CONTAMINATION" in parsed[
        "errors"
    ]


@pytest.mark.parametrize(
    "invalid_line",
    [
        '{"ea_id":1556,"ea_id":1556,"event":"INIT"}',
        (
            '{"ts_broker":"2020-01-01T00:00:00","ea_id":1556,'
            '"symbol":"XAUUSD.DWX","tf":"H1","magic":NaN,'
            '"event":"EQUITY_SNAPSHOT","payload":{}}'
        ),
        (
            '{"ts_broker":"2020-01-01T00:00:00","ea_id":"1556",'
            '"symbol":"XAUUSD.DWX","tf":"H1","magic":"15560004",'
            '"event":"EQUITY_SNAPSHOT","payload":{}}'
        ),
    ],
)
def test_runtime_log_parser_rejects_duplicate_nonfinite_and_string_ids(
    tmp_path: Path,
    invalid_line: str,
) -> None:
    job = _job(tmp_path, ea_id=1556, symbol="XAUUSD.DWX")
    log = tmp_path / "invalid.log"
    log.write_text(invalid_line + "\n", encoding="utf-8")

    parsed = subject.parse_runtime_log_strict(log, job)

    assert parsed["status"] == "FAIL"
    assert parsed["errors"]


def test_runtime_log_parser_requires_exactly_one_init_and_init_ok(
    tmp_path: Path,
) -> None:
    job, parsed, _q08 = _complete_runtime_evidence(tmp_path)
    log = tmp_path / "duplicate_init.log"
    original = (tmp_path / "runtime.log").read_text(encoding="utf-8").splitlines()
    _write_runtime_log(log, [original[0], original[0], *original[1:]])

    duplicate = subject.parse_runtime_log_strict(log, job)

    assert parsed["status"] == "PASS"
    assert duplicate["status"] == "FAIL"
    assert "RUNTIME_LOG_INIT_COUNT_INVALID:2" in duplicate["errors"]


def _complete_runtime_evidence(
    tmp_path: Path,
    *,
    expected_magic: int | None = None,
) -> tuple[subject.Job, dict, list[dict]]:
    job = _job(tmp_path, ea_id=1556, symbol="XAUUSD.DWX")
    magic = 15560004
    if expected_magic is not None:
        job = dataclasses.replace(job, expected_magic=expected_magic)
    entry_text = "2020-01-02T01:00:00"
    equity_text = "2020-01-02T12:00:00"
    exit_text = "2020-01-03T21:00:00"
    log = tmp_path / "runtime.log"
    _write_runtime_log(
        log,
        [
            _runtime_log_line(
                job,
                event="INIT",
                timestamp="2020-01-02T00:00:00",
                magic=magic,
                payload={"magic": magic, "symbol": job.symbol},
            ),
            _runtime_log_line(
                job,
                event="INIT_OK",
                timestamp="2020-01-02T00:00:00",
                magic=magic,
                payload={},
            ),
            _runtime_log_line(
                job,
                event="ENTRY_ACCEPTED",
                timestamp=entry_text,
                magic=magic,
                payload={
                    "ticket": 2,
                    "symbol": job.symbol,
                    "type": "QM_BUY",
                    "lots": 0.1,
                    "price": 1800.25,
                    "magic": magic,
                    "reason": "SIGNAL",
                },
            ),
            _runtime_log_line(
                job,
                event="EQUITY_SNAPSHOT",
                timestamp=equity_text,
                magic=magic,
                payload={
                    "day_key": 20200102,
                    "month_key": 202001,
                    "equity": 100001,
                    "day_pnl": 1,
                    "month_pnl": 1,
                    "atr_regime": "normal",
                    "symbol": job.symbol,
                },
            ),
            _runtime_log_line(
                job,
                event="TM_CLOSE",
                timestamp=exit_text,
                magic=magic,
                payload={
                    "ticket": 2,
                    "symbol": job.symbol,
                    "lots": 0.1,
                    "reason": "QM_EXIT_FRIDAY_CLOSE",
                    "partial": False,
                    "ok": True,
                },
            ),
        ],
    )
    q08 = [
        {
            "event": "TRADE_CLOSED",
            "entry_time": subject._runtime_log_timestamp(entry_text),
            "time": subject._runtime_log_timestamp(exit_text),
            "symbol": job.symbol,
            "magic": magic,
            "volume": 0.1,
            "profit": 10,
            "net": 9,
        }
    ]
    return job, subject.parse_runtime_log_strict(log, job), q08


def test_runtime_log_q08_binding_never_mistakes_requested_price_for_fill(
    tmp_path: Path,
) -> None:
    _job_value, parsed, q08 = _complete_runtime_evidence(tmp_path)
    binding = subject.bind_runtime_telemetry_to_q08(q08, parsed)
    identity = subject.target_reproducibility_identity(
        q08, runtime_telemetry=parsed, telemetry_binding=binding
    )

    assert parsed["status"] == "PASS"
    assert binding["entry_join_complete"] is True
    assert binding["entries_complete"] is False
    assert "ENTRY_FILL_PRICE_NOT_EMITTED" in binding["blockers"]
    assert binding["exit_join_complete"] is True
    assert binding["exits_complete"] is False
    assert binding["magic_cross_stream_consistent"] is True
    assert binding["authoritative_expected_magic_bound"] is False
    assert identity["entries"]["complete"] is False
    assert "ENTRY_FILL_PRICE_NOT_EMITTED" in identity["entries"]["reasons"]
    assert identity["exits"]["complete"] is False
    assert "AUTHORITATIVE_EXPECTED_MAGIC_NOT_HASH_BOUND" in identity["exits"][
        "reasons"
    ]
    assert identity["daily_mtm"]["count"] == 1
    assert identity["daily_mtm"]["complete"] is False


def test_expected_magic_closes_only_bijective_exit_axis(tmp_path: Path) -> None:
    job, parsed, q08 = _complete_runtime_evidence(
        tmp_path, expected_magic=15560004
    )

    binding = subject.bind_runtime_telemetry_to_q08(
        q08, parsed, expected_magic=job.expected_magic
    )
    identity = subject.target_reproducibility_identity(
        q08, runtime_telemetry=parsed, telemetry_binding=binding
    )

    assert parsed["status"] == "PASS"
    assert parsed["identity"]["observed_magic_matches_expected"] is True
    assert binding["authoritative_expected_magic_bound"] is True
    assert binding["entries_complete"] is False
    assert binding["exits_complete"] is True
    assert binding["status"] == "INCOMPLETE"
    assert "ENTRY_FILL_PRICE_NOT_EMITTED" in binding["blockers"]
    assert "AUTHORITATIVE_EXPECTED_MAGIC_NOT_HASH_BOUND" not in binding["blockers"]
    assert identity["entries"]["complete"] is False
    assert identity["exits"]["complete"] is True


def test_target_single_run_accepts_only_the_known_entry_fill_gap_contract(
    tmp_path: Path,
) -> None:
    job, parsed, q08 = _complete_runtime_evidence(
        tmp_path, expected_magic=15560004
    )
    binding = subject.bind_runtime_telemetry_to_q08(
        q08, parsed, expected_magic=job.expected_magic
    )

    assert subject.target_runtime_q08_binding_contract_issues(
        binding, expected_magic=job.expected_magic
    ) == []
    assert subject.target_runtime_q08_binding_blockers(
        binding, expected_magic=job.expected_magic
    ) == []


@pytest.mark.parametrize("axis", ["entries", "exits"])
def test_target_single_run_blocks_missing_bijection_even_when_magic_integrity_passes(
    tmp_path: Path,
    axis: str,
) -> None:
    job, parsed, q08 = _complete_runtime_evidence(
        tmp_path, expected_magic=15560004
    )
    parsed[axis]["sequence"] = []
    binding = subject.bind_runtime_telemetry_to_q08(
        q08, parsed, expected_magic=job.expected_magic
    )

    assert binding["integrity_status"] == "PASS"
    assert binding["status"] == "FAIL"
    contract_blockers = subject.target_runtime_q08_binding_blockers(
        binding, expected_magic=job.expected_magic
    )
    join_blocker = f"Q08_RUNTIME_{'ENTRY' if axis == 'entries' else 'EXIT'}_JOIN_NOT_UNIQUE_BIJECTION"
    assert "RUNTIME_LOG_Q08_BINDING_INVALID" in contract_blockers
    assert join_blocker in contract_blockers
    assert any(
        item.startswith("RUNTIME_LOG_Q08_BINDING_CONTRACT:")
        for item in contract_blockers
    )


@pytest.mark.parametrize(
    ("field", "forged"),
    [
        ("status", "PASS"),
        ("blockers", []),
        ("entries_complete", True),
        ("entry_axis_reasons", []),
        ("exits_complete", False),
        ("expected_magic_valid", False),
        ("authoritative_expected_magic_bound", False),
    ],
)
def test_target_single_run_binding_contract_rejects_self_report_drift(
    tmp_path: Path,
    field: str,
    forged,
) -> None:
    job, parsed, q08 = _complete_runtime_evidence(
        tmp_path, expected_magic=15560004
    )
    binding = subject.bind_runtime_telemetry_to_q08(
        q08, parsed, expected_magic=job.expected_magic
    )
    binding[field] = forged

    blockers = subject.target_runtime_q08_binding_blockers(
        binding, expected_magic=job.expected_magic
    )

    assert "RUNTIME_LOG_Q08_BINDING_INVALID" in blockers
    assert any(
        item == f"RUNTIME_LOG_Q08_BINDING_CONTRACT:FIELD_MISMATCH:{field}"
        for item in blockers
    )


def test_self_consistent_wrong_log_and_q08_magic_rejected_by_expected_magic(
    tmp_path: Path,
) -> None:
    job, parsed_without_authority, q08 = _complete_runtime_evidence(tmp_path)
    wrong_expected = 15560005
    parsed_with_authority = subject.parse_runtime_log_strict(
        tmp_path / "runtime.log",
        dataclasses.replace(job, expected_magic=wrong_expected),
    )
    binding = subject.bind_runtime_telemetry_to_q08(
        q08, parsed_without_authority, expected_magic=wrong_expected
    )

    assert parsed_with_authority["status"] == "FAIL"
    assert any(
        "EXPECTED_MAGIC_HEADER_MISMATCH" in error
        for error in parsed_with_authority["errors"]
    )
    assert any(
        "EXPECTED_MAGIC_PAYLOAD_MISMATCH" in error
        for error in parsed_with_authority["errors"]
    )
    assert binding["authoritative_expected_magic_bound"] is False
    assert binding["integrity_status"] == "FAIL"
    assert "RUNTIME_EXPECTED_MAGIC_IDENTITY_MISMATCH" in binding["blockers"]
    assert "Q08_EXPECTED_MAGIC_IDENTITY_MISMATCH" in binding["blockers"]
    assert binding["exits_complete"] is False


@pytest.mark.parametrize("mode", ["missing", "ambiguous", "partial"])
def test_runtime_log_q08_binding_rejects_non_bijective_event_join(
    tmp_path: Path,
    mode: str,
) -> None:
    _job_value, parsed, q08 = _complete_runtime_evidence(tmp_path)
    if mode == "missing":
        parsed["entries"]["sequence"] = []
    elif mode == "ambiguous":
        parsed["entries"]["sequence"].append(parsed["entries"]["sequence"][0])
    else:
        q08.append(dict(q08[0], time=q08[0]["time"] + 60, volume=0.05))

    binding = subject.bind_runtime_telemetry_to_q08(q08, parsed)

    assert binding["status"] == "FAIL"
    assert any("JOIN_NOT_UNIQUE_BIJECTION" in item for item in binding["blockers"])


def test_runtime_log_q08_binding_wrong_magic_never_closes_axes(tmp_path: Path) -> None:
    _job_value, parsed, q08 = _complete_runtime_evidence(tmp_path)
    q08[0]["magic"] += 1

    binding = subject.bind_runtime_telemetry_to_q08(q08, parsed)
    identity = subject.target_reproducibility_identity(
        q08, runtime_telemetry=parsed, telemetry_binding=binding
    )

    assert binding["magic_cross_stream_consistent"] is False
    assert "Q08_RUNTIME_MAGIC_IDENTITY_MISMATCH" in binding["blockers"]
    assert identity["entries"]["complete"] is False
    assert identity["exits"]["complete"] is False
