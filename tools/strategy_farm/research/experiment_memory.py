"""LEARN — experiment memory ledger + projector (design doc sec 8, directive sec 19).

Two pieces, built additively on the existing architecture (no new SQLite DB):

* An append-only ledger ``experiment_memory_ledger.jsonl``
  (``schema: qm.experiment_memory/v1``) mirroring the proven
  ``tester_memory_ledger.jsonl`` convention (audit sec 6.1). One line per idea /
  experiment observation.

* A pure, rebuildable projector that answers the directive sec 19 questions from an
  OBSERVE dataset directory (the CSV files emitted by :mod:`observe_projector`),
  emitting JSON with evidence links (work_item ids). No LLM calls; INFRA rows are
  excluded from every economic answer (design doc sec 1.2).

The projector reads only the deterministic CSV dataset — never the live DB, never
the gzip trees — so it is cheap and reproducible against a pinned dataset.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable

EXPERIMENT_MEMORY_SCHEMA = "qm.experiment_memory/v1"

_LEDGER_REQUIRED = (
    "strategy_id",
    "ea_id",
    "symbol",
    "phase",
    "verdict",
    "verdict_taxonomy",
)

# Q02 economic frequency floor: >= 5 trades/yr (OPERATING_RULES_2026-07-03.md via
# CLAUDE.md). UNVERIFIED per-year detail (design doc sec 8.2): the projector uses a
# total-trades / window-years proxy since per-year folds live in ea_metrics.detail_json,
# which the stdlib CSV dataset intentionally does not carry.
Q02_TRADES_PER_YEAR_FLOOR = 5.0


def _utc_now_iso() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


# --- ledger ------------------------------------------------------------------


def append_experiment(ledger_path: Path | str, record: dict[str, Any]) -> dict[str, Any]:
    """Append one validated experiment-memory observation (append-only)."""

    if not isinstance(record, dict):
        raise TypeError("experiment-memory record must be a dict")
    row = dict(record)
    row.setdefault("schema", EXPERIMENT_MEMORY_SCHEMA)
    row.setdefault("ts_utc", _utc_now_iso())
    missing = [f for f in _LEDGER_REQUIRED if f not in row]
    if missing:
        raise ValueError(f"experiment-memory record missing fields: {sorted(missing)}")

    path = Path(ledger_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    line = (json.dumps(row, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
    flags = os.O_WRONLY | os.O_CREAT | os.O_APPEND | getattr(os, "O_BINARY", 0)
    fd = os.open(path, flags, 0o600)
    try:
        os.write(fd, line)
    finally:
        os.close(fd)
    return row


def read_ledger(ledger_path: Path | str) -> list[dict[str, Any]]:
    path = Path(ledger_path)
    if not path.exists():
        return []
    rows: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


# --- projector ---------------------------------------------------------------


def _read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def _to_float(value: Any) -> float | None:
    text = str(value if value is not None else "").strip()
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def _window_years(window: str) -> float:
    """Estimate the span in years from a ``YYYY.MM.DD..YYYY.MM.DD`` window string."""

    text = str(window or "")
    if ".." not in text:
        return 1.0
    lo, hi = text.split("..", 1)

    def _year(token: str) -> int | None:
        token = token.strip()
        head = token.split(".", 1)[0]
        return int(head) if head.isdigit() and len(head) == 4 else None

    y0, y1 = _year(lo), _year(hi)
    if y0 is None or y1 is None:
        return 1.0
    return max(1.0, float(y1 - y0 + 1))


def project(
    dataset_dir: Path | str,
    *,
    trades_per_year_floor: float = Q02_TRADES_PER_YEAR_FLOOR,
    evidence_cap: int = 25,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Answer the directive sec 19 questions from an OBSERVE dataset directory."""

    dataset_dir = Path(dataset_dir)
    gate_rows = _read_csv(dataset_dir / "gate_outcomes.csv")
    metric_rows = _read_csv(dataset_dir / "ea_metrics.csv")
    family_rows = _read_csv(dataset_dir / "idea_families.csv")

    # ea_id -> family/strategy metadata
    family_by_ea = {r["ea_id"]: r for r in family_rows if r.get("ea_id")}
    # work_item_id -> gate row
    gate_by_wid = {r["work_item_id"]: r for r in gate_rows if r.get("work_item_id")}

    def _family_of(ea_id: str) -> str:
        rec = family_by_ea.get(ea_id)
        return (rec or {}).get("family", "unclassified") or "unclassified"

    def _strategy_of(ea_id: str) -> str:
        rec = family_by_ea.get(ea_id)
        return (rec or {}).get("strategy_id", "") or ""

    # Q1: which ideas repeatedly failed, and why (by family + reason class).
    # Only strategy-taxonomy FAIL/ZERO/RETIRE rows; INFRA is excluded.
    repeat_fail: dict[tuple[str, str], dict[str, Any]] = {}
    for row in gate_rows:
        if row.get("verdict_taxonomy") != "strategy":
            continue
        reason_class = row.get("reason_class", "")
        if reason_class not in {"FAIL", "FAIL_PORTFOLIO", "ZERO_TRADES", "RETIRE"}:
            continue
        family = _family_of(row.get("ea_id", ""))
        key = (family, reason_class)
        slot = repeat_fail.setdefault(
            key, {"family": family, "reason_class": reason_class, "count": 0, "work_item_ids": []}
        )
        slot["count"] += 1
        if len(slot["work_item_ids"]) < evidence_cap:
            slot["work_item_ids"].append(row.get("work_item_id"))
    repeatedly_failed = sorted(
        (v for v in repeat_fail.values() if v["count"] >= 2),
        key=lambda v: (-v["count"], v["family"], v["reason_class"]),
    )

    # Q2: redundant families (many distinct strategy_ids sharing one family).
    family_members: dict[str, set[str]] = defaultdict(set)
    for ea_id, rec in family_by_ea.items():
        family_members[rec.get("family", "unclassified") or "unclassified"].add(ea_id)
    redundant_families = sorted(
        (
            {"family": fam, "distinct_ea_count": len(members)}
            for fam, members in family_members.items()
            if len(members) >= 2
        ),
        key=lambda v: (-v["distinct_ea_count"], v["family"]),
    )

    # Q3/Q5: regime / symbol-family dependence — economic outcome vectors by symbol.
    symbol_stats: dict[str, dict[str, Any]] = {}
    for row in gate_rows:
        if row.get("verdict_taxonomy") != "strategy":
            continue
        symbol = row.get("symbol", "") or "<none>"
        slot = symbol_stats.setdefault(
            symbol, {"symbol": symbol, "pass": 0, "fail": 0, "zero_trades": 0, "total": 0}
        )
        slot["total"] += 1
        rc = row.get("reason_class", "")
        if rc == "PASS":
            slot["pass"] += 1
        elif rc == "ZERO_TRADES":
            slot["zero_trades"] += 1
        elif rc in {"FAIL", "FAIL_PORTFOLIO", "RETIRE"}:
            slot["fail"] += 1
    for slot in symbol_stats.values():
        total = slot["total"] or 1
        slot["pass_rate"] = round(slot["pass"] / total, 4)
    symbol_dependence = sorted(symbol_stats.values(), key=lambda v: (-v["total"], v["symbol"]))

    # Q6: strategies that fail only on economics (healthy risk, but FAIL/ZERO).
    # Q7: robust but too inactive (healthy risk metrics, trades/yr below the floor).
    economic_only_failures: list[dict[str, Any]] = []
    robust_but_inactive: list[dict[str, Any]] = []
    for metric in metric_rows:
        wid = metric.get("work_item_id", "")
        gate = gate_by_wid.get(wid)
        if gate is None or gate.get("verdict_taxonomy") != "strategy":
            continue
        pf = _to_float(metric.get("profit_factor"))
        dd = _to_float(metric.get("drawdown_pct"))
        sharpe = _to_float(metric.get("sharpe"))
        trades = _to_float(metric.get("trades"))
        healthy = (
            pf is not None and pf > 1.0
            and dd is not None and 0.0 <= dd <= 10.0
            and sharpe is not None and sharpe > 0.0
        )
        if not healthy:
            continue
        reason_class = gate.get("reason_class", "")
        ea_id = metric.get("ea_id", "")
        base = {
            "ea_id": ea_id,
            "symbol": metric.get("symbol", ""),
            "strategy_id": _strategy_of(ea_id),
            "family": _family_of(ea_id),
            "work_item_id": wid,
            "profit_factor": pf,
            "drawdown_pct": dd,
            "sharpe": sharpe,
            "trades": trades,
        }
        if reason_class in {"FAIL", "ZERO_TRADES", "RETIRE"}:
            economic_only_failures.append(dict(base))
        years = _window_years(gate.get("window", ""))
        trades_per_year = (trades / years) if trades is not None else None
        if trades_per_year is not None and trades_per_year < trades_per_year_floor:
            entry = dict(base)
            entry["trades_per_year"] = round(trades_per_year, 3)
            entry["window_years"] = years
            robust_but_inactive.append(entry)

    economic_only_failures.sort(key=lambda v: (v["ea_id"], v["symbol"]))
    robust_but_inactive.sort(key=lambda v: (v.get("trades_per_year", 0.0), v["ea_id"]))

    return {
        "schema": "qm.experiment_memory.projection/v1",
        "generated_at_utc": (now.isoformat() if now else _utc_now_iso()),
        "dataset_dir": str(dataset_dir.resolve()),
        "trades_per_year_floor": trades_per_year_floor,
        "counts": {
            "gate_rows": len(gate_rows),
            "metric_rows": len(metric_rows),
            "families": len(family_rows),
        },
        "repeatedly_failed_ideas": repeatedly_failed,
        "redundant_families": redundant_families,
        "symbol_family_dependence": symbol_dependence,
        "economic_only_failures": economic_only_failures[:evidence_cap],
        "robust_but_inactive": robust_but_inactive[:evidence_cap],
        "notes": [
            "INFRA-taxonomy rows are excluded from every economic answer (design doc sec 1.2).",
            "trades_per_year is a total/window-years proxy; per-year folds live in "
            "ea_metrics.detail_json and are UNVERIFIED here (design doc sec 8.2).",
            "Each conclusion resolves back to work_item_id evidence (directive sec 19).",
        ],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dataset_dir", type=Path)
    parser.add_argument("--out", type=Path, default=None)
    args = parser.parse_args(argv)
    projection = project(args.dataset_dir)
    rendered = json.dumps(projection, indent=2, sort_keys=True) + "\n"
    if args.out:
        args.out.write_text(rendered, encoding="utf-8", newline="\n")
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
