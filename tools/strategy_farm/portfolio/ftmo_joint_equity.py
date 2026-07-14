"""Exact FTMO 2-Step rule evaluation for synchronized portfolio equity traces.

This module does not invent intraday paths from trade entry/exit/MAE summaries.
It evaluates a joint trace only after all sleeves have been sampled on the same
UTC grid and their source evidence has passed report reconciliation.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence
from zoneinfo import ZoneInfo


PRAGUE = ZoneInfo("Europe/Prague")
EPSILON = 1e-9


@dataclass(frozen=True)
class FtmoRules:
    starting_balance: float = 100_000.0
    target_balance: float = 110_000.0
    daily_loss_amount: float = 5_000.0
    maximum_loss_amount: float = 10_000.0
    minimum_trading_days: int = 4

    @property
    def maximum_loss_floor(self) -> float:
        return self.starting_balance - self.maximum_loss_amount


PHASE1_RULES = FtmoRules()
PHASE2_RULES = FtmoRules(target_balance=105_000.0)


class TraceValidationError(ValueError):
    pass


def parse_utc(value: Any) -> dt.datetime:
    if isinstance(value, (int, float)):
        parsed = dt.datetime.fromtimestamp(float(value), tz=dt.UTC)
    else:
        raw = str(value or "").strip()
        if not raw:
            raise TraceValidationError("timestamp_missing")
        if raw.endswith("Z"):
            raw = raw[:-1] + "+00:00"
        try:
            parsed = dt.datetime.fromisoformat(raw)
        except ValueError as exc:
            raise TraceValidationError(f"timestamp_invalid:{value}") from exc
        if parsed.tzinfo is None:
            raise TraceValidationError("timestamp_timezone_missing")
        parsed = parsed.astimezone(dt.UTC)
    return parsed


def _finite_number(row: Mapping[str, Any], key: str) -> float:
    try:
        value = float(row[key])
    except (KeyError, TypeError, ValueError) as exc:
        raise TraceValidationError(f"{key}_invalid") from exc
    if not math.isfinite(value):
        raise TraceValidationError(f"{key}_nonfinite")
    return value


def _nonnegative_int(row: Mapping[str, Any], key: str) -> int:
    try:
        value = int(row.get(key, 0))
    except (TypeError, ValueError) as exc:
        raise TraceValidationError(f"{key}_invalid") from exc
    if value < 0:
        raise TraceValidationError(f"{key}_negative")
    return value


def normalize_trace(rows: Iterable[Mapping[str, Any]]) -> list[dict[str, Any]]:
    normalized: list[dict[str, Any]] = []
    seen: set[dt.datetime] = set()
    previous: dt.datetime | None = None
    for row in rows:
        timestamp = parse_utc(row.get("ts_utc"))
        if timestamp in seen:
            raise TraceValidationError(f"duplicate_timestamp:{timestamp.isoformat()}")
        if previous is not None and timestamp <= previous:
            raise TraceValidationError("timestamps_not_strictly_increasing")
        previous = timestamp
        seen.add(timestamp)
        normalized.append({
            "ts_utc": timestamp,
            "balance": _finite_number(row, "balance"),
            "equity": _finite_number(row, "equity"),
            "open_positions": _nonnegative_int(row, "open_positions"),
            "opened_positions": _nonnegative_int(row, "opened_positions"),
            "day_anchor": bool(row.get("day_anchor", False)),
        })
    if not normalized:
        raise TraceValidationError("trace_empty")
    return normalized


def _anchor_is_exact_midnight(timestamp: dt.datetime) -> bool:
    local = timestamp.astimezone(PRAGUE)
    return local.hour == local.minute == local.second == local.microsecond == 0


def evaluate_path(
    rows: Iterable[Mapping[str, Any]],
    *,
    rules: FtmoRules = PHASE1_RULES,
) -> dict[str, Any]:
    try:
        trace = normalize_trace(rows)
    except TraceValidationError as exc:
        return {"status": "INVALID", "reason": str(exc)}

    if abs(trace[0]["balance"] - rules.starting_balance) > 0.01:
        return {
            "status": "INVALID",
            "reason": (
                f"starting_balance_mismatch:{trace[0]['balance']:.2f}"
                f"!={rules.starting_balance:.2f}"
            ),
        }

    current_day: dt.date | None = None
    daily_floor: float | None = None
    trading_days: set[dt.date] = set()
    for index, row in enumerate(trace):
        timestamp: dt.datetime = row["ts_utc"]
        local_day = timestamp.astimezone(PRAGUE).date()
        if local_day != current_day:
            if not row["day_anchor"]:
                return {
                    "status": "INVALID",
                    "reason": f"day_anchor_missing:{local_day.isoformat()}",
                    "sample_index": index,
                }
            if not _anchor_is_exact_midnight(timestamp):
                return {
                    "status": "INVALID",
                    "reason": f"day_anchor_not_midnight:{timestamp.isoformat()}",
                    "sample_index": index,
                }
            current_day = local_day
            daily_floor = row["balance"] - rules.daily_loss_amount
        elif row["day_anchor"]:
            return {
                "status": "INVALID",
                "reason": f"duplicate_day_anchor:{local_day.isoformat()}",
                "sample_index": index,
            }

        if row["opened_positions"] > 0:
            trading_days.add(local_day)

        assert daily_floor is not None
        if row["equity"] < rules.maximum_loss_floor - EPSILON:
            return {
                "status": "MAX_BREACH",
                "timestamp_utc": timestamp.isoformat(),
                "equity": row["equity"],
                "floor": rules.maximum_loss_floor,
                "trading_days": len(trading_days),
            }
        if row["equity"] < daily_floor - EPSILON:
            return {
                "status": "DAILY_BREACH",
                "timestamp_utc": timestamp.isoformat(),
                "equity": row["equity"],
                "floor": daily_floor,
                "anchor_balance": daily_floor + rules.daily_loss_amount,
                "trading_days": len(trading_days),
            }
        if (
            row["balance"] + EPSILON >= rules.target_balance
            and row["open_positions"] == 0
            and len(trading_days) >= rules.minimum_trading_days
        ):
            return {
                "status": "PASS",
                "timestamp_utc": timestamp.isoformat(),
                "balance": row["balance"],
                "trading_days": len(trading_days),
            }

    final = trace[-1]
    return {
        "status": "NOT_REACHED",
        "balance": final["balance"],
        "equity": final["equity"],
        "open_positions": final["open_positions"],
        "trading_days": len(trading_days),
    }


def combine_sleeve_traces(
    traces: Mapping[str, Sequence[Mapping[str, Any]]],
    *,
    scales: Mapping[str, float] | None = None,
    starting_balance: float = 100_000.0,
) -> list[dict[str, Any]]:
    """Combine sleeve delta traces only when every UTC timestamp is identical.

    Sleeve rows must carry balance_delta and equity_delta relative to that
    sleeve's starting balance. Forward-filling different grids would fabricate
    co-movement and is therefore rejected.
    """
    if not traces:
        raise TraceValidationError("sleeve_traces_empty")
    parsed: dict[str, list[dict[str, Any]]] = {}
    timestamp_grid: list[dt.datetime] | None = None
    for key, rows in traces.items():
        current: list[dict[str, Any]] = []
        for row in rows:
            timestamp = parse_utc(row.get("ts_utc"))
            current.append({
                "ts_utc": timestamp,
                "balance_delta": _finite_number(row, "balance_delta"),
                "equity_delta": _finite_number(row, "equity_delta"),
                "open_positions": _nonnegative_int(row, "open_positions"),
                "opened_positions": _nonnegative_int(row, "opened_positions"),
                "day_anchor": bool(row.get("day_anchor", False)),
            })
        grid = [row["ts_utc"] for row in current]
        if len(grid) != len(set(grid)) or grid != sorted(grid):
            raise TraceValidationError(f"sleeve_grid_invalid:{key}")
        if timestamp_grid is None:
            timestamp_grid = grid
        elif grid != timestamp_grid:
            raise TraceValidationError(f"sleeve_grid_mismatch:{key}")
        parsed[key] = current

    assert timestamp_grid is not None
    output: list[dict[str, Any]] = []
    for index, timestamp in enumerate(timestamp_grid):
        balance = starting_balance
        equity = starting_balance
        open_positions = 0
        opened_positions = 0
        anchors: set[bool] = set()
        for key, rows in parsed.items():
            scale = float((scales or {}).get(key, 1.0))
            if not math.isfinite(scale) or scale < 0.0:
                raise TraceValidationError(f"sleeve_scale_invalid:{key}")
            row = rows[index]
            balance += row["balance_delta"] * scale
            equity += row["equity_delta"] * scale
            open_positions += row["open_positions"]
            opened_positions += row["opened_positions"]
            anchors.add(row["day_anchor"])
        if len(anchors) != 1:
            raise TraceValidationError(f"sleeve_anchor_mismatch:{timestamp.isoformat()}")
        output.append({
            "ts_utc": timestamp.isoformat(),
            "balance": round(balance, 8),
            "equity": round(equity, 8),
            "open_positions": open_positions,
            "opened_positions": opened_positions,
            "day_anchor": anchors.pop(),
        })
    return output


def evaluate_two_phase(
    phase1_rows: Iterable[Mapping[str, Any]],
    phase2_rows: Iterable[Mapping[str, Any]],
) -> dict[str, Any]:
    phase1 = evaluate_path(phase1_rows, rules=PHASE1_RULES)
    if phase1["status"] != "PASS":
        return {"status": "PHASE1_NOT_PASSED", "phase1": phase1, "phase2": None}
    phase2 = evaluate_path(phase2_rows, rules=PHASE2_RULES)
    return {
        "status": "PASS" if phase2["status"] == "PASS" else "PHASE2_NOT_PASSED",
        "phase1": phase1,
        "phase2": phase2,
    }


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open(encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, 1):
            if not line.strip():
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError as exc:
                raise TraceValidationError(f"json_invalid_line:{line_number}") from exc
    return rows


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--trace", type=Path, required=True)
    parser.add_argument("--phase", choices=("phase1", "phase2"), default="phase1")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args(argv)
    rules = PHASE1_RULES if args.phase == "phase1" else PHASE2_RULES
    artifact = evaluate_path(load_jsonl(args.trace), rules=rules)
    rendered = json.dumps(artifact, indent=2, sort_keys=True) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(rendered, encoding="utf-8")
        print(f"wrote {args.out} status={artifact['status']}")
    else:
        print(rendered, end="")
    return 0 if artifact["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
