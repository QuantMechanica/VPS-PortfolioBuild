from __future__ import annotations

import csv
import datetime as dt
import json
from pathlib import Path

import pytest

from framework.scripts.mt5_diagnostics import dwx_tick_tail_probe as probe
from tools.dukascopy import common as dukascopy_common
from tools.strategy_farm import dwx_tick_tail_probe_work_item as work_item
from tools.strategy_farm import farmctl, terminal_worker


UTC = dt.timezone.utc


def _write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def _valid_payload(stamp: str = "20260907_120000") -> dict[str, object]:
    symbols = sorted(dukascopy_common.CANONICAL_SYMBOLS)
    payload: dict[str, object] = {
        "authority_task_id": "a7e1333c-9b06-45de-a6be-f14477b5f78b",
        "diagnostic_allowed_terminals": ["T1"],
        "diagnostic_contract": farmctl.DWX_TICK_TAIL_PROBE_CONTRACT,
        "diagnostic_history_symbols": symbols,
        "diagnostic_non_admission": True,
        "diagnostic_queue_rank": 0,
        "history_ranges_sha256": work_item.sha256_file(work_item.HISTORY_RANGES),
        "manifest_path": "D:/QM/archive_manifest_owner_approved.json",
        "manifest_sha256": "a" * 64,
        "no_gate_verdict": True,
        "output_dir": str((work_item.SPLICE_ROOT / stamp).resolve()),
        "period": "M1",
        "priority_track": True,
        "probe_source_sha256": work_item.sha256_file(work_item.PROBE_SOURCE),
        "probe_stamp": stamp,
        "probe_timeout_seconds": 1800,
        "probe_wrapper_sha256": work_item.sha256_file(work_item.PROBE_WRAPPER),
        "read_only": True,
        "symbol_matrix_sha256": work_item.sha256_file(work_item.SYMBOL_MATRIX),
    }
    payload["dispatch_binding_sha256"] = work_item._canonical_sha256(
        work_item.dispatch_binding_body(payload)
    )
    return payload


def _diagnostic_row(payload: dict[str, object]) -> dict[str, object]:
    return {
        "id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
        "kind": farmctl.DIAGNOSTIC_WORK_ITEM_KIND,
        "phase": farmctl.DWX_TICK_TAIL_PROBE_PHASE,
        "ea_id": farmctl.DWX_TICK_TAIL_PROBE_EA_ID,
        "symbol": "DWX_UNIVERSE",
        "setfile_path": "",
        "payload_json": json.dumps(payload, sort_keys=True),
    }


def _broker_msc(value: dt.datetime) -> int:
    return dukascopy_common.utc_msc_to_broker_msc(int(value.timestamp() * 1000))


def test_mql_probe_is_exact_t1_read_only_and_37_symbols(tmp_path: Path) -> None:
    binding = probe.validate_mql_source()
    assert binding["read_only_api"] is True
    assert binding["symbol_count"] == 37

    source = probe.SOURCE.read_text(encoding="utf-8-sig")
    assert "Enabled=1" not in source
    assert "CopyTicks(" in source
    assert "CopyTicksRange(" in source
    assert "SymbolInfoInteger(symbol,SYMBOL_DIGITS" in source
    assert "SymbolInfoDouble(symbol,SYMBOL_POINT" in source

    custom_write = tmp_path / "custom_write.mq5"
    custom_write.write_text(
        source + '\nvoid Bad(){ MqlTick ticks[]; CustomTicksAdd("EURUSD.DWX",ticks); }\n',
        encoding="utf-8",
    )
    with pytest.raises(ValueError, match="custom-write"):
        probe.validate_mql_source(custom_write)

    wrong_terminal = tmp_path / "wrong_terminal.mq5"
    wrong_terminal.write_text(
        source.replace(r'd:\\qm\\mt5\\t1', r'd:\\qm\\mt5\\t2'),
        encoding="utf-8",
    )
    with pytest.raises(ValueError, match="T1 MQL path guard"):
        probe.validate_mql_source(wrong_terminal)


def test_broker_millisecond_inverse_obeys_us_dst_policy() -> None:
    instants = [
        dt.datetime(2026, 1, 15, 12, 34, 56, 789000, tzinfo=UTC),
        dt.datetime(2026, 3, 8, 6, 59, 59, 999000, tzinfo=UTC),
        dt.datetime(2026, 3, 8, 7, 0, 0, 0, tzinfo=UTC),
        dt.datetime(2026, 7, 15, 12, 34, 56, 789000, tzinfo=UTC),
        dt.datetime(2026, 11, 1, 6, 0, 0, 0, tzinfo=UTC),
    ]
    for instant in instants:
        assert probe.broker_msc_to_utc(_broker_msc(instant)) == instant

    # The repeated November wall-clock hour is deliberately resolved to the
    # standard-time (+2) candidate, matching qm.dst_rule.us.v1.
    ambiguous_wall = dt.datetime(2026, 11, 1, 8, 30, tzinfo=UTC)
    ambiguous_msc = int(ambiguous_wall.timestamp() * 1000)
    assert probe.broker_msc_to_utc(ambiguous_msc) == dt.datetime(
        2026, 11, 1, 6, 30, tzinfo=UTC
    )


def test_canonical_csv_schema_range_check_and_row_hashes(tmp_path: Path) -> None:
    symbols = sorted(dukascopy_common.CANONICAL_SYMBOLS)
    ranges = tmp_path / "history_ranges.csv"
    _write_csv(
        ranges,
        ["symbol", "period", "first_year", "last_year", "source_terminals"],
        [
            {
                "symbol": symbol,
                "period": "M1",
                "first_year": 2017,
                "last_year": 2025,
                "source_terminals": "T1,T2",
            }
            for symbol in symbols
        ],
    )
    first_msc = _broker_msc(dt.datetime(2017, 1, 3, 0, 0, tzinfo=UTC))
    last_utc = dt.datetime(2026, 7, 15, 12, 34, 56, 789000, tzinfo=UTC)
    last_msc = _broker_msc(last_utc)
    raw = tmp_path / "tick_tail_raw.csv"
    _write_csv(
        raw,
        probe.RAW_HEADER,
        [
            {
                "symbol": symbol,
                "last_tick_time_msc": last_msc,
                "last_tick_bid": f"{1.0 + index / 10000:.5f}",
                "last_tick_ask": f"{1.0002 + index / 10000:.5f}",
                "tick_count_last_day": 1000 + index,
                "first_tick_time_msc": first_msc,
                "source_terminal": "T1",
            }
            for index, symbol in reversed(list(enumerate(symbols)))
        ],
    )
    output = tmp_path / "tick_tail.csv"
    result = probe.canonicalize_raw_probe(
        raw,
        output,
        history_ranges_path=ranges,
        now_utc=dt.datetime(2026, 9, 7, tzinfo=UTC),
    )
    assert result["rows"] == 37
    assert result["schema"] == probe.FINAL_HEADER
    with output.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
    assert reader.fieldnames == probe.FINAL_HEADER
    assert [row["symbol"] for row in rows] == symbols
    assert {row["last_tick_utc"] for row in rows} == {
        "2026-07-15T12:34:56.789Z"
    }
    assert all(row["probe_sha256"] == probe._probe_row_hash(row) for row in rows)

    incomplete = tmp_path / "incomplete.csv"
    with raw.open(encoding="utf-8", newline="") as handle:
        raw_rows = list(csv.DictReader(handle))
    _write_csv(incomplete, probe.RAW_HEADER, list(reversed(raw_rows))[1:])
    with pytest.raises(ValueError, match="exactly one row"):
        probe.canonicalize_raw_probe(
            incomplete,
            tmp_path / "should_not_exist.csv",
            history_ranges_path=ranges,
            now_utc=dt.datetime(2026, 9, 7, tzinfo=UTC),
        )


def test_price_scale_receipt_has_exact_nine_t1_sourced_rows(tmp_path: Path) -> None:
    raw = tmp_path / "price_scale_raw.csv"
    _write_csv(
        raw,
        probe.PRICE_SCALE_HEADER,
        [
            {
                "symbol": symbol,
                "digits": index % 6,
                "point": format(10.0 ** -(index % 6), ".12g"),
                "price_scale": 10 ** (index % 6),
            }
            for index, symbol in enumerate(
                reversed(sorted(probe.PRICE_SCALE_SYMBOLS)), start=1
            )
        ],
    )
    output = tmp_path / "price_scale.csv"
    binding = probe.canonicalize_price_scale_probe(raw, output)
    assert binding["rows"] == 9
    assert binding["schema"] == ["symbol", "digits", "point", "price_scale"]
    assert binding["source_terminal"] == "T1"
    with output.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    assert [row["symbol"] for row in rows] == sorted(probe.PRICE_SCALE_SYMBOLS)

    bad = tmp_path / "bad.csv"
    _write_csv(bad, probe.PRICE_SCALE_HEADER, [{
        "symbol": sorted(probe.PRICE_SCALE_SYMBOLS)[0],
        "digits": 2,
        "point": "0.01",
        "price_scale": 10,
    }])
    with pytest.raises(ValueError, match="invalid T1 price-scale metadata"):
        probe.canonicalize_price_scale_probe(bad, tmp_path / "refused.csv")


def test_payload_binding_terminal_scope_and_history_expansion() -> None:
    payload = _valid_payload()
    assert work_item.validate_payload(payload) == {
        "valid": True,
        "symbol_count": 37,
        "terminal": "T1",
    }
    row = _diagnostic_row(payload)
    assert farmctl._is_dwx_tick_tail_probe_item(row, payload)
    expanded = terminal_worker._work_item_history_symbols(row, payload)
    assert [symbol for symbol in expanded if symbol.endswith(".DWX")] == sorted(
        dukascopy_common.CANONICAL_SYMBOLS
    )

    with pytest.raises(ValueError, match="terminal"):
        work_item.validate_payload(payload, terminal="T2")
    tampered = {**payload, "probe_stamp": "20260907_120001"}
    with pytest.raises(ValueError, match="dispatch_binding"):
        work_item.validate_payload(tampered)

    forged_symbols = {
        **payload,
        "diagnostic_history_symbols": [f"FAKE{index:02d}.DWX" for index in range(37)],
    }
    forged_symbols["dispatch_binding_sha256"] = work_item._canonical_sha256(
        work_item.dispatch_binding_body(forged_symbols)
    )
    with pytest.raises(ValueError, match="symbols"):
        work_item.validate_payload(forged_symbols)

    wrong_output = {**payload, "output_dir": "D:/QM/reports/dukascopy/not-splice"}
    wrong_output["dispatch_binding_sha256"] = work_item._canonical_sha256(
        work_item.dispatch_binding_body(wrong_output)
    )
    with pytest.raises(ValueError, match="output_dir"):
        work_item.validate_payload(wrong_output)


def test_dispatch_uses_exact_diagnostic_route(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    payload = _valid_payload()
    row = _diagnostic_row(payload)
    sentinel = {"spawned": True, "route": "tick_tail"}
    monkeypatch.setattr(
        farmctl,
        "_news_calendar_preflight",
        lambda *, use_cache: {"ok": True},
    )
    monkeypatch.setattr(
        farmctl,
        "_spawn_dwx_tick_tail_probe",
        lambda root, item_row, terminal: sentinel,
    )
    assert farmctl._spawn_work_item_runner(tmp_path, row, "T1") is sentinel


def test_claim_is_serialized_to_t1(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    payload = _valid_payload()
    row = _diagnostic_row(payload)
    now = farmctl.utc_now()
    with farmctl.connect(root) as connection:
        connection.execute(
            "INSERT INTO work_items "
            "(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,"
            "payload_json,created_at,updated_at,gate_contract_version) "
            "VALUES (?,?,?,?,?,?,'pending',0,?,?,?,?)",
            (
                row["id"], row["kind"], row["phase"], row["ea_id"],
                row["symbol"], row["setfile_path"], row["payload_json"],
                now, now, farmctl.ACTIVE_GATE_CONTRACT_VERSION,
            ),
        )
        connection.commit()
    monkeypatch.setattr(
        farmctl, "_news_calendar_preflight", lambda *, use_cache: {"ok": True}
    )
    monkeypatch.setattr(
        farmctl,
        "_dwx_symbol_history_registry",
        lambda: {
            (symbol, "M1"): {"source_terminals": "T1"}
            for symbol in dukascopy_common.CANONICAL_SYMBOLS
        },
    )
    monkeypatch.setattr(terminal_worker, "_multisymbol_ea_ids", lambda: frozenset())
    monkeypatch.setattr(terminal_worker, "_commit_headroom_gb", lambda: 1000.0)
    monkeypatch.setattr(terminal_worker, "_free_ram_gb", lambda: 1000.0)
    monkeypatch.setattr(terminal_worker, "_total_ram_gb", lambda: 1000.0)
    monkeypatch.setattr(terminal_worker, "_process_private_snapshot", lambda: {})

    wrong_lane = terminal_worker.claim_atomic(root, "T2")
    assert wrong_lane["claimed"] is False
    with farmctl.connect(root) as connection:
        assert connection.execute(
            "SELECT status,claimed_by FROM work_items WHERE id=?", (row["id"],)
        ).fetchone()["status"] == "pending"

    claim = terminal_worker.claim_atomic(root, "T1")
    assert claim["claimed"] is True
    assert claim["item"]["id"] == row["id"]
    assert claim["item"]["claimed_by"] == "T1"


def test_diagnostic_spawn_refuses_factory_off_before_process(tmp_path: Path) -> None:
    payload = _valid_payload()
    row = _diagnostic_row(payload)
    (tmp_path / "state").mkdir()
    (tmp_path / "state" / "FACTORY_OFF.flag").write_text("test\n", encoding="utf-8")
    result = farmctl._spawn_dwx_tick_tail_probe(tmp_path, row, "T1")
    assert result == {"spawned": False, "reason": "diagnostic_factory_off"}


def test_summary_keeps_queue_stamp_separate_from_fresh_run_tag() -> None:
    payload = _valid_payload("20260907_120000")
    output_dir = work_item.SPLICE_ROOT / "20260907_120000"
    summary = {
        "schema_version": work_item.SUMMARY_SCHEMA,
        "run_tag": "20260907_181500",
        "probe_stamp": "20260907_120000",
        "status": "PASS",
        "verdict": "REVIEW_REQUIRED",
        "no_gate_verdict": True,
        "work_item_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
        "terminal": "T1",
        "probe_receipt_path": str(output_dir / "probe_receipt.json"),
        "probe_receipt_sha256": "b" * 64,
        "tick_tail_csv": {
            "path": str(output_dir / "tick_tail.csv"),
            "sha256": "c" * 64,
            "rows": 37,
            "schema": probe.FINAL_HEADER,
        },
        "price_scale_csv": {
            "path": str(output_dir / "price_scale.csv"),
            "sha256": "d" * 64,
            "rows": 9,
            "schema": probe.PRICE_SCALE_HEADER,
            "source_terminal": "T1",
        },
        "signed_archive_unchanged": True,
        "error": None,
    }
    validated = work_item.validate_summary(
        summary,
        payload,
        summary["work_item_id"],
        verify_files=False,
    )
    assert validated["verdict"] == "REVIEW_REQUIRED"

    stale_identity = {**summary, "probe_stamp": summary["run_tag"]}
    with pytest.raises(ValueError, match="stamp"):
        work_item.validate_summary(
            stale_identity,
            payload,
            summary["work_item_id"],
            verify_files=False,
        )


def test_successful_diagnostic_completion_is_review_only(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    summary_path = tmp_path / "summary.json"
    summary_path.write_text(
        json.dumps({"schema_version": probe.SUMMARY_SCHEMA, "run_tag": "20260907_120000"}),
        encoding="utf-8",
    )
    receipt_path = tmp_path / "probe_receipt.json"
    receipt_path.write_text("{}\n", encoding="utf-8")
    payload = {
        **_valid_payload(),
        "phase_evidence_path": str(summary_path),
    }
    row = _diagnostic_row(payload)
    now = farmctl.utc_now()
    with farmctl.connect(root) as connection:
        connection.execute(
            "INSERT INTO work_items "
            "(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,"
            "payload_json,claimed_by,created_at,updated_at,gate_contract_version) "
            "VALUES (?,?,?,?,?,?,'active',0,?,?,?,?,?)",
            (
                row["id"],
                row["kind"],
                row["phase"],
                row["ea_id"],
                row["symbol"],
                row["setfile_path"],
                row["payload_json"],
                "T1",
                now,
                now,
                farmctl.ACTIVE_GATE_CONTRACT_VERSION,
            ),
        )
        connection.commit()
    monkeypatch.setattr(
        work_item,
        "validate_summary",
        lambda summary, payload, work_item_id, verify_files=True: {
            "valid": True,
            "verdict": "REVIEW_REQUIRED",
            "evidence_path": str(receipt_path),
            "tick_tail_csv": str(tmp_path / "tick_tail.csv"),
        },
    )
    result = terminal_worker._finish_work_item(root, str(row["id"]), 0)
    assert result["verdict"] == "REVIEW_REQUIRED"
    assert result["aggregate"] is None
    with farmctl.connect(root) as connection:
        stored = connection.execute(
            "SELECT status,verdict,verdict_taxonomy,evidence_path FROM work_items WHERE id=?",
            (row["id"],),
        ).fetchone()
    assert dict(stored) == {
        "status": "done",
        "verdict": "REVIEW_REQUIRED",
        "verdict_taxonomy": "review",
        "evidence_path": str(receipt_path),
    }


def test_startup_contract_is_fail_closed() -> None:
    source = Path(probe.__file__).read_text(encoding="utf-8")
    for required in (
        'ROOT = Path("D:/QM/mt5/T1")',
        '"Enabled=0"',
        '"AllowLiveTrading=0"',
        '"AllowDllImport=0"',
        '"ShutdownTerminal=0"',
        "_terminate_owned(identity, ini)",
        'state/FACTORY_OFF.flag',
        "signed_archive_unchanged",
    ):
        assert required in source
