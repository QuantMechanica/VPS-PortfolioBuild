from __future__ import annotations

import base64
import copy
import datetime as dt
import json
from pathlib import Path

import pytest

pytest.importorskip("cryptography")
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from tools.strategy_farm import dxz_12567_xau_repair_packet as subject
from tools.strategy_farm.dxz_cost_evidence import extract_round_trips


REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "docs" / "ops" / "evidence" / "dxz_12567_xauusd_d1_repair_spec_20260716.json"
NATIVE_REPORT = Path(
    r"D:\QM\reports\portfolio\dxz23_as_live_requal_20260716_effective_d1_staged_serial"
    r"\20260716T080201Z\runs\16_12567_XAUUSD_DWX\report.htm"
)
CANONICAL_COST = Path(r"D:\QM\reports\portfolio\dxz_cost_evidence_20260716_v3\report.json")


def _write(path: Path, content: bytes) -> dict[str, object]:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    return {"path": str(path), "sha256": subject.sha256_file(path), "bytes": len(content)}


def _native_history_bytes(symbol: str, kind: str) -> bytes:
    magic, marker = {
        "HCC": (b"\xf6\x01\x00\x00", "History"),
        "TKC": (b"\xfd\x01\x00\x00", "Ticks"),
    }[kind]
    header = f"Copyright 2000-2026, MetaQuotes Ltd.\0{marker}\0{symbol}\0".encode(
        "utf-16-le"
    )
    return magic + header + b"\0" * 512


def _payload_hash(payload: dict) -> dict:
    unsigned = dict(payload)
    unsigned.pop("artifact_payload_sha256", None)
    payload["artifact_payload_sha256"] = subject.canonical_json_sha(unsigned)
    return payload


def _identity_row(segment_id: str = "S0") -> dict:
    return {
        "segment_id": segment_id,
        "trade_index": 1,
        "symbol": "XAUUSD.DWX",
        "side": "BUY",
        "signal_bar_open_mt5_server": "2025.01.01 00:00:00",
        "signal_value": "20",
        "entry_time_mt5_server": "2025.01.02 00:00:00",
        "entry_price": "2600",
        "entry_reason": "CUM_RSI_LT_35",
        "initial_stop": "2550",
        "initial_target": "0",
        "exit_time_mt5_server": "2025.01.03 21:00:00",
        "exit_price": "2650",
        "exit_reason": "FRIDAY_21_BROKER",
        "volume": "0.1",
        "gross_profit": "50",
        "swap": "-1",
        "commission": "-0.5",
        "net_profit": "48.5",
        "gross_profit_sign": 1,
    }


def _instrument_properties(symbol: str) -> dict:
    return {
        "digits": 3 if symbol.startswith("XAU") else 5,
        "point": "0.001" if symbol.startswith("XAU") else "0.00001",
        "tick_size": "0.001" if symbol.startswith("XAU") else "0.00001",
        "tick_value": "1",
        "contract_size": "100" if symbol.startswith("XAU") else "100000",
        "currency_base": "XAU" if symbol.startswith("XAU") else "EUR",
        "currency_profit": "USD",
        "currency_margin": "USD",
        "trade_calc_mode": "CFD" if symbol.startswith("XAU") else "FOREX",
    }


def test_spec_is_hash_bound_blocked_and_xau_not_xng() -> None:
    result = subject.validate_spec(SPEC)
    assert result["status"] == "BLOCKED_OWNER_AND_NEW_EVIDENCE"
    assert result["error_count"] == 0
    payload = json.loads(SPEC.read_text(encoding="utf-8"))
    payload["scope"]["symbol"] = "XNGUSD.DWX"
    checks = subject.Checks()
    subject._validate_spec_payload(payload, SPEC, checks, verify_anchors=False)
    assert any(error.startswith("SPEC_SCOPE_INVALID") for error in checks.errors)


def test_pending_owner_trust_can_never_produce_bundle_pass(tmp_path: Path) -> None:
    bundle_path = tmp_path / "bundle.json"
    bundle_path.write_text("{}", encoding="utf-8")
    result = subject.validate_bundle(
        SPEC,
        bundle_path,
        verify_anchors=False,
        owner_trust_anchor_path=None,
        owner_trust_anchor_sha256=None,
    )
    assert result["status"] == "FAIL"
    assert result["qualified"] is False
    assert any(
        error.startswith("OWNER_TRUST_ANCHOR_NOT_REGISTERED_OUT_OF_BAND")
        for error in result["errors"]
    )


def test_friday_owner_directive_is_closed_but_unsealed() -> None:
    payload = json.loads(SPEC.read_text(encoding="utf-8"))
    friday = next(row for row in payload["owner_gates"] if row["gate_id"] == "FRIDAY_CLOSE_POLICY")
    assert friday["status"] == "OWNER_DIRECTIVE_RECORDED_UNSEALED"
    assert friday["required_decision"] == "FRAMEWORK_OVERRIDE_FRIDAY_21_BROKER"
    assert "allowed_decisions" not in friday
    assert "No weekend holdings" in friday["directive_basis"]


@pytest.mark.parametrize(
    "value",
    ["0" * 64, "f" * 64, "deadbeef" * 8, "0123456789abcdef" * 4, "", None],
)
def test_dummy_hashes_fail_closed(value: object) -> None:
    assert subject._valid_sha(value) is False


def test_real_hash_and_casefold_nested_path_rules(tmp_path: Path) -> None:
    artifact = tmp_path / "artifact.bin"
    artifact.write_bytes(b"real artifact")
    assert subject._valid_sha(subject.sha256_file(artifact))
    left = tmp_path / "Run"
    right = left / "nested"
    left.mkdir()
    right.mkdir()
    assert subject._strictly_nested(left, right)
    assert subject._path_key(left) == subject._path_key(Path(str(left).swapcase()))


def test_owner_signature_uses_registered_key_material_and_rejects_tamper() -> None:
    private = Ed25519PrivateKey.generate()
    public = private.public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )
    payload = {
        "schema_version": 1,
        "artifact_type": subject.OWNER_DECISION_ARTIFACT,
        "packet_id": subject.PACKET_ID,
        "decision_type": "OWNER_GATE:FRIDAY_CLOSE_POLICY",
        "status": "APPROVED",
        "signed_utc": "2026-07-16T12:00:00+00:00",
        "decision": {"value": "FRAMEWORK_OVERRIDE_FRIDAY_21_BROKER"},
    }
    signature = private.sign(
        json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    )
    payload["signature_base64"] = base64.b64encode(signature).decode("ascii")
    checks = subject.Checks()
    subject._verify_owner_signed_payload(
        payload,
        expected_decision_type="OWNER_GATE:FRIDAY_CLOSE_POLICY",
        public_key=public,
        checks=checks,
        label="friday",
    )
    assert checks.errors == []
    payload["decision"] = {"value": "NO_FRAMEWORK_FRIDAY_CLOSE"}
    tampered = subject.Checks()
    subject._verify_owner_signed_payload(
        payload,
        expected_decision_type="OWNER_GATE:FRIDAY_CLOSE_POLICY",
        public_key=public,
        checks=tampered,
        label="friday",
    )
    assert any("OWNER_SIGNATURE_INVALID" in error for error in tampered.errors)


def test_owner_key_cannot_self_pin_inside_spec_or_bundle(tmp_path: Path) -> None:
    private = Ed25519PrivateKey.generate()
    public = private.public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )
    out_of_band = tmp_path / "owner-public-key.raw"
    out_of_band.write_bytes(public)
    bundle_dir = tmp_path / "bundle"
    bundle_dir.mkdir()
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    spec["owner_trust_contract"]["status"] = "REGISTERED_OUT_OF_BAND"
    spec["owner_trust_contract"]["trusted_public_key_sha256"] = subject.sha256_file(
        out_of_band
    )
    bundle = {"owner_trust_anchor": _write(out_of_band, public)}

    self_attested = subject.Checks()
    key, _ = subject._load_owner_trust_anchor(
        spec,
        bundle,
        bundle_dir,
        self_attested,
        out_of_band_path=None,
        out_of_band_sha256=None,
    )
    assert key is None
    assert any(
        error.startswith("OWNER_TRUST_ANCHOR_OUT_OF_BAND_ABSOLUTE_PATH_REQUIRED")
        for error in self_attested.errors
    )

    wrong_pin = subject.Checks()
    key, _ = subject._load_owner_trust_anchor(
        spec,
        bundle,
        bundle_dir,
        wrong_pin,
        out_of_band_path=out_of_band.resolve(),
        out_of_band_sha256=subject.canonical_json_sha("wrong-key"),
    )
    assert key is None
    assert any("OWNER_TRUST_ANCHOR_HASH_MISMATCH" in error for error in wrong_pin.errors)

    correctly_pinned = subject.Checks()
    key, digest = subject._load_owner_trust_anchor(
        spec,
        bundle,
        bundle_dir,
        correctly_pinned,
        out_of_band_path=out_of_band.resolve(),
        out_of_band_sha256=subject.sha256_file(out_of_band),
    )
    assert correctly_pinned.errors == []
    assert key == public
    assert digest == subject.sha256_file(out_of_band)


def test_effective_contract_requires_friday_21() -> None:
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    contract = {
        "ea_id": 12567,
        "symbol": "XAUUSD.DWX",
        "timeframe": "D1",
        "risk": {
            "mode": "PERCENT",
            "percent": "0.7938",
            "fixed": "0",
            "portfolio_weight": "1",
            "deposit": 100000,
            "account_currency": "EUR",
        },
        "friday": {
            "enabled": True,
            "hour_broker": 21,
            "weekend_holdings": False,
            "effective_cutoff_rule": subject.WEEKEND_CUTOFF_POLICY,
            "bound_calendar_required": True,
        },
        "news": {"temporal": 3, "compliance": 1},
        "strategy": {
            "rsi_period": 2,
            "cum_window": 2,
            "cum_rsi_entry": 35.0,
            "rsi_exit": 65.0,
            "sma_period": 200,
            "atr_period": 14,
            "atr_sl_mult": 2.5,
            "max_hold_bars": 5,
            "max_spread_points": 300,
        },
    }
    bundle = {
        "effective_contract": contract,
        "effective_contract_sha256": subject.canonical_json_sha(contract),
    }
    decisions = {
        "AS_LIVE_RISK_CONTRACT": "LIVE_AS_FOUND_RP0_7938_PW1",
        "FRIDAY_CLOSE_POLICY": "FRAMEWORK_OVERRIDE_FRIDAY_21_BROKER",
        "NEWS_POLICY": "DXZ_PRE30_POST30",
    }
    checks = subject.Checks()
    subject._validate_effective_contract(spec, bundle, decisions, checks)
    assert checks.errors == []
    contract["friday"] = {"enabled": False, "hour_broker": 21}
    bundle["effective_contract_sha256"] = subject.canonical_json_sha(contract)
    rejected = subject.Checks()
    subject._validate_effective_contract(spec, bundle, decisions, rejected)
    assert any(error.startswith("EFFECTIVE_FRIDAY_INVALID") for error in rejected.errors)


def test_friday_directive_is_proved_from_round_trip_times() -> None:
    safe = _identity_row()
    safe["entry_time_mt5_server"] = "2025.01.02 00:00:00"  # Thursday
    safe["exit_time_mt5_server"] = "2025.01.03 21:00:00"  # Friday cutoff
    regular_cutoff = dt.datetime(2025, 1, 3, 21)
    checks = subject.Checks()
    subject._validate_no_weekend_holdings(
        [safe], cutoffs=[regular_cutoff], label="safe", checks=checks
    )
    assert checks.errors == []

    held = dict(safe)
    held["exit_time_mt5_server"] = "2025.01.06 00:00:00"  # Monday
    rejected = subject.Checks()
    subject._validate_no_weekend_holdings(
        [held], cutoffs=[regular_cutoff], label="held", checks=rejected
    )
    assert any(
        error.startswith("WEEKEND_HOLDING_AFTER_EFFECTIVE_CUTOFF")
        for error in rejected.errors
    )

    early_close = dt.datetime(2025, 1, 2, 18)
    early_close_rejected = subject.Checks()
    subject._validate_no_weekend_holdings(
        [safe],
        cutoffs=[early_close],
        label="holiday-early-close",
        checks=early_close_rejected,
    )
    assert any(
        error.startswith("WEEKEND_HOLDING_AFTER_EFFECTIVE_CUTOFF")
        for error in early_close_rejected.errors
    )

    late_entry = dict(safe)
    late_entry["entry_time_mt5_server"] = "2025.01.03 21:00:00"
    late_entry["exit_time_mt5_server"] = "2025.01.03 22:00:00"
    rejected = subject.Checks()
    subject._validate_no_weekend_holdings(
        [late_entry], cutoffs=[regular_cutoff], label="late", checks=rejected
    )
    assert any(
        error.startswith("FRIDAY_ENTRY_AT_OR_AFTER_CUTOFF")
        for error in rejected.errors
    )


def test_weekend_calendar_is_complete_source_bound_and_uses_early_close(
    tmp_path: Path,
) -> None:
    entries = []
    sessions = []
    fridays = subject._expected_weekend_fridays()
    early_friday = fridays[10]
    for friday in fridays:
        regular = dt.datetime.combine(friday, dt.time(hour=21))
        last_tradable = (
            regular - dt.timedelta(days=1, hours=3)
            if friday == early_friday
            else regular
        )
        entries.append(
            {
                "week_friday_date": friday.isoformat(),
                "regular_cutoff_broker": regular.strftime("%Y.%m.%d %H:%M:%S"),
                "last_tradable_session_close_broker": last_tradable.strftime(
                    "%Y.%m.%d %H:%M:%S"
                ),
                "effective_cutoff_broker": last_tradable.strftime(
                    "%Y.%m.%d %H:%M:%S"
                ),
                "early_close": friday == early_friday,
            }
        )
        sessions.append(
            {
                "week_friday_date": friday.isoformat(),
                "last_tradable_session_close_broker": last_tradable.strftime(
                    "%Y.%m.%d %H:%M:%S"
                ),
            }
        )
    scope = {
        "symbol": "XAUUSD.DWX",
        "timezone_basis": "MT5_BROKER_SERVER_TIME",
        "window": dict(subject.QUALIFICATION_WINDOW),
    }
    source_payload = _payload_hash(
        {
            "schema_version": 1,
            "artifact_type": subject.WEEKEND_CALENDAR_SOURCE_ARTIFACT,
            "packet_id": subject.PACKET_ID,
            "status": "FROZEN",
            "generated_utc": "2026-07-16T12:00:00+00:00",
            "scope": scope,
            "provenance": {
                "terminal": "DarwinexZero MT5",
                "literal_dwx": True,
                "method": "BROKER_SESSION_PLUS_LITERAL_DWX_TICK_CALENDAR",
            },
            "sessions": sessions,
        }
    )
    source_path = tmp_path / "broker-session-source.json"
    source_path.write_text(json.dumps(source_payload), encoding="utf-8")
    calendar = _payload_hash(
        {
            "schema_version": 1,
            "artifact_type": subject.WEEKEND_CALENDAR_ARTIFACT,
            "packet_id": subject.PACKET_ID,
            "status": "FROZEN",
            "immutable": True,
            "generated_utc": "2026-07-16T12:01:00+00:00",
            "scope": scope,
            "policy": subject.WEEKEND_CUTOFF_POLICY,
            "source_session_export": {
                "path": str(source_path),
                "sha256": subject.sha256_file(source_path),
            },
            "entries": entries,
        }
    )
    checks = subject.Checks()
    cutoffs = subject._validate_weekend_flat_calendar(
        calendar, base_dir=tmp_path, checks=checks
    )
    assert checks.errors == []
    assert cutoffs[10] == dt.datetime.combine(
        early_friday - dt.timedelta(days=1), dt.time(hour=18)
    )

    incomplete = copy.deepcopy(calendar)
    incomplete["entries"].pop()
    incomplete = _payload_hash(incomplete)
    rejected = subject.Checks()
    subject._validate_weekend_flat_calendar(
        incomplete, base_dir=tmp_path, checks=rejected
    )
    assert any(
        error.startswith("WEEKEND_CALENDAR_COVERAGE_INVALID")
        for error in rejected.errors
    )


@pytest.mark.skipif(not NATIVE_REPORT.is_file(), reason="immutable native report unavailable")
def test_native_html_is_semantically_parsed_and_tamper_rejected() -> None:
    trades, _ = extract_round_trips(NATIVE_REPORT)
    rows = [
        {
            "trade_index": index,
            "symbol": trade.symbol,
            "side": trade.side,
            "entry_time_mt5_server": trade.entry_time,
            "exit_time_mt5_server": trade.exit_time,
            "entry_price": str(trade.entry_price),
            "exit_price": str(trade.exit_price),
            "volume": str(trade.volume),
            "gross_profit": str(trade.gross_pnl),
            "swap": str(trade.recorded_swap),
            "commission": str(trade.native_commission),
            "net_profit": str(trade.gross_pnl + trade.recorded_swap + trade.native_commission),
        }
        for index, trade in enumerate(trades, start=1)
    ]
    checks = subject.Checks()
    subject._validate_native_html_semantics(
        NATIVE_REPORT, rows, inference=True, label="native", checks=checks
    )
    assert checks.errors == []
    wrong_window = subject.Checks()
    subject._validate_native_html_semantics(
        NATIVE_REPORT,
        rows,
        inference=True,
        label="native-wrong-window",
        checks=wrong_window,
        segment_id="S0",
    )
    assert any(
        error.startswith("NATIVE_HTML_PERIOD_INVALID")
        for error in wrong_window.errors
    )
    rows[0]["volume"] = "999"
    rejected = subject.Checks()
    subject._validate_native_html_semantics(
        NATIVE_REPORT, rows, inference=True, label="native", checks=rejected
    )
    assert any("NATIVE_HTML_VALUE_MISMATCH" in error for error in rejected.errors)


def test_plain_or_arbitrary_native_report_cannot_pass(tmp_path: Path) -> None:
    report = tmp_path / "report.htm"
    report.write_text("<html><body>PASS</body></html>", encoding="utf-8")
    checks = subject.Checks()
    subject._validate_native_html_semantics(
        report,
        [_identity_row()],
        inference=True,
        label="plain",
        checks=checks,
    )
    assert any(
        error.startswith("NATIVE_HTML_SEMANTIC_PARSE_FAILED")
        for error in checks.errors
    )


def test_q08_raw_identity_is_not_accepted_by_hash_declaration_alone(tmp_path: Path) -> None:
    raw = tmp_path / "q08.jsonl"
    row = _identity_row()
    raw.write_text(
        json.dumps({"event": "DXZ_12567_FULL_ROUND_TRIP", "payload": row}) + "\n",
        encoding="utf-8",
    )
    checks = subject.Checks()
    assert subject._read_q08_raw_identity_rows(
        raw, segment_id="S0", label="q08", checks=checks
    ) == [row]
    assert checks.errors == []
    raw.write_text(json.dumps({"event": "DXZ_12567_FAKE", "payload": row}) + "\n", encoding="utf-8")
    rejected = subject.Checks()
    subject._read_q08_raw_identity_rows(raw, segment_id="S0", label="q08", checks=rejected)
    assert any("Q08_RAW_UNKNOWN_12567_EVENT" in error for error in rejected.errors)


def test_data_manifest_binds_six_actual_files_and_csv_semantics(tmp_path: Path) -> None:
    root = tmp_path / "run"
    root.mkdir()
    files = []
    start_stamp = int(
        dt.datetime(2025, 12, 22, tzinfo=dt.timezone.utc).timestamp()
    )
    end_stamp = int(
        dt.datetime(2025, 12, 31, tzinfo=dt.timezone.utc).timestamp()
    )
    for symbol in subject.REQUIRED_DWX:
        token = symbol.replace(".", "_")
        files.append(
            {
                "symbol": symbol,
                "kind": "HCC",
                **_write(
                    root / "history" / symbol / "2025.hcc",
                    _native_history_bytes(symbol, "HCC"),
                ),
            }
        )
        files.append(
            {
                "symbol": symbol,
                "kind": "TKC",
                **_write(
                    root / "ticks" / symbol / "202512.tkc",
                    _native_history_bytes(symbol, "TKC"),
                ),
            }
        )
        files.append(
            {
                "symbol": symbol,
                "kind": "SEGMENTATION_CSV",
                **_write(
                    root / f"{token}.csv",
                    (
                        "time,open,high,low,close,tickvol\n"
                        + (
                            f"{start_stamp},2000,2002,1999,2001,10\n"
                            f"{end_stamp},2001,2003,2000,2002,12\n"
                            if symbol == "XAUUSD.DWX"
                            else (
                                f"{start_stamp},1,2,0.5,1.5,10\n"
                                f"{end_stamp},1.5,2,1,1.7,12\n"
                            )
                        )
                    ).encode("ascii"),
                ),
            }
        )
    payload = _payload_hash(
        {
            "schema_version": 1,
            "artifact_type": subject.DATA_MANIFEST_ARTIFACT,
            "packet_id": subject.PACKET_ID,
            "run_id": "RUN-A",
            "segment_id": "S3",
            "immutable": True,
            "required_symbols": list(subject.REQUIRED_DWX),
            "files": files,
        }
    )
    checks = subject.Checks()
    subject._validate_data_file_manifest(
        payload,
        run_id="RUN-A",
        segment_id="S3",
        run_root=root,
        base_dir=root,
        label="data",
        checks=checks,
    )
    assert checks.errors == []

    reuse_payload = copy.deepcopy(payload)
    eur_csv = next(
        row
        for row in reuse_payload["files"]
        if row["symbol"] == "EURUSD.DWX" and row["kind"] == "SEGMENTATION_CSV"
    )
    xau_csv = next(
        row
        for row in reuse_payload["files"]
        if row["symbol"] == "XAUUSD.DWX" and row["kind"] == "SEGMENTATION_CSV"
    )
    xau_path = Path(xau_csv["path"])
    xau_path.write_bytes(Path(eur_csv["path"]).read_bytes())
    xau_csv["sha256"] = subject.sha256_file(xau_path)
    xau_csv["bytes"] = xau_path.stat().st_size
    reuse_payload = _payload_hash(reuse_payload)
    reused = subject.Checks()
    subject._validate_data_file_manifest(
        reuse_payload,
        run_id="RUN-A",
        segment_id="S3",
        run_root=root,
        base_dir=root,
        label="data-reuse",
        checks=reused,
    )
    assert any(
        error.startswith("DATA_CROSS_SYMBOL_BYTES_REUSED")
        for error in reused.errors
    )

    # Restore the XAU CSV so the subsequent hash-tamper assertion is isolated.
    xau_path.write_text(
        "time,open,high,low,close,tickvol\n"
        f"{start_stamp},2000,2002,1999,2001,10\n"
        f"{end_stamp},2001,2003,2000,2002,12\n",
        encoding="ascii",
    )
    payload["files"][0]["sha256"] = "0" * 64
    rejected = subject.Checks()
    subject._validate_data_file_manifest(
        payload,
        run_id="RUN-A",
        segment_id="S3",
        run_root=root,
        base_dir=root,
        label="data",
        checks=rejected,
    )
    assert any("BINDING_FIELDS_INVALID" in error for error in rejected.errors)

    plain = root / "plain.hcc"
    plain_binding = _write(plain, b"hcc-data")
    native_checks = subject.Checks()
    subject._validate_mt5_native_history_file(
        plain,
        symbol="XAUUSD.DWX",
        kind="HCC",
        label="plain",
        checks=native_checks,
    )
    assert any(
        error.startswith("DATA_NATIVE_MAGIC_OR_LENGTH_INVALID")
        for error in native_checks.errors
    )


def test_native_inventory_covers_every_year_and_month_in_each_segment() -> None:
    expected_counts = {
        "S0": (7, 75),
        "S1": (3, 23),
        "S2": (1, 2),
        "S3": (1, 1),
    }
    for segment_id, counts in expected_counts.items():
        hcc, tkc = subject._required_native_periods(segment_id)
        assert (len(hcc), len(tkc)) == counts


def test_segment_artifacts_must_be_inside_their_own_output(tmp_path: Path) -> None:
    output_a = tmp_path / "run" / "S0"
    output_b = tmp_path / "run" / "S1"
    output_a.mkdir(parents=True)
    output_b.mkdir(parents=True)
    artifact = output_b / "native-report.htm"
    artifact.write_text("report", encoding="utf-8")
    checks = subject.Checks()
    subject._require_within_own_output(
        artifact, output_a, label="S0.native_report", checks=checks
    )
    assert any(
        error.startswith("SEGMENT_ARTIFACT_OUTSIDE_OWN_OUTPUT_ROOT")
        for error in checks.errors
    )


def test_instrument_snapshot_revalidates_actual_symbol_exports(tmp_path: Path) -> None:
    root = tmp_path / "run"
    root.mkdir()
    records = []
    for symbol in subject.REQUIRED_DWX:
        properties = _instrument_properties(symbol)
        source_path = root / f"{symbol}.spec.json"
        source_path.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "artifact_type": "DXZ_MT5_SYMBOL_SPEC_EXPORT",
                    "symbol": symbol,
                    "properties": properties,
                }
            ),
            encoding="utf-8",
        )
        records.append(
            {
                "symbol": symbol,
                "source": {"path": str(source_path), "sha256": subject.sha256_file(source_path)},
                "properties": properties,
            }
        )
    payload = _payload_hash(
        {
            "schema_version": 1,
            "artifact_type": subject.INSTRUMENT_SNAPSHOT_ARTIFACT,
            "packet_id": subject.PACKET_ID,
            "run_id": "RUN-A",
            "segment_id": "S0",
            "account_currency": "EUR",
            "observed_utc": "2026-07-16T12:00:00+00:00",
            "records": records,
        }
    )
    checks = subject.Checks()
    subject._validate_instrument_snapshot(
        payload,
        run_id="RUN-A",
        segment_id="S0",
        run_root=root,
        base_dir=root,
        label="instrument",
        checks=checks,
    )
    assert checks.errors == []
    xng_confusion = copy.deepcopy(payload)
    xau_record = next(
        row for row in xng_confusion["records"] if row["symbol"] == "XAUUSD.DWX"
    )
    xng_source = root / "XNGUSD.DWX.spec.json"
    xng_source.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "artifact_type": "DXZ_MT5_SYMBOL_SPEC_EXPORT",
                "symbol": "XNGUSD.DWX",
                "properties": xau_record["properties"],
            }
        ),
        encoding="utf-8",
    )
    xau_record["source"] = {
        "path": str(xng_source),
        "sha256": subject.sha256_file(xng_source),
    }
    xng_confusion = _payload_hash(xng_confusion)
    xng_rejected = subject.Checks()
    subject._validate_instrument_snapshot(
        xng_confusion,
        run_id="RUN-A",
        segment_id="S0",
        run_root=root,
        base_dir=root,
        label="instrument-xng",
        checks=xng_rejected,
    )
    assert any(
        error.startswith("INSTRUMENT_SOURCE_SEMANTICS_INVALID")
        for error in xng_rejected.errors
    )
    payload["records"][0]["properties"]["currency_profit"] = "EUR"
    rejected = subject.Checks()
    subject._validate_instrument_snapshot(
        payload,
        run_id="RUN-A",
        segment_id="S0",
        run_root=root,
        base_dir=root,
        label="instrument",
        checks=rejected,
    )
    assert any("INSTRUMENT_SOURCE_SEMANTICS_INVALID" in error for error in rejected.errors)


def test_extractor_receipt_binds_exact_input_output_and_tool(tmp_path: Path) -> None:
    source = tmp_path / "raw.jsonl"
    output = tmp_path / "identity.jsonl"
    extractor = tmp_path / "extractor.py"
    source.write_text("{}\n", encoding="utf-8")
    output.write_text("{}\n", encoding="utf-8")
    extractor.write_text("# deterministic\n", encoding="utf-8")
    payload = {
        "schema_version": 1,
        "artifact_type": subject.EXTRACTOR_RECEIPT_ARTIFACT,
        "packet_id": subject.PACKET_ID,
        "run_id": "RUN-A",
        "segment_id": "S0",
        "producer": "Q08_INSTRUMENTED_EXTRACTOR",
        "extractor_sha256": subject.sha256_file(extractor),
        "input": {"path": str(source), "sha256": subject.sha256_file(source)},
        "output": {"path": str(output), "sha256": subject.sha256_file(output)},
        "canonicalization_contract": "DXZ_12567_FULL_ROUND_TRIP_IDENTITY_V1",
        "deterministic": True,
        "exit_code": 0,
        "started_utc": "2026-07-16T12:01:00+00:00",
        "finished_utc": "2026-07-16T12:02:00+00:00",
    }
    checks = subject.Checks()
    subject._validate_extractor_receipt(
        payload,
        producer="Q08_INSTRUMENTED_EXTRACTOR",
        run_id="RUN-A",
        segment_id="S0",
        extractor_sha256=subject.sha256_file(extractor),
        input_path=source,
        input_sha256=subject.sha256_file(source),
        output_path=output,
        output_sha256=subject.sha256_file(output),
        segment_start=dt.datetime(2026, 7, 16, 12, 0, tzinfo=dt.timezone.utc),
        segment_finish=dt.datetime(2026, 7, 16, 12, 3, tzinfo=dt.timezone.utc),
        label="q08",
        checks=checks,
    )
    assert checks.errors == []
    payload["extractor_sha256"] = subject.sha256_file(source)
    rejected = subject.Checks()
    subject._validate_extractor_receipt(
        payload,
        producer="Q08_INSTRUMENTED_EXTRACTOR",
        run_id="RUN-A",
        segment_id="S0",
        extractor_sha256=subject.sha256_file(extractor),
        input_path=source,
        input_sha256=subject.sha256_file(source),
        output_path=output,
        output_sha256=subject.sha256_file(output),
        segment_start=None,
        segment_finish=None,
        label="q08",
        checks=rejected,
    )
    assert any("EXTRACTOR_RECEIPT_BINDING_INVALID" in error for error in rejected.errors)


def test_approved_preset_must_encode_friday_news_risk_and_strategy(tmp_path: Path) -> None:
    preset = tmp_path / "approved.set"
    preset.write_text(
        """; ea_id: 12567
; symbol: XAUUSD.DWX
; timeframe: D1
; environment: live
; magic_slot: 3
qm_magic_slot_offset=3
RISK_FIXED=0
RISK_PERCENT=0.7938
PORTFOLIO_WEIGHT=1
qm_friday_close_enabled=true
qm_friday_close_hour_broker=21
qm_news_temporal=3
qm_news_compliance=1
strategy_rsi_period=2
strategy_cum_window=2
strategy_cum_rsi_entry=35
strategy_rsi_exit=65
strategy_sma_period=200
strategy_atr_period=14
strategy_atr_sl_mult=2.5
strategy_max_hold_bars=5
strategy_max_spread_points=300
""",
        encoding="utf-8",
    )
    candidate = {
        "RISK_PERCENT": "0.7938",
        "RISK_FIXED": "0",
        "PORTFOLIO_WEIGHT": "1",
    }
    decisions = {"NEWS_POLICY": "DXZ_PRE30_POST30"}
    checks = subject.Checks()
    subject._validate_approved_preset(
        preset, candidate=candidate, decisions=decisions, checks=checks
    )
    assert checks.errors == []
    preset.write_text(
        preset.read_text(encoding="utf-8")
        + "qm_filter_news_enabled=1\nRISK_PERCENT=0.7938\n",
        encoding="utf-8",
    )
    rejected = subject.Checks()
    subject._validate_approved_preset(
        preset, candidate=candidate, decisions=decisions, checks=rejected
    )
    assert any("PRESET_DUPLICATE_INPUT" in error for error in rejected.errors)
    assert any("PRESET_INERT_FILTER_KEYS_FORBIDDEN" in error for error in rejected.errors)


def test_source_closure_binds_real_mq5_and_recursive_includes(tmp_path: Path) -> None:
    source = tmp_path / "EA.mq5"
    include = tmp_path / "QM_KillSwitch.mqh"
    source.write_text(
        f'''#define {subject.WEEKEND_RUNTIME_MARKER}
#include "QM_KillSwitch.mqh"
void OnTick()
  {{
   if(!QM_KillSwitchCheck()) return;
   if({subject.WEEKEND_RUNTIME_HANDLER}()) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NewsFilterHook(TimeCurrent())) return;
   if(!QM_NewsAllowsTrade2()) return;
   if(Strategy_NoTradeFilter()) return;
  }}
''',
        encoding="utf-8",
    )
    include.write_text(
        """void QM_KillSwitchTrip(const string reason)
{
  QM_KillSwitchSaveState();
  QM_KillSwitchCloseOwnedPositions();
  QM_KillSwitchDeleteOwnedPendings();
}
bool QM_KillSwitchCheck()
{
  if(g_qm_ks_halted)
  {
    if(now_retry - g_qm_ks_halt_retry_ts >= 60)
    {
      if(QM_KillSwitchOwnedExposureExists())
      {
        QM_KillSwitchCloseOwnedPositions();
        QM_KillSwitchDeleteOwnedPendings();
      }
    }
    return false;
  }
  return true;
}
""",
        encoding="utf-8",
    )
    payload = _payload_hash(
        {
            "schema_version": 1,
            "artifact_type": "DXZ_12567_SOURCE_INCLUDE_CLOSURE",
            "packet_id": subject.PACKET_ID,
            "scope": {"ea_id": 12567, "symbol": "XAUUSD.DWX", "timeframe": "D1"},
            "files": [
                {"role": "SOURCE_OF_RECORD", **_write(source, source.read_bytes())},
                {"role": "RECURSIVE_INCLUDE", **_write(include, include.read_bytes())},
            ],
        }
    )
    checks = subject.Checks()
    assert subject._validate_source_closure_manifest(
        payload, base_dir=tmp_path, checks=checks
    ) == subject.sha256_file(source)
    assert checks.errors == []
    unrelated = tmp_path / "QM_Unused.mqh"
    unrelated.write_text("// not reachable from the source graph\n", encoding="utf-8")
    unreachable_payload = copy.deepcopy(payload)
    unreachable_payload["files"].append(
        {
            "role": "RECURSIVE_INCLUDE",
            **_write(unrelated, unrelated.read_bytes()),
        }
    )
    unreachable_payload = _payload_hash(unreachable_payload)
    unreachable = subject.Checks()
    subject._validate_source_closure_manifest(
        unreachable_payload, base_dir=tmp_path, checks=unreachable
    )
    assert any(
        error.startswith("SOURCE_CLOSURE_UNREACHABLE_INCLUDE")
        for error in unreachable.errors
    )
    payload["files"][1]["role"] = "SOURCE_OF_RECORD"
    rejected = subject.Checks()
    subject._validate_source_closure_manifest(payload, base_dir=tmp_path, checks=rejected)
    assert any("SOURCE_CLOSURE_ROOT_COUNT_INVALID" in error for error in rejected.errors)


def test_current_source_is_blocked_by_news_before_mandatory_close() -> None:
    current_source = (
        REPO
        / "framework"
        / "EAs"
        / "QM5_12567_cum-rsi2-commodity"
        / "QM5_12567_cum-rsi2-commodity.mq5"
    )
    checks = subject.Checks()
    subject._validate_source_of_record_runtime_order(current_source, checks)
    assert any(
        error.startswith("SOURCE_FRIDAY_CLOSE_AFTER_ENTRY_OR_NEWS_FILTER")
        for error in checks.errors
    )
    assert any(
        error.startswith("SOURCE_WEEKEND_DEADLINE_HANDLER_MISSING")
        for error in checks.errors
    )


def test_bound_kill_switch_has_trip_flatten_and_halted_retry_semantics() -> None:
    kill_switch = REPO / "framework" / "include" / "QM" / "QM_KillSwitch.mqh"
    checks = subject.Checks()
    subject._validate_kill_switch_flatten_semantics(kill_switch, checks)
    assert checks.errors == []


def test_cost_source_manifest_cannot_float_from_build_or_window() -> None:
    hashes = {
        "binary_sha256": subject.canonical_json_sha("binary"),
        "preset_sha256": subject.canonical_json_sha("preset"),
        "effective_contract_sha256": subject.canonical_json_sha("effective"),
        "source_closure_sha256": subject.canonical_json_sha("closure"),
    }
    payload = _payload_hash(
        {
            "schema_version": 1,
            "artifact_type": subject.COST_SOURCE_MANIFEST_ARTIFACT,
            "packet_id": subject.PACKET_ID,
            "status": "FROZEN",
            "immutable": True,
            "scope": {"ea_id": 12567, "symbol": "XAUUSD.DWX", "timeframe": "D1", "magic": 125670003},
            "covered_sleeves": [{"ea_id": 12567, "symbol": "XAUUSD.DWX", "timeframe": "D1"}],
            "evaluation_window": dict(subject.QUALIFICATION_WINDOW),
            "input_hashes": hashes,
        }
    )
    checks = subject.Checks()
    subject._validate_cost_source_manifest(payload, expected_hashes=hashes, checks=checks)
    assert checks.errors == []
    payload["evaluation_window"]["effective_from_date"] = "2020-01-01"
    rejected = subject.Checks()
    subject._validate_cost_source_manifest(payload, expected_hashes=hashes, checks=rejected)
    assert any("COST_SOURCE_MANIFEST_WINDOW_INVALID" in error for error in rejected.errors)


@pytest.mark.skipif(not CANONICAL_COST.is_file(), reason="canonical immutable cost artifact unavailable")
def test_canonical_cost_v3_binds_0p005_percent_equal_0p5_bp() -> None:
    checks = subject.Checks()
    subject._validate_canonical_cost_v3(
        {
            "path": str(CANONICAL_COST),
            "sha256": subject.CANONICAL_COST_V3_SHA256,
            "payload_sha256": subject.CANONICAL_COST_V3_PAYLOAD_SHA256,
        },
        base_dir=CANONICAL_COST.parent,
        checks=checks,
    )
    assert checks.errors == []
    rejected = subject.Checks()
    subject._validate_canonical_cost_v3(
        {
            "path": str(CANONICAL_COST),
            "sha256": subject.CANONICAL_COST_V3_SHA256,
            "payload_sha256": "0" * 64,
        },
        base_dir=CANONICAL_COST.parent,
        checks=rejected,
    )
    assert any("COST_COMMISSION_V3_CANONICAL_HASH_INVALID" in error for error in rejected.errors)


def test_sealed_input_is_structured_and_cannot_claim_dummy_hashes() -> None:
    hashes = {"binary_sha256": subject.canonical_json_sha("binary")}
    payload = _payload_hash(
        {
            "schema_version": 3,
            "artifact_type": subject.SEALED_INPUT_ARTIFACT,
            "packet_id": subject.PACKET_ID,
            "immutable": True,
            "scope": {"ea_id": 12567, "symbol": "XAUUSD.DWX", "timeframe": "D1", "magic": 125670003},
            "required_symbols": list(subject.REQUIRED_DWX),
            "segment_ids": list(subject.SEGMENTS),
            "input_hashes": hashes,
        }
    )
    checks = subject.Checks()
    subject._validate_sealed_input(payload, hashes, checks)
    assert checks.errors == []
    rejected = subject.Checks()
    subject._validate_sealed_input(payload, {"binary_sha256": "0" * 64}, rejected)
    assert any("SEALED_INPUT_HASHES_INVALID" in error for error in rejected.errors)


def test_external_controls_cannot_live_under_any_mt5_tree(tmp_path: Path) -> None:
    artifact = tmp_path / "mt5" / "Custom" / "owner.json"
    binding = _write(artifact, b"{}")
    checks = subject.Checks()
    checks.binding(
        binding,
        label="owner",
        base_dir=tmp_path,
        unique=True,
        external=True,
    )
    assert any("EXTERNAL_CONTROL_ARTIFACT_IN_MT5_TREE" in error for error in checks.errors)
