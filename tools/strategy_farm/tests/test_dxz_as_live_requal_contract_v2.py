from __future__ import annotations

import json
from pathlib import Path

import pytest

from tools.strategy_farm import dxz_as_live_requal as subject


def _row(*, entry: int, close: int, profit: float = 1.0) -> dict:
    return {
        "event": "TRADE_CLOSED",
        "entry_time": entry,
        "time": close,
        "symbol": "EURUSD.DWX",
        "profit": profit,
        "net": profit,
    }


def _write_stream(path: Path, rows: list[dict]) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "".join(json.dumps(row, sort_keys=True) + "\n" for row in rows),
        encoding="utf-8",
    )
    return path


def _job(tmp_path: Path, reference: Path | None = None) -> subject.Job:
    ex5 = tmp_path / "source.ex5"
    preset = tmp_path / "source.set"
    ex5.write_bytes(b"ex5")
    preset.write_text(
        "; environment: live\nRISK_FIXED=0\nRISK_PERCENT=0.1\nPORTFOLIO_WEIGHT=1\n",
        encoding="utf-8",
    )
    return subject.Job(
        ordinal=1,
        ea_id=7001,
        symbol="EURUSD.DWX",
        ea_label="QM5_7001_test",
        timeframe="H1",
        live_ex5=ex5,
        live_preset=preset,
        manifest_trades=1,
        reference_stream=reference,
        set_file_expectation={
            "ENV": "live",
            "RISK_FIXED": 0,
            "RISK_PERCENT": 0.1,
            "PORTFOLIO_WEIGHT": 1,
        },
        manifest_risk_percent=0.1,
    )


def _snapshot(tmp_path: Path, job: subject.Job, rows: list[dict]) -> tuple[Path, Path, str]:
    root = tmp_path / "snapshot"
    # Deliberately not the legacy guessed filename: selected.frozen_relative_path
    # is the sole source of truth.
    stream = _write_stream(root / "streams" / "selected" / "opaque.jsonl", rows)
    source_sha = "c" * 64
    manifest_payload = {
        "schema_version": 1,
        "status": "PASS",
        "source_manifest": {"sha256": source_sha},
        "sleeves": [
            {
                "key": job.key,
                "selected": {
                    "frozen_relative_path": "streams/selected/opaque.jsonl",
                    "frozen_sha256": subject.sha256_file(stream),
                },
            }
        ],
    }
    manifest = root / "reference_stream_manifest.json"
    manifest.write_text(json.dumps(manifest_payload), encoding="utf-8")
    (root / "seal.sha256").write_text(
        f"{subject.sha256_file(manifest)}  reference_stream_manifest.json\n"
        f"{subject.sha256_file(stream)}  streams/selected/opaque.jsonl\n",
        encoding="ascii",
    )
    return root, stream, source_sha


def test_snapshot_and_stream_cli_layouts_have_same_canonical_identity_and_selection(
    tmp_path: Path,
) -> None:
    provisional = _job(tmp_path)
    row = _row(entry=1_704_067_200, close=1_704_070_800)
    root, stream, source_sha = _snapshot(tmp_path, provisional, [row])

    from_snapshot, rows_a = subject.verify_reference_snapshot(
        root, source_manifest_sha256=source_sha
    )
    from_streams, rows_b = subject.verify_reference_snapshot(
        root / "streams", source_manifest_sha256=source_sha
    )

    assert from_snapshot["seal_verified"] is True
    assert from_snapshot["canonical_identity_sha256"] == from_streams[
        "canonical_identity_sha256"
    ]
    assert rows_a == rows_b
    [bound] = subject.bind_jobs_to_reference_snapshot(
        [provisional], snapshot=from_snapshot, snapshot_rows=rows_a
    )
    assert bound.reference_stream == stream.resolve()
    assert bound.reference_frozen_relative_path == "streams/selected/opaque.jsonl"


def test_reference_window_preflight_allows_later_clean_start_and_rejects_boundary_breaches(
    tmp_path: Path,
) -> None:
    provisional = _job(tmp_path)
    # 2024-01-02 -> 2024-01-03 sits safely inside the effective window.
    valid = _row(entry=1_704_153_600, close=1_704_240_000)
    root, _stream, source_sha = _snapshot(tmp_path, provisional, [valid])
    snapshot, rows = subject.verify_reference_snapshot(root, source_manifest_sha256=source_sha)
    [job] = subject.bind_jobs_to_reference_snapshot(
        [provisional], snapshot=snapshot, snapshot_rows=rows
    )
    window = subject.build_window_contract(
        "2023.01.01", "2024.12.31", effective_from="2024.01.01"
    )
    assert subject.reference_preflight_blockers(
        job, snapshot=snapshot, snapshot_rows=rows, window_contract=window
    ) == []

    before = _row(entry=1_703_980_799, close=1_704_240_000)
    root2, _stream2, source_sha2 = _snapshot(tmp_path / "before", provisional, [before])
    snapshot2, rows2 = subject.verify_reference_snapshot(
        root2, source_manifest_sha256=source_sha2
    )
    [job2] = subject.bind_jobs_to_reference_snapshot(
        [provisional], snapshot=snapshot2, snapshot_rows=rows2
    )
    assert "REFERENCE_ENTRY_BEFORE_EFFECTIVE_WINDOW" in subject.reference_preflight_blockers(
        job2, snapshot=snapshot2, snapshot_rows=rows2, window_contract=window
    )

    after = _row(entry=1_704_153_600, close=1_735_689_600)
    root3, _stream3, source_sha3 = _snapshot(tmp_path / "after", provisional, [after])
    snapshot3, rows3 = subject.verify_reference_snapshot(
        root3, source_manifest_sha256=source_sha3
    )
    [job3] = subject.bind_jobs_to_reference_snapshot(
        [provisional], snapshot=snapshot3, snapshot_rows=rows3
    )
    assert "REFERENCE_CLOSE_AFTER_EFFECTIVE_WINDOW" in subject.reference_preflight_blockers(
        job3, snapshot=snapshot3, snapshot_rows=rows3, window_contract=window
    )


def test_identity_empty_is_incomplete_and_outcome_comparison_is_independent() -> None:
    empty = subject.signal_identity_stats([])
    assert empty["complete"] is False
    assert empty["row_count"] == 0
    assert empty["valid_identity_rows"] == 0
    assert empty["invalid_identity_rows"] == 0

    left = subject.signal_identity_stats(
        [_row(entry=100, close=200, profit=1), _row(entry=300, close=400, profit=-1)]
    )
    different_closes_same_signs = subject.signal_identity_stats(
        [_row(entry=100, close=201, profit=100), _row(entry=300, close=401, profit=-0.01)]
    )
    comparison = subject.compare_signal_identity(left, different_closes_same_signs)
    assert comparison == {"identity_match": False, "outcome_sign_match": True}


def test_cost_evidence_never_certifies_degraded_or_unknown_metrics(tmp_path: Path) -> None:
    registry = tmp_path / "cost.json"
    registry.write_text('{"cost":"bound"}\n', encoding="utf-8")
    certified = subject.build_cost_evidence(
        {
            "commission_model": {
                "registry_path": str(registry),
                "degraded": False,
                "degraded_symbols": [],
                "unknown_symbols": [],
            }
        }
    )
    assert certified["status"] == "NOT_EVALUATED"
    assert certified["cost_certified"] is False
    assert "EXECUTION_COST_EVIDENCE_MANIFEST_MISSING" in certified["reasons"]
    assert certified["registry_sha256"] == subject.sha256_file(registry)

    degraded = subject.build_cost_evidence(
        {
            "commission_model": {
                "registry_path": str(registry),
                "degraded": True,
                "degraded_symbols": ["EURUSD.DWX"],
                "unknown_symbols": [],
            }
        }
    )
    assert degraded["status"] == "NOT_EVALUATED"
    assert degraded["cost_certified"] is False
    assert "DEGRADED_SYMBOL_COSTS" in degraded["legacy_commission_model"]["reasons"]
    assert subject.build_cost_evidence({})["status"] == "NOT_EVALUATED"


def test_native_report_execution_header_is_bound_and_real_ticks_are_required(
    tmp_path: Path,
) -> None:
    report = tmp_path / "report.htm"
    report.write_text(
        "<table><tr><td>History Quality:</td><td><b>100% real ticks</b></td></tr>"
        "<tr><td>Bars:</td><td>12,345</td><td>Ticks:</td><td>98,765</td>"
        "<td>Symbols:</td><td>2</td></tr></table>",
        encoding="utf-16",
    )
    evidence = subject.parse_native_report_execution_evidence(report)
    assert evidence == {
        "history_quality": "100% real ticks",
        "history_quality_normalized": "100% real ticks",
        "bars": 12345,
        "ticks": 98765,
        "symbol_count": 2,
        "real_ticks_certified": True,
        "errors": [],
    }
    report.write_text(
        "<table><tr><td>History Quality:</td><td>99.9%</td></tr>"
        "<tr><td>Bars:</td><td>1</td><td>Ticks:</td><td>2</td>"
        "<td>Symbols:</td><td>1</td></tr></table>",
        encoding="utf-16",
    )
    evidence = subject.parse_native_report_execution_evidence(report)
    assert evidence["real_ticks_certified"] is False
    assert "HISTORY_QUALITY_NOT_100_PERCENT_REAL_TICKS" in evidence["errors"]


def test_modes_pin_as_live_and_discovery_requires_hash_bound_overrides(tmp_path: Path) -> None:
    reference = tmp_path / "sealed"
    with pytest.raises(subject.RequalError, match="pins the canonical"):
        subject.validate_qualification_contract(
            qualification_mode="AS_LIVE_REQUAL",
            live_root=tmp_path / "fake-live",
            reference_stream_root=reference,
            artifact_override_manifest=None,
        )
    subject.validate_qualification_contract(
        qualification_mode="AS_LIVE_REQUAL",
        live_root=subject.DEFAULT_LIVE_ROOT,
        reference_stream_root=reference,
        artifact_override_manifest=None,
    )
    with pytest.raises(subject.RequalError, match="requires --artifact"):
        subject.validate_qualification_contract(
            qualification_mode="DISCOVERY_COMPLETE_UNREFERENCED",
            live_root=tmp_path,
            reference_stream_root=None,
            artifact_override_manifest=None,
        )

    ex5 = tmp_path / "candidate.ex5"
    preset = tmp_path / "candidate.set"
    ex5.write_bytes(b"candidate")
    preset.write_text("x=1\n", encoding="utf-8")
    override = tmp_path / "override.json"
    override.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "qualification_mode": "DISCOVERY_COMPLETE_UNREFERENCED",
                "artifacts": [
                    {
                        "ea_id": 7001,
                        "symbol": "EURUSD.DWX",
                        "timeframe": "H1",
                        "ex5": {"path": str(ex5), "sha256": subject.sha256_file(ex5)},
                        "set": {
                            "path": str(preset),
                            "sha256": subject.sha256_file(preset),
                        },
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    metadata, rows = subject.load_artifact_override_manifest(override)
    assert metadata["sha256"] == subject.sha256_file(override)
    assert rows["7001:EURUSD.DWX:H1"]["timeframe"] == "H1"
    subject.validate_qualification_contract(
        qualification_mode="DISCOVERY_COMPLETE_UNREFERENCED",
        live_root=tmp_path,
        reference_stream_root=None,
        artifact_override_manifest=override,
    )
    ex5.write_bytes(b"tampered")
    with pytest.raises(subject.RequalError, match="hash mismatch"):
        subject.load_artifact_override_manifest(override)


def test_discovery_summary_is_nonqualifying_even_after_technical_pass(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    manifest = tmp_path / "manifest.json"
    manifest.write_text('{"n_sleeves":1,"sleeves":[]}', encoding="utf-8")
    override = tmp_path / "override.json"
    override.write_text("{}", encoding="utf-8")
    output = tmp_path / "out"
    job = _job(tmp_path)

    monkeypatch.setattr(subject, "validate_sandbox_root", lambda path: Path(path).resolve())
    monkeypatch.setattr(subject, "validate_output_root", lambda path, _live: Path(path).resolve())
    monkeypatch.setattr(subject, "validate_common_root", lambda path, execute: Path(path).resolve())
    monkeypatch.setattr(subject, "validate_qualification_contract", lambda **_kwargs: None)
    monkeypatch.setattr(
        subject,
        "load_artifact_override_manifest",
        lambda _path, **_kwargs: (
            {
                "path": str(override),
                "sha256": subject.sha256_file(override),
                "qualification_mode": "DISCOVERY_COMPLETE_UNREFERENCED",
                "rows": 1,
            },
            {job.key: {}},
        ),
    )
    monkeypatch.setattr(
        subject,
        "build_jobs",
        lambda *_args, **_kwargs: ({"status": "DRAFT"}, [job]),
    )
    monkeypatch.setattr(
        subject,
        "execute_book",
        lambda *_args, **_kwargs: [
            {
                "schema_version": 2,
                "status": "NONQUALIFYING",
                "technical_status": "PASS",
                "qualification_mode": "DISCOVERY_COMPLETE_UNREFERENCED",
                "qualification_status": "NONQUALIFYING_DISCOVERY",
                "deployment_eligible": False,
                "job": {"ordinal": 1, "ea_id": 7001, "symbol": "EURUSD.DWX"},
                "cost_evidence": {
                    "status": "CERTIFIED",
                    "cost_certified": True,
                    "reasons": [],
                    "registry_path": str(subject.DEFAULT_COST_REGISTRY.resolve()),
                    "registry_sha256": subject.sha256_file(subject.DEFAULT_COST_REGISTRY),
                    "unknown_symbols": [],
                    "degraded_symbols": [],
                },
            }
        ],
    )

    return_code = subject.main(
        [
            "--manifest",
            str(manifest),
            "--live-root",
            str(tmp_path / "discovery-source"),
            "--sandbox-root",
            str(tmp_path / "DXZ_Truth_1"),
            "--common-root",
            str(tmp_path / "common"),
            "--output-dir",
            str(output),
            "--qualification-mode",
            "DISCOVERY_COMPLETE_UNREFERENCED",
            "--artifact-override-manifest",
            str(override),
            "--execute",
        ]
    )

    assert return_code == 0
    summary_path = next(output.glob("*/summary.json"))
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    assert summary["schema_version"] == 2
    assert summary["status"] == "NONQUALIFYING_DISCOVERY"
    assert summary["technical_status"] == "PASS"
    assert summary["qualification_status"] == "NONQUALIFYING_DISCOVERY"
    assert summary["deployment_eligible"] is False
    assert summary["qualification_mode"] == "DISCOVERY_COMPLETE_UNREFERENCED"
