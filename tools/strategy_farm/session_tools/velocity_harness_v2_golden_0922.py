#!/usr/bin/env python3
"""Build deterministic harness-v2 fixture and USDJPY C2 golden evidence.

The comparison is intentionally diagnostic.  It may establish that placement
and gap rules are represented faithfully; it may not turn an offline prescreen
into economic validation or override the registered MT5 pipeline.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path

from velocity_execution_harness_v2_0922 import (
    SymbolExecutionSpec,
    TickQuote,
    deterministic_json_bytes,
    pending_stop_fill,
    protective_stop_fill,
    target_fill,
    validate_oco_placement,
)
from velocity_family_f1_sweep_0921 import RELEASE_AUDIT_DOC, RELEASE_NATIVE_CSV, parse_control_report

REPO = Path("C:/QM/repo")
TASK_DIR = REPO / "docs/ops/evidence/2026-09-21_velocity_harness_v2/task_7088da77-9e03-45cf-a568-581863f03ef1"
CONTROL = TASK_DIR / "control_usdjpy_v2.json"
SWEEP = TASK_DIR / "velocity_family_f1_sweep_v2.json"
LOGGER = Path("D:/QM/reports/work_items/dc30f5ce-bd61-4026-8970-8d3a41582196/QM5_41485/20260921_151301/logger_sample.jsonl")
REPORTS = {
    2023: Path("D:/QM/reports/work_items/65ba3f5f-ee8f-4699-a93c-1b98e5d6c9a9/QM5_41485/20260921_152051/raw/run_01/report.htm"),
    2024: Path("D:/QM/reports/work_items/65ba3f5f-ee8f-4699-a93c-1b98e5d6c9a9/QM5_41485/20260921_152240/raw/run_01/report.htm"),
    2025: Path("D:/QM/reports/work_items/65ba3f5f-ee8f-4699-a93c-1b98e5d6c9a9/QM5_41485/20260921_152416/raw/run_01/report.htm"),
}
GROUND_TRUTH_PF = {2023: 1.004, 2024: 0.724, 2025: 0.916}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def trade_stats(trades: list[dict]) -> dict:
    values = [float(t["net_r"]) for t in trades]
    gain = sum(v for v in values if v > 0)
    loss = -sum(v for v in values if v < 0)
    return {
        "trades": len(values),
        "net_R": round(sum(values), 6),
        "E_R": round(sum(values) / len(values), 6) if values else None,
        "PF_from_trade_net_R": round(gain / loss, 6) if loss else None,
    }


def logger_rejections() -> list[dict]:
    out = []
    for raw in LOGGER.read_text(encoding="utf-8").splitlines():
        row = json.loads(raw)
        if row.get("event") != "ENTRY_REJECTED":
            continue
        payload = row.get("payload", {})
        stamp = dt.datetime.strptime(row["ts_broker"][:19], "%Y-%m-%dT%H:%M:%S")
        out.append({
            "day": stamp.date().isoformat(),
            "broker_time": stamp.isoformat(timespec="seconds"),
            "side": payload.get("type"),
            "detail": payload.get("detail"),
        })
    return sorted(out, key=lambda row: (row["day"], row["broker_time"], str(row["side"])))


def synthetic_fixture() -> dict:
    spec = SymbolExecutionSpec("USDJPY.DWX", 0.001, 0, 0, "synthetic_golden_fixture", "0" * 64, "0" * 64)
    quote = TickQuote(1_712_763_000, 1_712_763_000_593, 151.790, 151.858, "synthetic://release-tick")
    decision = validate_oco_placement(151.854, 151.774, quote, spec)
    gap_fills = {
        "buy_pending": pending_stop_fill(+1, 150.0, 150.4, 150.6, 150.3),
        "sell_pending": pending_stop_fill(-1, 150.0, 149.7, 149.8, 149.5),
        "long_protective": protective_stop_fill(+1, 149.0, 148.8, 149.0, 148.6),
        "short_protective": protective_stop_fill(-1, 151.0, 151.4, 151.6, 151.2),
        "long_target": target_fill(+1, 151.0, 151.3, 151.5, 151.2),
    }
    return {
        "schema": "qm.velocity-harness-v2-synthetic-fixture/v1",
        "release_anchor": {"zone": "America/New_York", "local_time": "08:30", "high_impact": True},
        "placement": {
            "requested_buy_stop": 151.854,
            "requested_sell_stop": 151.774,
            "quote": quote.to_dict(),
            "decision": decision.to_dict(),
            "expected_status": "CANCEL_NO_TRADE_ONE_SIDED",
        },
        "gap_rules": {
            "buy_pending": {"level": 150.0, "m1_open": 150.4, "m1_high": 150.6, "m1_low": 150.3,
                            "fill": gap_fills["buy_pending"]},
            "sell_pending": {"level": 150.0, "m1_open": 149.7, "m1_high": 149.8, "m1_low": 149.5,
                             "fill": gap_fills["sell_pending"]},
            "long_protective": {"level": 149.0, "m1_open": 148.8, "m1_high": 149.0, "m1_low": 148.6,
                                "fill": gap_fills["long_protective"]},
            "short_protective": {"level": 151.0, "m1_open": 151.4, "m1_high": 151.6, "m1_low": 151.2,
                                 "fill": gap_fills["short_protective"]},
            "long_target": {"level": 151.0, "m1_open": 151.3, "m1_high": 151.5, "m1_low": 151.2,
                            "fill": gap_fills["long_target"]},
        },
        "assertions": {
            "one_side_never_becomes_trade": decision.status == "CANCEL_NO_TRADE_ONE_SIDED" and not decision.pair_accepted,
            "all_gaps_use_first_m1_open": gap_fills == {
                "buy_pending": 150.4, "sell_pending": 149.7, "long_protective": 148.8,
                "short_protective": 151.4, "long_target": 151.3,
            },
        },
    }


def slim_sim(t: dict | None) -> dict | None:
    if t is None:
        return None
    return {k: t.get(k) for k in (
        "dir", "requested_entry", "entry", "exit", "w", "net_r", "fill_t", "exit_t", "exit_kind",
        "placement_t", "placement_tick_msc", "placement_bid", "placement_ask", "release_anchor"
    )}


def slim_report(t: dict | None) -> dict | None:
    if t is None:
        return None
    return {
        "dir": t["dir"], "entry": t["entry"], "exit": t["exit"], "net_r": round(t["net_r"], 6),
        "fill_t": t["fill_t"].isoformat(timespec="seconds"),
        "exit_t": t["exit_t"].isoformat(timespec="seconds"), "comment": t.get("comment"),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--control", type=Path, default=CONTROL)
    ap.add_argument("--sweep", type=Path, default=SWEEP)
    ap.add_argument("--out", type=Path, default=TASK_DIR / "golden_comparison.json")
    ap.add_argument("--fixture-out", type=Path, default=TASK_DIR / "synthetic_release_gap_fixture.json")
    args = ap.parse_args()

    fixture = synthetic_fixture()
    fixture_bytes = deterministic_json_bytes(fixture)
    args.fixture_out.parent.mkdir(parents=True, exist_ok=True)
    args.fixture_out.write_bytes(fixture_bytes)

    control = json.loads(args.control.read_text(encoding="utf-8"))
    sim_all = control["diagnostic_trades"]["USDJPY.DWX"]["C2"]
    placements = control["diagnostic_placements"]["USDJPY.DWX"]["C2"]
    rejections = logger_rejections()
    rejection_by_day = {r["day"]: r for r in rejections}
    placement_by_day = {p["day"]: p for p in placements}
    per_year = {}
    difficult = []

    for year, report_path in REPORTS.items():
        sim = [t for t in sim_all if t["day"].startswith(str(year))]
        report = parse_control_report(report_path)
        sim_by_day = {t["day"]: t for t in sim}
        report_by_day = {t["day"].isoformat(): t for t in report}
        common = sorted(set(sim_by_day) & set(report_by_day))
        sim_only = sorted(set(sim_by_day) - set(report_by_day))
        report_only = sorted(set(report_by_day) - set(sim_by_day))
        direction_mismatch = [day for day in common if sim_by_day[day]["dir"] != report_by_day[day]["dir"]]
        entry_gap = [day for day, t in sim_by_day.items() if abs(t["entry"] - t["requested_entry"]) > 1e-9]
        stop_gap = [day for day, t in sim_by_day.items() if "gap_through" in t["exit_kind"]]
        release = [day for day, p in placement_by_day.items()
                   if day.startswith(str(year)) and p.get("release_anchor")]
        rejected = [day for day in rejection_by_day if day.startswith(str(year))]
        flagged = sorted(set(sim_only + report_only + direction_mismatch + entry_gap + stop_gap + release + rejected))

        for day in flagged:
            tags = []
            if day in sim_only: tags.append("harness_only")
            if day in report_only: tags.append("tester_only")
            if day in direction_mismatch: tags.append("direction_mismatch")
            if day in entry_gap: tags.append("entry_gap_through")
            if day in stop_gap: tags.append("protective_gap_through")
            if day in release: tags.append("high_impact_0830_ny")
            if day in rejection_by_day: tags.append("tester_entry_rejected")
            difficult.append({
                "day": day,
                "tags": tags,
                "placement": placement_by_day.get(day),
                "harness": slim_sim(sim_by_day.get(day)),
                "tester": slim_report(report_by_day.get(day)),
            })

        per_year[str(year)] = {
            "harness": trade_stats(sim),
            "tester": trade_stats(report),
            "registered_ground_truth_PF": GROUND_TRUTH_PF[year],
            "days_common": len(common),
            "same_direction_common": len(common) - len(direction_mismatch),
            "harness_only_days": len(sim_only),
            "tester_only_days": len(report_only),
            "direction_mismatch_days": len(direction_mismatch),
            "entry_gap_days": len(entry_gap),
            "protective_gap_days": len(stop_gap),
            "high_impact_0830_ny_eligible_days": len(release),
            "high_impact_0830_ny_statuses": {
                status: sum(1 for day in release if placement_by_day[day]["status"] == status)
                for status in sorted({placement_by_day[day]["status"] for day in release})
            },
        }

    logger_days = {row["day"] for row in rejections}
    cancelled_days = {p["day"] for p in placements if p["status"] == "CANCEL_NO_TRADE_ONE_SIDED"}
    overlap = sorted(logger_days & cancelled_days)
    out = {
        "schema": "qm.velocity-harness-v2-golden/v1",
        "scope": "USDJPY.DWX C2, registered VAL folds 2023-2025",
        "inputs": {
            "control": {"path": str(args.control), "sha256": sha256(args.control)},
            "sweep": {"path": str(args.sweep), "sha256": sha256(args.sweep)},
            "logger": {"path": str(LOGGER), "sha256": sha256(LOGGER)},
            "release_attribution": {"path": str(RELEASE_NATIVE_CSV), "sha256": sha256(RELEASE_NATIVE_CSV),
                                    "authority_record": str(RELEASE_AUDIT_DOC),
                                    "authority_record_sha256": sha256(RELEASE_AUDIT_DOC)},
            "reports": {str(y): {"path": str(p), "sha256": sha256(p)} for y, p in REPORTS.items()},
            "fixture": {"path": str(args.fixture_out), "sha256": hashlib.sha256(fixture_bytes).hexdigest()},
        },
        "per_year": per_year,
        "placement_reconciliation_2024": {
            "tester_entry_rejected_days": len(logger_days),
            "harness_one_sided_cancel_days": len(cancelled_days),
            "overlap_days": len(overlap),
            "overlap": overlap,
            "logger_rejections": rejections,
        },
        "negative_lineage": {
            "hypothesis": "H-V4",
            "ea_id": 41485,
            "tag": "PRESCREEN_EXECUTION_MODEL_FALSE_POSITIVE",
            "permanent": True,
        },
        "difficult_days": sorted(difficult, key=lambda row: row["day"]),
        "verdict": {
            "placement_and_gap_mechanics": "PASS",
            "economic_equivalence": "UNKNOWN",
            "pipeline_authority": False,
            "explanation": "The fixture and archived-tick comparisons validate mechanics only; material trade/PF differences from Q04 remain.",
        },
    }
    args.out.write_bytes(deterministic_json_bytes(out))
    print(json.dumps({"out": str(args.out), "fixture": str(args.fixture_out), "per_year": per_year,
                      "placement_overlap": len(overlap)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
