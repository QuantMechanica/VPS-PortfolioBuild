from __future__ import annotations

import copy
import base64
import datetime as dt
import json
import shutil
from pathlib import Path

import pytest

pytest.importorskip("cryptography")
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from tools.strategy_farm import dxz_10939_repair_packet as packet
from tools.strategy_farm import dxz_as_live_requal as hardened_requal
from tools.strategy_farm.tests.test_dxz_cost_manifest_security import (
    _axis_payload as _security_axis_payload,
    _write_bound_json as _security_write_bound_json,
)


REPO_ROOT = Path(__file__).resolve().parents[3]
REAL_SPEC = (
    REPO_ROOT
    / "docs"
    / "ops"
    / "evidence"
    / "dxz_10939_gbpusd_h4_repair_spec_20260716.json"
)


def _write(path: Path, content: str | bytes) -> dict[str, str]:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(content, bytes):
        path.write_bytes(content)
    else:
        path.write_text(content, encoding="utf-8")
    return {"path": str(path), "sha256": packet.sha256_file(path)}


def _write_structured(
    path: Path, payload: dict, *, hash_field: str = "manifest_payload_sha256"
) -> dict[str, str]:
    unsigned = dict(payload)
    unsigned.pop(hash_field, None)
    payload[hash_field] = packet.canonical_json_sha(unsigned)
    return _write(path, json.dumps(payload, indent=2, sort_keys=True) + "\n")


def _write_signed_structured(
    path: Path,
    payload: dict,
    *,
    private_key: Ed25519PrivateKey,
    hash_field: str,
) -> dict[str, str]:
    unsigned = dict(payload)
    unsigned.pop(hash_field, None)
    unsigned.pop("signature_base64", None)
    signature = private_key.sign(
        json.dumps(
            unsigned, sort_keys=True, separators=(",", ":"), ensure_ascii=False
        ).encode("utf-8")
    )
    payload["signature_base64"] = base64.b64encode(signature).decode("ascii")
    return _write_structured(path, payload, hash_field=hash_field)


def _make_cost_manifest(
    root: Path, *, source_sha: str, window: dict[str, str]
) -> dict[str, str]:
    root.mkdir(parents=True, exist_ok=True)
    sleeves = [{"ea_id": 10939, "symbol": "GBPUSD.DWX", "timeframe": "H4"}]
    axes = {}
    for axis in hardened_requal.EXECUTION_COST_AXES:
        artifact = root / f"{axis}.json"
        payload = _security_axis_payload(axis, source_sha=source_sha, sleeves=sleeves)
        payload["evaluation_window"] = dict(window)
        _security_write_bound_json(artifact, payload, "artifact_payload_sha256")
        axes[axis] = {
            "status": "PASS",
            "evidence": {
                "path": artifact.name,
                "sha256": hardened_requal.sha256_file(artifact),
                "evidence_type": payload["evidence_type"],
            },
        }
    manifest = root / "cost_manifest.json"
    payload = {
        "schema_version": 1,
        "artifact_type": hardened_requal.EXECUTION_COST_MANIFEST_TYPE,
        "status": "PASS",
        "source_manifest_sha256": source_sha,
        "valid_from_utc": "2026-07-15T00:00:00+00:00",
        "valid_until_utc": "2026-07-20T00:00:00+00:00",
        "scope": "GLOBAL",
        "covered_keys": ["10939:GBPUSD.DWX"],
        "covered_sleeves": sleeves,
        "evaluation_window": dict(window),
        "axes": axes,
    }
    _security_write_bound_json(manifest, payload, "manifest_payload_sha256")
    return {"path": str(manifest), "sha256": hardened_requal.sha256_file(manifest)}


def _make_spec(tmp_path: Path) -> tuple[Path, dict]:
    spec = json.loads(REAL_SPEC.read_text(encoding="utf-8"))
    baseline = _write(tmp_path / "baseline.txt", "baseline")
    baseline.update({"id": "test_baseline", "role": "test", "bytes": 8})
    spec["baseline"]["hash_bindings"] = [baseline]
    spec_path = tmp_path / "spec.json"
    spec_path.write_text(json.dumps(spec, indent=2), encoding="utf-8")
    return spec_path, spec


def _identity_row(segment_id: str) -> dict:
    when = (
        ("2019.01.02 12:00:00", "2019.01.03 12:00:00")
        if segment_id == "pre_B"
        else ("2024.06.03 12:00:00", "2024.06.04 12:00:00")
    )
    return {
        "segment_id": segment_id,
        "trade_index": 1,
        "symbol": "GBPUSD.DWX",
        "side": "BUY",
        "entry_time_mt5_server": when[0],
        "entry_price": "1.25",
        "entry_reason": "GRIMES_CONTEXT_PB_LONG",
        "initial_stop": "1.24",
        "initial_target": "1.27",
        "exit_time_mt5_server": when[1],
        "exit_price": "1.27",
        "exit_reason": "TAKE_PROFIT",
        "volume": "0.2",
        "gross_profit_sign": 1,
    }


def _time(day: int, minute: int) -> str:
    value = dt.datetime(2026, 7, day, tzinfo=dt.UTC) + dt.timedelta(minutes=minute)
    return value.isoformat().replace("+00:00", "Z")


def _native_report(segment_id: str, *, inference: bool) -> str:
    row = _identity_row(segment_id)
    entry_comment = f"QM10939E|GCPBL|{row['initial_stop']}|{row['initial_target']}"
    exit_comment = "QM10939X|TP"
    deals = ""
    if inference:
        deals = f"""
<tr><td>{row['entry_time_mt5_server']}</td><td>1</td><td>GBPUSD.DWX</td><td>buy</td><td>in</td><td>0.20</td><td>1.25000</td><td>1</td><td>0</td><td>0</td><td>0</td><td>100000</td><td>{entry_comment}</td></tr>
<tr><td>{row['exit_time_mt5_server']}</td><td>2</td><td>GBPUSD.DWX</td><td>sell</td><td>out</td><td>0.20</td><td>1.27000</td><td>1</td><td>-2.00</td><td>0</td><td>200.00</td><td>100198</td><td>{exit_comment}</td></tr>
"""
    return f"""<html><body><table>
<tr><td>Expert:</td><td>QM5_10939</td></tr>
<tr><td>Symbol:</td><td>GBPUSD.DWX</td></tr>
<tr><td>Period:</td><td>H4 (2017.10.25 - 2025.12.31)</td></tr>
<tr><td>History Quality:</td><td>100% real ticks</td></tr>
<tr><td>Bars:</td><td>1000</td></tr>
<tr><td>Ticks:</td><td>100000</td></tr>
<tr><td>Symbols:</td><td>2</td></tr>
<tr><td>Total Trades:</td><td>{1 if inference else 0}</td></tr>
<tr><th>Deals</th></tr>
<tr><th>Time</th><th>Deal</th><th>Symbol</th><th>Type</th><th>Direction</th><th>Volume</th><th>Price</th><th>Order</th><th>Commission</th><th>Swap</th><th>Profit</th><th>Balance</th><th>Comment</th></tr>
{deals}</table></body></html>
"""


def _make_bundle(tmp_path: Path) -> tuple[Path, Path, dict, dict, dict[str, str]]:
    spec_path, spec = _make_spec(tmp_path)
    artifact_dir = tmp_path / "artifacts"
    owner_private_key = Ed25519PrivateKey.generate()
    owner_public_key = _write(
        tmp_path / "owner_oob" / "owner_ed25519.pub",
        owner_private_key.public_key().public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw,
        ),
    )
    window = {
        "requested_from_date": "2017-10-25",
        "requested_to_date": "2025-12-31",
        "effective_from_date": "2017-10-25",
        "effective_to_date": "2025-12-31",
    }
    segment_windows = {
        "pre_B": {
            "warmup_start": "2017.10.25 00:00:00",
            "score_start": "2018.01.15 00:00:00",
            "score_end": "2023.12.12 00:00:00",
            "actual_first_session_bar": "2017.10.25 00:00:00",
            "actual_last_session_bar": "2023.12.12 00:00:00",
        },
        "post_B_pre_C": {
            "warmup_start": "2023.12.18 00:00:00",
            "score_start": "2024.03.01 00:00:00",
            "score_end": "2025.10.08 00:00:00",
            "actual_first_session_bar": "2023.12.18 00:00:00",
            "actual_last_session_bar": "2025.10.08 00:00:00",
        },
        "post_C_pre_D": {
            "warmup_start": "2025.11.03 00:00:00",
            "score_start": "2025.11.03 00:00:00",
            "score_end": "2025.12.17 00:00:00",
            "actual_first_session_bar": "2025.11.03 00:00:00",
            "actual_last_session_bar": "2025.12.17 00:00:00",
        },
        "post_D_tail": {
            "warmup_start": "2025.12.22 00:00:00",
            "score_start": "2025.12.22 00:00:00",
            "score_end": "2025.12.31 00:00:00",
            "actual_first_session_bar": "2025.12.22 00:00:00",
            "actual_last_session_bar": "2025.12.31 00:00:00",
        },
    }
    card = _write(
        artifact_dir / "card_v2.md",
        """---
card_schema_version: 2
ea_id: QM5_10939
g0_status: APPROVED
execution_contract_status: APPROVED
---
## Source-defined rules
Qualitative source only.
## QM interpretations
QM-10939-V1.
## Framework execution overrides
Friday and news are explicit.
## Exit precedence
Ordered.
## Runtime data dependencies
Bound.
## Falsification and requalification
Fail closed.
""",
    )
    source_file = _write(
        artifact_dir / "source.mq5",
        """// approved source
void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NewsFilterHook(TimeCurrent()))
      return;
   if(!QM_NewsAllowsTrade2(_Symbol, TimeCurrent(), 3, 1))
      return;
   Strategy_ManageOpenPosition();
  }
""",
    )
    kill_switch_include = _write(
        artifact_dir / "QM_KillSwitch.mqh",
        """bool g_qm_ks_halted = false;
bool QM_KillSwitchOwnedExposureExists() { return false; }
int QM_KillSwitchCloseOwnedPositions() { return 0; }
int QM_KillSwitchDeleteOwnedPendings() { return 0; }
bool QM_KillSwitchCheck()
  {
   if(g_qm_ks_halted && QM_KillSwitchOwnedExposureExists())
     {
      QM_KillSwitchCloseOwnedPositions();
      QM_KillSwitchDeleteOwnedPendings();
      // KILL_SWITCH_FLATTEN_RETRY
     }
   return !g_qm_ks_halted;
  }
""",
    )
    closure = _write_structured(
        artifact_dir / "source_closure.json",
        {
            "schema_version": 1,
            "artifact_type": packet.SOURCE_CLOSURE_ARTIFACT,
            "packet_id": packet.PACKET_ID,
            "entries": [source_file, kill_switch_include],
        },
    )
    preset = _write(
        artifact_dir / "approved.set",
        "; environment: live\n; symbol: GBPUSD.DWX\n; timeframe: H4\n"
        "RISK_FIXED=0\nRISK_PERCENT=0.2007\nPORTFOLIO_WEIGHT=1\n"
        "qm_friday_close_enabled=true\nqm_friday_close_hour_broker=21\n"
        "qm_news_temporal=3\nqm_news_compliance=1\nqm_news_mode_legacy=0\n",
    )
    compile_log = _write(artifact_dir / "compile.log", "0 errors, 0 warnings")
    ex5 = _write(artifact_dir / "ea.ex5", b"synthetic ex5")
    q08_extractor = _write(artifact_dir / "q08_extractor.py", "# q08")
    native_extractor = _write(artifact_dir / "native_extractor.py", "# native")
    source_manifest = _write_structured(
        artifact_dir / "source_manifest.json",
        {
            "schema_version": 1,
            "artifact_type": packet.SOURCE_MANIFEST_ARTIFACT,
            "packet_id": packet.PACKET_ID,
            "sleeves": [{"ea_id": 10939, "symbol": "GBPUSD.DWX", "timeframe": "H4"}],
            "evaluation_window": window,
        },
    )
    host_h4 = _write(artifact_dir / "GBPUSD_DWX_H4.hcc", b"h4")
    host_d1 = _write(artifact_dir / "GBPUSD_DWX_D1.hcc", b"d1")
    conversion = _write(artifact_dir / "EURUSD_DWX_conversion.hcc", b"conversion")
    series_rows = [
        ("GBPUSD.DWX", "H4", "HOST", host_h4, 1000),
        ("GBPUSD.DWX", "D1", "CONTEXT", host_d1, 500),
        ("EURUSD.DWX", "CONVERSION", "EUR_ACCOUNT_CONVERSION", conversion, 1000),
    ]
    series_manifests = []
    for symbol, timeframe, role, data_file, record_count in series_rows:
        series_manifests.append(
            _write_structured(
                artifact_dir / f"{symbol.replace('.', '_')}_{timeframe}_manifest.json",
                {
                    "schema_version": 1,
                    "artifact_type": packet.DATA_SERIES_FILE_MANIFEST_ARTIFACT,
                    "packet_id": packet.PACKET_ID,
                    "symbol": symbol,
                    "timeframe": timeframe,
                    "role": role,
                    "literal_dwx": True,
                    "source": "READ_ONLY_DARWINEXZERO_MT5_EXPORT",
                    "record_count": record_count,
                    "first_mt5_server": "2017.10.25 00:00:00",
                    "last_mt5_server": "2025.12.31 20:00:00",
                    "data_file": data_file,
                },
            )
        )
    instrument_files = []
    for symbol, base, profit in (
        ("GBPUSD.DWX", "GBP", "USD"),
        ("EURUSD.DWX", "EUR", "USD"),
    ):
        instrument_files.append(
            _write_structured(
                artifact_dir / f"{symbol.replace('.', '_')}_instrument.json",
                {
                    "schema_version": 1,
                    "artifact_type": packet.INSTRUMENT_FILE_ARTIFACT,
                    "packet_id": packet.PACKET_ID,
                    "symbol": symbol,
                    "broker_server": "DarwinexZero",
                    "literal_dwx": True,
                    "digits": 5,
                    "point": "0.00001",
                    "contract_size": "100000",
                    "currency_base": base,
                    "currency_profit": profit,
                },
                hash_field="instrument_payload_sha256",
            )
        )
    instrument_manifest = _write_structured(
        artifact_dir / "instrument_manifest.json",
        {
            "schema_version": 1,
            "artifact_type": packet.INSTRUMENT_MANIFEST_ARTIFACT,
            "packet_id": packet.PACKET_ID,
            "broker_server": "DarwinexZero",
            "literal_dwx_only": True,
            "instruments": [
                {
                    "symbol": "GBPUSD.DWX",
                    "role": "TRADED",
                    "instrument_file": instrument_files[0],
                },
                {
                    "symbol": "EURUSD.DWX",
                    "role": "EUR_ACCOUNT_CONVERSION",
                    "instrument_file": instrument_files[1],
                },
            ],
        },
    )
    weekend_cutoffs = []
    cursor = dt.date(2017, 10, 25)
    while cursor.weekday() != 4:
        cursor += dt.timedelta(days=1)
    while cursor <= dt.date(2025, 12, 31):
        weekend_cutoffs.append(
            {
                "weekend_friday": cursor.isoformat(),
                "last_tradable_mt5_server": f"{cursor:%Y.%m.%d} 21:00:00",
                "next_tradable_mt5_server": (
                    f"{cursor + dt.timedelta(days=3):%Y.%m.%d} 00:00:00"
                ),
                "source": "DARWINEXZERO_MT5_SESSION_EXPORT",
            }
        )
        cursor += dt.timedelta(days=7)
    calendar = _write_structured(
        artifact_dir / "dxz_sessions.json",
        {
            "schema_version": 1,
            "artifact_type": packet.SESSION_CALENDAR_ARTIFACT,
            "packet_id": packet.PACKET_ID,
            "broker_server": "DarwinexZero",
            "timezone_contract": "MT5_SERVER_TIME",
            "literal_dwx_only": True,
            "covered_symbols": ["EURUSD.DWX", "GBPUSD.DWX"],
            "coverage_from_date": "2017-10-25",
            "coverage_to_date": "2025-12-31",
            "weekly_sessions": [
                {"weekday": day, "open_mt5": "00:00", "close_mt5": "23:59"}
                for day in range(5)
            ],
            "dst_transitions": [
                {
                    "date": "2025-03-30",
                    "utc_offset_before": "+02:00",
                    "utc_offset_after": "+03:00",
                }
            ],
            "weekend_flat_cutoffs": weekend_cutoffs,
        },
        hash_field="calendar_payload_sha256",
    )
    data_manifest = _write_structured(
        artifact_dir / "data_manifest.json",
        {
            "schema_version": 1,
            "artifact_type": packet.DATA_MANIFEST_ARTIFACT,
            "packet_id": packet.PACKET_ID,
            "literal_dwx_only": True,
            "series": [
                {
                    "symbol": symbol,
                    "timeframe": timeframe,
                    "role": role,
                    "file": data_file,
                    "file_manifest": series_manifests[index],
                }
                for index, (symbol, timeframe, role, data_file, _) in enumerate(series_rows)
            ],
            "session_calendar": calendar,
            "instrument_manifest": instrument_manifest,
        },
    )
    segment_manifest = _write_structured(
        artifact_dir / "segment_manifest.json",
        {
            "schema_version": 1,
            "artifact_type": packet.SEGMENT_MANIFEST_ARTIFACT,
            "packet_id": packet.PACKET_ID,
            "data_manifest_sha256": data_manifest["sha256"],
            "session_calendar_sha256": calendar["sha256"],
            "session_aware": True,
            "host_d1_conversion_intersection": True,
            "segments": [
                {
                    "segment_id": row["segment_id"],
                    "role": row["role"],
                    **segment_windows[row["segment_id"]],
                }
                for row in spec["history_contract"]["segments"]
            ],
        },
    )
    cost_manifest = _make_cost_manifest(
        artifact_dir / "cost", source_sha=source_manifest["sha256"], window=window
    )

    effective_contract = {
        "friday": {"enabled": True, "hour_broker": 21},
        "news": {"temporal": 3, "compliance": 1},
        "risk": {
            "mode": "PERCENT",
            "percent": 0.2007,
            "fixed": 0,
            "deposit": 100000,
            "account_currency": "EUR",
            "portfolio_weight": 1,
        },
    }
    effective_sha = packet.canonical_json_sha(effective_contract)

    owner_decisions = {
        "CARD_V2_SEMANTICS": "QM_INTERPRETATION_VARIANT_APPROVED",
        "FRIDAY_CLOSE_POLICY": "FRAMEWORK_OVERRIDE_FRIDAY_21_BROKER",
        "NEWS_POLICY": "DXZ_PRE30_POST30",
        "AS_LIVE_RISK_CONTRACT": "AS_LIVE_PERCENT_EUR_100K",
        "SOURCE_OF_RECORD": "OWNER_SELECTED_SOURCE_CLOSURE",
    }
    owner_gates = []
    owner_receipts = {}
    for gate_id, decision in owner_decisions.items():
        receipt = _write_structured(
            artifact_dir / f"owner_{gate_id}.json",
            {
                "schema_version": 1,
                "artifact_type": packet.OWNER_RECEIPT_ARTIFACT,
                "packet_id": packet.PACKET_ID,
                "gate_id": gate_id,
                "decision": decision,
                "spec_sha256": packet.sha256_file(spec_path),
                "approved_by": "OWNER",
                "approved_at_utc": "2026-07-16T12:00:00Z",
            },
            hash_field="receipt_payload_sha256",
        )
        owner_receipts[gate_id] = receipt
        owner_gates.append(
            {
                "gate_id": gate_id,
                "status": "APPROVED",
                "decision": decision,
                "receipt": receipt,
            }
        )
    resolved = []
    for row in spec["commission_ambiguities"]:
        commission_evidence = _write(
            artifact_dir / f"commission_resolution_{row['index']}.json",
            json.dumps({"index": row["index"], "native_deal": True}) + "\n",
        )
        resolved.append(
            {
                **row,
                "method": "NATIVE_DXZ_ROUND_TRIP_COMMISSION",
                "account_currency": "EUR",
                "commission_account_currency": 2.5,
                "evidence": commission_evidence,
            }
        )
    commission_resolution = _write_structured(
        artifact_dir / "commission_resolution.json",
        {
            "schema_version": 1,
            "artifact_type": packet.COMMISSION_RESOLUTION_ARTIFACT,
            "packet_id": packet.PACKET_ID,
            "status": "COMPLETE",
            "ambiguous_trade_count": 0,
            "unbounded_trade_count": 0,
            "resolved_rows": resolved,
        },
        hash_field="resolution_payload_sha256",
    )
    trust_anchor_input_bindings = {
        "card_v2_sha256": card["sha256"],
        "source_manifest_sha256": source_manifest["sha256"],
        "source_closure_manifest_sha256": closure["sha256"],
        "compile_log_sha256": compile_log["sha256"],
        "ex5_sha256": ex5["sha256"],
        "preset_sha256": preset["sha256"],
        "data_manifest_sha256": data_manifest["sha256"],
        "segment_boundary_manifest_sha256": segment_manifest["sha256"],
        "q08_extractor_sha256": q08_extractor["sha256"],
        "native_extractor_sha256": native_extractor["sha256"],
        "execution_cost_manifest_sha256": cost_manifest["sha256"],
        "commission_resolution_sha256": commission_resolution["sha256"],
        "effective_contract_sha256": effective_sha,
    }
    trust_anchor = _write_signed_structured(
        tmp_path / "owner_oob" / "trust_anchor.json",
        {
            "schema_version": 1,
            "artifact_type": packet.OWNER_TRUST_ANCHOR_ARTIFACT,
            "packet_id": packet.PACKET_ID,
            "spec_sha256": packet.sha256_file(spec_path),
            "owner_authority_id": "OWNER",
            "signer_public_key_sha256": owner_public_key["sha256"],
            "issued_at_utc": "2026-07-16T12:05:00Z",
            "receipts": {
                gate_id: {
                    "decision": owner_decisions[gate_id],
                    "receipt_sha256": owner_receipts[gate_id]["sha256"],
                }
                for gate_id in sorted(owner_receipts)
            },
            "input_bindings": trust_anchor_input_bindings,
        },
        private_key=owner_private_key,
        hash_field="anchor_payload_sha256",
    )
    trust_anchor.update(
        {
            "owner_public_key_path": owner_public_key["path"],
            "owner_public_key_sha256": owner_public_key["sha256"],
            "private_key": owner_private_key,
        }
    )

    sealed_bindings = {
        "card_v2": card,
        "source_manifest": source_manifest,
        "source_closure_manifest": closure,
        "compile_log": compile_log,
        "ex5": ex5,
        "preset": preset,
        "data_manifest": data_manifest,
        "segment_boundary_manifest": segment_manifest,
        "q08_extractor": q08_extractor,
        "native_extractor": native_extractor,
        "execution_cost_manifest": cost_manifest,
        "commission_resolution": commission_resolution,
    }
    input_contract = packet._input_contract_payload(
        card_v2=card,
        owner_receipts=owner_receipts,
        source_manifest=source_manifest,
        source_closure=closure,
        compile_log=compile_log,
        ex5=ex5,
        preset=preset,
        data_manifest=data_manifest,
        segment_manifest=segment_manifest,
        q08_extractor=q08_extractor,
        native_extractor=native_extractor,
        cost_manifest=cost_manifest,
        commission_resolution=commission_resolution,
        effective_contract_sha256=effective_sha,
        owner_trust_anchor_sha256=trust_anchor["sha256"],
        owner_public_key_sha256=owner_public_key["sha256"],
    )
    input_contract_sha = packet.canonical_json_sha(input_contract)
    sealed = _write_structured(
        artifact_dir / "sealed_inputs.json",
        {
            "schema_version": 1,
            "artifact_type": packet.SEALED_INPUT_ARTIFACT,
            "packet_id": packet.PACKET_ID,
            "bindings": sealed_bindings,
            "owner_receipts": owner_receipts,
            "input_contract": input_contract,
            "input_contract_sha256": input_contract_sha,
        },
    )
    common_hashes = {
        "sealed_input_manifest_sha256": sealed["sha256"],
        "input_contract_sha256": input_contract_sha,
        "source_manifest_sha256": source_manifest["sha256"],
        "binary_sha256": ex5["sha256"],
        "preset_sha256": preset["sha256"],
        "effective_contract_sha256": effective_sha,
        "execution_cost_manifest_sha256": cost_manifest["sha256"],
        "commission_resolution_sha256": commission_resolution["sha256"],
        "data_manifest_sha256": data_manifest["sha256"],
        "segment_boundary_manifest_sha256": segment_manifest["sha256"],
        "q08_extractor_sha256": q08_extractor["sha256"],
        "native_extractor_sha256": native_extractor["sha256"],
        "owner_trust_anchor_sha256": trust_anchor["sha256"],
        "owner_public_key_sha256": owner_public_key["sha256"],
    }

    def make_group(name: str, role: str, day: int) -> dict:
        segments = []
        for ordinal, segment_spec in enumerate(spec["history_contract"]["segments"]):
            segment_id = segment_spec["segment_id"]
            inference = segment_spec["role"] == "INFERENCE"
            folder = artifact_dir / name / segment_id
            mt5_root = folder / "mt5"
            q08_raw = _write(folder / "q08_raw.jsonl", f"raw {name} {segment_id}")
            native_report = _write(
                mt5_root / "report.htm", _native_report(segment_id, inference=inference)
            )
            rows = [_identity_row(segment_id)] if inference else []
            stream_text = "".join(json.dumps(row) + "\n" for row in rows)
            q08_identity = _write(folder / "q08_identity.jsonl", stream_text)
            q08_identity.update(
                {
                    "producer": "Q08_EMITTER_PARSER",
                    "source_sha256": q08_raw["sha256"],
                    "extractor_sha256": q08_extractor["sha256"],
                }
            )
            native_identity = _write(folder / "native_identity.jsonl", stream_text)
            native_identity.update(
                {
                    "producer": "VALIDATOR_BUILTIN_MT5_REPORT_DERIVATION_V1",
                    "source_sha256": native_report["sha256"],
                    "extractor_sha256": native_extractor["sha256"],
                    "derived_stream_sha256": native_identity["sha256"],
                    "derived_identity_sha256": packet.canonical_json_sha(rows),
                }
            )
            boundary = segment_windows[segment_id]
            history = {
                **boundary,
                "gap_boundary_manifest_sha256": segment_manifest["sha256"],
                "warmup_h4_bars": 60 if inference else 10,
                "warmup_d1_bars": 50 if inference else 5,
                "session_aware_continuity_pass": True,
                "host_d1_conversion_intersection_pass": True,
                "segment_process_restarted": True,
                "history_staged_without_pre_gap": True,
                "indicator_state_reset": True,
                "rolling_state_reset": True,
                "entries_during_warmup": 0,
                "position_at_segment_start": 0,
                "position_at_segment_end": 0,
                "pending_orders_at_segment_start": 0,
                "pending_orders_at_segment_end": 0,
                "tester_forced_exit_count": 0,
                "economics_used": inference,
                "score_enabled": inference,
                "warmup_complete": inference,
                "score_started_after_warmup": inference,
            }
            start_minute = ordinal * 20
            history_receipt = _write_structured(
                folder / "history.json",
                {
                    "schema_version": 1,
                    "artifact_type": packet.HISTORY_RECEIPT_ARTIFACT,
                    "packet_id": packet.PACKET_ID,
                    "run_id": name,
                    "segment_id": segment_id,
                    "history_contract_sha256": packet.canonical_json_sha(history),
                },
                hash_field="receipt_payload_sha256",
            )
            reset_receipt = _write_structured(
                folder / "reset.json",
                {
                    "schema_version": 1,
                    "artifact_type": packet.RESET_RECEIPT_ARTIFACT,
                    "packet_id": packet.PACKET_ID,
                    "run_id": name,
                    "segment_id": segment_id,
                    "process_restarted": True,
                    "indicator_state_reset": True,
                    "rolling_state_reset": True,
                    "position_count": 0,
                    "pending_order_count": 0,
                },
                hash_field="receipt_payload_sha256",
            )
            execution_id = f"{name}-{segment_id}"
            sandbox_id = f"DXZ_Truth_{name}_{ordinal}"
            started_utc = _time(day, start_minute)
            finished_utc = _time(day, start_minute + 10)
            receipt_artifacts = {
                "history_receipt": history_receipt,
                "reset_receipt": reset_receipt,
                "native_report": native_report,
                "q08_raw": q08_raw,
                "q08_identity_stream": q08_identity,
                "native_identity_stream": native_identity,
            }
            execution_receipt = _write_signed_structured(
                folder / "receipt.json",
                {
                    "schema_version": 1,
                    "artifact_type": packet.EXECUTION_RECEIPT_ARTIFACT,
                    "packet_id": packet.PACKET_ID,
                    "run_id": name,
                    "role": role,
                    "isolation_id": f"isolation-{name}",
                    "segment_id": segment_id,
                    "execution_id": execution_id,
                    "sandbox_id": sandbox_id,
                    "output_root": str(folder),
                    "mt5_root": str(mt5_root),
                    "started_utc": started_utc,
                    "finished_utc": finished_utc,
                    "history_contract_sha256": packet.canonical_json_sha(history),
                    "input_hashes": common_hashes,
                    "artifacts": receipt_artifacts,
                    "signer_role": "OWNER_QUALIFICATION_AUTHORITY",
                    "signer_public_key_sha256": owner_public_key["sha256"],
                    "signed_at_utc": _time(day, start_minute + 11),
                },
                private_key=owner_private_key,
                hash_field="receipt_payload_sha256",
            )
            segments.append(
                {
                    "segment_id": segment_id,
                    "role": segment_spec["role"],
                    "execution_id": execution_id,
                    "sandbox_id": sandbox_id,
                    "output_root": str(folder),
                    "mt5_root": str(mt5_root),
                    "started_utc": started_utc,
                    "finished_utc": finished_utc,
                    **common_hashes,
                    "history": history,
                    **receipt_artifacts,
                    "receipt": execution_receipt,
                }
            )
        group = {
            "run_id": name,
            "role": role,
            "isolation_id": f"isolation-{name}",
            "started_utc": _time(day, 0),
            "finished_utc": _time(day, 90),
            "collision_free": True,
            "source_inputs_unchanged": True,
            **common_hashes,
            "segments": segments,
        }
        if role == "REFERENCE_PRODUCER":
            group["frozen_before_verification"] = True
            seal_segments = []
            for segment in segments:
                stream_rows = (
                    [_identity_row(segment["segment_id"])]
                    if segment["role"] == "INFERENCE"
                    else []
                )
                seal_segments.append(
                    {
                        "segment_id": segment["segment_id"],
                        "output_root": segment["output_root"],
                        "artifacts": {
                            field: segment[field] for field in packet.RUN_BINDINGS
                        },
                        "identity": packet._identity_digests(stream_rows),
                    }
                )
            group["seal"] = _write_signed_structured(
                artifact_dir / name / "reference_seal.json",
                {
                    "schema_version": 1,
                    "artifact_type": packet.REFERENCE_SEAL_ARTIFACT,
                    "packet_id": packet.PACKET_ID,
                    "run_id": name,
                    "role": "REFERENCE_PRODUCER",
                    "reference_finished_utc": _time(day, 90),
                    "sealed_at_utc": _time(day, 100),
                    "input_contract_sha256": input_contract_sha,
                    "segments": seal_segments,
                    "signer_role": "OWNER_QUALIFICATION_AUTHORITY",
                    "signer_public_key_sha256": owner_public_key["sha256"],
                },
                private_key=owner_private_key,
                hash_field="seal_payload_sha256",
            )
        return group

    bundle = {
        "schema_version": 1,
        "artifact_type": packet.BUNDLE_ARTIFACT,
        "packet_id": packet.PACKET_ID,
        "spec_sha256": packet.sha256_file(spec_path),
        "status": "READY_FOR_QUALIFICATION_VALIDATION",
        "deployment_eligible": False,
        "validation_as_of_utc": "2026-07-19T03:00:00Z",
        "card_v2": card,
        "owner_gates": owner_gates,
        "effective_contract": effective_contract,
        "effective_contract_sha256": effective_sha,
        "source_manifest": source_manifest,
        "data_manifest": data_manifest,
        "segment_boundary_manifest": segment_manifest,
        "sealed_input_manifest": sealed,
        "approved_preset": preset,
        "build": {
            "clean_compile": True,
            "compile_pass": True,
            "recursive_include_closure_bound": True,
            "source_closure_manifest": closure,
            "source_of_record_sha256": closure["sha256"],
            "compile_log": compile_log,
            "ex5": ex5,
        },
        "q08_extractor": q08_extractor,
        "native_extractor": native_extractor,
        "execution_costs": {
            "status": "PASS",
            "manifest": cost_manifest,
            "commission_resolution": commission_resolution,
        },
        "reference_run": make_group("reference", "REFERENCE_PRODUCER", 17),
        "verification_runs": [
            make_group("verify1", "VERIFICATION", 18),
            make_group("verify2", "VERIFICATION", 19),
        ],
    }
    bundle_path = tmp_path / "bundle" / "bundle.json"
    bundle_path.parent.mkdir(parents=True, exist_ok=True)
    bundle_path.write_text(json.dumps(bundle, indent=2), encoding="utf-8")
    return spec_path, bundle_path, spec, bundle, trust_anchor


def _save(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _validate_bundle(spec_path: Path, bundle_path: Path, trust_anchor: dict[str, str]) -> dict:
    return packet.validate_bundle(
        spec_path,
        bundle_path,
        owner_trust_anchor_path=Path(trust_anchor["path"]),
        owner_trust_anchor_sha256=trust_anchor["sha256"],
        owner_public_key_path=Path(trust_anchor["owner_public_key_path"]),
        owner_public_key_sha256=trust_anchor["owner_public_key_sha256"],
    )


def test_real_spec_hash_bindings_pass() -> None:
    result = packet.validate_spec(REAL_SPEC)
    assert result["status"] == "BLOCKED_OWNER_TRUST_UNREGISTERED", result
    assert result["verified_bindings"] == 16


def test_complete_three_group_bundle_passes(tmp_path: Path) -> None:
    spec_path, bundle_path, _, _, trust_anchor = _make_bundle(tmp_path)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert result["status"] == "PASS", result
    assert result["run_groups_validated"] == 3


def test_self_referential_run_artifact_path_fails(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    bundle["verification_runs"][0]["segments"][0]["receipt"] = copy.deepcopy(
        bundle["reference_run"]["segments"][0]["receipt"]
    )
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any("RUN_ARTIFACT_PATH_REUSED" in error for error in result["errors"])


def test_missing_full_entry_field_fails(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    meta = bundle["verification_runs"][0]["segments"][0]["q08_identity_stream"]
    path = Path(meta["path"])
    row = json.loads(path.read_text(encoding="utf-8"))
    row.pop("entry_reason")
    path.write_text(json.dumps(row) + "\n", encoding="utf-8")
    meta["sha256"] = packet.sha256_file(path)
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any("IDENTITY_FIELDS_MISSING" in error for error in result["errors"])


def test_short_inference_warmup_fails(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    bundle["verification_runs"][1]["segments"][0]["history"]["warmup_d1_bars"] = 49
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any("HISTORY_D1_WARMUP_SHORT" in error for error in result["errors"])


def test_unresolved_commission_fingerprint_fails(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    resolution_path = Path(bundle["execution_costs"]["commission_resolution"]["path"])
    resolution = json.loads(resolution_path.read_text(encoding="utf-8"))
    resolution["resolved_rows"].pop()
    resolution.pop("resolution_payload_sha256")
    resolution["resolution_payload_sha256"] = packet.canonical_json_sha(resolution)
    resolution_path.write_text(json.dumps(resolution), encoding="utf-8")
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any("COMMISSION_RESOLUTION_ROW_COUNT_INVALID" in error for error in result["errors"])


def test_friday_runtime_must_match_owner_decision(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    for gate in bundle["owner_gates"]:
        if gate["gate_id"] == "FRIDAY_CLOSE_POLICY":
            gate["decision"] = "NO_FRAMEWORK_FRIDAY_CLOSE"
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any("EFFECTIVE_FRIDAY_OWNER_MISMATCH" in error for error in result["errors"])


def test_verification_groups_must_be_serial(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    bundle["verification_runs"][1]["started_utc"] = _time(18, 30)
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any("VERIFICATION_RUNS_NOT_SERIAL" in error for error in result["errors"])


def test_terminal_output_root_is_forbidden(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    bundle["verification_runs"][0]["segments"][0]["output_root"] = str(
        tmp_path / "T_Live" / "evidence"
    )
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any("RUN_OUTPUT_FORBIDDEN_ROOT" in error for error in result["errors"])


def test_arbitrary_empty_cost_evidence_cannot_self_attest_pass(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    empty_manifest = _write(tmp_path / "costs" / "empty_manifest.json", "{}\n")
    bundle["execution_costs"]["manifest"] = empty_manifest
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert result["status"] == "FAIL"
    assert any(
        "EXECUTION_COST_MANIFEST_REVALIDATION_FAILED" in error
        for error in result["errors"]
    )


def test_effective_portfolio_weight_must_be_exactly_one(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    bundle["effective_contract"]["risk"]["portfolio_weight"] = 0.5
    bundle["effective_contract_sha256"] = packet.canonical_json_sha(
        bundle["effective_contract"]
    )
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any(
        "EFFECTIVE_PORTFOLIO_WEIGHT_INVALID" in error for error in result["errors"]
    )


def test_live_preset_portfolio_weight_must_be_exactly_one(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    preset_path = Path(bundle["approved_preset"]["path"])
    preset_path.write_text(
        preset_path.read_text(encoding="utf-8").replace(
            "PORTFOLIO_WEIGHT=1", "PORTFOLIO_WEIGHT=0.5"
        ),
        encoding="utf-8",
    )
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any(
        "PRESET_PORTFOLIO_WEIGHT_INVALID" in error for error in result["errors"]
    )


def test_empty_reference_seal_is_rejected(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    empty_seal = _write(tmp_path / "reference" / "empty_seal.json", "{}\n")
    bundle["reference_run"]["seal"] = empty_seal
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert result["status"] == "FAIL"
    assert any(
        "STRUCTURED_ARTIFACT_TYPE_INVALID" in error for error in result["errors"]
    )


def test_output_root_cannot_be_reused_across_run_groups(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    bundle["verification_runs"][0]["segments"][0]["output_root"] = bundle[
        "reference_run"
    ]["segments"][0]["output_root"]
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any("RUN_OUTPUT_ROOT_REUSED" in error for error in result["errors"])


def test_bundle_cannot_self_supply_owner_authority(tmp_path: Path) -> None:
    spec_path, bundle_path, _, _, _ = _make_bundle(tmp_path)
    result = packet.validate_bundle(spec_path, bundle_path)
    assert any(
        "OWNER_TRUST_ANCHOR_OUT_OF_BAND_PATH_REQUIRED" in error
        for error in result["errors"]
    )


def test_owner_trust_anchor_requires_out_of_band_expected_hash(tmp_path: Path) -> None:
    spec_path, bundle_path, _, _, trust_anchor = _make_bundle(tmp_path)
    result = packet.validate_bundle(
        spec_path,
        bundle_path,
        owner_trust_anchor_path=Path(trust_anchor["path"]),
        owner_trust_anchor_sha256="0" * 64,
    )
    assert any(
        "OWNER_TRUST_ANCHOR_OUT_OF_BAND_HASH_MISMATCH" in error
        for error in result["errors"]
    )


def test_self_rehashed_owner_receipt_is_not_approval(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    gate = bundle["owner_gates"][0]
    receipt_path = Path(gate["receipt"]["path"])
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    receipt["approved_at_utc"] = "2026-07-16T12:01:00Z"
    receipt.pop("receipt_payload_sha256")
    receipt["receipt_payload_sha256"] = packet.canonical_json_sha(receipt)
    receipt_path.write_text(json.dumps(receipt, sort_keys=True), encoding="utf-8")
    gate["receipt"]["sha256"] = packet.sha256_file(receipt_path)
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any(
        "OWNER_RECEIPT_NOT_PINNED_BY_OUT_OF_BAND_ANCHOR" in error
        for error in result["errors"]
    )


def test_owner_trust_anchor_must_be_outside_bundle_root(tmp_path: Path) -> None:
    spec_path, bundle_path, _, _, trust_anchor = _make_bundle(tmp_path)
    inside = _write(
        bundle_path.parent / "self_supplied_trust_anchor.json",
        Path(trust_anchor["path"]).read_bytes(),
    )
    result = packet.validate_bundle(
        spec_path,
        bundle_path,
        owner_trust_anchor_path=Path(inside["path"]),
        owner_trust_anchor_sha256=inside["sha256"],
    )
    assert any(
        "OWNER_TRUST_ANCHOR_INSIDE_BUNDLE_ROOT" in error for error in result["errors"]
    )


def test_arbitrary_text_is_not_a_native_mt5_report(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    segment = bundle["verification_runs"][0]["segments"][0]
    report_path = Path(segment["native_report"]["path"])
    report_path.write_text("report verify1 pre_B", encoding="utf-8")
    segment["native_report"]["sha256"] = packet.sha256_file(report_path)
    segment["native_identity_stream"]["source_sha256"] = segment["native_report"]["sha256"]
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any(error.startswith("NATIVE_REPORT_") for error in result["errors"])


def test_native_identity_must_be_derived_from_report(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    segment = bundle["verification_runs"][0]["segments"][0]
    meta = segment["native_identity_stream"]
    path = Path(meta["path"])
    row = json.loads(path.read_text(encoding="utf-8"))
    row["exit_price"] = "1.26"
    path.write_text(json.dumps(row) + "\n", encoding="utf-8")
    meta["sha256"] = packet.sha256_file(path)
    meta["derived_stream_sha256"] = meta["sha256"]
    meta["derived_identity_sha256"] = packet.canonical_json_sha([row])
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any(
        "NATIVE_IDENTITY_NOT_DERIVED_FROM_REPORT" in error for error in result["errors"]
    )


def test_unstructured_series_file_manifest_is_rejected(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    data_path = Path(bundle["data_manifest"]["path"])
    data = json.loads(data_path.read_text(encoding="utf-8"))
    manifest_path = Path(data["series"][0]["file_manifest"]["path"])
    manifest_path.write_text("{}\n", encoding="utf-8")
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any(
        "STRUCTURED_ARTIFACT_TYPE_INVALID" in error for error in result["errors"]
    )


def test_unstructured_instrument_file_is_rejected(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    data_path = Path(bundle["data_manifest"]["path"])
    data = json.loads(data_path.read_text(encoding="utf-8"))
    instrument_manifest_path = Path(data["instrument_manifest"]["path"])
    instrument_manifest = json.loads(
        instrument_manifest_path.read_text(encoding="utf-8")
    )
    instrument_path = Path(
        instrument_manifest["instruments"][0]["instrument_file"]["path"]
    )
    instrument_path.write_text("{}\n", encoding="utf-8")
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any(
        "STRUCTURED_ARTIFACT_TYPE_INVALID" in error for error in result["errors"]
    )


def test_run_ids_are_globally_casefold_distinct(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    bundle["verification_runs"][0]["run_id"] = "REFERENCE"
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any("RUN_RUN_ID_REUSED_GLOBALLY" in error for error in result["errors"])


def test_output_roots_cannot_be_ancestor_descendant(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    reference_root = Path(bundle["reference_run"]["segments"][0]["output_root"])
    nested = reference_root / "nested_verification"
    nested.mkdir(parents=True)
    bundle["verification_runs"][0]["segments"][0]["output_root"] = str(nested)
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any(
        "RUN_OUTPUT_ROOT_REUSED_OR_NESTED" in error for error in result["errors"]
    )


def test_reference_seal_cannot_live_inside_run_root(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    old_seal = Path(bundle["reference_run"]["seal"]["path"])
    run_root = Path(bundle["reference_run"]["segments"][0]["output_root"])
    nested_seal = _write(run_root / "forged_reference_seal.json", old_seal.read_bytes())
    bundle["reference_run"]["seal"] = nested_seal
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any(
        "CONTROL_ARTIFACT_INSIDE_OR_CONTAINS_RUN_ROOT" in error
        for error in result["errors"]
    )


def test_generated_artifact_must_stay_in_own_output_root(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    segment = bundle["verification_runs"][0]["segments"][0]
    segment["receipt"] = _write(tmp_path / "foreign" / "receipt.json", "{}\n")
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any(
        "RUN_ARTIFACT_OUTSIDE_OWN_OUTPUT_ROOT" in error for error in result["errors"]
    )


def test_owner_receipt_cannot_live_inside_run_root(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    gate = bundle["owner_gates"][0]
    original = Path(gate["receipt"]["path"])
    run_root = Path(bundle["reference_run"]["segments"][0]["output_root"])
    nested = _write(run_root / "forged_owner_receipt.json", original.read_bytes())
    gate["receipt"] = nested
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any(
        "CONTROL_ARTIFACT_INSIDE_OR_CONTAINS_RUN_ROOT" in error
        for error in result["errors"]
    )


def test_cost_manifest_and_axes_cannot_live_inside_run_root(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    original = Path(bundle["execution_costs"]["manifest"]["path"])
    run_root = Path(bundle["reference_run"]["segments"][0]["output_root"])
    nested_cost_root = run_root / "embedded_cost"
    shutil.copytree(original.parent, nested_cost_root)
    nested_manifest = nested_cost_root / original.name
    bundle["execution_costs"]["manifest"] = {
        "path": str(nested_manifest),
        "sha256": packet.sha256_file(nested_manifest),
    }
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any(
        "CONTROL_ARTIFACT_INSIDE_OR_CONTAINS_RUN_ROOT" in error
        for error in result["errors"]
    )


def test_bundle_cannot_bootstrap_owner_key_from_its_own_files(tmp_path: Path) -> None:
    spec_path, bundle_path, _, _, trust_anchor = _make_bundle(tmp_path)
    result = packet.validate_bundle(
        spec_path,
        bundle_path,
        owner_trust_anchor_path=Path(trust_anchor["path"]),
        owner_trust_anchor_sha256=trust_anchor["sha256"],
    )
    assert any(
        "OWNER_PUBLIC_KEY_OUT_OF_BAND_PATH_REQUIRED" in error
        for error in result["errors"]
    )


def test_self_rehashed_owner_anchor_without_valid_signature_fails(tmp_path: Path) -> None:
    spec_path, bundle_path, _, _, trust_anchor = _make_bundle(tmp_path)
    anchor_path = Path(trust_anchor["path"])
    anchor = json.loads(anchor_path.read_text(encoding="utf-8"))
    anchor["issued_at_utc"] = "2026-07-16T12:06:00Z"
    anchor.pop("anchor_payload_sha256")
    anchor["anchor_payload_sha256"] = packet.canonical_json_sha(anchor)
    anchor_path.write_text(json.dumps(anchor, sort_keys=True), encoding="utf-8")
    trust_anchor["sha256"] = packet.sha256_file(anchor_path)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any(
        "SIGNED_PAYLOAD_SIGNATURE_INVALID" in error for error in result["errors"]
    )


def test_self_rehashed_execution_receipt_without_authority_signature_fails(
    tmp_path: Path,
) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    segment = bundle["verification_runs"][0]["segments"][0]
    receipt_path = Path(segment["receipt"]["path"])
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    receipt["run_id"] = "forged-run"
    receipt.pop("receipt_payload_sha256")
    receipt["receipt_payload_sha256"] = packet.canonical_json_sha(receipt)
    receipt_path.write_text(json.dumps(receipt, sort_keys=True), encoding="utf-8")
    segment["receipt"]["sha256"] = packet.sha256_file(receipt_path)
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any(
        "SIGNED_PAYLOAD_SIGNATURE_INVALID" in error for error in result["errors"]
    )


def test_fake_data_manifest_rehash_is_not_owner_authorized(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    data_path = Path(bundle["data_manifest"]["path"])
    data = json.loads(data_path.read_text(encoding="utf-8"))
    data["literal_dwx_only"] = False
    data.pop("manifest_payload_sha256")
    data["manifest_payload_sha256"] = packet.canonical_json_sha(data)
    data_path.write_text(json.dumps(data, sort_keys=True), encoding="utf-8")
    bundle["data_manifest"]["sha256"] = packet.sha256_file(data_path)
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any(
        "OWNER_TRUST_ANCHOR_INPUT_BINDING_MISMATCH" in error
        for error in result["errors"]
    )


def test_weekend_trade_interval_is_rejected_from_identity_stream(tmp_path: Path) -> None:
    row = _identity_row("pre_B")
    row["entry_time_mt5_server"] = "2024.06.07 20:00:00"
    row["exit_time_mt5_server"] = "2024.06.10 08:00:00"
    stream = tmp_path / "weekend.jsonl"
    stream.write_text(json.dumps(row) + "\n", encoding="utf-8")
    checks = packet.Checks()
    packet._read_identity_rows(
        stream,
        expected_segment="pre_B",
        score_start=dt.datetime(2024, 1, 1),
        score_end=dt.datetime(2024, 12, 31),
        session_calendar={
            "coverage_from_date": "2024-01-01",
            "coverage_to_date": "2024-12-31",
            "weekend_flat_cutoffs": [
                {
                    "weekend_friday": "2024-06-07",
                    "last_tradable_mt5_server": "2024.06.07 21:00:00",
                }
            ],
        },
        label="weekend",
        checks=checks,
    )
    assert any(
        "IDENTITY_WEEKEND_HOLDING_OR_FRIDAY_CUTOFF_BREACH" in error
        for error in checks.errors
    )


def test_early_close_is_stricter_than_friday_21(tmp_path: Path) -> None:
    row = _identity_row("pre_B")
    row["entry_time_mt5_server"] = "2024.03.28 17:00:00"
    row["exit_time_mt5_server"] = "2024.03.28 19:00:00"
    stream = tmp_path / "early_close.jsonl"
    stream.write_text(json.dumps(row) + "\n", encoding="utf-8")
    checks = packet.Checks()
    packet._read_identity_rows(
        stream,
        expected_segment="pre_B",
        score_start=dt.datetime(2024, 1, 1),
        score_end=dt.datetime(2024, 12, 31),
        session_calendar={
            "coverage_from_date": "2024-01-01",
            "coverage_to_date": "2024-12-31",
            "weekend_flat_cutoffs": [
                {
                    "weekend_friday": "2024-03-29",
                    "last_tradable_mt5_server": "2024.03.28 18:00:00",
                }
            ],
        },
        label="early_close",
        checks=checks,
    )
    assert any(
        "IDENTITY_WEEKEND_HOLDING_OR_FRIDAY_CUTOFF_BREACH" in error
        for error in checks.errors
    )


def test_current_source_news_return_before_friday_close_is_blocked(tmp_path: Path) -> None:
    current_source = (
        REPO_ROOT
        / "framework"
        / "EAs"
        / "QM5_10939_grimes-context-pb"
        / "QM5_10939_grimes-context-pb.mq5"
    )
    kill_switch = REPO_ROOT / "framework" / "include" / "QM" / "QM_KillSwitch.mqh"
    closure_path = tmp_path / "current_source_closure.json"
    _write_structured(
        closure_path,
        {
            "schema_version": 1,
            "artifact_type": packet.SOURCE_CLOSURE_ARTIFACT,
            "packet_id": packet.PACKET_ID,
            "entries": [
                {"path": str(current_source), "sha256": packet.sha256_file(current_source)},
                {"path": str(kill_switch), "sha256": packet.sha256_file(kill_switch)},
            ],
        },
    )
    checks = packet.Checks()
    packet._validate_source_closure(closure_path, base_dir=tmp_path, checks=checks)
    assert any("SOURCE_FRIDAY_EXIT_PRECEDENCE_INVALID" in error for error in checks.errors)


def test_reference_seal_timestamp_after_verification_start_fails(tmp_path: Path) -> None:
    spec_path, bundle_path, _, bundle, trust_anchor = _make_bundle(tmp_path)
    seal_path = Path(bundle["reference_run"]["seal"]["path"])
    seal = json.loads(seal_path.read_text(encoding="utf-8"))
    seal.pop("seal_payload_sha256")
    seal.pop("signature_base64")
    seal["sealed_at_utc"] = "2026-07-18T01:00:00Z"
    binding = _write_signed_structured(
        seal_path,
        seal,
        private_key=trust_anchor["private_key"],
        hash_field="seal_payload_sha256",
    )
    bundle["reference_run"]["seal"] = binding
    _save(bundle_path, bundle)
    result = _validate_bundle(spec_path, bundle_path, trust_anchor)
    assert any("REFERENCE_SEAL_NOT_BEFORE_VERIFICATION" in error for error in result["errors"])
