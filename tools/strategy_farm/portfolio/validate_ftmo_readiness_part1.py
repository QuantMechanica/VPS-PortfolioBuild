#!/usr/bin/env python3
"""Produce the read-only FTMO readiness part-1 validation pack.

The producer snapshots existing broker/account-monitor output but never writes
inside T_Live.  It also derives exact lifecycle holding statistics from the
eight hash-bound native Q08 reports.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import html
import json
import math
import random
import shutil
import statistics
from collections import defaultdict
from html.parser import HTMLParser
from pathlib import Path
from typing import Any


TASK_ID = "b5a4e196-4670-44b3-af12-1152b40824ed"
DRIFT_MAGICS = {104760004, 106920005, 107150004, 109400003}
AUDIT_REFERENCE_NET = -469.0
AUDIT_WINDOW_START = dt.date(2026, 8, 1)
BOOTSTRAP_RUNS = 10_000
BOOTSTRAP_SEED = 20_260_905

REPO = Path(r"C:\QM\repo")
LIVE_CSV = Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\journal\live_deals_normalized.csv")
POINTER = Path(r"D:\QM\reports\state\live_deployment_pointer.json")
AUDIT_INVENTORY = REPO / "artifacts/audit_live_book_inventory_20260819.json"
COST_CURRENT = REPO / "docs/ops/evidence/2026-09-05_ftmo_current_pool_cost_snapshot.json"
COST_PRIOR = REPO / "docs/ops/evidence/2026-07-30_ftmo_book3_symbol_cost_snapshot.json"
VENUE_COST = REPO / "framework/registry/venue_cost_model.json"
LIVE_COMMISSION = REPO / "framework/registry/live_commission.json"

REPORTS = {
    "10706:GBPUSD": Path(r"D:\QM\reports\pipeline\QM5_10706\Q08\_baseline\QM5_10706\20260904_051342\raw\run_01\report.htm"),
    "11421:EURUSD": Path(r"D:\QM\reports\pipeline\QM5_11421\Q08\_baseline\QM5_11421\20260902_193230\raw\run_01\report.htm"),
    "11422:USDCAD": Path(r"D:\QM\reports\pipeline\QM5_11422\Q08\_baseline\QM5_11422\20260904_061656\raw\run_01\report.htm"),
    "11910:NZDUSD": Path(r"D:\QM\reports\pipeline\QM5_11910\Q08\_baseline\QM5_11910\20260904_160009\raw\run_01\report.htm"),
    "13054:XTIUSD": Path(r"D:\QM\reports\pipeline\QM5_13054\Q08\_baseline\QM5_13054\20260904_061139\raw\run_01\report.htm"),
    "1537:XAGUSD": Path(r"D:\QM\reports\pipeline\QM5_1537\Q08\_baseline\QM5_1537\20260904_050325\raw\run_01\report.htm"),
    "20048:XTIUSD": Path(r"D:\QM\reports\pipeline\QM5_20048\Q08\_baseline\QM5_20048\20260904_065008\raw\run_01\report.htm"),
    "21505:XAGUSD": Path(r"D:\QM\reports\pipeline\QM5_21505\Q08\_baseline\QM5_21505\20260904_060120\raw\run_01\report.htm"),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def identity(path: Path) -> dict[str, Any]:
    stat = path.stat()
    return {
        "path": str(path.resolve()),
        "sha256": sha256(path),
        "size_bytes": stat.st_size,
        "mtime_utc": dt.datetime.fromtimestamp(stat.st_mtime, dt.timezone.utc).isoformat(),
    }


def number(value: str) -> float:
    return float(value.replace(" ", "").replace("\xa0", ""))


class TableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.rows: list[list[str]] = []
        self.row: list[str] | None = None
        self.cell = False
        self.parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        del attrs
        if tag.lower() == "tr":
            self.row = []
        elif tag.lower() in {"td", "th"} and self.row is not None:
            self.cell, self.parts = True, []

    def handle_data(self, data: str) -> None:
        if self.cell:
            self.parts.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() in {"td", "th"} and self.row is not None and self.cell:
            value = html.unescape("".join(self.parts)).replace("\xa0", " ")
            self.row.append(" ".join(value.split()))
            self.cell = False
        elif tag.lower() == "tr" and self.row is not None:
            self.rows.append(self.row)
            self.row = None


def report_deals(path: Path) -> list[dict[str, str]]:
    raw = path.read_bytes()
    text = raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")
    parser = TableParser()
    parser.feed(text)
    expected = ["Time", "Deal", "Symbol", "Type", "Direction", "Volume", "Price", "Order", "Commission", "Swap", "Profit", "Balance", "Comment"]
    start = next(i for i, row in enumerate(parser.rows) if row == ["Deals"])
    if parser.rows[start + 1] != expected:
        raise ValueError(f"Deals schema mismatch: {path}")
    result = []
    for row in parser.rows[start + 2 :]:
        if len(row) != len(expected) or not row[0][:4].isdigit():
            break
        result.append(dict(zip(expected, row)))
    return [row for row in result if row["Symbol"]]


def holding_stats(path: Path) -> dict[str, Any]:
    deals = report_deals(path)
    if len(deals) % 2:
        raise ValueError(f"odd traded-deal count: {path}")
    trades = []
    for index in range(0, len(deals), 2):
        entry, exit_ = deals[index : index + 2]
        if entry["Direction"].lower() != "in" or exit_["Direction"].lower() != "out":
            raise ValueError(f"non-sequential lifecycle at deal row {index}: {path}")
        opened = dt.datetime.strptime(entry["Time"], "%Y.%m.%d %H:%M:%S")
        closed = dt.datetime.strptime(exit_["Time"], "%Y.%m.%d %H:%M:%S")
        hours = (closed - opened).total_seconds() / 3600.0
        # Native reports omit DEAL_POSITION_ID. For these eight reports every
        # lifecycle is strict IN,OUT with no overlap, so the opening order is a
        # deterministic derived lifecycle key; it is not mislabelled as native.
        trades.append({
            "derived_position_key": int(entry["Order"]),
            "entry_deal": int(entry["Deal"]),
            "exit_deal": int(exit_["Deal"]),
            "holding_hours": hours,
            "calendar_midnights_crossed": (closed.date() - opened.date()).days,
            "reported_swap": number(entry["Swap"]) + number(exit_["Swap"]),
        })
    holds = [row["holding_hours"] for row in trades]
    exposure = [row["calendar_midnights_crossed"] for row in trades]
    return {
        "report": identity(path),
        "pairing_contract": "strict_native_IN_OUT_no_overlap; derived_position_key=opening_Order (native report has no DEAL_POSITION_ID)",
        "trade_count": len(trades),
        "median_holding_hours": round(statistics.median(holds), 6),
        "median_holding_days": round(statistics.median(holds) / 24.0, 6),
        "mean_calendar_midnights_crossed_per_trade": round(statistics.mean(exposure), 6),
        "trades_crossing_at_least_one_midnight": sum(value > 0 for value in exposure),
        "trades_with_nonzero_reported_swap": sum(row["reported_swap"] != 0 for row in trades),
        "reported_swap_total": round(sum(row["reported_swap"] for row in trades), 2),
        "lifecycle_key_unique": len({row["derived_position_key"] for row in trades}) == len(trades),
    }


def magic_of(rows: list[dict[str, str]]) -> int:
    for row in rows:
        for key in ("logical_magic", "deal_magic", "magic"):
            raw = row.get(key, "").strip()
            if raw and int(raw):
                return int(raw)
    return 0


def percentile(values: list[float], probability: float) -> float:
    ordered = sorted(values)
    rank = probability * (len(ordered) - 1)
    low, high = math.floor(rank), math.ceil(rank)
    if low == high:
        return ordered[low]
    return ordered[low] + (ordered[high] - ordered[low]) * (rank - low)


def sharpe(values: list[float]) -> float | None:
    if len(values) < 2 or statistics.stdev(values) == 0:
        return None
    return statistics.mean(values) / statistics.stdev(values) * math.sqrt(252)


def sharpe_ci(values: list[float], seed: int) -> dict[str, Any]:
    estimate = sharpe(values)
    if estimate is None:
        return {"estimate": None, "ci95": [None, None], "reason": "fewer_than_2_or_zero_variance"}
    rng = random.Random(seed)
    samples = []
    for _ in range(BOOTSTRAP_RUNS):
        candidate = [rng.choice(values) for _ in values]
        sample = sharpe(candidate)
        if sample is not None and math.isfinite(sample):
            samples.append(sample)
    return {
        "estimate": round(estimate, 6),
        "ci95": [round(percentile(samples, 0.025), 6), round(percentile(samples, 0.975), 6)],
        "bootstrap_valid_replicates": len(samples),
    }


def daterange(start: dt.date, end: dt.date) -> list[dt.date]:
    return [start + dt.timedelta(days=i) for i in range((end - start).days + 1)]


def live_attribution(pointer: dict[str, Any]) -> dict[str, Any]:
    with LIVE_CSV.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    positions: dict[int, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        if row["type"].upper() != "BALANCE" and int(row["position_id"] or 0) > 0:
            positions[int(row["position_id"])].append(row)
    closed = []
    for position_id, lifecycle in positions.items():
        lifecycle.sort(key=lambda row: (row["time_utc"], int(row["deal_id"])))
        exits = [row for row in lifecycle if row["entry"].upper() in {"OUT", "OUT_BY", "INOUT"}]
        if not exits:
            continue
        closed.append({
            "position_id": position_id,
            "magic": magic_of(lifecycle),
            "symbol": next((row["symbol"] for row in lifecycle if row["symbol"]), ""),
            "close_date": max(row["time_utc"] for row in exits)[:10],
            "net_actual": round(sum(float(row["net_actual"]) for row in lifecycle), 2),
            "swap": round(sum(float(row["swap"]) for row in lifecycle), 2),
        })
    roster_rows = pointer["binary_setfile_fingerprint"]["per_sleeve"]
    roster = {int(row["magic_number"]): row for row in roster_rows}
    last_date = dt.date.fromisoformat(max(row["close_date"] for row in closed))
    days = daterange(AUDIT_WINDOW_START, last_date)
    governed = [row for row in closed if row["magic"] in roster]
    window = [row for row in governed if AUDIT_WINDOW_START.isoformat() <= row["close_date"] <= last_date.isoformat()]
    per_sleeve = []
    for index, (magic, roster_row) in enumerate(sorted(roster.items())):
        sleeve = [row for row in window if row["magic"] == magic]
        daily = [round(sum(row["net_actual"] for row in sleeve if row["close_date"] == day.isoformat()), 2) for day in days]
        per_sleeve.append({
            "ea_id": magic // 10000,
            "magic": magic,
            "symbol": next((row["symbol"] for row in sleeve), Path(roster_row["deployed_preset"]).name.split("_")[1]),
            "closed_trades": len(sleeve),
            "active_days": sum(value != 0 for value in daily),
            "net_actual": round(sum(daily), 2),
            "swap": round(sum(row["swap"] for row in sleeve), 2),
            "annualized_calendar_daily_sharpe": sharpe_ci(daily, BOOTSTRAP_SEED + index),
        })
    book_daily = [round(sum(row["net_actual"] for row in window if row["close_date"] == day.isoformat()), 2) for day in days]
    active_dates = sorted({row["close_date"] for row in governed})[-30:]
    last_30 = [row for row in governed if row["close_date"] in set(active_dates)]
    excluded_magic0 = [row for row in closed if row["magic"] == 0]
    excluded_drift = [row for row in closed if row["magic"] in DRIFT_MAGICS]
    return {
        "deal_export": identity(LIVE_CSV),
        "deal_rows": len(rows),
        "last_deal_utc": max(row["time_utc"] for row in rows),
        "governance": {
            "roster_source": identity(POINTER),
            "roster_magic_count": len(roster),
            "pointer_signed": bool(pointer.get("signed")),
            "excluded_magics": [0, *sorted(DRIFT_MAGICS)],
        },
        "audit_reconciliation_window": {
            "start": AUDIT_WINDOW_START.isoformat(),
            "end": last_date.isoformat(),
            "calendar_days": len(days),
            "active_close_days": sum(value != 0 for value in book_daily),
            "closed_trades": len(window),
            "net_actual": round(sum(book_daily), 2),
            "audit_reference_net": AUDIT_REFERENCE_NET,
            "delta_vs_audit_reference": round(sum(book_daily) - AUDIT_REFERENCE_NET, 2),
            "sharpe": sharpe_ci(book_daily, BOOTSTRAP_SEED),
        },
        "literal_latest_30_active_close_days": {
            "start": min(active_dates),
            "end": max(active_dates),
            "active_close_days": 30,
            "closed_trades": len(last_30),
            "net_actual": round(sum(row["net_actual"] for row in last_30), 2),
        },
        "excluded": {
            "magic_0": {"closed_trades": len(excluded_magic0), "net_actual": round(sum(row["net_actual"] for row in excluded_magic0), 2)},
            "drift_magics": {"closed_trades": len(excluded_drift), "net_actual": round(sum(row["net_actual"] for row in excluded_drift), 2), "last_close_by_magic": {str(magic): max((row["close_date"] for row in excluded_drift if row["magic"] == magic), default=None) for magic in sorted(DRIFT_MAGICS)}},
        },
        "per_sleeve": per_sleeve,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--evidence-json", type=Path, required=True)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=False)
    pointer = json.loads(POINTER.read_text(encoding="utf-8-sig"))
    shutil.copy2(LIVE_CSV, args.output_dir / "live_deals_normalized.csv")
    shutil.copy2(AUDIT_INVENTORY, args.output_dir / "audit_live_book_inventory.json")
    holdings = {sleeve: holding_stats(path) for sleeve, path in REPORTS.items()}
    current_cost = json.loads(COST_CURRENT.read_text(encoding="utf-8-sig"))
    result = {
        "schema": "qm.ftmo-readiness-part1-validation/v1",
        "task_id": TASK_ID,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "mode": "READ_ONLY_INPUTS_NO_TLIVE_MUTATION",
        "verdict": "PASS_WITH_RECONCILIATION_AND_OWNER_INPUTS_OPEN",
        "output_dir": str(args.output_dir.resolve()),
        "inputs": [identity(path) for path in [LIVE_CSV, POINTER, AUDIT_INVENTORY, VENUE_COST, LIVE_COMMISSION, COST_PRIOR, COST_CURRENT, *REPORTS.values()]],
        "live_attribution": live_attribution(pointer),
        "holding_periods": holdings,
        "cost_source_matrix": {
            "governed_registry": {"source": identity(VENUE_COST), "status": "swap_null; contract/commission context only"},
            "prior_snapshot": {"source": identity(COST_PRIOR), "status": "dated; only XTIUSD applies to current eight"},
            "current_snapshot": {"source": identity(COST_CURRENT), "status": current_cost["status"], "symbols": current_cost["symbols"]},
        },
        "owner_lookup_required": current_cost["owner_actions"],
        "authorization": {"purchase": False, "deploy": False, "live_write": False, "autotrading_toggle": False},
    }
    args.evidence_json.parent.mkdir(parents=True, exist_ok=True)
    args.evidence_json.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (args.output_dir / "validation.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": result["verdict"], "output_dir": str(args.output_dir), "evidence_json": str(args.evidence_json)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
