from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import q08_durable_stream_export as dse


def _sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _write(path: Path, data: bytes) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return _sha_bytes(data)


SEALED = b'{"event":"TRADE_CLOSED","time":1,"net":10.0,"volume":1.0}\n'
OTHER = b'{"event":"TRADE_CLOSED","time":2,"net":20.0,"volume":1.0}\n'


# --------------------------------------------------------------------------- #
# export_sealed_stream
# --------------------------------------------------------------------------- #

def test_seal_path_exports_and_records_when_durable_present(tmp_path):
    """Common seal path: the recorded durable file already holds the sealed bytes."""
    stream = tmp_path / "QM" / "q08_trades" / "9001_EURUSD_DWX.jsonl"
    sha = _write(stream, SEALED)
    block = {
        "persisted": True,
        "path": str(stream),
        "content_sha256": sha,
        "source_artifact_path": str(tmp_path / "common" / "9001_EURUSD_DWX.jsonl"),
        "n": 1,
    }
    out = dse.export_sealed_stream(block)
    assert out is block  # mutated in place
    assert block["durable_export_status"] == "EXPORTED"
    assert block["durable_path"] == str(stream)
    assert block["durable_sha256"] == sha
    assert isinstance(block["exported_at"], str) and block["exported_at"]
    # idempotent no-op: no sibling created, the original file is untouched
    assert dse.sha256_file(stream) == sha
    assert sorted(p.name for p in stream.parent.glob("*.jsonl")) == ["9001_EURUSD_DWX.jsonl"]


def test_seal_path_copies_from_source_when_durable_absent(tmp_path):
    """Recorded path absent, but the volatile source artifact still holds the bytes."""
    stream = tmp_path / "QM" / "q08_trades" / "9001_EURUSD_DWX.jsonl"  # not written
    source = tmp_path / "common" / "9001_EURUSD_DWX.jsonl"
    sha = _write(source, SEALED)
    block = {
        "persisted": True,
        "path": str(stream),
        "content_sha256": sha,
        "source_artifact_path": str(source),
    }
    dse.export_sealed_stream(block)
    assert block["durable_export_status"] == "EXPORTED"
    assert block["durable_path"] == str(stream)
    assert stream.is_file()
    assert dse.sha256_file(stream) == sha


def test_sha_mismatch_source_is_refused_no_write(tmp_path):
    """Source artifact exists but hashes differently -> refuse; write nothing."""
    stream = tmp_path / "QM" / "q08_trades" / "9002_USDCAD_DWX.jsonl"  # absent
    source = tmp_path / "common" / "9002_USDCAD_DWX.jsonl"
    _write(source, OTHER)  # real bytes, but not the sealed ones
    sealed_sha = _sha_bytes(SEALED)
    block = {
        "persisted": True,
        "path": str(stream),
        "content_sha256": sealed_sha,
        "source_artifact_path": str(source),
    }
    dse.export_sealed_stream(block)
    assert block["durable_export_status"] == "WARN_SEALED_BYTES_UNAVAILABLE"
    assert "durable_path" not in block
    assert not stream.exists()


def test_missing_source_is_warning_not_failure(tmp_path):
    """No durable file and no source artifact -> structured warning, never raises."""
    warnings: list[dict] = []
    stream = tmp_path / "QM" / "q08_trades" / "9003_XTIUSD_DWX.jsonl"  # absent
    block = {
        "persisted": True,
        "path": str(stream),
        "content_sha256": _sha_bytes(SEALED),
        "source_artifact_path": str(tmp_path / "common" / "gone.jsonl"),  # absent
    }
    out = dse.export_sealed_stream(block, logger=warnings.append)
    assert out is block
    assert block["durable_export_status"] == "WARN_SEALED_BYTES_UNAVAILABLE"
    assert "durable_path" not in block
    assert warnings and warnings[0]["status"] == "WARN_SEALED_BYTES_UNAVAILABLE"


def test_append_only_sibling_when_recorded_path_differs(tmp_path):
    """Recorded path holds DIFFERENT bytes -> never overwrite; write a sha-suffixed sibling."""
    stream = tmp_path / "QM" / "q08_trades" / "9004_XAGUSD_DWX.jsonl"
    other_sha = _write(stream, OTHER)  # a newer re-grade already clobbered the pointer
    source = tmp_path / "common" / "9004_XAGUSD_DWX.jsonl"
    sealed_sha = _write(source, SEALED)  # the old seal's bytes survive at the source
    assert sealed_sha != other_sha
    block = {
        "persisted": True,
        "path": str(stream),
        "content_sha256": sealed_sha,
        "source_artifact_path": str(source),
    }
    dse.export_sealed_stream(block)
    assert block["durable_export_status"] == "EXPORTED_SIBLING"
    sibling = stream.with_name(f"9004_XAGUSD_DWX.{sealed_sha[:16]}.jsonl")
    assert block["durable_path"] == str(sibling)
    assert block["durable_sha256"] == sealed_sha
    assert sibling.is_file() and dse.sha256_file(sibling) == sealed_sha
    # the mutable pointer was NOT overwritten
    assert dse.sha256_file(stream) == other_sha


def test_not_persisted_is_skipped_without_fields(tmp_path):
    block = {"persisted": False, "reason": "no_trades", "n": 0}
    dse.export_sealed_stream(block)
    assert block["durable_export_status"] == "SKIPPED_NOT_PERSISTED"
    assert "durable_path" not in block


def test_export_never_raises_on_bad_input():
    # non-dict input returns unchanged, no exception
    assert dse.export_sealed_stream(None) is None
    assert dse.export_sealed_stream("nope") == "nope"


def test_no_content_sha_is_skipped(tmp_path):
    block = {"persisted": True, "path": str(tmp_path / "x.jsonl"), "content_sha256": ""}
    dse.export_sealed_stream(block)
    assert block["durable_export_status"] == "SKIPPED_NO_CONTENT_SHA"


# --------------------------------------------------------------------------- #
# backfill
# --------------------------------------------------------------------------- #

def _make_db(db_path: Path) -> sqlite3.Connection:
    con = sqlite3.connect(db_path)
    con.execute(
        "CREATE TABLE work_items (id TEXT, kind TEXT, phase TEXT, ea_id TEXT, symbol TEXT, "
        "status TEXT, verdict TEXT, evidence_path TEXT, payload_json TEXT, ex5_sha256 TEXT, "
        "updated_at TEXT)"
    )
    return con


def _q08(con, wid, ea, symbol, aggregate_path, verdict="PASS"):
    con.execute(
        "INSERT INTO work_items (id, phase, ea_id, symbol, status, verdict, evidence_path, updated_at) "
        "VALUES (?, 'Q08', ?, ?, 'done', ?, ?, '2026-09-01T00:00:00Z')",
        (wid, ea, symbol, verdict, str(aggregate_path)),
    )


def _aggregate(path: Path, *, content_sha: str, stream_path: Path, source_path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "verdict": "PASS",
        "portfolio_stream": {
            "persisted": True,
            "source": "common_copy",
            "path": str(stream_path),
            "content_sha256": content_sha,
            "source_artifact_path": str(source_path),
            "identity_schema": "q08_portfolio_stream/v2",
        },
    }
    path.write_text(json.dumps(payload), encoding="utf-8")


@pytest.fixture()
def backfill_layout(tmp_path):
    ev = tmp_path / "reports" / "work_items"
    seal_dir = tmp_path / "reports" / "portfolio" / "sleeve_streams" / "QM" / "q08_trades"
    common = tmp_path / "common"
    db_path = tmp_path / "farm_state.sqlite"
    con = _make_db(db_path)

    # (ok) durable bytes were lost; source artifact still holds them, sha matches.
    stream_ok = seal_dir / "9001_EURUSD_DWX.jsonl"  # NOT written (lost)
    src_ok = common / "9001_EURUSD_DWX.jsonl"
    sha_ok = _write(src_ok, SEALED)
    agg_ok = ev / "wi_ok" / "aggregate.json"
    _aggregate(agg_ok, content_sha=sha_ok, stream_path=stream_ok, source_path=src_ok)
    _q08(con, "q08_ok", "QM5_9001", "EURUSD.DWX", agg_ok)

    # (missing) source artifact gone.
    stream_gone = seal_dir / "9002_USDCAD_DWX.jsonl"
    src_gone = common / "9002_USDCAD_DWX.jsonl"  # NOT written
    agg_gone = ev / "wi_gone" / "aggregate.json"
    _aggregate(agg_gone, content_sha=_sha_bytes(SEALED), stream_path=stream_gone, source_path=src_gone)
    _q08(con, "q08_gone", "QM5_9002", "USDCAD.DWX", agg_gone)

    # (mismatch) source artifact present but hashes differently.
    stream_mm = seal_dir / "9003_XTIUSD_DWX.jsonl"
    src_mm = common / "9003_XTIUSD_DWX.jsonl"
    _write(src_mm, OTHER)
    agg_mm = ev / "wi_mm" / "aggregate.json"
    _aggregate(agg_mm, content_sha=_sha_bytes(SEALED), stream_path=stream_mm, source_path=src_mm)
    _q08(con, "q08_mm", "QM5_9003", "XTIUSD.DWX", agg_mm)

    con.commit()
    con.close()
    return {"db_path": db_path, "seal_dir": seal_dir, "agg_ok": agg_ok, "sha_ok": sha_ok}


def test_backfill_re_exports_from_source_writes_only_durable(backfill_layout):
    agg_before = backfill_layout["agg_ok"].read_bytes()
    result = dse.backfill_work_item("q08_ok", db_path=backfill_layout["db_path"])
    assert result["outcome"] == "exported"
    durable = backfill_layout["seal_dir"] / "9001_EURUSD_DWX.jsonl"
    assert result["durable_path"] == str(durable)
    assert result["durable_sha256"] == backfill_layout["sha_ok"]
    assert result["sibling"] is False
    assert durable.is_file() and dse.sha256_file(durable) == backfill_layout["sha_ok"]
    # the aggregate.json was NOT rewritten (writes only the durable file)
    assert backfill_layout["agg_ok"].read_bytes() == agg_before


def test_backfill_missing_source_refused(backfill_layout):
    result = dse.backfill_work_item("q08_gone", db_path=backfill_layout["db_path"])
    assert result["outcome"] == "refused"
    assert result["reason"] == "source_artifact_missing"
    assert not (backfill_layout["seal_dir"] / "9002_USDCAD_DWX.jsonl").exists()


def test_backfill_sha_mismatch_refused(backfill_layout):
    result = dse.backfill_work_item("q08_mm", db_path=backfill_layout["db_path"])
    assert result["outcome"] == "refused"
    assert result["reason"] == "source_artifact_sha_mismatch"
    assert not (backfill_layout["seal_dir"] / "9003_XTIUSD_DWX.jsonl").exists()


def test_backfill_unknown_work_item_refused(backfill_layout):
    result = dse.backfill_work_item("does_not_exist", db_path=backfill_layout["db_path"])
    assert result["outcome"] == "refused"
    assert result["reason"] == "no_q08_work_item"


def test_backfill_writes_sibling_when_pointer_differs(backfill_layout, tmp_path):
    # the recorded durable path already holds a DIFFERENT (newer) stream
    durable = backfill_layout["seal_dir"] / "9001_EURUSD_DWX.jsonl"
    other_sha = _write(durable, OTHER)
    result = dse.backfill_work_item("q08_ok", db_path=backfill_layout["db_path"])
    assert result["outcome"] == "exported"
    assert result["sibling"] is True
    sibling = durable.with_name(f"9001_EURUSD_DWX.{backfill_layout['sha_ok'][:16]}.jsonl")
    assert result["durable_path"] == str(sibling)
    assert sibling.is_file()
    # the newer pointer is untouched
    assert dse.sha256_file(durable) == other_sha


def test_backfill_cli_exit_codes(backfill_layout, capsys):
    rc = dse.main([
        "backfill", "--work-item-id", "q08_ok",
        "--db-path", str(backfill_layout["db_path"]), "--json",
    ])
    assert rc == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["outcome"] == "exported"

    rc = dse.main([
        "backfill", "--work-item-id", "q08_gone",
        "--db-path", str(backfill_layout["db_path"]), "--json",
    ])
    assert rc == 3
