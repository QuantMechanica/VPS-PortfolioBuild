"""Simulate a report-reconciled FTMO book on continuous Prague calendar days.

Each sleeve must provide a native MT5 summary, its exact Q08 MAE stream, and an
FTMO cost snapshot. The tool rejects count/net/time mismatches, replaces every
trade's native commission and swap with the FTMO values, and then runs the
conservative worst-aligned MAE model used for Phase-1 research.
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from .ftmo_phase1_mae import (
        START,
        TARGET,
        bootstrap,
        continuous_calendar_days,
        evaluate_window,
        ftmo_calendar_day,
        parse_number_list,
        q08_round_trip_values,
    )
    from .ftmo_report_cost_reconcile import extract_round_trips, ftmo_trade_net
    from .ftmo_stream_reconciliation import reconcile_case
except ImportError:  # pragma: no cover - direct script execution
    from ftmo_phase1_mae import (  # type: ignore
        START,
        TARGET,
        bootstrap,
        continuous_calendar_days,
        evaluate_window,
        ftmo_calendar_day,
        parse_number_list,
        q08_round_trip_values,
    )
    from ftmo_report_cost_reconcile import extract_round_trips, ftmo_trade_net  # type: ignore
    from ftmo_stream_reconciliation import reconcile_case  # type: ignore


ALIGNMENT_SECONDS_TOLERANCE = 1.0
NATIVE_NET_TOLERANCE = 0.06


@dataclass(frozen=True)
class CostedTrade:
    entry_day: dt.date
    close_day: dt.date
    net: float
    mae: float


@dataclass(frozen=True)
class LoadedSleeve:
    key: str
    ea_id: int
    symbol: str
    base_risk_fixed: float
    trades: tuple[CostedTrade, ...]
    native_net: float
    ftmo_net: float
    ftmo_commission: float
    ftmo_swap: float


def sleeve_key(ea_id: int, symbol: str) -> str:
    return f"{int(ea_id)}:{str(symbol).upper()}"


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open(encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, 1):
            if not line.strip():
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(f"{path}: invalid JSON on line {line_number}") from exc
            if str(row.get("event") or "TRADE_CLOSED") == "TRADE_CLOSED":
                rows.append(row)
    return rows


def _positive_number(mapping: Mapping[str, Any], key: str, default: float | None = None) -> float:
    raw = mapping.get(key, default)
    try:
        value = float(raw)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{key} must be numeric") from exc
    if not math.isfinite(value) or value <= 0.0:
        raise ValueError(f"{key} must be positive")
    return value


def _finite_number(mapping: Mapping[str, Any], key: str, default: float | None = None) -> float:
    raw = mapping.get(key, default)
    try:
        value = float(raw)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{key} must be numeric") from exc
    if not math.isfinite(value):
        raise ValueError(f"{key} must be finite")
    return value


def _timestamp(value: Any, label: str) -> float:
    try:
        timestamp = float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{label} timestamp missing") from exc
    if not math.isfinite(timestamp):
        raise ValueError(f"{label} timestamp invalid")
    return timestamp


def conservative_ftmo_mae(source_mae: float, native_net: float, ftmo_net: float) -> float:
    """Apply adverse cost delta to MAE without crediting favorable carry."""
    adverse_cost_delta = min(0.0, ftmo_net - native_net)
    return min(0.0, source_mae + adverse_cost_delta, ftmo_net)


def load_sleeve(case: Mapping[str, Any]) -> LoadedSleeve:
    ea_id = int(case["ea_id"])
    symbol = str(case["symbol"]).upper()
    summary_path = Path(str(case["summary_path"]))
    stream_path = Path(str(case["stream_path"]))
    reconciliation = reconcile_case(ea_id, symbol, summary_path, stream_path=stream_path)
    if reconciliation["status"] != "PASS":
        raise ValueError(
            f"{sleeve_key(ea_id, symbol)} reconciliation failed: "
            + ",".join(reconciliation["reasons"])
        )

    report_path = Path(str(reconciliation["report"]["report_canonical_path"]))
    report_trades, _ = extract_round_trips(report_path, symbol)
    stream_rows = sorted(load_jsonl(stream_path), key=lambda row: _timestamp(row.get("time"), "close"))
    if len(stream_rows) != len(report_trades):
        raise ValueError(f"{sleeve_key(ea_id, symbol)} trade count changed after reconciliation")

    cost = case.get("cost")
    if not isinstance(cost, Mapping):
        raise ValueError(f"{sleeve_key(ea_id, symbol)} cost specification missing")
    commission_percent = _finite_number(cost, "commission_percent_per_side", 0.0) / 100.0
    flat_commission = _finite_number(cost, "flat_round_trip_commission_per_lot", 0.0)
    swap_long = _finite_number(cost, "swap_long_points")
    swap_short = _finite_number(cost, "swap_short_points", swap_long)
    contract_size = _positive_number(cost, "contract_size")
    source_contract_size = _positive_number(cost, "source_contract_size", contract_size)
    account_rate = _positive_number(cost, "profit_currency_to_account_rate", 1.0)
    digits = int(cost["digits"])
    derive_rate = bool(cost.get("derive_profit_currency_rate_from_pnl", False))
    triple_weekday = int(cost.get("triple_weekday", 2))

    costed: list[CostedTrade] = []
    native_total = 0.0
    ftmo_total = 0.0
    commission_total = 0.0
    swap_total = 0.0
    for index, (row, report_trade) in enumerate(zip(stream_rows, report_trades), 1):
        entry_timestamp = _timestamp(row.get("entry_time"), "entry")
        close_timestamp = _timestamp(row.get("time"), "close")
        if abs(entry_timestamp - report_trade.entry_time.timestamp()) > ALIGNMENT_SECONDS_TOLERANCE:
            raise ValueError(f"{sleeve_key(ea_id, symbol)} trade {index} entry time mismatch")
        if abs(close_timestamp - report_trade.exit_time.timestamp()) > ALIGNMENT_SECONDS_TOLERANCE:
            raise ValueError(f"{sleeve_key(ea_id, symbol)} trade {index} close time mismatch")

        stream_native_net, source_mae = q08_round_trip_values(row)
        report_native_net = (
            report_trade.profit + report_trade.native_swap + report_trade.native_commission
        )
        if abs(stream_native_net - report_native_net) > NATIVE_NET_TOLERANCE:
            raise ValueError(
                f"{sleeve_key(ea_id, symbol)} trade {index} native net mismatch: "
                f"{stream_native_net:.2f}!={report_native_net:.2f}"
            )
        ftmo_net, commission, swap, _ = ftmo_trade_net(
            report_trade,
            commission_rate_per_side=commission_percent,
            flat_round_trip_commission_per_lot=flat_commission,
            swap_long_points=swap_long,
            swap_short_points=swap_short,
            contract_size=contract_size,
            source_contract_size=source_contract_size,
            profit_currency_to_account_rate=account_rate,
            derive_profit_currency_rate_from_pnl=derive_rate,
            digits=digits,
            triple_weekday=triple_weekday,
        )
        costed.append(
            CostedTrade(
                entry_day=ftmo_calendar_day(entry_timestamp),
                close_day=ftmo_calendar_day(close_timestamp),
                net=ftmo_net,
                mae=conservative_ftmo_mae(source_mae, report_native_net, ftmo_net),
            )
        )
        native_total += report_native_net
        ftmo_total += ftmo_net
        commission_total += commission
        swap_total += swap

    return LoadedSleeve(
        key=sleeve_key(ea_id, symbol),
        ea_id=ea_id,
        symbol=symbol,
        base_risk_fixed=_positive_number(case, "base_risk_fixed", 1000.0),
        trades=tuple(costed),
        native_net=native_total,
        ftmo_net=ftmo_total,
        ftmo_commission=commission_total,
        ftmo_swap=swap_total,
    )


def build_daily(
    sleeves: Sequence[LoadedSleeve],
    weights: Mapping[str, float],
    multiplier: float,
) -> tuple[list[dt.date], list[tuple[float, float, int]]]:
    if multiplier <= 0.0 or not math.isfinite(multiplier):
        raise ValueError("multiplier must be positive")
    realized: collections.defaultdict[dt.date, float] = collections.defaultdict(float)
    open_mae: collections.defaultdict[dt.date, float] = collections.defaultdict(float)
    trade_opens: collections.defaultdict[dt.date, int] = collections.defaultdict(int)
    observed: set[dt.date] = set()
    for sleeve in sleeves:
        weight = float(weights.get(sleeve.key, 0.0))
        if weight < 0.0 or not math.isfinite(weight):
            raise ValueError(f"invalid weight for {sleeve.key}")
        if weight == 0.0:
            continue
        scale = weight * multiplier
        for trade in sleeve.trades:
            realized[trade.close_day] += trade.net * scale
            trade_opens[trade.entry_day] += 1
            day = trade.entry_day
            while day <= trade.close_day:
                open_mae[day] += trade.mae * scale
                observed.add(day)
                day += dt.timedelta(days=1)
            observed.add(trade.close_day)
            observed.add(trade.entry_day)
    days = continuous_calendar_days(observed)
    return days, [
        (realized.get(day, 0.0), open_mae.get(day, 0.0), trade_opens.get(day, 0))
        for day in days
    ]


def count_windows(pairs: Sequence[tuple[float, float, int]], horizon: int) -> collections.Counter:
    counts: collections.Counter[str] = collections.Counter()
    if len(pairs) < horizon:
        return counts
    for start in range(0, len(pairs) - horizon + 1):
        counts[evaluate_window(pairs[start : start + horizon], target=TARGET)] += 1
    return counts


def _rates(counts: Mapping[str, int]) -> dict[str, float]:
    total = sum(counts.values())
    if total == 0:
        return {
            "runs": 0,
            "pass_pct": 0.0,
            "daily_breach_pct": 0.0,
            "max_breach_pct": 0.0,
            "not_reached_pct": 0.0,
        }
    return {
        "runs": total,
        "pass_pct": counts.get("passed", 0) / total * 100.0,
        "daily_breach_pct": counts.get("daily_breach", 0) / total * 100.0,
        "max_breach_pct": counts.get("max_breach", 0) / total * 100.0,
        "not_reached_pct": counts.get("not_reached", 0) / total * 100.0,
    }


def evaluate_manifest(
    manifest: Mapping[str, Any],
    *,
    multipliers: Sequence[float],
    horizons: Sequence[int],
    seeds: Sequence[int],
    runs: int,
    block: int,
) -> dict[str, Any]:
    raw_sleeves = manifest.get("sleeves")
    if not isinstance(raw_sleeves, list) or not raw_sleeves:
        raise ValueError("manifest sleeves must be a non-empty list")
    sleeves = [load_sleeve(case) for case in raw_sleeves]
    known_keys = {sleeve.key for sleeve in sleeves}

    raw_scenarios = manifest.get("scenarios") or [
        {
            "name": "manifest_weights",
            "weights": {
                sleeve.key: float(raw_sleeves[index].get("weight", 1.0))
                for index, sleeve in enumerate(sleeves)
            },
        }
    ]
    if not isinstance(raw_scenarios, list) or not raw_scenarios:
        raise ValueError("manifest scenarios must be a non-empty list")

    results: list[dict[str, Any]] = []
    for scenario in raw_scenarios:
        name = str(scenario.get("name") or "").strip()
        raw_weights = scenario.get("weights")
        if not name or not isinstance(raw_weights, Mapping):
            raise ValueError("every scenario needs name and weights")
        unknown = set(raw_weights) - known_keys
        if unknown:
            raise ValueError(f"scenario {name} has unknown sleeves: {sorted(unknown)}")
        weights = {key: float(raw_weights.get(key, 0.0)) for key in known_keys}
        if not any(value > 0.0 for value in weights.values()):
            raise ValueError(f"scenario {name} has no positive weights")

        for multiplier in multipliers:
            days, pairs = build_daily(sleeves, weights, multiplier)
            nominal_risk_fixed = sum(
                sleeve.base_risk_fixed * weights[sleeve.key] * multiplier
                for sleeve in sleeves
            )
            for horizon in horizons:
                boot_counts: collections.Counter[str] = collections.Counter()
                for seed in seeds:
                    boot_counts.update(bootstrap(pairs, horizon, block, runs, seed, target=TARGET))
                historical_counts = count_windows(pairs, horizon)
                results.append(
                    {
                        "scenario": name,
                        "weights": weights,
                        "multiplier": multiplier,
                        "nominal_risk_fixed": nominal_risk_fixed,
                        "nominal_risk_pct": nominal_risk_fixed / START * 100.0,
                        "horizon_calendar_days": horizon,
                        "data_start": days[0].isoformat(),
                        "data_end": days[-1].isoformat(),
                        "data_calendar_days": len(days),
                        "bootstrap": _rates(boot_counts),
                        "historical_rolling": _rates(historical_counts),
                    }
                )

    return {
        "schema_version": 1,
        "basis": "report_reconciled_trade_level_ftmo_cost_continuous_calendar_conservative_mae",
        "snapshot_date": manifest.get("snapshot_date"),
        "rules": {
            "starting_balance": START,
            "phase1_target": TARGET,
            "daily_loss_amount": 5000.0,
            "maximum_loss_amount": 10000.0,
            "minimum_trading_days": 4,
            "timezone": "Europe/Prague",
        },
        "limitations": [
            "Open trades are assumed to reach MAE simultaneously on every open calendar day.",
            "Current FTMO swap snapshot is applied to the full historical sample.",
            "Block bootstrap estimates research frequency and is not a pass guarantee.",
        ],
        "sleeves": [
            {
                "key": sleeve.key,
                "trades": len(sleeve.trades),
                "base_risk_fixed": sleeve.base_risk_fixed,
                "native_net": round(sleeve.native_net, 2),
                "ftmo_net": round(sleeve.ftmo_net, 2),
                "ftmo_commission": round(sleeve.ftmo_commission, 2),
                "ftmo_swap": round(sleeve.ftmo_swap, 2),
            }
            for sleeve in sleeves
        ],
        "results": results,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--multipliers", default="1,2,3,4,5")
    parser.add_argument("--horizons", default="30")
    parser.add_argument("--seeds", default="3,7,11")
    parser.add_argument("--runs", type=int, default=5000)
    parser.add_argument("--block", type=int, default=5)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    if args.runs < 1:
        parser.error("--runs must be positive")
    if args.block < 1:
        parser.error("--block must be positive")
    artifact = evaluate_manifest(
        json.loads(args.manifest.read_text(encoding="utf-8-sig")),
        multipliers=parse_number_list(args.multipliers, float, "multipliers"),
        horizons=parse_number_list(args.horizons, int, "horizons"),
        seeds=parse_number_list(args.seeds, int, "seeds", allow_zero=True),
        runs=args.runs,
        block=args.block,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    for row in artifact["results"]:
        boot = row["bootstrap"]
        print(
            f"{row['scenario']} risk={row['nominal_risk_pct']:.2f}% "
            f"horizon={row['horizon_calendar_days']}d pass={boot['pass_pct']:.2f}% "
            f"daily={boot['daily_breach_pct']:.2f}% max={boot['max_breach_pct']:.2f}% "
            f"not_reached={boot['not_reached_pct']:.2f}%"
        )
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
