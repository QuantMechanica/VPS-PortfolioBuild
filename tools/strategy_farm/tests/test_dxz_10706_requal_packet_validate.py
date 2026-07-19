from __future__ import annotations

import copy
import datetime as dt
import hashlib
import json
import sys
from pathlib import Path

import pytest


REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))

import dxz_10706_requal_packet_validate as validator  # noqa: E402


SPEC_PATH = (
    REPO_ROOT
    / "docs"
    / "ops"
    / "evidence"
    / "dxz_10706_gbpusd_requalification_spec_20260716.json"
)


class _Bundle(dict):
    external_owner_trust_anchors: dict[str, str]
def _sha_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _h(label: str) -> str:
    return _sha_bytes(label.encode("utf-8"))


def _write_json(path: Path, payload: dict) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return validator.sha256_file(path)


def _load_spec() -> dict:
    return json.loads(SPEC_PATH.read_text(encoding="utf-8"))


def _hermetic_spec(tmp_path: Path) -> dict:
    """Real committed spec with its live/volatile bindings replaced.

    ``source_closure_contract`` and ``anchor_files`` pin the spec to the
    live repo working tree (``framework/EAs/QM5_10706_tv-mon-ls/...``) and
    the live ``T_Live`` terminal (``live_preset``). Both drift out from
    under a committed spec as the factory keeps rebuilding/editing those
    paths, which makes any test asserting an *exact* validator status or
    an empty issue list non-hermetic (it starts failing the moment repo
    source or T_Live state moves on from the day the spec was captured).

    This rebuilds those two sub-contracts against a self-contained source
    tree and anchor files created fresh under ``tmp_path`` and hashed with
    the validator's own hashing/closure functions, so the spec is
    internally consistent by construction and stays that way regardless
    of unrelated repo/T_Live drift. Every other field (segments, risk
    contract candidates, cost axes, owner-trust contract, ...) is kept
    byte-for-byte from the committed spec, since those are pure data and
    do not reference any live filesystem path.
    """
    spec = copy.deepcopy(_load_spec())

    repo_root = (tmp_path / "hermetic_repo").resolve()
    ea_dir = repo_root / "framework" / "EAs" / "QM5_10706_tv-mon-ls"
    include_dir = repo_root / "framework" / "include" / "QM"
    ea_dir.mkdir(parents=True, exist_ok=True)
    include_dir.mkdir(parents=True, exist_ok=True)

    includes = {
        "QM_Exit.mqh": "// hermetic QM_Exit stub\n",
        "QM_KillSwitch.mqh": "// hermetic QM_KillSwitch stub\n",
        "QM_KillSwitchKS.mqh": "// hermetic QM_KillSwitchKS stub\n",
        "QM_NewsFilter.mqh": "// hermetic QM_NewsFilter stub\n",
    }
    for name, content in includes.items():
        (include_dir / name).write_text(content, encoding="utf-8")

    source_path = ea_dir / "QM5_10706_tv-mon-ls.mq5"
    source_path.write_text(
        "".join(f"#include <QM/{name}>\n" for name in includes) + "// hermetic EA source\n",
        encoding="utf-8",
    )

    closure_paths = validator._source_dependency_closure(source_path, repo_root)
    rows = [
        {
            "path": path.relative_to(repo_root).as_posix(),
            "sha256": validator.sha256_file(path),
        }
        for path in closure_paths
    ]
    row_index = {row["path"]: row["sha256"] for row in rows}
    aggregate = validator.canonical_json_sha(rows)
    source_key = "framework/EAs/QM5_10706_tv-mon-ls/QM5_10706_tv-mon-ls.mq5"

    spec["source_closure_contract"] = {
        "repo_root": str(repo_root),
        "source_path": str(source_path.resolve()),
        "resolver": "RECURSIVE_MQL5_INCLUDE_CLOSURE",
        "canonical_path_encoding": "REPO_RELATIVE_POSIX",
        "expected_member_count": len(rows),
        "aggregate_sha256": aggregate,
        "critical_member_sha256s": dict(row_index),
    }

    anchor_root = (tmp_path / "hermetic_anchors").resolve()
    anchor_root.mkdir(parents=True, exist_ok=True)
    approved_card = anchor_root / "QM5_10706_tv-mon-ls.md"
    approved_card.write_text("# hermetic approved card\n", encoding="utf-8")
    ea_spec_doc = anchor_root / "SPEC.md"
    ea_spec_doc.write_text("# hermetic ea spec\n", encoding="utf-8")
    live_ex5 = anchor_root / "QM5_10706_tv-mon-ls.ex5"
    live_ex5.write_bytes(b"hermetic-live-ex5-binary")
    live_preset = (
        anchor_root
        / "slot1_GBPUSD_H1_QM5_10706_tv-mon-ls_magic107060001_dxz23_live.set"
    )
    live_preset.write_text("; hermetic live preset\nRISK_PERCENT=0\n", encoding="utf-8")
    risk_sizer = anchor_root / "QM_RiskSizer.mqh"
    risk_sizer.write_text("// hermetic risk sizer\n", encoding="utf-8")

    anchor_specs = [
        ("approved_card", approved_card, "CONTRACT"),
        ("ea_spec", ea_spec_doc, "CONTRACT"),
        ("ea_source", source_path, "CONTRACT"),
        ("live_ex5", live_ex5, "READ_ONLY_CONTRACT"),
        ("live_preset", live_preset, "READ_ONLY_CONTRACT"),
        ("risk_sizer", risk_sizer, "CONTRACT"),
    ]
    spec["anchor_files"] = [
        {
            "label": label,
            "path": str(path.resolve()),
            "sha256": validator.sha256_file(path),
            "role": role,
        }
        for label, path, role in anchor_specs
    ]

    spec["contract_artifact_sha256s"] = {
        "approved_card": validator.sha256_file(approved_card),
        "ea_spec": validator.sha256_file(ea_spec_doc),
        "ea_source": row_index[source_key],
        "source_dependency_closure": aggregate,
        "live_ex5": validator.sha256_file(live_ex5),
        "live_preset": validator.sha256_file(live_preset),
        "risk_sizer": validator.sha256_file(risk_sizer),
    }
    return spec


def _embedded(payload: dict, field: str) -> dict:
    payload[field] = validator.embedded_hash(payload, field)
    return payload


def _structured(payload: dict, field: str) -> dict:
    payload[field] = validator.embedded_hash(payload, field)
    return payload


def _segment_trade_rows(spec: dict) -> dict[str, list[dict]]:
    timestamps = {
        "S0": [
            "2018.01.09 08:00:00",
            "2019.04.09 08:00:00",
            "2021.06.08 08:00:00",
            "2023.01.10 08:00:00",
        ],
        "S1": [
            "2024.01.09 08:00:00",
            "2024.09.10 08:00:00",
            "2025.01.14 08:00:00",
        ],
        "S2": ["2025.11.04 08:00:00", "2025.12.02 08:00:00"],
        "S3": ["2025.12.23 08:00:00"],
    }
    rows: dict[str, list[dict]] = {}
    deal = 1
    for segment in spec["segments"]:
        segment_rows = []
        for offset, entry_time in enumerate(timestamps[segment["segment_id"]]):
            entry = dt.datetime.strptime(entry_time, "%Y.%m.%d %H:%M:%S")
            exit_time = (entry + dt.timedelta(hours=1)).strftime("%Y.%m.%d %H:%M:%S")
            side = "buy" if deal % 4 == 1 else "sell"
            profit = "10.00" if offset % 2 == 0 else "-5.00"
            segment_rows.append(
                {
                    "entry_time": entry_time,
                    "exit_time": exit_time,
                    "entry_deal": str(deal),
                    "exit_deal": str(deal + 1),
                    "side": side,
                    "volume": "0.10",
                    "entry_price": "1.25000",
                    "exit_price": "1.25100" if side == "buy" else "1.24900",
                    "profit": profit,
                }
            )
            deal += 2
        rows[segment["segment_id"]] = segment_rows
    return rows


def _native_report_bytes(trades: list[dict]) -> bytes:
    profits = [float(row["profit"]) for row in trades]
    net = sum(profits)
    gross_profit = sum(value for value in profits if value > 0)
    gross_loss = sum(value for value in profits if value < 0)
    pf = gross_profit / abs(gross_loss) if gross_loss else 999.0
    rows = [
        ("Expert", "QM5_10706_tv-mon-ls"),
        ("Symbol", "GBPUSD.DWX"),
        ("Period", "H1 (2017.10.09 - 2025.12.31)"),
        ("Currency", "EUR"),
        ("History Quality", "100% real ticks"),
        ("Bars", "50 000"),
        ("Ticks", "5 000 000"),
        ("Symbols", "2"),
        ("Total Net Profit", f"{net:.2f}"),
        ("Gross Profit", f"{gross_profit:.2f}"),
        ("Gross Loss", f"{gross_loss:.2f}"),
        ("Profit Factor", f"{pf:.2f}"),
        ("Total Trades", str(len(trades))),
        ("Equity Drawdown Maximal", "50.00 (0.05%)"),
    ]
    parts = ["<html><body><table>"]
    parts.extend(f"<tr><td>{key}</td><td>{value}</td></tr>" for key, value in rows)
    parts.append("<tr><td><b>Deals</b></td></tr>")
    headers = [
        "Time", "Deal", "Symbol", "Type", "Direction", "Volume", "Price",
        "Order", "Commission", "Swap", "Profit",
    ]
    parts.append("<tr>" + "".join(f"<td>{value}</td>" for value in headers) + "</tr>")
    for trade in trades:
        entry = [
            trade["entry_time"], trade["entry_deal"], "GBPUSD.DWX", trade["side"],
            "in", trade["volume"], trade["entry_price"], trade["entry_deal"],
            "0.00", "0.00", "0.00",
        ]
        exit_type = "sell" if trade["side"] == "buy" else "buy"
        exit_row = [
            trade["exit_time"], trade["exit_deal"], "GBPUSD.DWX", exit_type,
            "out", trade["volume"], trade["exit_price"], trade["exit_deal"],
            "0.00", "0.00", trade["profit"],
        ]
        parts.append("<tr>" + "".join(f"<td>{value}</td>" for value in entry) + "</tr>")
        parts.append("<tr>" + "".join(f"<td>{value}</td>" for value in exit_row) + "</tr>")
    parts.append("</table></body></html>")
    return "\n".join(parts).encode("utf-8")


def _write_native_report(path: Path, trades: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(_native_report_bytes(trades))


def _owner_receipt(
    path: Path,
    *,
    gate_id: str,
    spec_sha: str,
    approved_at: str,
    **extra,
) -> dict:
    payload = _structured(
        {
            "schema_version": 1,
            "artifact_type": validator.OWNER_RECEIPT_ARTIFACT_TYPE,
            "gate_id": gate_id,
            "spec_sha256": spec_sha,
            "status": "APPROVED",
            "approved_by": "OWNER",
            "approved_at_utc": approved_at,
            **extra,
        },
        "receipt_payload_sha256",
    )
    return {"path": str(path.resolve()), "sha256": _write_json(path, payload)}


def _cost_axes() -> dict:
    return {axis: {"status": "OPEN"} for axis in _load_spec()["required_cost_axes"]}


def _input_manifests(tmp_path: Path, spec: dict) -> tuple[dict, dict, str, str]:
    root = tmp_path / "control" / "inputs"
    data_rows = []
    snapshot_rows = []
    for symbol in spec["frozen_data_contract"]["required_symbols"]:
        for year in spec["frozen_data_contract"]["required_years"]:
            for kind in ("HCC", "TKC"):
                path = root / "history" / symbol / f"{year}.{kind.lower()}"
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(f"{symbol}|{year}|{kind}\n".encode())
                row = {
                    "symbol": symbol,
                    "year": year,
                    "kind": kind,
                    "path": str(path.resolve()),
                    "sha256": validator.sha256_file(path),
                    "bytes": path.stat().st_size,
                }
                data_rows.append(row)
                snapshot_rows.append({key: row[key] for key in ("symbol", "year", "kind", "sha256", "bytes")})
    snapshot_rows.sort(key=lambda row: (row["symbol"], row["year"], row["kind"]))
    data_snapshot_sha = validator.canonical_json_sha(snapshot_rows)
    data_payload = _structured(
        {
            "schema_version": 1,
            "artifact_type": validator.DATA_MANIFEST_ARTIFACT_TYPE,
            "required_symbols": spec["frozen_data_contract"]["required_symbols"],
            "required_years": spec["frozen_data_contract"]["required_years"],
            "files": data_rows,
            "data_snapshot_sha256": data_snapshot_sha,
        },
        "manifest_payload_sha256",
    )
    data_path = root / "data_manifest.json"
    data_binding = {"path": str(data_path.resolve()), "sha256": _write_json(data_path, data_payload)}

    properties = {
        "account_currency": "EUR",
        "contract_size": 100000.0,
        "digits": 5,
        "leverage": 100,
        "profit_currency": "USD",
        "tick_size": 0.00001,
        "tick_value": 1.0,
        "volume_max": 100.0,
        "volume_min": 0.01,
        "volume_step": 0.01,
    }
    snapshot = {
        "source": "DARWINEXZERO_MT5_SERVER",
        "captured_at_utc": "2026-07-16T07:30:00Z",
        "account_currency": "EUR",
        "leverage": 100,
        "symbols": {
            symbol: dict(properties)
            for symbol in spec["frozen_data_contract"]["required_symbols"]
        },
    }
    raw_path = root / "instrument_terminal_export.json"
    raw_binding = {"path": str(raw_path.resolve()), "sha256": _write_json(raw_path, snapshot)}
    instrument_snapshot_sha = validator.canonical_json_sha(
        {**snapshot, "raw_terminal_export_sha256": raw_binding["sha256"]}
    )
    instrument_payload = _structured(
        {
            "schema_version": 1,
            "artifact_type": validator.INSTRUMENT_MANIFEST_ARTIFACT_TYPE,
            "raw_terminal_export": raw_binding,
            "snapshot": snapshot,
            "instrument_snapshot_sha256": instrument_snapshot_sha,
        },
        "manifest_payload_sha256",
    )
    instrument_path = root / "instrument_manifest.json"
    instrument_binding = {
        "path": str(instrument_path.resolve()),
        "sha256": _write_json(instrument_path, instrument_payload),
    }
    return data_binding, instrument_binding, data_snapshot_sha, instrument_snapshot_sha


def _session_calendar_manifest(tmp_path: Path, spec: dict) -> tuple[dict, str]:
    root = tmp_path / "control" / "inputs"
    window = spec["cost_evaluation_window"]
    start = dt.date.fromisoformat(window["effective_from_date"])
    end = dt.date.fromisoformat(window["effective_to_date"])
    boundaries = [
        {
            "week_ending_friday": friday.isoformat(),
            "last_tradable_broker_time": f"{friday.isoformat().replace('-', '.')} 21:00:00",
            "effective_cutoff_rule": "MIN_FRIDAY_21_AND_LAST_TRADABLE_BEFORE_WEEKEND",
        }
        for friday in validator._fridays_between(start, end)
    ]
    raw = {
        "source": "DARWINEXZERO_MT5_SERVER_BOUND_SESSION_EXPORT",
        "timezone_basis": "MT5_BROKER_TIME",
        "effective_from_date": start.isoformat(),
        "effective_to_date": end.isoformat(),
        "weekend_boundaries": boundaries,
    }
    raw_path = root / "session_calendar_terminal_export.json"
    raw_binding = {"path": str(raw_path.resolve()), "sha256": _write_json(raw_path, raw)}
    calendar_sha = validator.canonical_json_sha(
        {
            "raw_server_session_export_sha256": raw_binding["sha256"],
            "weekend_boundaries": boundaries,
        }
    )
    payload = _structured(
        {
            "schema_version": 1,
            "artifact_type": validator.SESSION_CALENDAR_ARTIFACT_TYPE,
            **raw,
            "raw_server_session_export": raw_binding,
            "session_calendar_sha256": calendar_sha,
        },
        "manifest_payload_sha256",
    )
    path = root / "session_calendar_manifest.json"
    binding = {"path": str(path.resolve()), "sha256": _write_json(path, payload)}
    return binding, calendar_sha


def _contract_template(
    spec: dict,
    selected_candidate: dict,
    *,
    data_binding: dict,
    instrument_binding: dict,
    session_calendar_binding: dict,
    data_snapshot_sha: str,
    instrument_snapshot_sha: str,
    session_calendar_sha: str,
) -> dict:
    return {
        "ea_id": 10706,
        "symbol": "GBPUSD.DWX",
        "timeframe": "H1",
        "magic": 107060001,
        "model": 4,
        "deposit_currency": "EUR",
        "initial_deposit": "100000",
        "leverage": 100,
        "risk_contract_id": selected_candidate["contract_id"],
        "RISK_PERCENT": selected_candidate["RISK_PERCENT"],
        "RISK_FIXED": selected_candidate["RISK_FIXED"],
        "PORTFOLIO_WEIGHT": selected_candidate["PORTFOLIO_WEIGHT"],
        "effective_risk_percent": selected_candidate["effective_risk_percent"],
        "artifact_sha256s": spec["contract_artifact_sha256s"],
        "data_symbols": spec["frozen_data_contract"]["required_symbols"],
        "segment_contract_sha256": validator.canonical_json_sha(
            {"segments": spec["segments"], "rules": spec["segment_execution_rules"]}
        ),
        "data_manifest_sha256": data_binding["sha256"],
        "data_snapshot_sha256": data_snapshot_sha,
        "instrument_manifest_sha256": instrument_binding["sha256"],
        "instrument_snapshot_sha256": instrument_snapshot_sha,
        "session_calendar_manifest_sha256": session_calendar_binding["sha256"],
        "session_calendar_sha256": session_calendar_sha,
    }


def _write_bound_json_sidecar(path: Path, payload: dict, hash_field: str) -> None:
    payload[hash_field] = validator.canonical_json_sha(
        {key: value for key, value in payload.items() if key != hash_field}
    )
    _write_json(path, payload)
    path.with_name(path.name + ".sha256").write_text(
        f"{validator.sha256_file(path)}  {path.name}\n", encoding="ascii"
    )


def _strict_cost_axis_payload(axis: str, source_sha: str, spec: dict) -> dict:
    sleeve = {"ea_id": 10706, "symbol": "GBPUSD.DWX", "timeframe": "H1"}
    key = "10706:GBPUSD.DWX"
    common = {
        "schema_version": 1,
        "artifact_type": validator.requal_runner.EXECUTION_COST_AXIS_ARTIFACT_TYPE,
        "axis": axis,
        "evidence_type": next(
            iter(validator.requal_runner.EXECUTION_COST_EVIDENCE_TYPES[axis])
        ),
        "status": "PASS",
        "source_manifest_sha256": source_sha,
        "covered_sleeves": [sleeve],
        "evaluation_window": spec["cost_evaluation_window"],
        "valid_from_utc": "2026-07-15T00:00:00+00:00",
        "valid_until_utc": "2026-07-20T00:00:00+00:00",
        "assertion": f"structured conservative {axis} evidence",
        "methodology": f"measured and replayed {axis}",
    }
    if axis == "commission":
        common.update(
            {
                "parameters": {
                    "conservative": True,
                    "charge_basis": "ROUND_TRIP_NOTIONAL_BPS",
                    "rate": 0.5,
                    "currency": "EUR",
                },
                "scenarios": [
                    {
                        "covered_key": key,
                        "name": "official-0.005-percent-round-trip",
                        "applied_rate": 0.5,
                        "status": "PASS",
                    }
                ],
                "results": {
                    "all_trades_costed": True,
                    "unknown_symbols": [],
                    "degraded_symbols": [],
                },
            }
        )
    elif axis == "historical_tester_spread":
        common.update(
            {
                "parameters": {
                    "conservative": True,
                    "tester_model": "EVERY_TICK_BASED_ON_REAL_TICKS",
                    "history_quality": "100% real ticks",
                    "spread_embedded": True,
                },
                "scenarios": [
                    {
                        "covered_key": key,
                        "spread_multiplier": 1.0,
                        "observed_spread_points": 1.0,
                        "applied_spread_points": 1.0,
                        "status": "PASS",
                    }
                ],
                "results": {"all_reports_bound": True, "missing_reports": []},
            }
        )
    elif axis == "current_broker_spread_parity":
        common.update(
            {
                "parameters": {
                    "minimum_samples_per_symbol": 100,
                    "quantile": 0.95,
                    "minimum_applied_to_observed_multiplier": 1.0,
                },
                "scenarios": [
                    {
                        "covered_key": key,
                        "symbol": "GBPUSD.DWX",
                        "samples": 100,
                        "observed_quantile_points": 1.0,
                        "applied_spread_points": 1.0,
                        "status": "PASS",
                    }
                ],
                "results": {"all_symbols_pass": True},
            }
        )
    elif axis == "current_broker_swap_rate_parity":
        common.update(
            {
                "parameters": {
                    "minimum_observation_days": 5,
                    "maximum_rate_age_days": 7,
                    "include_long_and_short": True,
                    "include_triple_swap": True,
                    "minimum_adverse_multiplier": 1.0,
                },
                "scenarios": [
                    {
                        "covered_key": key,
                        "symbol": "GBPUSD.DWX",
                        "side": side,
                        "observation_days": 5,
                        "rollover_multiplier": rollover,
                        "observed_cost_account_ccy": 1.0,
                        "applied_cost_account_ccy": 1.0,
                        "status": "PASS",
                    }
                    for side, rollover in (("LONG", 1.0), ("SHORT", 3.0))
                ],
                "results": {"all_symbols_sides_pass": True},
            }
        )
    else:
        common.update(
            {
                "parameters": {
                    "minimum_samples_per_symbol": 30,
                    "quantile": 0.95,
                    "minimum_adverse_multiplier": 1.0,
                    "include_gap_stress": True,
                },
                "scenarios": [
                    {
                        "covered_key": key,
                        "symbol": "GBPUSD.DWX",
                        "scenario": scenario,
                        "samples": 30,
                        "observed_adverse_points": 1.0,
                        "applied_adverse_points": 1.0,
                        "status": "PASS",
                    }
                    for scenario in ("ADVERSE_QUANTILE", "GAP_STRESS")
                ],
                "results": {"all_symbols_scenarios_pass": True},
            }
        )
    return common


def _strict_cost_manifest(tmp_path: Path, *, source_sha: str, spec: dict) -> dict:
    tmp_path.mkdir(parents=True, exist_ok=True)
    axes = {}
    for axis in spec["required_cost_axes"]:
        artifact = tmp_path / f"{axis}.json"
        payload = _strict_cost_axis_payload(axis, source_sha, spec)
        _write_bound_json_sidecar(artifact, payload, "artifact_payload_sha256")
        axes[axis] = {
            "status": "PASS",
            "evidence": {
                "path": artifact.name,
                "sha256": validator.sha256_file(artifact),
                "evidence_type": payload["evidence_type"],
            },
        }
    manifest = tmp_path / "cost_manifest.json"
    payload = {
        "schema_version": 1,
        "artifact_type": validator.requal_runner.EXECUTION_COST_MANIFEST_TYPE,
        "status": "PASS",
        "source_manifest_sha256": source_sha,
        "valid_from_utc": "2026-07-01T00:00:00+00:00",
        "valid_until_utc": "2026-07-31T00:00:00+00:00",
        "scope": "GLOBAL",
        "covered_keys": ["10706:GBPUSD.DWX"],
        "covered_sleeves": [
            {"ea_id": 10706, "symbol": "GBPUSD.DWX", "timeframe": "H1"}
        ],
        "evaluation_window": spec["cost_evaluation_window"],
        "axes": axes,
    }
    _write_bound_json_sidecar(manifest, payload, "manifest_payload_sha256")
    metadata, _contracts = validator.requal_runner.load_execution_cost_evidence_manifest(
        manifest,
        source_manifest_sha256=source_sha,
        as_of_utc=dt.datetime(2026, 7, 16, 11, 30, tzinfo=dt.timezone.utc),
        required_sleeves=[
            {"ea_id": 10706, "symbol": "GBPUSD.DWX", "timeframe": "H1"}
        ],
        window_contract=spec["cost_evaluation_window"],
    )
    axis_hashes = validator.requal_runner.execution_cost_axis_hash_snapshot(metadata)
    return {
        "path": str(manifest.resolve()),
        "sha256": metadata["sha256"],
        "semantic_contract_sha256": metadata["semantic_contract_sha256"],
        "axis_hashes_sha256": validator.canonical_json_sha(axis_hashes),
    }


def _make_receipt(
    spec: dict,
    tmp_path: Path,
    *,
    run_id: str,
    phase: str,
    started: str,
    finished: str,
    selected_candidate: dict,
    reference_path: Path | None,
    reference_sha: str | None,
    seal_manifest_sha: str | None,
    sealed_input_sha: str,
    contract_template: dict,
    cost_axes: dict,
    trades_by_segment: dict[str, list[dict]],
) -> tuple[dict, dict, Path]:
    root = tmp_path / "runs" / run_id
    root.mkdir(parents=True)
    stream_path = root / "aggregate.jsonl"
    report_path = root / "report.htm"
    all_trades = [
        trade
        for expected in spec["segments"]
        for trade in trades_by_segment[expected["segment_id"]]
    ]
    _write_native_report(report_path, all_trades)
    native_rows, report_metrics = validator._native_report_rows(report_path, "GBPUSD.DWX")
    stream_path.write_bytes(validator._canonical_jsonl(native_rows))
    aggregate = validator._identity_digests(native_rows)
    aggregate["stream_path"] = str(stream_path.resolve())

    segments = []
    for expected in spec["segments"]:
        segment_id = expected["segment_id"]
        segment_root = root / "segments" / segment_id
        segment_root.mkdir(parents=True)
        segment_stream = segment_root / "stream.jsonl"
        segment_report = segment_root / "report.htm"
        _write_native_report(segment_report, trades_by_segment[segment_id])
        parsed_segment_rows, _ = validator._native_report_rows(
            segment_report, "GBPUSD.DWX"
        )
        segment_stream.write_bytes(validator._canonical_jsonl(parsed_segment_rows))
        segment_digest = validator._identity_digests(parsed_segment_rows)
        segment = {
            key: expected[key]
            for key in (
                "segment_id",
                "tester_from_date",
                "tester_to_date",
                "score_from_utc",
                "score_to_exclusive_utc",
            )
        }
        segment.update(
            {
                "segment_root": str(segment_root.resolve()),
                "start_flat": True,
                "end_flat": True,
                "cross_gap_position_count": 0,
                "cross_gap_pending_order_count": 0,
                "tester_forced_exit_count": 0,
                "state_carried_from_previous_segment": False,
                "report_path": str(segment_report.resolve()),
                "report_sha256": validator.sha256_file(segment_report),
                "stream_path": str(segment_stream.resolve()),
            }
        )
        segment.update(segment_digest)
        segments.append(segment)

    contract = {**contract_template, "sealed_input_manifest_sha256": sealed_input_sha}
    sweep = dict(spec["contract_artifact_sha256s"])
    sweep.update(
        {
            "data_manifest": contract["data_manifest_sha256"],
            "data_snapshot": contract["data_snapshot_sha256"],
            "instrument_manifest": contract["instrument_manifest_sha256"],
            "instrument_snapshot": contract["instrument_snapshot_sha256"],
            "session_calendar_manifest": contract["session_calendar_manifest_sha256"],
            "session_calendar": contract["session_calendar_sha256"],
            "segment_contract": contract["segment_contract_sha256"],
        }
    )
    selected_reference = None
    if phase == "QUALIFICATION":
        assert reference_path is not None and reference_sha is not None
        selected_reference = {
            "path": str(reference_path.resolve()),
            "sha256": reference_sha,
            "provenance": validator.SEAL_PROVENANCE,
            "independent_reference": False,
            "seal_manifest_sha256": seal_manifest_sha,
            "sealed_input_manifest_sha256": sealed_input_sha,
            "identity_matches": {axis: True for axis in spec["identity_axes"]},
            "reference_trade_count": len(native_rows),
            "current_trade_count": len(native_rows),
        }
    contract_sha = validator.canonical_json_sha(contract)
    run_identity = {
        "execution_id": f"exec-{run_id}",
        "sandbox_id": f"DXZ_Truth_10706_{run_id}",
        "output_root": str(root.resolve()),
        "contract_sha256": contract_sha,
    }
    receipt = {
        "schema_version": 2,
        "artifact_type": validator.RECEIPT_ARTIFACT_TYPE,
        "run_id": run_id,
        "execution_id": run_identity["execution_id"],
        "sandbox_id": run_identity["sandbox_id"],
        "output_root": run_identity["output_root"],
        "run_identity_sha256": validator.canonical_json_sha(run_identity),
        "phase": phase,
        "run_root": str(root.resolve()),
        "started_utc": started,
        "finished_utc": finished,
        "qualification_mode": (
            validator.BASELINE_MODE if phase == "BASELINE" else validator.QUALIFICATION_MODE
        ),
        "qualifying": phase == "QUALIFICATION",
        "technical_status": validator.BASELINE_MODE if phase == "BASELINE" else "PASS",
        "selected_reference": selected_reference,
        "contract": contract,
        "contract_sha256": contract_sha,
        "immutable_input_sweep": {
            "hashes_start": sweep,
            "hashes_end": sweep,
            "unchanged": True,
        },
        "aggregate": aggregate,
        "segments": segments,
        "report_path": str(report_path.resolve()),
        "report_sha256": validator.sha256_file(report_path),
        "report_metrics": report_metrics,
        "cost_axes": copy.deepcopy(cost_axes),
    }
    receipt_path = root / "receipt.json"
    binding = {"path": str(receipt_path.resolve()), "sha256": _write_json(receipt_path, receipt)}
    return binding, receipt, receipt_path


def _make_bundle(
    tmp_path: Path,
    *,
    certified_costs: bool = False,
    selected_contract_id: str = "LIVE_AS_FOUND_RP0_0564_PW1",
    spec: dict | None = None,
) -> tuple[dict, dict]:
    if spec is None:
        spec = _load_spec()
    # Owner-receipt payloads bind to the on-disk spec file's hash (see
    # `_validate`/`validate_evidence`, which always pass `spec_path=SPEC_PATH`
    # and derive `bound_spec_sha` from that literal file), independent of
    # whichever `spec` dict content is under test.
    spec_sha = validator.sha256_file(SPEC_PATH)
    candidate = next(
        row for row in spec["risk_contract_candidates"] if row["contract_id"] == selected_contract_id
    )
    decision = _embedded(
        {
            "status": "APPROVED",
            "selected_contract_id": selected_contract_id,
            "approved_by": "OWNER",
            "approved_at_utc": "2026-07-16T08:00:00Z",
            "authorization_scope": "RISK_CONTRACT_ONLY_NO_MUTATION_NO_DEPLOY",
        },
        "decision_sha256",
    )
    costs = _cost_axes()
    trades_by_segment = _segment_trade_rows(spec)
    data_binding, instrument_binding, data_snapshot_sha, instrument_snapshot_sha = (
        _input_manifests(tmp_path, spec)
    )
    session_calendar_binding, session_calendar_sha = _session_calendar_manifest(
        tmp_path, spec
    )
    template = _contract_template(
        spec,
        candidate,
        data_binding=data_binding,
        instrument_binding=instrument_binding,
        session_calendar_binding=session_calendar_binding,
        data_snapshot_sha=data_snapshot_sha,
        instrument_snapshot_sha=instrument_snapshot_sha,
        session_calendar_sha=session_calendar_sha,
    )
    control_root = tmp_path / "control"
    receipt_root = control_root / "owner_receipts"
    risk_receipt_binding = _owner_receipt(
        receipt_root / "risk.json",
        gate_id="RISK_CONTRACT",
        spec_sha=spec_sha,
        approved_at="2026-07-16T08:00:00Z",
        decision={
            "selected_contract_id": selected_contract_id,
            "authorization_scope": "RISK_CONTRACT_ONLY_NO_MUTATION_NO_DEPLOY",
        },
    )
    selected_risk = {
        "contract_id": candidate["contract_id"],
        "RISK_PERCENT": candidate["RISK_PERCENT"],
        "RISK_FIXED": candidate["RISK_FIXED"],
        "PORTFOLIO_WEIGHT": candidate["PORTFOLIO_WEIGHT"],
        "effective_risk_percent": candidate["effective_risk_percent"],
    }
    pre_input_bindings = {
        "data_manifest": validator._binding_descriptor(data_binding),
        "instrument_manifest": validator._binding_descriptor(instrument_binding),
        "session_calendar_manifest": validator._binding_descriptor(
            session_calendar_binding
        ),
        "owner_risk_receipt": validator._binding_descriptor(risk_receipt_binding),
    }
    input_approved_object = validator.canonical_json_sha(
        {
            "contract_template": template,
            "bindings": pre_input_bindings,
            "selected_risk_contract": selected_risk,
        }
    )
    input_receipt_binding = _owner_receipt(
        receipt_root / "sealed_input.json",
        gate_id="SEALED_INPUT",
        spec_sha=spec_sha,
        approved_at="2026-07-16T08:25:00Z",
        approved_object_sha256=input_approved_object,
    )
    sealed_input = _structured({
        "schema_version": 1,
        "artifact_type": validator.SEALED_INPUT_ARTIFACT_TYPE,
        "sealed_at_utc": "2026-07-16T08:30:00Z",
        "owner_decision_sha256": decision["decision_sha256"],
        "selected_risk_contract": selected_risk,
        "contract_template": template,
        "contract_template_sha256": validator.canonical_json_sha(template),
        "bindings": {
            **pre_input_bindings,
            "owner_input_receipt": validator._binding_descriptor(input_receipt_binding),
        },
    }, "manifest_payload_sha256")
    sealed_input_path = control_root / "sealed_inputs" / "sealed_input_manifest.json"
    sealed_input_binding = {
        "path": str(sealed_input_path.resolve()),
        "sha256": _write_json(sealed_input_path, sealed_input),
    }
    baseline_bindings = []
    baseline_payloads = []
    for run_id, start, finish in (
        ("baseline_a", "2026-07-16T09:00:00Z", "2026-07-16T09:10:00Z"),
        ("baseline_b", "2026-07-16T09:20:00Z", "2026-07-16T09:30:00Z"),
    ):
        binding, payload, _path = _make_receipt(
            spec,
            tmp_path,
            run_id=run_id,
            phase="BASELINE",
            started=start,
            finished=finish,
            selected_candidate=candidate,
            reference_path=None,
            reference_sha=None,
            seal_manifest_sha=None,
            sealed_input_sha=sealed_input_binding["sha256"],
            contract_template=template,
            cost_axes=costs,
            trades_by_segment=trades_by_segment,
        )
        baseline_bindings.append(binding)
        baseline_payloads.append(payload)

    seal_root = control_root / "owner_seal"
    seal_root.mkdir()
    reference_path = seal_root / "consensus.jsonl"
    baseline_report = Path(baseline_payloads[0]["report_path"])
    baseline_rows, _ = validator._native_report_rows(baseline_report, "GBPUSD.DWX")
    reference_path.write_bytes(validator._canonical_jsonl(baseline_rows))
    reference_sha = validator.sha256_file(reference_path)
    baseline_shas = sorted(binding["sha256"] for binding in baseline_bindings)
    baseline_runs = sorted(
        [
            {
                "run_id": payload["run_id"],
                "receipt_sha256": binding["sha256"],
                "contract_sha256": payload["contract_sha256"],
                "run_identity_sha256": payload["run_identity_sha256"],
                "execution_id": payload["execution_id"],
                "sandbox_id": payload["sandbox_id"],
                "output_root": payload["output_root"],
            }
            for payload, binding in zip(baseline_payloads, baseline_bindings, strict=True)
        ],
        key=lambda row: row["receipt_sha256"],
    )
    consensus_axes = {
        axis: baseline_payloads[0]["aggregate"][axis] for axis in spec["identity_axes"]
    }
    reference_approved_object = validator.canonical_json_sha(
        {
            "reference_sha256": reference_sha,
            "source_baseline_receipt_sha256s": baseline_shas,
            "source_baseline_runs": baseline_runs,
            "consensus_contract_sha256": baseline_payloads[0]["contract_sha256"],
            "consensus_identity_sha256s": consensus_axes,
            "owner_decision_sha256": decision["decision_sha256"],
        }
    )
    reference_receipt_binding = _owner_receipt(
        receipt_root / "reference_seal.json",
        gate_id="REFERENCE_SEAL",
        spec_sha=spec_sha,
        approved_at="2026-07-16T10:00:00Z",
        approved_object_sha256=reference_approved_object,
    )
    seal = _structured({
        "schema_version": 1,
        "artifact_type": validator.SEAL_ARTIFACT_TYPE,
        "provenance": validator.SEAL_PROVENANCE,
        "independent_reference": False,
        "sealed_at_utc": "2026-07-16T10:00:00Z",
        "reference_path": str(reference_path.resolve()),
        "reference_sha256": reference_sha,
        "source_baseline_receipt_sha256s": baseline_shas,
        "source_baseline_runs": baseline_runs,
        "consensus_contract_sha256": baseline_payloads[0]["contract_sha256"],
        "consensus_identity_sha256s": consensus_axes,
        "owner_decision_sha256": decision["decision_sha256"],
        "owner_receipt": validator._binding_descriptor(reference_receipt_binding),
    }, "seal_payload_sha256")
    seal_path = seal_root / "seal.json"
    seal_binding = {"path": str(seal_path.resolve()), "sha256": _write_json(seal_path, seal)}

    qualification_bindings = []
    for run_id, start, finish in (
        ("qualification_c", "2026-07-16T11:00:00Z", "2026-07-16T11:10:00Z"),
        ("qualification_d", "2026-07-16T11:20:00Z", "2026-07-16T11:30:00Z"),
    ):
        binding, _payload, _path = _make_receipt(
            spec,
            tmp_path,
            run_id=run_id,
            phase="QUALIFICATION",
            started=start,
            finished=finish,
            selected_candidate=candidate,
            reference_path=reference_path,
            reference_sha=reference_sha,
            seal_manifest_sha=seal_binding["sha256"],
            sealed_input_sha=sealed_input_binding["sha256"],
            contract_template=template,
            cost_axes=costs,
            trades_by_segment=trades_by_segment,
        )
        qualification_bindings.append(binding)

    bundle = _Bundle({
        "schema_version": 1,
        "artifact_type": validator.BUNDLE_ARTIFACT_TYPE,
        "spec_path": str(SPEC_PATH.resolve()),
        "spec_sha256": validator.sha256_file(SPEC_PATH),
        "owner_decision": decision,
        "owner_receipts": {
            "RISK_CONTRACT": risk_receipt_binding,
            "SEALED_INPUT": input_receipt_binding,
            "REFERENCE_SEAL": reference_receipt_binding,
        },
        "data_manifest": data_binding,
        "instrument_manifest": instrument_binding,
        "session_calendar_manifest": session_calendar_binding,
        "sealed_input_manifest": sealed_input_binding,
        "baseline_receipts": baseline_bindings,
        "frozen_reference": {
            "path": str(reference_path.resolve()),
            "sha256": reference_sha,
            "provenance": validator.SEAL_PROVENANCE,
            "independent_reference": False,
            "seal_manifest": seal_binding,
        },
        "qualification_receipts": qualification_bindings,
    })
    bundle.external_owner_trust_anchors = {
        gate: binding["sha256"] for gate, binding in bundle["owner_receipts"].items()
    }
    if certified_costs:
        bundle["execution_cost_evidence_manifest"] = _strict_cost_manifest(
            tmp_path / "cost",
            source_sha=baseline_payloads[0]["contract_sha256"],
            spec=spec,
        )
    return spec, bundle


def _validate(spec: dict, bundle: dict) -> dict:
    return validator.validate_evidence(
        spec,
        bundle,
        spec_path=SPEC_PATH,
        expected_owner_receipt_sha256s=getattr(
            bundle, "external_owner_trust_anchors", None
        ),
    )


def _rewrite_receipt(binding: dict, mutator) -> None:
    path = Path(binding["path"])
    payload = json.loads(path.read_text(encoding="utf-8"))
    mutator(payload)
    binding["sha256"] = _write_json(path, payload)


def _replace_receipt_native_trades(
    binding: dict, spec: dict, trades_by_segment: dict[str, list[dict]]
) -> None:
    path = Path(binding["path"])
    payload = json.loads(path.read_text(encoding="utf-8"))
    all_trades = [
        trade
        for expected in spec["segments"]
        for trade in trades_by_segment[expected["segment_id"]]
    ]
    report = Path(payload["report_path"])
    _write_native_report(report, all_trades)
    rows, metrics = validator._native_report_rows(report, "GBPUSD.DWX")
    aggregate_stream = Path(payload["aggregate"]["stream_path"])
    aggregate_stream.write_bytes(validator._canonical_jsonl(rows))
    payload["aggregate"].update(validator._identity_digests(rows))
    payload["report_sha256"] = validator.sha256_file(report)
    payload["report_metrics"] = metrics
    for segment in payload["segments"]:
        segment_id = segment["segment_id"]
        segment_report = Path(segment["report_path"])
        _write_native_report(segment_report, trades_by_segment[segment_id])
        segment_rows, _ = validator._native_report_rows(
            segment_report, "GBPUSD.DWX"
        )
        Path(segment["stream_path"]).write_bytes(
            validator._canonical_jsonl(segment_rows)
        )
        segment.update(validator._identity_digests(segment_rows))
        segment["report_sha256"] = validator.sha256_file(segment_report)
    binding["sha256"] = _write_json(path, payload)


def test_bound_spec_is_valid_and_waits_for_owner(tmp_path: Path) -> None:
    # Uses a hermetic spec (see _hermetic_spec): the committed spec's
    # anchor_files/source_closure_contract pin live repo (.ex5) and T_Live
    # (live_preset) paths that drift/disappear as the factory keeps
    # rebuilding, which makes an exact "issues == []" assertion against
    # verify_anchors=True non-deterministic over time.
    result = validator.validate_spec(_hermetic_spec(tmp_path), verify_anchors=True)
    assert result["status"] == "BLOCKED_OWNER_TRUST_AND_RUNTIME_REMEDIATION"
    assert result["issues"] == []


def test_spec_forbids_self_binding_fields() -> None:
    spec = _load_spec()
    spec["spec_sha256"] = "0" * 64
    assert "SPEC_SELF_REFERENCE_FIELD_FORBIDDEN" in validator.validate_spec(spec)["issues"]


def test_edited_spec_cannot_bootstrap_owner_trust_with_self_pinned_hashes() -> None:
    spec = _load_spec()
    spec["owner_trust_contract"]["pinned_receipt_sha256s"] = {
        gate: _h(f"self-pin:{gate}") for gate in validator.OWNER_GATES
    }
    assert "SPEC_OWNER_TRUST_CONTRACT_INVALID" in validator.validate_spec(spec)["issues"]


def test_source_closure_is_recomputed_and_binds_critical_risk_members() -> None:
    spec = _load_spec()
    spec["source_closure_contract"]["critical_member_sha256s"][
        "framework/include/QM/QM_Exit.mqh"
    ] = _h("forged-exit-member")
    result = validator.validate_spec(spec)
    assert "SPEC_SOURCE_CLOSURE_CRITICAL_MEMBER_INVALID" in result["issues"]


def test_weight_factor_is_exact_and_double_weight_is_not_selectable() -> None:
    spec = _load_spec()
    factor = spec["risk_scale_comparison"]["PORTFOLIO_WEIGHT_1_vs_0_005783_factor"]
    assert factor.startswith("172.920629431091")
    double = next(row for row in spec["risk_contract_candidates"] if row["PORTFOLIO_WEIGHT"] != "1")
    assert double["owner_selectable"] is False
    assert double["qualification_class"] == "REJECTED_DIMENSIONAL_DOUBLE_SCALING"


def test_complete_identity_packet_can_pass_technically_with_cost_block(tmp_path: Path) -> None:
    # Hermetic spec (see _hermetic_spec): avoids live repo/T_Live drift so
    # the exact TECHNICAL_PASS status keeps asserting deterministically.
    spec, bundle = _make_bundle(tmp_path, spec=_hermetic_spec(tmp_path))
    result = _validate(spec, bundle)
    assert result["status"] == "TECHNICAL_PASS_COST_AND_RUNTIME_POLICY_BLOCKED"
    assert result["technical_identity_pass"] is True
    assert result["promotion_ready"] is False


def test_all_certified_cost_axes_are_required_for_pass(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(
        tmp_path, certified_costs=True, spec=_hermetic_spec(tmp_path)
    )
    result = _validate(spec, bundle)
    assert result["status"] == "TECHNICAL_PASS_RUNTIME_POLICY_BLOCKED"
    assert result["costs_certified"] is True
    assert result["promotion_ready"] is False
    assert result["runtime_policy_issues"] == [
        "BOUND_SOURCE_LACKS_HOLIDAY_EARLY_CLOSE_SESSION_CALENDAR_FALLBACK",
        "BOUND_SOURCE_NEWS_RETURNS_PRECEDE_FRIDAY_WEEKEND_RISK_CLOSE",
    ]
    assert result["registry_change_authorized"] is False
    assert result["deployment_authorized"] is False


def test_double_weight_owner_selection_is_rejected(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(
        tmp_path, selected_contract_id="DOUBLE_WEIGHT_RP0_056389_PW0_005783"
    )
    result = _validate(spec, bundle)
    assert "OWNER_SELECTION_REJECTED_DIMENSIONAL_DOUBLE_SCALING" in result["issues"]


def test_source_precision_selection_requires_new_rebase_spec(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path, selected_contract_id="SOURCE_PRECISION_RP0_056389_PW1")
    result = _validate(spec, bundle)
    assert "OWNER_SELECTION_REQUIRES_NEW_PRESET_REBASE_SPEC" in result["issues"]


def test_all_top_level_run_roots_must_be_distinct(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    first = bundle["baseline_receipts"][0]
    second = bundle["baseline_receipts"][1]
    payload = json.loads(Path(first["path"]).read_text(encoding="utf-8"))
    _rewrite_receipt(second, lambda row: row.__setitem__("run_root", payload["run_root"]))
    result = _validate(spec, bundle)
    assert "RUN_ROOTS_NOT_PAIRWISE_DISTINCT_OR_NESTED" in result["issues"]


def test_all_receipt_byte_hashes_must_be_distinct(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    bundle["qualification_receipts"][1] = copy.deepcopy(bundle["qualification_receipts"][0])
    result = _validate(spec, bundle)
    assert "RECEIPT_HASHES_NOT_PAIRWISE_DISTINCT" in result["issues"]


def test_contract_drift_between_repeats_is_rejected(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)

    def mutate(row: dict) -> None:
        row["contract"]["data_snapshot_sha256"] = _h("different-data")
        row["contract_sha256"] = validator.canonical_json_sha(row["contract"])

    _rewrite_receipt(bundle["qualification_receipts"][1], mutate)
    result = _validate(spec, bundle)
    assert "REPEAT_CONTRACT_HASH_MISMATCH" in result["issues"]


def test_stream_drift_between_repeats_is_rejected(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    binding = bundle["qualification_receipts"][1]

    def mutate(row: dict) -> None:
        stream = Path(row["aggregate"]["stream_path"])
        stream.write_bytes(b"different stream\n")
        row["aggregate"]["full_stream_sha256"] = validator.sha256_file(stream)

    _rewrite_receipt(binding, mutate)
    result = _validate(spec, bundle)
    assert any(
        issue.startswith("AGGREGATE_STREAM_NOT_DERIVED_FROM_NATIVE_REPORT")
        for issue in result["issues"]
    )


def test_reference_inside_qualification_run_root_is_self_reference(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    qualification_path = Path(bundle["qualification_receipts"][0]["path"])
    payload = json.loads(qualification_path.read_text(encoding="utf-8"))
    stream = Path(payload["aggregate"]["stream_path"])
    bundle["frozen_reference"]["path"] = str(stream.resolve())
    bundle["frozen_reference"]["sha256"] = validator.sha256_file(stream)
    result = _validate(spec, bundle)
    assert "SELF_REFERENCE_PATH_INSIDE_RUN_ROOT" in result["issues"]
    assert "SELF_REFERENCE_GENERATED_ARTIFACT_SELECTED" in result["issues"]


def test_consensus_reference_cannot_claim_independence(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    bundle["frozen_reference"]["independent_reference"] = True
    result = _validate(spec, bundle)
    assert "CONSENSUS_REFERENCE_MUST_NOT_BE_CALLED_INDEPENDENT" in result["issues"]


def test_seal_must_bind_exactly_baseline_not_qualification_receipts(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    seal_binding = bundle["frozen_reference"]["seal_manifest"]
    qualification_sha = bundle["qualification_receipts"][0]["sha256"]

    def mutate(row: dict) -> None:
        row["source_baseline_receipt_sha256s"][0] = qualification_sha

    _rewrite_receipt(seal_binding, mutate)
    result = _validate(spec, bundle)
    assert "OWNER_SEAL_CONTRACT_INVALID" in result["issues"]


def test_qualification_must_start_after_owner_seal(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    _rewrite_receipt(
        bundle["qualification_receipts"][0],
        lambda row: row.__setitem__("started_utc", "2026-07-16T09:59:00Z"),
    )
    result = _validate(spec, bundle)
    assert any(issue.startswith("QUALIFICATION_NOT_AFTER_SEAL") for issue in result["issues"])


def test_baseline_must_be_unreferenced_and_nonqualifying(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    _rewrite_receipt(
        bundle["baseline_receipts"][0],
        lambda row: row.__setitem__("selected_reference", {"path": "forbidden"}),
    )
    result = _validate(spec, bundle)
    assert any(issue.startswith("BASELINE_MODE_OR_REFERENCE_INVALID") for issue in result["issues"])


def test_qualification_must_select_exact_sealed_reference(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)

    def mutate(row: dict) -> None:
        row["selected_reference"]["sha256"] = _h("wrong-reference")

    _rewrite_receipt(bundle["qualification_receipts"][0], mutate)
    result = _validate(spec, bundle)
    assert any(
        issue.startswith("QUALIFICATION_REFERENCE_COMPARISON_INVALID")
        for issue in result["issues"]
    )


def test_segment_gap_crossing_or_state_carry_is_rejected(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)

    def mutate(row: dict) -> None:
        row["segments"][1]["cross_gap_position_count"] = 1
        row["segments"][1]["state_carried_from_previous_segment"] = True

    _rewrite_receipt(bundle["qualification_receipts"][0], mutate)
    result = _validate(spec, bundle)
    assert any(issue.startswith("SEGMENT_SEAM_STATE_INVALID") for issue in result["issues"])


def test_start_end_artifact_hash_sweep_must_be_identical(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)

    def mutate(row: dict) -> None:
        row["immutable_input_sweep"]["hashes_end"]["live_preset"] = _h("mutated-preset")

    _rewrite_receipt(bundle["qualification_receipts"][0], mutate)
    result = _validate(spec, bundle)
    assert any(issue.startswith("IMMUTABLE_INPUT_SWEEP_INVALID") for issue in result["issues"])


def test_effective_risk_receipt_must_explicitly_bind_weight_one(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)

    def mutate(row: dict) -> None:
        row["contract"]["PORTFOLIO_WEIGHT"] = "0.005783"
        row["contract"]["effective_risk_percent"] = "0.000326097587"
        row["contract_sha256"] = validator.canonical_json_sha(row["contract"])

    _rewrite_receipt(bundle["qualification_receipts"][0], mutate)
    result = _validate(spec, bundle)
    assert any(
        issue.startswith("EFFECTIVE_RISK_MUST_BIND_PORTFOLIO_WEIGHT_ONE")
        for issue in result["issues"]
    )


def test_sealed_input_manifest_structurally_binds_receipt_contract(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    binding = bundle["sealed_input_manifest"]

    def mutate(row: dict) -> None:
        row["contract_template"]["data_snapshot_sha256"] = _h("unsealed-data")
        row["contract_template_sha256"] = validator.canonical_json_sha(
            row["contract_template"]
        )

    _rewrite_receipt(binding, mutate)
    result = _validate(spec, bundle)
    assert "RECEIPT_CONTRACT_NOT_BOUND_BY_SEALED_INPUT" in result["issues"]


def test_owner_seal_structurally_binds_baseline_run_identity_hashes(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    binding = bundle["frozen_reference"]["seal_manifest"]

    def mutate(row: dict) -> None:
        row["source_baseline_runs"][0]["run_identity_sha256"] = _h("wrong-run")

    _rewrite_receipt(binding, mutate)
    result = _validate(spec, bundle)
    assert "OWNER_SEAL_CONTRACT_INVALID" in result["issues"]


@pytest.mark.parametrize(
    ("field", "expected_issue"),
    [
        ("execution_id", "EXECUTION_IDS_NOT_GLOBALLY_CASEFOLD_DISTINCT"),
        ("sandbox_id", "SANDBOX_IDS_NOT_GLOBALLY_CASEFOLD_DISTINCT"),
        ("output_root", "OUTPUT_ROOTS_NOT_GLOBALLY_DISTINCT_OR_NESTED"),
    ],
)
def test_run_execution_sandbox_and_output_identities_are_globally_distinct(
    tmp_path: Path, field: str, expected_issue: str
) -> None:
    spec, bundle = _make_bundle(tmp_path)
    baseline = json.loads(
        Path(bundle["baseline_receipts"][0]["path"]).read_text(encoding="utf-8")
    )

    def mutate(row: dict) -> None:
        row[field] = baseline[field]
        run_identity = {
            "execution_id": row["execution_id"],
            "sandbox_id": row["sandbox_id"],
            "output_root": row["output_root"],
            "contract_sha256": row["contract_sha256"],
        }
        row["run_identity_sha256"] = validator.canonical_json_sha(run_identity)

    _rewrite_receipt(bundle["qualification_receipts"][0], mutate)
    result = _validate(spec, bundle)
    assert expected_issue in result["issues"]


def test_hash_bound_dummy_cost_file_cannot_promote(tmp_path: Path) -> None:
    # Hermetic spec (see _hermetic_spec): avoids live repo/T_Live drift so
    # the exact TECHNICAL_PASS status keeps asserting deterministically.
    spec, bundle = _make_bundle(tmp_path, spec=_hermetic_spec(tmp_path))
    dummy = tmp_path / "dummy_cost.json"
    dummy.write_text('{"status":"PASS"}\n', encoding="utf-8")
    bundle["execution_cost_evidence_manifest"] = {
        "path": str(dummy.resolve()),
        "sha256": validator.sha256_file(dummy),
        "semantic_contract_sha256": _h("fake-semantic-contract"),
        "axis_hashes_sha256": _h("fake-axis-snapshot"),
    }
    result = _validate(spec, bundle)
    assert result["status"] == "TECHNICAL_PASS_COST_AND_RUNTIME_POLICY_BLOCKED"
    assert result["promotion_ready"] is False
    assert any(
        issue.startswith("EXECUTION_COST_SEMANTIC_VALIDATION_FAILED")
        for issue in result["cost_issues"]
    )


@pytest.mark.parametrize(
    "axis",
    [
        "signal_identity_sha256",
        "outcome_sign_sha256",
        "lot_identity_sha256",
        "pnl_identity_sha256",
    ],
)
def test_signal_outcome_lot_and_pnl_are_independent_identity_axes(
    tmp_path: Path, axis: str
) -> None:
    spec, bundle = _make_bundle(tmp_path)

    def mutate(row: dict) -> None:
        row["aggregate"][axis] = _h(f"drift:{axis}")

    _rewrite_receipt(bundle["qualification_receipts"][1], mutate)
    result = _validate(spec, bundle)
    assert any(
        issue.startswith("AGGREGATE_IDENTITY_NOT_DERIVED_FROM_NATIVE_REPORT")
        for issue in result["issues"]
    )


def test_plain_text_report_and_self_declared_metrics_cannot_qualify(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)

    def mutate(row: dict) -> None:
        report = Path(row["report_path"])
        report.write_text("self declared PASS 100% real ticks", encoding="utf-8")
        row["report_sha256"] = validator.sha256_file(report)
        row["report_metrics"] = {
            "currency": "EUR",
            "trade_count": 10,
            "net_profit": "999999",
        }

    _rewrite_receipt(bundle["qualification_receipts"][0], mutate)
    result = _validate(spec, bundle)
    assert any(issue.startswith("NATIVE_REPORT_PARSE_INVALID") for issue in result["issues"])
    assert any(
        issue.startswith("REPORT_METRICS_NOT_DERIVED_FROM_NATIVE_REPORT")
        for issue in result["issues"]
    )


def test_arbitrary_segment_stream_and_identity_hashes_are_recomputed(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)

    def mutate(row: dict) -> None:
        segment = row["segments"][0]
        stream = Path(segment["stream_path"])
        stream.write_text('{"claimed":"PASS"}\n', encoding="utf-8")
        segment["full_stream_sha256"] = validator.sha256_file(stream)
        segment["signal_identity_sha256"] = _h("self-attested-signal")

    _rewrite_receipt(bundle["qualification_receipts"][0], mutate)
    result = _validate(spec, bundle)
    assert any(
        issue.startswith("SEGMENT_STREAM_NOT_DERIVED_FROM_NATIVE_REPORT")
        for issue in result["issues"]
    )
    assert any(
        issue.startswith("SEGMENT_IDENTITY_NOT_DERIVED_FROM_NATIVE_REPORT")
        for issue in result["issues"]
    )


def test_data_snapshot_requires_real_complete_file_bindings(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    binding = bundle["data_manifest"]
    path = Path(binding["path"])
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["files"][0]["sha256"] = _h("fabricated-history")
    payload["data_snapshot_sha256"] = validator.canonical_json_sha(
        [
            {key: row[key] for key in ("symbol", "year", "kind", "sha256", "bytes")}
            for row in sorted(
                payload["files"], key=lambda row: (row["symbol"], row["year"], row["kind"])
            )
        ]
    )
    payload["manifest_payload_sha256"] = validator.embedded_hash(
        payload, "manifest_payload_sha256"
    )
    binding["sha256"] = _write_json(path, payload)
    result = _validate(spec, bundle)
    assert any(issue.startswith("DATA_FILE_HASH_OR_SIZE_MISMATCH") for issue in result["issues"])


def test_instrument_snapshot_must_equal_bound_raw_terminal_export(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    binding = bundle["instrument_manifest"]
    path = Path(binding["path"])
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["snapshot"]["symbols"]["GBPUSD.DWX"]["volume_step"] = 0.5
    payload["instrument_snapshot_sha256"] = validator.canonical_json_sha(
        {
            **payload["snapshot"],
            "raw_terminal_export_sha256": payload["raw_terminal_export"]["sha256"],
        }
    )
    payload["manifest_payload_sha256"] = validator.embedded_hash(
        payload, "manifest_payload_sha256"
    )
    binding["sha256"] = _write_json(path, payload)
    result = _validate(spec, bundle)
    assert "INSTRUMENT_RAW_EXPORT_MISMATCH" in result["issues"]


def test_self_attested_owner_approvals_fail_without_external_trust_anchors(
    tmp_path: Path,
) -> None:
    spec, bundle = _make_bundle(tmp_path)
    bundle["owner_decision"]["self_attested"] = True
    result = validator.validate_evidence(spec, bundle, spec_path=SPEC_PATH)
    assert all(
        f"OWNER_TRUST_ANCHOR_MISSING:{gate}" in result["issues"]
        for gate in validator.OWNER_GATES
    )
    assert result["technical_identity_pass"] is False


def test_external_owner_receipt_hash_mismatch_is_rejected(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    bundle.external_owner_trust_anchors["REFERENCE_SEAL"] = _h("forged-owner-receipt")
    result = _validate(spec, bundle)
    assert "OWNER_TRUST_ANCHOR_MISMATCH:REFERENCE_SEAL" in result["issues"]


@pytest.mark.parametrize("field", ["execution_id", "sandbox_id"])
def test_ids_are_casefold_distinct(tmp_path: Path, field: str) -> None:
    spec, bundle = _make_bundle(tmp_path)
    first = json.loads(Path(bundle["baseline_receipts"][0]["path"]).read_text())

    def mutate(row: dict) -> None:
        row[field] = first[field].swapcase()
        row["run_identity_sha256"] = validator.canonical_json_sha(
            {
                "execution_id": row["execution_id"],
                "sandbox_id": row["sandbox_id"],
                "output_root": row["output_root"],
                "contract_sha256": row["contract_sha256"],
            }
        )

    _rewrite_receipt(bundle["qualification_receipts"][0], mutate)
    result = _validate(spec, bundle)
    expected = (
        "EXECUTION_IDS_NOT_GLOBALLY_CASEFOLD_DISTINCT"
        if field == "execution_id"
        else "SANDBOX_IDS_NOT_GLOBALLY_CASEFOLD_DISTINCT"
    )
    assert expected in result["issues"]


def test_nested_run_roots_are_rejected_even_when_textually_distinct(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    first = json.loads(Path(bundle["baseline_receipts"][0]["path"]).read_text())
    nested_root = Path(first["run_root"]) / "nested"
    nested_root.mkdir()

    def mutate(row: dict) -> None:
        row["run_root"] = str(nested_root.resolve())
        row["output_root"] = str(nested_root.resolve())
        row["run_identity_sha256"] = validator.canonical_json_sha(
            {
                "execution_id": row["execution_id"],
                "sandbox_id": row["sandbox_id"],
                "output_root": row["output_root"],
                "contract_sha256": row["contract_sha256"],
            }
        )

    _rewrite_receipt(bundle["qualification_receipts"][0], mutate)
    result = _validate(spec, bundle)
    assert "RUN_ROOTS_NOT_PAIRWISE_DISTINCT_OR_NESTED" in result["issues"]


def test_generated_report_stream_path_collision_is_rejected(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)

    def mutate(row: dict) -> None:
        row["aggregate"]["stream_path"] = row["report_path"]

    _rewrite_receipt(bundle["qualification_receipts"][0], mutate)
    result = _validate(spec, bundle)
    assert any(
        issue.startswith("GENERATED_ARTIFACT_PATH_COLLISION")
        for issue in result["issues"]
    )


def test_owner_control_receipt_cannot_reuse_generated_run_artifact(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    generated = bundle["baseline_receipts"][0]
    bundle["owner_receipts"]["SEALED_INPUT"] = dict(generated)
    bundle.external_owner_trust_anchors["SEALED_INPUT"] = generated["sha256"]
    result = _validate(spec, bundle)
    assert any(
        issue.startswith("CONTROL_ARTIFACT_REUSES_GENERATED_PATH")
        for issue in result["issues"]
    )


def test_seal_in_forbidden_tier_named_root_is_rejected(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    old = Path(bundle["frozen_reference"]["seal_manifest"]["path"])
    forbidden = tmp_path / "T1" / "control" / "seal.json"
    forbidden.parent.mkdir(parents=True)
    forbidden.write_bytes(old.read_bytes())
    bundle["frozen_reference"]["seal_manifest"] = {
        "path": str(forbidden.resolve()),
        "sha256": validator.sha256_file(forbidden),
    }
    result = _validate(spec, bundle)
    assert any(
        issue.startswith("CONTROL_ARTIFACT_IN_FORBIDDEN_MT5_ROOT")
        for issue in result["issues"]
    )


def test_certified_cost_manifest_cannot_live_inside_run_root(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    receipt = json.loads(Path(bundle["qualification_receipts"][0]["path"]).read_text())
    cost_binding = _strict_cost_manifest(
        Path(receipt["run_root"]) / "control_cost",
        source_sha=receipt["contract_sha256"],
        spec=spec,
    )
    bundle["execution_cost_evidence_manifest"] = cost_binding
    result = _validate(spec, bundle)
    assert any(
        issue.startswith("CONTROL_ARTIFACT_OVERLAPS_RUN_ROOT")
        for issue in result["issues"]
    )


def test_run_level_report_must_be_directly_under_its_own_run_root(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)

    def mutate(row: dict) -> None:
        source = Path(row["report_path"])
        misplaced = Path(row["segments"][0]["segment_root"]) / "run_report.htm"
        misplaced.write_bytes(source.read_bytes())
        row["report_path"] = str(misplaced.resolve())
        row["report_sha256"] = validator.sha256_file(misplaced)

    _rewrite_receipt(bundle["qualification_receipts"][0], mutate)
    result = _validate(spec, bundle)
    assert any(issue.startswith("REPORT_BINDING_INVALID") for issue in result["issues"])


def test_segment_report_must_be_directly_under_its_own_segment_root(
    tmp_path: Path,
) -> None:
    spec, bundle = _make_bundle(tmp_path)

    def mutate(row: dict) -> None:
        segment = row["segments"][0]
        source = Path(segment["report_path"])
        sibling_root = Path(row["segments"][1]["segment_root"])
        misplaced = sibling_root / "s0_report.htm"
        misplaced.write_bytes(source.read_bytes())
        segment["report_path"] = str(misplaced.resolve())
        segment["report_sha256"] = validator.sha256_file(misplaced)

    _rewrite_receipt(bundle["qualification_receipts"][0], mutate)
    result = _validate(spec, bundle)
    assert any(
        issue.startswith("SEGMENT_REPORT_BINDING_INVALID")
        for issue in result["issues"]
    )


@pytest.mark.parametrize(
    ("entry_time", "exit_time"),
    [
        ("2024.01.12 18:45:00", "2024.01.12 19:00:00"),
        ("2024.01.12 22:00:00", "2024.01.12 23:00:00"),
        ("2024.01.12 20:00:00", "2024.01.15 01:00:00"),
        ("2024.01.13 10:00:00", "2024.01.13 11:00:00"),
    ],
)
def test_parsed_trade_intervals_enforce_card_cutoff_fallback_and_no_weekend(
    tmp_path: Path, entry_time: str, exit_time: str
) -> None:
    spec, bundle = _make_bundle(tmp_path)
    trades = _segment_trade_rows(spec)
    trades["S1"][0]["entry_time"] = entry_time
    trades["S1"][0]["exit_time"] = exit_time
    _replace_receipt_native_trades(bundle["qualification_receipts"][0], spec, trades)
    result = _validate(spec, bundle)
    assert any(
        issue.startswith("OWNER_EFFECTIVE_WEEKEND_FLAT_DEADLINE_VIOLATION")
        for issue in result["issues"]
    )


def test_session_calendar_is_mandatory_and_cannot_be_self_declared(tmp_path: Path) -> None:
    spec, bundle = _make_bundle(tmp_path)
    del bundle["session_calendar_manifest"]
    result = _validate(spec, bundle)
    assert any(issue.startswith("SESSION_CALENDAR_MANIFEST") for issue in result["issues"])


def test_holiday_early_close_from_bound_calendar_advances_flat_deadline(
    tmp_path: Path,
) -> None:
    spec, bundle = _make_bundle(tmp_path)
    binding = bundle["session_calendar_manifest"]
    manifest_path = Path(binding["path"])
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    boundary = next(
        row
        for row in manifest["weekend_boundaries"]
        if row["week_ending_friday"] == "2024-01-12"
    )
    boundary["last_tradable_broker_time"] = "2024.01.11 17:00:00"
    raw_path = Path(manifest["raw_server_session_export"]["path"])
    raw = {
        key: manifest[key]
        for key in (
            "source",
            "timezone_basis",
            "effective_from_date",
            "effective_to_date",
            "weekend_boundaries",
        )
    }
    manifest["raw_server_session_export"]["sha256"] = _write_json(raw_path, raw)
    manifest["session_calendar_sha256"] = validator.canonical_json_sha(
        {
            "raw_server_session_export_sha256": manifest["raw_server_session_export"]["sha256"],
            "weekend_boundaries": manifest["weekend_boundaries"],
        }
    )
    manifest["manifest_payload_sha256"] = validator.embedded_hash(
        manifest, "manifest_payload_sha256"
    )
    binding["sha256"] = _write_json(manifest_path, manifest)

    trades = _segment_trade_rows(spec)
    trades["S1"][0]["entry_time"] = "2024.01.11 18:00:00"
    trades["S1"][0]["exit_time"] = "2024.01.11 19:00:00"
    _replace_receipt_native_trades(bundle["qualification_receipts"][0], spec, trades)
    result = _validate(spec, bundle)
    assert any(
        issue.startswith("OWNER_EFFECTIVE_WEEKEND_FLAT_DEADLINE_VIOLATION")
        for issue in result["issues"]
    )
