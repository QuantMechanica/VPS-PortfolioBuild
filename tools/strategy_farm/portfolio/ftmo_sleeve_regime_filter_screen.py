"""Sealed causal regime-filter screen for report-reconciled FTMO sleeves.

Each feature is known before the native report trade enters. Candidate rules
are selected on 2018-2019 and 2021-2022 development plus 2023 validation.
Only one locked rule per sleeve is then evaluated on 2024-2025.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Callable, Mapping, Sequence

import numpy as np
import pandas as pd

try:
    from . import ftmo_bar_joint_book_sim as joint
    from .ftmo_report_cost_reconcile import RoundTrip, ftmo_trade_net
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_bar_joint_book_sim as joint  # type: ignore
    from ftmo_report_cost_reconcile import RoundTrip, ftmo_trade_net  # type: ignore


DEV_YEARS = (2018, 2019, 2021, 2022)
VALIDATION_YEAR = 2023
HOLDOUT_YEARS = (2024, 2025)


@dataclass(frozen=True)
class FeatureTrade:
    entry_time_utc: str
    year: int
    weekday: int
    prague_hour: int
    side: int
    net_r: float
    signed_return_4h: float
    signed_return_24h: float
    signed_return_5d: float
    signed_return_20d: float
    volatility_ratio: float


Rule = Callable[[FeatureTrade], bool]


def rule_set() -> dict[str, Rule]:
    return {
        "long_only": lambda row: row.side > 0,
        "short_only": lambda row: row.side < 0,
        "trend_4h_align": lambda row: row.signed_return_4h > 0.0,
        "trend_4h_fade": lambda row: row.signed_return_4h < 0.0,
        "trend_24h_align": lambda row: row.signed_return_24h > 0.0,
        "trend_24h_fade": lambda row: row.signed_return_24h < 0.0,
        "trend_consensus_align": lambda row: row.signed_return_4h > 0.0
        and row.signed_return_24h > 0.0,
        "trend_consensus_fade": lambda row: row.signed_return_4h < 0.0
        and row.signed_return_24h < 0.0,
        "trend_5d_align": lambda row: row.signed_return_5d > 0.0,
        "trend_5d_fade": lambda row: row.signed_return_5d < 0.0,
        "trend_20d_align": lambda row: row.signed_return_20d > 0.0,
        "trend_20d_fade": lambda row: row.signed_return_20d < 0.0,
        "trend_24h_5d_align": lambda row: row.signed_return_24h > 0.0
        and row.signed_return_5d > 0.0,
        "trend_5d_20d_align": lambda row: row.signed_return_5d > 0.0
        and row.signed_return_20d > 0.0,
        "volatility_active": lambda row: row.volatility_ratio >= 1.0,
        "volatility_calm": lambda row: row.volatility_ratio < 1.0,
        "trend_4h_align_active": lambda row: row.signed_return_4h > 0.0
        and row.volatility_ratio >= 1.0,
        "trend_4h_align_calm": lambda row: row.signed_return_4h > 0.0
        and row.volatility_ratio < 1.0,
        "trend_24h_align_active": lambda row: row.signed_return_24h > 0.0
        and row.volatility_ratio >= 1.0,
        "trend_24h_align_calm": lambda row: row.signed_return_24h > 0.0
        and row.volatility_ratio < 1.0,
        "trend_5d_align_active": lambda row: row.signed_return_5d > 0.0
        and row.volatility_ratio >= 1.0,
        "trend_20d_align_active": lambda row: row.signed_return_20d > 0.0
        and row.volatility_ratio >= 1.0,
        "exclude_friday": lambda row: row.weekday != 4,
        "asia_only": lambda row: row.prague_hour < 7,
        "europe_only": lambda row: 7 <= row.prague_hour < 13,
        "us_only": lambda row: 13 <= row.prague_hour < 22,
        "overnight_only": lambda row: row.prague_hour >= 22,
    }


def _number(mapping: Mapping[str, Any], key: str, default: float = 0.0) -> float:
    value = float(mapping.get(key, default))
    if not np.isfinite(value):
        raise ValueError(f"{key} must be finite")
    return value


def current_ftmo_net(case: Mapping[str, Any], trade: RoundTrip) -> float:
    cost = case.get("cost")
    if not isinstance(cost, Mapping):
        raise ValueError("cost specification missing")
    net, _commission, _swap, _units = ftmo_trade_net(
        trade,
        commission_rate_per_side=_number(cost, "commission_percent_per_side") / 100.0,
        flat_round_trip_commission_per_lot=_number(cost, "flat_round_trip_commission_per_lot"),
        swap_long_points=_number(cost, "swap_long_points"),
        swap_short_points=_number(cost, "swap_short_points", _number(cost, "swap_long_points")),
        contract_size=_number(cost, "contract_size"),
        source_contract_size=_number(cost, "source_contract_size", _number(cost, "contract_size")),
        profit_currency_to_account_rate=_number(cost, "profit_currency_to_account_rate", 1.0),
        derive_profit_currency_rate_from_pnl=bool(cost.get("derive_profit_currency_rate_from_pnl", False)),
        digits=int(cost["digits"]),
        triple_weekday=int(cost.get("triple_weekday", 2)),
    )
    return float(net)


def trade_features(
    case: Mapping[str, Any],
    bars: pd.DataFrame,
    trade: RoundTrip,
) -> FeatureTrade | None:
    timestamp_basis = str(case.get("timestamp_basis") or joint.TIMESTAMP_BASIS_UNIX_UTC)
    entry = joint.normalize_timestamp(trade.entry_time, timestamp_basis)
    entry_bucket = entry.floor(joint.GRID_FREQUENCY)
    position = int(bars.index.searchsorted(entry_bucket, side="left"))
    if position < 97:
        return None
    history = bars.iloc[max(0, position - 1921) : position]
    if len(history) < 97 or history[["high", "low", "close"]].isna().any().any():
        return None
    closes = history["close"].to_numpy(dtype=float)
    ranges = (history["high"] - history["low"]).to_numpy(dtype=float)
    if closes[0] <= 0.0 or closes[-17] <= 0.0:
        return None
    long_range = float(np.mean(ranges[-96:]))
    recent_range = float(np.mean(ranges[-16:]))
    if not np.isfinite(long_range) or long_range <= 0.0:
        return None
    side = 1 if trade.side == "buy" else -1
    prague = entry.tz_convert(joint.PRAGUE)
    base_risk = float(case.get("base_risk_fixed") or 1000.0)
    return FeatureTrade(
        entry_time_utc=entry.isoformat(),
        year=int(prague.year),
        weekday=int(prague.weekday()),
        prague_hour=int(prague.hour),
        side=side,
        net_r=current_ftmo_net(case, trade) / base_risk,
        signed_return_4h=side * (float(closes[-1]) / float(closes[-17]) - 1.0),
        signed_return_24h=side * (float(closes[-1]) / float(closes[-97]) - 1.0),
        signed_return_5d=(
            side * (float(closes[-1]) / float(closes[-481]) - 1.0)
            if len(closes) >= 481 and float(closes[-481]) > 0.0
            else float("nan")
        ),
        signed_return_20d=(
            side * (float(closes[-1]) / float(closes[-1921]) - 1.0)
            if len(closes) >= 1921 and float(closes[-1921]) > 0.0
            else float("nan")
        ),
        volatility_ratio=recent_range / long_range,
    )


def summarize(rows: Sequence[FeatureTrade]) -> dict[str, Any]:
    values = [row.net_r for row in rows]
    gross_profit = sum(value for value in values if value > 0.0)
    gross_loss = sum(value for value in values if value < 0.0)
    balance = 0.0
    peak = 0.0
    drawdown = 0.0
    for value in values:
        balance += value
        peak = max(peak, balance)
        drawdown = max(drawdown, peak - balance)
    return {
        "trades": len(values),
        "net_r": round(sum(values), 6),
        "profit_factor": None if gross_loss == 0.0 else round(gross_profit / abs(gross_loss), 6),
        "max_drawdown_r": round(drawdown, 6),
        "win_rate": round(sum(value > 0.0 for value in values) / len(values), 6) if values else 0.0,
    }


def split_metrics(rows: Sequence[FeatureTrade]) -> dict[str, Any]:
    return {
        "development": summarize([row for row in rows if row.year in DEV_YEARS]),
        "validation_2023": summarize([row for row in rows if row.year == VALIDATION_YEAR]),
        "holdout_2024_2025": summarize([row for row in rows if row.year in HOLDOUT_YEARS]),
        "annual": {
            str(year): summarize([row for row in rows if row.year == year])
            for year in (*DEV_YEARS, VALIDATION_YEAR, *HOLDOUT_YEARS)
        },
    }


def pf_value(metrics: Mapping[str, Any]) -> float:
    value = metrics.get("profit_factor")
    return 999.0 if value is None and int(metrics.get("trades", 0)) > 0 else float(value or 0.0)


def preholdout_score(metrics: Mapping[str, Any]) -> float:
    return min(pf_value(metrics["development"]), pf_value(metrics["validation_2023"]))


def preholdout_pass(
    metrics: Mapping[str, Any],
    control: Mapping[str, Any],
) -> bool:
    dev = metrics["development"]
    validation = metrics["validation_2023"]
    control_dev = control["development"]
    control_validation = control["validation_2023"]
    positive_dev_years = sum(
        metrics["annual"][str(year)]["net_r"] > 0.0 for year in DEV_YEARS
    )
    retention_dev = dev["trades"] / max(1, control_dev["trades"])
    retention_validation = validation["trades"] / max(1, control_validation["trades"])
    return (
        dev["trades"] >= 40
        and validation["trades"] >= 8
        and retention_dev >= 0.35
        and retention_validation >= 0.35
        and dev["net_r"] > 0.0
        and validation["net_r"] > 0.0
        and pf_value(dev) >= 1.10
        and pf_value(validation) >= 1.05
        and positive_dev_years >= 3
        and preholdout_score(metrics) >= preholdout_score(control) + 0.05
    )


def holdout_pass(metrics: Mapping[str, Any]) -> bool:
    holdout = metrics["holdout_2024_2025"]
    annual = metrics["annual"]
    return (
        holdout["trades"] >= 20
        and holdout["net_r"] > 0.0
        and pf_value(holdout) >= 1.10
        and annual["2024"]["net_r"] > 0.0
        and annual["2025"]["net_r"] > 0.0
    )


def screen_case(
    case: Mapping[str, Any],
    bars: pd.DataFrame,
    rules: Mapping[str, Rule],
) -> dict[str, Any]:
    feature_rows = [trade_features(case, bars, trade) for trade in case["trades"]]
    features = [row for row in feature_rows if row is not None and row.year != 2020]
    control = split_metrics(features)
    candidates: list[dict[str, Any]] = []
    for name, rule in rules.items():
        selected = [row for row in features if rule(row)]
        metrics = split_metrics(selected)
        candidates.append(
            {
                "rule": name,
                "metrics": metrics,
                "preholdout_score": preholdout_score(metrics),
                "preholdout_pass": preholdout_pass(metrics, control),
            }
        )
    eligible = [row for row in candidates if row["preholdout_pass"]]
    winner = max(
        eligible,
        key=lambda row: (
            row["preholdout_score"],
            row["metrics"]["development"]["trades"],
        ),
        default=None,
    )
    selected_winner = None
    if winner is not None:
        selected_winner = {
            "rule": winner["rule"],
            "preholdout_score": winner["preholdout_score"],
            "metrics": winner["metrics"],
            "holdout_verdict": "PASS" if holdout_pass(winner["metrics"]) else "FAIL",
        }
    leaderboard = sorted(
        candidates,
        key=lambda row: (row["preholdout_score"], row["metrics"]["development"]["trades"]),
        reverse=True,
    )[:5]
    return {
        "ea_id": int(case["ea_id"]),
        "symbol": str(case["symbol"]),
        "available_feature_trades": len(features),
        "control_metrics": control,
        "eligible_rule_count": len(eligible),
        "preholdout_leaderboard": [
            {
                "rule": row["rule"],
                "preholdout_score": row["preholdout_score"],
                "preholdout_pass": row["preholdout_pass"],
                "development": row["metrics"]["development"],
                "validation_2023": row["metrics"]["validation_2023"],
                "positive_dev_years": sum(
                    row["metrics"]["annual"][str(year)]["net_r"] > 0.0 for year in DEV_YEARS
                ),
            }
            for row in leaderboard
        ],
        "selected_winner": selected_winner,
    }


def screen(manifest: Mapping[str, Any], data_root: Path) -> dict[str, Any]:
    cases, bars = joint.load_cases(manifest, bar_paths=joint.default_bar_paths(data_root))
    rules = rule_set()
    sleeves = [screen_case(case, bars[str(case["symbol"]).upper()], rules) for case in cases]
    winners = [row["selected_winner"] for row in sleeves if row["selected_winner"] is not None]
    return {
        "schema_version": 1,
        "status": "HOLDOUT_SURVIVOR_FOUND"
        if any(row["holdout_verdict"] == "PASS" for row in winners)
        else "NO_HOLDOUT_SURVIVOR",
        "selection_contract": {
            "development": list(DEV_YEARS),
            "validation": VALIDATION_YEAR,
            "sealed_holdout": list(HOLDOUT_YEARS),
            "excluded_regime_year": 2020,
            "selection_uses_holdout": False,
            "features": "only completed bars strictly before native trade entry",
            "multiple_testing_control": "one locked winner opened per native sleeve",
            "costs": "native report round trips recosted to manifest FTMO snapshot",
        },
        "timestamp_basis": manifest.get("timestamp_basis", joint.TIMESTAMP_BASIS_UNIX_UTC),
        "candidate_rules": list(rules),
        "sleeves": sleeves,
        "selected_winner_count": len(winners),
        "holdout_pass_count": sum(row["holdout_verdict"] == "PASS" for row in winners),
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument(
        "--data-root",
        type=Path,
        default=Path(r"D:\QM\mt5\T_Export\MQL5\Files"),
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    artifact = screen(manifest, args.data_root)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "status": artifact["status"],
                "selected": artifact["selected_winner_count"],
                "holdout_pass": artifact["holdout_pass_count"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
