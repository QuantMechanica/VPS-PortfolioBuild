"""Cryptographic portfolio-stream provenance emitted by the Q08 aggregate."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from framework.scripts.q08_davey import aggregate as q08


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_stream_identity_binds_emitted_bytes_source_and_report(tmp_path: Path) -> None:
    stream = tmp_path / "durable.jsonl"
    host = tmp_path / "host.jsonl"
    source = tmp_path / "common.jsonl"
    report = tmp_path / "report.htm"
    summary = tmp_path / "summary.json"
    stream_bytes = (
        b'{"event":"TRADE_CLOSED","time":1,"net":2.0,"volume":0.1}\n'
        b'{"event":"TRADE_CLOSED","time":2,"net":-1.0,"volume":0.1}\n'
    )
    stream.write_bytes(stream_bytes)
    host.write_bytes(stream_bytes)
    source.write_bytes(stream_bytes)
    report.write_text("<html>bound report</html>", encoding="utf-8")
    summary.write_text('{"evidence_schema":"run_smoke/v2"}', encoding="utf-8")

    bound = q08._bind_portfolio_stream_identity(
        ea_id=1001,
        symbol="EURUSD.DWX",
        portfolio_stream={
            "persisted": True,
            "path": str(stream),
            "host_copy": str(host),
            "n": 2,
        },
        source_kind="fresh_baseline_common_stream",
        source_path=source,
        baseline_run={
            "baseline_report_path": str(report),
            "baseline_summary_path": str(summary),
            "baseline_ex5_path": str(tmp_path / "expert.ex5"),
            "baseline_ex5_sha256": "a" * 64,
            "baseline_setfile_path": str(tmp_path / "baseline.set"),
            "baseline_setfile_sha256": "b" * 64,
            "baseline_mq5_path": str(tmp_path / "expert.mq5"),
            "baseline_mq5_sha256": "c" * 64,
        },
    )

    assert bound["identity_schema"] == "q08_portfolio_stream/v2"
    assert bound["content_sha256"] == _sha(stream)
    assert bound["host_copy_sha256"] == _sha(host)
    assert bound["source_artifact_sha256"] == _sha(source)
    assert bound["source_report_sha256"] == _sha(report)
    assert bound["source_summary_sha256"] == _sha(summary)
    assert bound["source_ex5_sha256"] == "a" * 64
    assert bound["source_setfile_sha256"] == "b" * 64
    assert bound["source_mq5_sha256"] == "c" * 64
    assert bound["content_row_count"] == 2
    assert bound["identity_status"] == "BOUND_STREAM_BUILD_SETFILE_SOURCE_AND_REPORT"
    assert len(bound["identity_sha256"]) == 64

    report.write_text("<html>different report</html>", encoding="utf-8")
    rebound = q08._bind_portfolio_stream_identity(
        ea_id=1001,
        symbol="EURUSD.DWX",
        portfolio_stream={
            "persisted": True,
            "path": str(stream),
            "host_copy": str(host),
            "n": 2,
        },
        source_kind="fresh_baseline_common_stream",
        source_path=source,
        baseline_run={
            "baseline_report_path": str(report),
            "baseline_summary_path": str(summary),
            "baseline_ex5_sha256": "a" * 64,
            "baseline_setfile_sha256": "b" * 64,
            "baseline_mq5_sha256": "c" * 64,
        },
    )
    assert rebound["source_report_sha256"] != bound["source_report_sha256"]
    assert rebound["identity_sha256"] != bound["identity_sha256"]


def test_missing_report_is_explicit_not_an_invented_binding(tmp_path: Path) -> None:
    stream = tmp_path / "durable.jsonl"
    source = tmp_path / "input.jsonl"
    stream.write_text('{"event":"TRADE_CLOSED","volume":0.1}\n', encoding="utf-8")
    source.write_bytes(stream.read_bytes())

    bound = q08._bind_portfolio_stream_identity(
        ea_id=1001,
        symbol="EURUSD.DWX",
        portfolio_stream={"persisted": True, "path": str(stream), "n": 1},
        source_kind="input_log",
        source_path=source,
        baseline_run=None,
    )

    assert bound["content_sha256"] == _sha(stream)
    assert bound["source_artifact_sha256"] == _sha(source)
    assert bound["source_report_sha256"] is None
    assert bound["source_report_binding"] == "not_available_for_recorded_source"
    assert bound["identity_status"] == "BOUND_STREAM_AND_SOURCE_REPORT_UNAVAILABLE"
    assert len(bound["identity_sha256"]) == 64


def test_baseline_metadata_binds_completed_run_not_invalid_warmup(tmp_path: Path) -> None:
    invalid_report = tmp_path / "invalid.htm"
    completed_report = tmp_path / "completed.htm"
    invalid_report.write_text("cold", encoding="utf-8")
    completed_report.write_text("completed", encoding="utf-8")
    summary = tmp_path / "summary.json"
    summary.write_text(
        json.dumps(
            {
                "result": "PASS",
                "execution_identity": {
                    "expert_binary": {
                        "deployed": {"path": "expert.ex5", "sha256": "a" * 64}
                    },
                    "setfile": {
                        "source": {"path": "baseline.set", "sha256": "b" * 64}
                    },
                    "mq5_source": {"path": "expert.mq5", "sha256": "c" * 64},
                },
                "runs": [
                    {
                        "status": "INVALID",
                        "report_canonical_path": str(invalid_report),
                        "report_sha256": _sha(invalid_report),
                    },
                    {
                        "status": "OK",
                        "report_canonical_path": str(completed_report),
                        "report_sha256": _sha(completed_report),
                        "total_trades": 22,
                    },
                ],
            }
        ),
        encoding="utf-8",
    )

    metadata = q08._baseline_report_metadata(summary)

    assert metadata["baseline_report_path"] == str(completed_report)
    assert metadata["baseline_report_sha256"] == _sha(completed_report)
    assert metadata["baseline_ex5_sha256"] == "a" * 64
    assert metadata["baseline_setfile_sha256"] == "b" * 64
    assert metadata["baseline_mq5_sha256"] == "c" * 64
    assert metadata["baseline_total_trades"] == 22


def test_unpersisted_stream_has_no_cryptographic_identity() -> None:
    bound = q08._bind_portfolio_stream_identity(
        ea_id=1001,
        symbol="EURUSD.DWX",
        portfolio_stream={"persisted": False, "reason": "no_trades", "n": 0},
        source_kind=None,
        source_path=None,
        baseline_run=None,
    )

    assert bound["identity_status"] == "UNAVAILABLE_STREAM_NOT_PERSISTED"
    assert bound["content_sha256"] is None
    assert bound["identity_sha256"] is None
