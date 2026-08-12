"""Derive a fixed per-sleeve weekday exclusion manifest from current-cost trades."""

from __future__ import annotations

import argparse
import copy
import json
from collections import defaultdict
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from .ftmo_bar_governor_sim import PRAGUE, _cost_spec
    from .ftmo_bar_joint_book_sim import (
        default_bar_paths,
        load_cases,
        normalize_timestamp,
        sleeve_key,
    )
    from .ftmo_report_cost_reconcile import ftmo_trade_net
except ImportError:  # pragma: no cover - direct script execution
    from ftmo_bar_governor_sim import PRAGUE, _cost_spec  # type: ignore
    from ftmo_bar_joint_book_sim import (  # type: ignore
        default_bar_paths,
        load_cases,
        normalize_timestamp,
        sleeve_key,
    )
    from ftmo_report_cost_reconcile import ftmo_trade_net  # type: ignore


TRAINING_YEARS = (2018, 2019, 2020, 2021, 2022)


def qualifying_weekdays(
    stats: Mapping[int, Mapping[int, Mapping[str, float]]],
    *,
    training_years: Sequence[int] = TRAINING_YEARS,
    minimum_trades_each_year: int = 2,
    minimum_negative_years: int = 4,
) -> list[int]:
    selected: list[int] = []
    for weekday in range(5):
        rows = [stats.get(weekday, {}).get(year, {}) for year in training_years]
        if any(int(row.get("trades", 0)) < minimum_trades_each_year for row in rows):
            continue
        negative_years = sum(float(row.get("net", 0.0)) < 0.0 for row in rows)
        pooled_net = sum(float(row.get("net", 0.0)) for row in rows)
        if negative_years >= minimum_negative_years and pooled_net < 0.0:
            selected.append(weekday)
    return selected


def _trade_net(case: Mapping[str, Any], trade: Any) -> float:
    spec = _cost_spec(case)
    net, _, _, _ = ftmo_trade_net(
        trade,
        commission_rate_per_side=spec["commission_rate"],
        flat_round_trip_commission_per_lot=spec["flat_commission"],
        swap_long_points=spec["swap_long"],
        swap_short_points=spec["swap_short"],
        contract_size=spec["contract_size"],
        source_contract_size=spec["source_size"],
        profit_currency_to_account_rate=spec["account_rate"],
        derive_profit_currency_rate_from_pnl=spec["derive_rate"],
        digits=spec["digits"],
        triple_weekday=spec["triple_weekday"],
    )
    return float(net)


def collect_stats(cases: Sequence[Mapping[str, Any]]) -> dict[str, dict[int, dict[int, dict[str, float]]]]:
    stats: dict[str, dict[int, dict[int, dict[str, float]]]] = defaultdict(
        lambda: defaultdict(lambda: defaultdict(lambda: {"trades": 0, "net": 0.0}))
    )
    for case in cases:
        key = str(case.get("weight_key") or sleeve_key(int(case["ea_id"]), str(case["symbol"])))
        timestamp_basis = str(case.get("timestamp_basis") or "unix_utc")
        for trade in case["trades"]:
            entry = normalize_timestamp(trade.entry_time, timestamp_basis).tz_convert(PRAGUE)
            if entry.year not in TRAINING_YEARS or entry.weekday() >= 5:
                continue
            bucket = stats[key][entry.weekday()][entry.year]
            bucket["trades"] += 1
            bucket["net"] += _trade_net(case, trade)
    return stats


def apply_exclusions(
    manifest: Mapping[str, Any],
    selections: Mapping[str, Sequence[int]],
) -> dict[str, Any]:
    output = copy.deepcopy(dict(manifest))
    application: dict[str, list[int]] = {}
    for sleeve in output["sleeves"]:
        key = sleeve_key(int(sleeve["ea_id"]), str(sleeve["symbol"]))
        weekdays = sorted({int(value) for value in selections.get(key, [])})
        if not weekdays:
            continue
        if str(sleeve.get("entry_filter") or "").strip():
            raise ValueError(f"{key}: refusing to replace existing entry_filter")
        sleeve["entry_filter"] = "exclude_weekdays"
        sleeve["entry_filter_excluded_weekdays"] = weekdays
        application[key] = weekdays
    output["weekday_filter_application"] = application
    output["weekday_filter_predeclaration"] = (
        "artifacts/ftmo_incumbent_weekday_filter_predeclaration_2026-07-12.json"
    )
    output["deployment_allowed"] = False
    output["status"] = "RESEARCH_ONLY_NO_GO"
    return output


def build_artifacts(manifest: Mapping[str, Any], cases: Sequence[Mapping[str, Any]]) -> tuple[dict[str, Any], dict[str, Any]]:
    stats = collect_stats(cases)
    selections = {
        key: qualifying_weekdays(by_weekday)
        for key, by_weekday in stats.items()
    }
    filtered = apply_exclusions(manifest, selections)
    serial_stats = {
        key: {
            str(weekday): {
                str(year): {
                    "trades": int(values["trades"]),
                    "net": round(float(values["net"]), 6),
                }
                for year, values in sorted(by_year.items())
            }
            for weekday, by_year in sorted(by_weekday.items())
        }
        for key, by_weekday in sorted(stats.items())
    }
    evidence = {
        "schema_version": 1,
        "status": "FILTERS_DERIVED" if filtered["weekday_filter_application"] else "NO_FILTERS_DERIVED",
        "training_years": list(TRAINING_YEARS),
        "minimum_trades_each_training_year": 2,
        "minimum_negative_years": 4,
        "weekday_basis": "Prague entry weekday; Monday=0",
        "selections": filtered["weekday_filter_application"],
        "stats": serial_stats,
        "deployment_allowed": False,
        "label": "RESEARCH_ONLY_NO_GO",
    }
    return filtered, evidence


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument(
        "--data-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\MQL5\Files")
    )
    parser.add_argument("--out-manifest", type=Path, required=True)
    parser.add_argument("--out-evidence", type=Path, required=True)
    args = parser.parse_args(argv)
    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    cases, _ = load_cases(manifest, bar_paths=default_bar_paths(args.data_root))
    filtered, evidence = build_artifacts(manifest, cases)
    args.out_manifest.parent.mkdir(parents=True, exist_ok=True)
    args.out_evidence.parent.mkdir(parents=True, exist_ok=True)
    args.out_manifest.write_text(json.dumps(filtered, indent=2) + "\n", encoding="utf-8")
    args.out_evidence.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "manifest": str(args.out_manifest),
                "evidence": str(args.out_evidence),
                "status": evidence["status"],
                "selections": evidence["selections"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
