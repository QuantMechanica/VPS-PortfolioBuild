from __future__ import annotations

import csv
import datetime as dt
import json
from pathlib import Path

import pytest

from framework.scripts.mt5_diagnostics import dwx_m1_overlap_export as export
from tools.dukascopy import common as dukascopy_common
from tools.dukascopy import reconcile_overlap
from tools.strategy_farm import dwx_m1_overlap_export_work_item as work_item
from tools.strategy_farm import farmctl, terminal_worker


UTC = dt.timezone.utc


def _write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def _raw_bar(instant: dt.datetime, price: float = 1.1) -> dict[str, object]:
    return {
        "time": dukascopy_common.broker_epoch_seconds_for_utc(instant),
        "open": price,
        "high": price + 0.0002,
        "low": price - 0.0002,
        "close": price + 0.0001,
        "tickvol": 42,
    }


def _price_scale_fixture(path: Path) -> None:
    _write_csv(
        path,
        dukascopy_common.NONFX_METADATA_HEADER,
        [
            {
                "symbol": symbol,
                "digits": 2,
                "point": "0.01",
                "price_scale": 100,
            }
            for symbol in sorted(dukascopy_common.NON_FX_INSTRUMENTS)
        ],
    )


def _valid_payload(stamp: str = "20260911_010000") -> dict[str, object]:
    payload: dict[str, object] = {
        "authority_task_id": "ba2a478e-f437-404b-843b-a1def6f2cf4c",
        "diagnostic_allowed_terminals": ["T1"],
        "diagnostic_contract": farmctl.DWX_M1_OVERLAP_EXPORT_CONTRACT,
        "diagnostic_history_symbols": sorted(dukascopy_common.CANONICAL_SYMBOLS),
        "diagnostic_non_admission": True,
        "diagnostic_queue_rank": 0,
        "end_broker_epoch": work_item.OVERLAP_END_BROKER_EPOCH,
        "export_source_sha256": "a" * 64,
        "export_stamp": stamp,
        "export_timeout_seconds": 3600,
        "export_wrapper_sha256": "b" * 64,
        "governance_guard_sha256": "c" * 64,
        "history_ranges_sha256": "d" * 64,
        "manifest_path": "D:/QM/archive_manifest_owner_approved.json",
        "manifest_sha256": "e" * 64,
        "no_gate_verdict": True,
        "output_dir": str((work_item.EXPORT_ROOT / stamp).resolve()),
        "overlap_end_utc": work_item.OVERLAP_END_TEXT,
        "overlap_start_utc": work_item.OVERLAP_START_TEXT,
        "period": "M1",
        "price_scale_path": str(work_item.PRICE_SCALE.resolve()),
        "price_scale_sha256": "f" * 64,
        "priority_track": True,
        "read_only": True,
        "reconcile_overlap_sha256": "1" * 64,
        "start_broker_epoch": work_item.OVERLAP_START_BROKER_EPOCH,
        "symbol_matrix_sha256": "2" * 64,
    }
    payload["dispatch_binding_sha256"] = work_item._canonical_sha256(
        work_item.dispatch_binding_body(payload)
    )
    return payload


def _diagnostic_row(payload: dict[str, object]) -> dict[str, object]:
    return {
        "id": "11111111-2222-4333-8444-555555555555",
        "kind": farmctl.DIAGNOSTIC_WORK_ITEM_KIND,
        "phase": farmctl.DWX_M1_OVERLAP_EXPORT_PHASE,
        "ea_id": farmctl.DWX_M1_OVERLAP_EXPORT_EA_ID,
        "symbol": "DWX_UNIVERSE",
        "setfile_path": "",
        "payload_json": json.dumps(payload, sort_keys=True),
    }


def test_mql_export_is_exact_t1_read_only_copyrates_and_37_symbols(
    tmp_path: Path,
) -> None:
    binding = export.validate_mql_source()
    assert binding["read_only_api"] is True
    assert binding["symbol_count"] == 37
    assert binding["overlap_start_utc"] == "2025-10-01T00:00:00Z"
    assert binding["overlap_end_utc"] == "2026-04-01T00:00:00Z"

    source = export.SOURCE.read_text(encoding="utf-8-sig")
    assert "CopyRates(" in source
    assert "PERIOD_M1" in source
    assert "CopyTicks" not in source
    assert "Enabled=1" not in source

    custom_write = tmp_path / "custom_write.mq5"
    custom_write.write_text(
        source + '\nvoid Bad(){ MqlRates r[]; CustomRatesUpdate("EURUSD.DWX",r); }\n',
        encoding="utf-8",
    )
    with pytest.raises(ValueError, match="custom API"):
        export.validate_mql_source(custom_write)

    trading = tmp_path / "trading.mq5"
    trading.write_text(
        source + "\nvoid Bad(){ MqlTradeRequest r={}; MqlTradeResult x={}; OrderSend(r,x); }\n",
        encoding="utf-8",
    )
    with pytest.raises(ValueError, match="trading"):
        export.validate_mql_source(trading)


def test_fixed_window_contains_both_intervening_us_dst_transitions() -> None:
    fall_2025 = dukascopy_common.us_dst_bounds_utc(2025)[1]
    spring_2026 = dukascopy_common.us_dst_bounds_utc(2026)[0]
    assert work_item.OVERLAP_START_UTC < fall_2025 < work_item.OVERLAP_END_UTC
    assert work_item.OVERLAP_START_UTC < spring_2026 < work_item.OVERLAP_END_UTC
    for instant in (
        fall_2025 + dt.timedelta(days=7),
        spring_2026 - dt.timedelta(minutes=1),
        spring_2026,
        spring_2026 + dt.timedelta(days=7),
    ):
        broker = dukascopy_common.broker_epoch_seconds_for_utc(instant)
        assert export.broker_epoch_to_utc(broker) == instant


def test_csv_writer_loads_directly_for_fx_and_nonfx_price_scale_contract(
    tmp_path: Path,
) -> None:
    instants = [
        dt.datetime(2026, 1, 5, 10, 0, tzinfo=UTC),
        dt.datetime(2026, 1, 5, 10, 1, tzinfo=UTC),
    ]
    outputs: dict[str, Path] = {}
    for symbol, price in (("EURUSD.DWX", 1.1), ("XAUUSD.DWX", 2500.0)):
        raw = tmp_path / f"{symbol}.raw.csv"
        _write_csv(raw, export.RAW_HEADER, [_raw_bar(value, price) for value in instants])
        output = tmp_path / f"{symbol}_M1.csv"
        binding = export.canonicalize_raw_symbol(raw, output, symbol=symbol)
        assert binding["schema"] == [
            "time", "open", "high", "low", "close", "tickvol"
        ]
        assert binding["rows"] == 2
        with output.open(encoding="utf-8", newline="") as handle:
            rows = list(csv.DictReader(handle))
        assert [row["time"] for row in rows] == [
            "2026-01-05T10:00:00Z",
            "2026-01-05T10:01:00Z",
        ]
        loaded = reconcile_overlap.read_m1_csv(output)
        assert list(loaded) == [
            dukascopy_common.broker_epoch_seconds_for_utc(value)
            for value in instants
        ]
        outputs[symbol] = output

    metadata = tmp_path / "price_scale.csv"
    _price_scale_fixture(metadata)
    assert len(dukascopy_common.load_nonfx_instrument_metadata(metadata)) == 9
    nonfx = reconcile_overlap.reconcile_symbol(
        symbol="XAUUSD.DWX",
        dukascopy_csv=outputs["XAUUSD.DWX"],
        dwx_csv=outputs["XAUUSD.DWX"],
        instrument_metadata_path=metadata,
        typical_spread_points=2.0,
    )
    assert nonfx["point_size"] == 0.01
    assert nonfx["instrument_metadata"]["sha256"] == work_item.sha256_file(metadata)


def test_export_set_writes_and_validates_exact_37_symbol_manifest(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    stamp = "20260911_013000"
    export_root = tmp_path / "exports"
    output_dir = export_root / stamp
    raw_dir = tmp_path / "terminal_raw"
    output_dir.mkdir(parents=True)
    raw_dir.mkdir()
    price_scale = tmp_path / "price_scale.csv"
    _price_scale_fixture(price_scale)
    monkeypatch.setattr(work_item, "EXPORT_ROOT", export_root)
    monkeypatch.setattr(work_item, "PRICE_SCALE", price_scale)
    instant = dt.datetime(2026, 1, 5, 10, 0, tzinfo=UTC)
    for index, symbol in enumerate(sorted(dukascopy_common.CANONICAL_SYMBOLS)):
        _write_csv(
            raw_dir / f"{symbol}_M1.csv",
            export.RAW_HEADER,
            [_raw_bar(instant, 1.0 + index)],
        )

    binding = export.canonicalize_export_set(raw_dir, output_dir)
    assert binding["symbols"] == 37
    assert binding["total_rows"] == 37
    assert len(list((output_dir / "dwx_m1").glob("*.csv"))) == 37
    payload = _valid_payload(stamp)
    payload["price_scale_path"] = str(price_scale.resolve())
    payload["price_scale_sha256"] = work_item.sha256_file(price_scale)
    payload["reconcile_overlap_sha256"] = work_item.sha256_file(
        work_item.RECONCILE_OVERLAP
    )
    checked = work_item._validate_export_manifest(
        Path(str(binding["path"])), payload, verify_files=True
    )
    assert checked == {"symbols": 37, "total_rows": 37}


def test_export_set_records_empty_symbol_and_continues_across_universe(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    output_dir = tmp_path / "exports" / "20260911_013500"
    raw_dir = tmp_path / "terminal_raw"
    output_dir.mkdir(parents=True)
    raw_dir.mkdir()
    price_scale = tmp_path / "price_scale.csv"
    _price_scale_fixture(price_scale)
    monkeypatch.setattr(work_item, "EXPORT_ROOT", output_dir.parent)
    monkeypatch.setattr(work_item, "PRICE_SCALE", price_scale)
    instant = dt.datetime(2026, 1, 5, 10, 0, tzinfo=UTC)
    symbols = sorted(dukascopy_common.CANONICAL_SYMBOLS)
    failed_symbol = "AUDCHF.DWX"
    assert symbols.index(failed_symbol) == 1
    for index, symbol in enumerate(symbols):
        rows = [] if symbol == failed_symbol else [_raw_bar(instant, 1.0 + index)]
        _write_csv(raw_dir / f"{symbol}_M1.csv", export.RAW_HEADER, rows)

    binding = export.canonicalize_export_set(raw_dir, output_dir)
    manifest = json.loads(Path(binding["path"]).read_text(encoding="utf-8"))

    expected_failure = {
        "symbol": failed_symbol,
        "reason": "raw M1 export is empty: AUDCHF.DWX",
    }
    assert binding["canonicalization_status"] == "PARTIAL"
    assert binding["symbols"] == 36
    assert binding["attempted_symbol_count"] == 37
    assert binding["successful_symbol_count"] == 36
    assert binding["failed_symbol_count"] == 1
    assert binding["failed_symbols"] == [expected_failure]
    assert manifest["canonicalization_status"] == "PARTIAL"
    assert manifest["attempted_symbol_count"] == 37
    assert manifest["successful_symbol_count"] == 36
    assert manifest["failed_symbol_count"] == 1
    assert manifest["failed_symbols"] == [expected_failure]
    assert len(manifest["files"]) == 36
    assert {row["symbol"] for row in manifest["files"]} >= {
        "AUDCAD.DWX",
        "AUDJPY.DWX",
    }
    assert (output_dir / "dwx_m1" / "AUDCAD.DWX_M1.csv").is_file()
    assert (output_dir / "dwx_m1" / "AUDJPY.DWX_M1.csv").is_file()
    assert not (output_dir / "dwx_m1" / "AUDCHF.DWX_M1.csv").exists()
    assert len(list((output_dir / "raw").glob("*.csv"))) == 37
    payload = _valid_payload(output_dir.name)
    payload["price_scale_path"] = str(price_scale.resolve())
    payload["price_scale_sha256"] = work_item.sha256_file(price_scale)
    payload["reconcile_overlap_sha256"] = work_item.sha256_file(
        work_item.RECONCILE_OVERLAP
    )
    with pytest.raises(ValueError, match="manifest contract mismatch"):
        work_item._validate_export_manifest(
            Path(str(binding["path"])), payload, verify_files=True
        )


def test_reconcile_reader_retains_numeric_epoch_compatibility(tmp_path: Path) -> None:
    instant = dt.datetime(2026, 2, 2, 12, 0, tzinfo=UTC)
    raw = tmp_path / "numeric.csv"
    _write_csv(raw, export.RAW_HEADER, [_raw_bar(instant)])
    assert list(reconcile_overlap.read_m1_csv(raw)) == [
        dukascopy_common.broker_epoch_seconds_for_utc(instant)
    ]


def test_payload_validator_seals_terminal_window_and_safety_flags() -> None:
    payload = _valid_payload()
    assert work_item.validate_payload(payload, verify_files=False) == {
        "valid": True,
        "symbol_count": 37,
        "terminal": "T1",
    }
    row = _diagnostic_row(payload)
    assert farmctl._is_dwx_m1_overlap_export_item(row, payload)
    expanded = terminal_worker._work_item_history_symbols(row, payload)
    assert [symbol for symbol in expanded if symbol.endswith(".DWX")] == sorted(
        dukascopy_common.CANONICAL_SYMBOLS
    )

    with pytest.raises(ValueError, match="terminal"):
        work_item.validate_payload(payload, terminal="T2", verify_files=False)
    for key, value, reason in (
        ("overlap_start_utc", "2025-11-01T00:00:00Z", "fixed_window"),
        ("read_only", False, "safety_flags"),
        ("export_stamp", "20260911_010001", "dispatch_binding"),
    ):
        tampered = {**payload, key: value}
        with pytest.raises(ValueError, match=reason):
            work_item.validate_payload(tampered, verify_files=False)


def test_dispatch_uses_exact_m1_diagnostic_route(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    payload = _valid_payload()
    row = _diagnostic_row(payload)
    sentinel = {"spawned": True, "route": "dwx_m1_overlap"}
    monkeypatch.setattr(
        farmctl, "_news_calendar_preflight", lambda *, use_cache: {"ok": True}
    )
    monkeypatch.setattr(
        farmctl,
        "_spawn_dwx_m1_overlap_export",
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

    assert terminal_worker.claim_atomic(root, "T2")["claimed"] is False
    claim = terminal_worker.claim_atomic(root, "T1")
    assert claim["claimed"] is True
    assert claim["item"]["id"] == row["id"]
    assert claim["item"]["claimed_by"] == "T1"


def test_diagnostic_spawn_refuses_factory_off_before_process(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    payload = _valid_payload()
    row = _diagnostic_row(payload)
    monkeypatch.setattr(
        work_item,
        "validate_payload",
        lambda payload, terminal, verify_files: {"valid": True},
    )
    (tmp_path / "state").mkdir()
    (tmp_path / "state" / "FACTORY_OFF.flag").write_text("test\n", encoding="utf-8")
    result = farmctl._spawn_dwx_m1_overlap_export(tmp_path, row, "T1")
    assert result == {"spawned": False, "reason": "diagnostic_factory_off"}


def test_summary_contract_is_review_only() -> None:
    payload = _valid_payload()
    output_dir = work_item.EXPORT_ROOT / str(payload["export_stamp"])
    summary = {
        "schema_version": work_item.SUMMARY_SCHEMA,
        "run_tag": "20260911_020000",
        "export_stamp": payload["export_stamp"],
        "status": "PASS",
        "verdict": "REVIEW_REQUIRED",
        "no_gate_verdict": True,
        "work_item_id": "11111111-2222-4333-8444-555555555555",
        "terminal": "T1",
        "export_receipt_path": str(output_dir / "export_receipt.json"),
        "export_receipt_sha256": "3" * 64,
        "m1_export_manifest": {
            "path": str(output_dir / "dwx_m1_manifest.json"),
            "sha256": "4" * 64,
            "symbols": 37,
            "total_rows": 100,
            "schema": work_item.M1_HEADER,
            "overlap_start_utc": work_item.OVERLAP_START_TEXT,
            "overlap_end_utc": work_item.OVERLAP_END_TEXT,
        },
        "signed_archive_unchanged": True,
        "error": None,
    }
    checked = work_item.validate_summary(
        summary, payload, summary["work_item_id"], verify_files=False
    )
    assert checked["verdict"] == "REVIEW_REQUIRED"


def test_successful_completion_stores_review_without_aggregate(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    summary_path = tmp_path / "summary.json"
    summary_path.write_text(
        json.dumps({"schema_version": work_item.SUMMARY_SCHEMA, "run_tag": "20260911_020000"}),
        encoding="utf-8",
    )
    receipt = tmp_path / "export_receipt.json"
    receipt.write_text("{}\n", encoding="utf-8")
    payload = {**_valid_payload(), "phase_evidence_path": str(summary_path)}
    row = _diagnostic_row(payload)
    now = farmctl.utc_now()
    with farmctl.connect(root) as connection:
        connection.execute(
            "INSERT INTO work_items "
            "(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,"
            "payload_json,claimed_by,created_at,updated_at,gate_contract_version) "
            "VALUES (?,?,?,?,?,?,'active',0,?,?,?,?,?)",
            (
                row["id"], row["kind"], row["phase"], row["ea_id"],
                row["symbol"], row["setfile_path"], row["payload_json"],
                "T1", now, now, farmctl.ACTIVE_GATE_CONTRACT_VERSION,
            ),
        )
        connection.commit()
    monkeypatch.setattr(
        work_item,
        "validate_summary",
        lambda summary, payload, work_item_id, verify_files=True: {
            "valid": True,
            "verdict": "REVIEW_REQUIRED",
            "evidence_path": str(receipt),
            "m1_export_manifest": str(tmp_path / "manifest.json"),
        },
    )
    result = terminal_worker._finish_work_item(root, str(row["id"]), 0)
    assert result["verdict"] == "REVIEW_REQUIRED"
    assert result["aggregate"] is None
    with farmctl.connect(root) as connection:
        stored = connection.execute(
            "SELECT status,verdict,verdict_taxonomy,evidence_path "
            "FROM work_items WHERE id=?",
            (row["id"],),
        ).fetchone()
    assert dict(stored) == {
        "status": "done",
        "verdict": "REVIEW_REQUIRED",
        "verdict_taxonomy": "review",
        "evidence_path": str(receipt),
    }


def test_startup_contract_is_fail_closed_and_worker_only() -> None:
    source = Path(export.__file__).read_text(encoding="utf-8")
    for required in (
        'ROOT = Path("D:/QM/mt5/T1")',
        '"Enabled=0"',
        '"AllowLiveTrading=0"',
        '"AllowDllImport=0"',
        '"ShutdownTerminal=0"',
        "_terminate_owned(identity, ini)",
        "state/FACTORY_OFF.flag",
        "signed_archive_unchanged",
        "manual_terminal_start\": False",
    ):
        assert required in source
