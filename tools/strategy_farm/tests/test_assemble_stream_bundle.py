from __future__ import annotations

import datetime as dt
import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import assemble_stream_bundle as asb
from tools.strategy_farm.portfolio import book_builder_common


def _sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _write_stream(path: Path, symbol: str, *, days: int = 4) -> str:
    """Write a synthetic sealed q08 stream and return its content sha256."""
    path.parent.mkdir(parents=True, exist_ok=True)
    base = dt.datetime(2024, 1, 1, 12, 0, tzinfo=dt.timezone.utc)
    lines = []
    for index in range(days):
        close = base + dt.timedelta(days=index)
        entry = close - dt.timedelta(hours=6)
        record = {
            "event": "TRADE_CLOSED",
            "time": int(close.timestamp()),
            "entry_time": int(entry.timestamp()),
            "net": 100.0 + index,
            "profit": 105.0 + index,
            "swap": -1.0,
            "commission": -2.0,
            "volume": 1.0,
            "notional": 100000.0,
            "symbol": symbol,
        }
        lines.append(json.dumps(record))
    data = ("\n".join(lines) + "\n").encode("utf-8")
    path.write_bytes(data)
    return _sha_bytes(data)


def _make_db(db_path: Path) -> sqlite3.Connection:
    con = sqlite3.connect(db_path)
    con.execute(
        """
        CREATE TABLE work_items (
            id TEXT, kind TEXT, phase TEXT, ea_id TEXT, symbol TEXT,
            status TEXT, verdict TEXT, evidence_path TEXT, payload_json TEXT,
            ex5_sha256 TEXT, updated_at TEXT
        )
        """
    )
    return con


def _q14(con, wid, ea, symbol, ex5, ts, verdict="KEEP_INCUMBENT"):
    con.execute(
        "INSERT INTO work_items (id, phase, ea_id, symbol, status, verdict, ex5_sha256, updated_at) "
        "VALUES (?, 'Q14', ?, ?, 'done', ?, ?, ?)",
        (wid, ea, symbol, verdict, ex5, ts),
    )


def _q08(con, wid, ea, symbol, aggregate_path, ts, verdict="PASS"):
    con.execute(
        "INSERT INTO work_items (id, phase, ea_id, symbol, status, verdict, evidence_path, updated_at) "
        "VALUES (?, 'Q08', ?, ?, 'done', ?, ?, ?)",
        (wid, ea, symbol, verdict, str(aggregate_path), ts),
    )


def _aggregate(path: Path, *, source_ex5: str, content_sha: str, stream_path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "portfolio_stream": {
            "source": "common_copy",
            "path": str(stream_path),
            "identity_schema": "q08_portfolio_stream/v2",
            "content_sha256": content_sha,
            "source_ex5_sha256": source_ex5,
            "source_artifact_path": str(stream_path),
            "identity_status": "BOUND_STREAM_BUILD_SETFILE_SOURCE_AND_REPORT",
        }
    }
    path.write_text(json.dumps(payload), encoding="utf-8")


@pytest.fixture()
def layout(tmp_path: Path):
    """A synthetic evidence layout with one bindable and several unbindable pairs."""
    ev = tmp_path / "reports" / "work_items"
    seal_dir = tmp_path / "reports" / "portfolio" / "sleeve_streams" / "QM" / "q08_trades"
    db_path = tmp_path / "farm_state.sqlite"
    con = _make_db(db_path)

    # (1) BOUND pair: identity -> Q08 seal -> physical file present, hash matches.
    ex5_ok = "a" * 64
    stream_ok = seal_dir / "9001_EURUSD_DWX.jsonl"
    sha_ok = _write_stream(stream_ok, "EURUSD.DWX")
    agg_ok = ev / "wi_ok" / "aggregate.json"
    _aggregate(agg_ok, source_ex5=ex5_ok, content_sha=sha_ok, stream_path=stream_ok)
    _q14(con, "q14_ok", "QM5_9001", "EURUSD.DWX", ex5_ok, "2026-09-01T00:00:00Z")
    _q08(con, "q08_ok", "QM5_9001", "EURUSD.DWX", agg_ok, "2026-09-01T00:00:00Z")

    # (2) REFUSED (bytes gone): seal recorded, but no physical file with that hash.
    ex5_gone = "b" * 64
    missing_stream = seal_dir / "9002_USDCAD_DWX.jsonl"  # never written
    agg_gone = ev / "wi_gone" / "aggregate.json"
    _aggregate(agg_gone, source_ex5=ex5_gone, content_sha=("c" * 64), stream_path=missing_stream)
    _q14(con, "q14_gone", "QM5_9002", "USDCAD.DWX", ex5_gone, "2026-09-01T00:00:00Z")
    _q08(con, "q08_gone", "QM5_9002", "USDCAD.DWX", agg_gone, "2026-09-01T00:00:00Z")

    # (3) REFUSED (hash mismatch): a file exists at the path but its content differs
    #     from the recorded seal -> must not be copied (bind by content, not name).
    ex5_wrong = "d" * 64
    stream_wrong = seal_dir / "9003_XTIUSD_DWX.jsonl"
    _write_stream(stream_wrong, "XTIUSD.DWX")  # real bytes, but seal points elsewhere
    agg_wrong = ev / "wi_wrong" / "aggregate.json"
    _aggregate(agg_wrong, source_ex5=ex5_wrong, content_sha=("e" * 64), stream_path=stream_wrong)
    _q14(con, "q14_wrong", "QM5_9003", "XTIUSD.DWX", ex5_wrong, "2026-09-01T00:00:00Z")
    _q08(con, "q08_wrong", "QM5_9003", "XTIUSD.DWX", agg_wrong, "2026-09-01T00:00:00Z")

    # (4) REFUSED (no Q14 identity): only a Q08 stream, no terminal Q14 row.
    stream_orphan = seal_dir / "9004_XAGUSD_DWX.jsonl"
    sha_orphan = _write_stream(stream_orphan, "XAGUSD.DWX")
    agg_orphan = ev / "wi_orphan" / "aggregate.json"
    _aggregate(agg_orphan, source_ex5="f" * 64, content_sha=sha_orphan, stream_path=stream_orphan)
    _q08(con, "q08_orphan", "QM5_9004", "XAGUSD.DWX", agg_orphan, "2026-09-01T00:00:00Z")

    # (5) REFUSED (identity mismatch): Q14 identity != any Q08 stream's source_ex5.
    stream_mis = seal_dir / "9005_GBPUSD_DWX.jsonl"
    sha_mis = _write_stream(stream_mis, "GBPUSD.DWX")
    agg_mis = ev / "wi_mis" / "aggregate.json"
    _aggregate(agg_mis, source_ex5="1" * 64, content_sha=sha_mis, stream_path=stream_mis)
    _q14(con, "q14_mis", "QM5_9005", "GBPUSD.DWX", "2" * 64, "2026-09-01T00:00:00Z")
    _q08(con, "q08_mis", "QM5_9005", "GBPUSD.DWX", agg_mis, "2026-09-01T00:00:00Z")

    con.commit()
    con.close()

    search_roots = [tmp_path / "reports" / "portfolio" / "sleeve_streams"]
    return {
        "db_path": db_path,
        "search_roots": search_roots,
        "sha_ok": sha_ok,
        "tmp": tmp_path,
    }


def _by_pair(manifest):
    return {f"{item['ea_id']}:{item['symbol']}": item for item in manifest["results"]}


def test_bound_pair_produces_loader_accepted_bundle(layout, tmp_path):
    out_root = tmp_path / "out"
    pairs = [("QM5_9001", "EURUSD.DWX")]
    manifest = asb.assemble_bundle(
        db_path=layout["db_path"],
        out_root=out_root,
        pairs=pairs,
        search_roots=layout["search_roots"],
        verify_loadable=True,
    )
    item = _by_pair(manifest)["QM5_9001:EURUSD.DWX"]
    assert item["outcome"] == "bound"
    assert item["gate"] == "Q08"
    assert item["sha256"] == layout["sha_ok"]
    assert item["q08_work_item_id"] == "q08_ok"
    assert item["q14_work_item_id"] == "q14_ok"
    assert item["identity_ex5_sha256"] == "a" * 64
    bundle_file = out_root / "QM" / "q08_trades" / "9001_EURUSD_DWX.jsonl"
    assert bundle_file.is_file()
    assert asb.sha256_file(bundle_file) == layout["sha_ok"]

    # loader verification passed inside the tool
    assert manifest["loader_verification"]["verified"] is True

    # and the builders' own loader independently accepts the assembled bundle
    daily, provenance = book_builder_common.load_daily(out_root.resolve(), [(9001, "EURUSD.DWX")])
    assert (9001, "EURUSD.DWX") in daily
    assert daily[(9001, "EURUSD.DWX")]  # non-empty daily PnL
    assert provenance["stream_count"] == 1


def test_missing_bytes_pair_refused(layout, tmp_path):
    out_root = tmp_path / "out"
    manifest = asb.assemble_bundle(
        db_path=layout["db_path"],
        out_root=out_root,
        pairs=[("QM5_9002", "USDCAD.DWX")],
        search_roots=layout["search_roots"],
        verify_loadable=True,
    )
    item = _by_pair(manifest)["QM5_9002:USDCAD.DWX"]
    assert item["outcome"] == "refused"
    assert item["reason"] == "sealed_stream_bytes_unavailable"
    assert not (out_root / "QM" / "q08_trades" / "9002_USDCAD_DWX.jsonl").exists()


def test_hash_mismatch_file_refused_not_copied(layout, tmp_path):
    out_root = tmp_path / "out"
    manifest = asb.assemble_bundle(
        db_path=layout["db_path"],
        out_root=out_root,
        pairs=[("QM5_9003", "XTIUSD.DWX")],
        search_roots=layout["search_roots"],
        verify_loadable=True,
    )
    item = _by_pair(manifest)["QM5_9003:XTIUSD.DWX"]
    assert item["outcome"] == "refused"
    assert item["reason"] == "sealed_stream_bytes_unavailable"
    # a name-matching file existed but its content did not match the seal
    assert not (out_root / "QM" / "q08_trades" / "9003_XTIUSD_DWX.jsonl").exists()


def test_no_terminal_identity_refused(layout, tmp_path):
    out_root = tmp_path / "out"
    manifest = asb.assemble_bundle(
        db_path=layout["db_path"],
        out_root=out_root,
        pairs=[("QM5_9004", "XAGUSD.DWX")],
        search_roots=layout["search_roots"],
        verify_loadable=True,
    )
    item = _by_pair(manifest)["QM5_9004:XAGUSD.DWX"]
    assert item["outcome"] == "refused"
    assert item["reason"] == "no_terminal_q14_identity"


def test_identity_not_bound_to_stream_refused(layout, tmp_path):
    out_root = tmp_path / "out"
    manifest = asb.assemble_bundle(
        db_path=layout["db_path"],
        out_root=out_root,
        pairs=[("QM5_9005", "GBPUSD.DWX")],
        search_roots=layout["search_roots"],
        verify_loadable=True,
    )
    item = _by_pair(manifest)["QM5_9005:GBPUSD.DWX"]
    assert item["outcome"] == "refused"
    assert item["reason"] == "no_q08_stream_bound_to_identity"


def test_mixed_pool_manifest_counts_and_no_stray_writes(layout, tmp_path):
    out_root = tmp_path / "out"
    pairs = [
        ("QM5_9001", "EURUSD.DWX"),
        ("QM5_9002", "USDCAD.DWX"),
        ("QM5_9003", "XTIUSD.DWX"),
        ("QM5_9004", "XAGUSD.DWX"),
        ("QM5_9005", "GBPUSD.DWX"),
    ]
    manifest = asb.assemble_bundle(
        db_path=layout["db_path"],
        out_root=out_root,
        pairs=pairs,
        search_roots=layout["search_roots"],
        verify_loadable=True,
    )
    assert manifest["bound_count"] == 1
    assert manifest["refused_count"] == 4
    # exactly one stream file was written into the bundle
    written = sorted(p.name for p in (out_root / "QM" / "q08_trades").glob("*.jsonl"))
    assert written == ["9001_EURUSD_DWX.jsonl"]
    assert manifest["loader_verification"]["verified"] is True


def test_parse_pair_normalizes_symbol_and_ea():
    assert asb.parse_pair("1537:XAGUSD") == ("QM5_1537", "XAGUSD.DWX")
    assert asb.parse_pair("QM5_11421:EURUSD.DWX") == ("QM5_11421", "EURUSD.DWX")
    with pytest.raises(asb.BundleError):
        asb.parse_pair("no-colon")


def test_cli_writes_manifest_and_exit_code(layout, tmp_path):
    out_root = tmp_path / "cli_out"
    manifest_path = out_root / "bundle_manifest.json"
    rc = asb.main([
        "--out", str(out_root),
        "--db-path", str(layout["db_path"]),
        "--pairs", "9001:EURUSD.DWX,9002:USDCAD.DWX",
        "--search-root", str(layout["search_roots"][0]),
    ])
    # one bound, one refused -> partial exit code 3
    assert rc == 3
    assert manifest_path.is_file()
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    assert manifest["bound_count"] == 1
    assert manifest["refused_count"] == 1


def test_q08_pass_class_mirrors_the_census_rule():
    """OWNER-DEC-BUNDLE-Q08-PASSCLASS-20260904: the bundle accepts exactly the
    census Q08 PASS-class (PASS plus rebaseline_census.GATE_SCOPED_PASS['Q08'])."""
    import tools.strategy_farm.rebaseline_census as rc

    expected = {"PASS"} | set(rc.GATE_SCOPED_PASS.get("Q08", ()))
    assert set(asb.Q08_STREAM_PASS_VERDICTS) == expected
    assert "FAIL_SOFT" in asb.Q08_STREAM_PASS_VERDICTS
    assert "FAIL_HARD" not in asb.Q08_STREAM_PASS_VERDICTS


def test_q08_fail_soft_stream_binds_and_fail_hard_does_not(tmp_path):
    """Pair 8 (QM5_11910 NZDUSD, 2026-09-04): a Q08 FAIL_SOFT row with a sealed
    current-identity stream binds; a FAIL_HARD row never does."""
    ev = tmp_path / "reports" / "work_items"
    seal_dir = tmp_path / "reports" / "portfolio" / "sleeve_streams" / "QM" / "q08_trades"
    db_path = tmp_path / "farm_state.sqlite"
    con = _make_db(db_path)

    ex5_soft = "5" * 64
    stream_soft = seal_dir / "9010_NZDUSD_DWX.jsonl"
    sha_soft = _write_stream(stream_soft, "NZDUSD.DWX")
    agg_soft = ev / "wi_soft" / "aggregate.json"
    _aggregate(agg_soft, source_ex5=ex5_soft, content_sha=sha_soft, stream_path=stream_soft)
    _q14(con, "q14_soft", "QM5_9010", "NZDUSD.DWX", ex5_soft, "2026-09-04T15:34:00Z")
    _q08(con, "q08_soft", "QM5_9010", "NZDUSD.DWX", agg_soft, "2026-09-04T16:05:00Z", verdict="FAIL_SOFT")

    ex5_hard = "6" * 64
    stream_hard = seal_dir / "9011_AUDUSD_DWX.jsonl"
    sha_hard = _write_stream(stream_hard, "AUDUSD.DWX")
    agg_hard = ev / "wi_hard" / "aggregate.json"
    _aggregate(agg_hard, source_ex5=ex5_hard, content_sha=sha_hard, stream_path=stream_hard)
    _q14(con, "q14_hard", "QM5_9011", "AUDUSD.DWX", ex5_hard, "2026-09-04T15:34:00Z")
    _q08(con, "q08_hard", "QM5_9011", "AUDUSD.DWX", agg_hard, "2026-09-04T16:05:00Z", verdict="FAIL_HARD")
    con.commit(); con.close()

    manifest = asb.assemble_bundle(
        db_path=db_path,
        out_root=tmp_path / "out",
        pairs=[("QM5_9010", "NZDUSD.DWX"), ("QM5_9011", "AUDUSD.DWX")],
        search_roots=[tmp_path / "reports" / "portfolio" / "sleeve_streams"],
        verify_loadable=True,
    )
    items = _by_pair(manifest)
    soft = items["QM5_9010:NZDUSD.DWX"]
    assert soft["outcome"] == "bound"
    assert soft["q08_work_item_id"] == "q08_soft"
    assert soft["sha256"] == sha_soft
    assert manifest["loader_verification"]["verified"] is True
    hard = items["QM5_9011:AUDUSD.DWX"]
    assert hard["outcome"] == "refused"
    assert hard["reason"] == "no_q08_stream_bound_to_identity"


@pytest.mark.parametrize("older_verdict,newer_verdict", [("PASS", "FAIL_SOFT"), ("FAIL_SOFT", "PASS")])
@pytest.mark.parametrize("reverse", [False, True])
@pytest.mark.parametrize("older_ts", ["2026-09-04T09:30:00Z", "2026-09-04T11:30:00+02:00"])
def test_q08_mixed_pass_class_uses_newest_instant(tmp_path, older_verdict, newer_verdict, reverse, older_ts):
    db = tmp_path / "mixed.sqlite"
    con = _make_db(db)
    identity = "a" * 64
    rows = [("older", older_verdict, older_ts), ("newer", newer_verdict, "2026-09-04T10:00:00Z")]
    if reverse:
        rows.reverse()
    for wid, verdict, timestamp in rows:
        stream = tmp_path / wid / "9001_EURUSD_DWX.jsonl"
        sha = _write_stream(stream, "EURUSD.DWX")
        aggregate = tmp_path / wid / "aggregate.json"
        _aggregate(aggregate, source_ex5=identity, content_sha=sha, stream_path=stream)
        _q08(con, wid, "QM5_9001", "EURUSD.DWX", aggregate, timestamp, verdict)
    con.commit()
    con.close()
    con = asb.open_ro(db)
    try:
        bound = asb.find_bound_q08(con, "QM5_9001", "EURUSD.DWX", identity)
        assert bound["q08_work_item_id"] == "newer"
    finally:
        con.close()
