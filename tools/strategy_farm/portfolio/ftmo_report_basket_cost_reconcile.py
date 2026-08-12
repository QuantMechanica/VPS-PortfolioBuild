"""Re-cost a multi-symbol MT5 report with one current FTMO model per leg."""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

try:
    from .ftmo_report_cost_reconcile import (
        DEFAULT_MIN_TRADES_PER_YEAR,
        DEFAULT_Q02_PF_FLOOR,
        RoundTrip,
        conservative_trade_net,
        extract_round_trips,
        file_sha256,
        ftmo_trade_net,
        parse_summary_spec,
        report_period_years,
        summarize_cost_rows,
    )
except ImportError:  # pragma: no cover - direct script execution
    from ftmo_report_cost_reconcile import (  # type: ignore
        DEFAULT_MIN_TRADES_PER_YEAR,
        DEFAULT_Q02_PF_FLOOR,
        RoundTrip,
        conservative_trade_net,
        extract_round_trips,
        file_sha256,
        ftmo_trade_net,
        parse_summary_spec,
        report_period_years,
        summarize_cost_rows,
    )


def _positive(spec: Mapping[str, Any], name: str, default: float | None = None) -> float:
    value = spec.get(name, default)
    if value is None or float(value) <= 0.0:
        raise ValueError(f"{name} must be positive")
    return float(value)


def _finite(spec: Mapping[str, Any], name: str, default: float = 0.0) -> float:
    value = float(spec.get(name, default))
    if not -float("inf") < value < float("inf"):
        raise ValueError(f"{name} must be finite")
    return value


def recost_trades(
    trades: Sequence[RoundTrip],
    symbol_costs: Mapping[str, Mapping[str, Any]],
    *,
    internal_round_trip_notional_rate: float = 0.00005,
) -> tuple[
    list[float],
    list[tuple[float, float, float, int]],
    list[tuple[float, float, float, int]],
]:
    normalized_costs = {str(symbol).upper(): spec for symbol, spec in symbol_costs.items()}
    native_nets: list[float] = []
    ftmo_rows: list[tuple[float, float, float, int]] = []
    conservative_rows: list[tuple[float, float, float, int]] = []
    for trade in trades:
        spec = normalized_costs.get(trade.symbol.upper())
        if spec is None:
            raise ValueError(f"missing cost specification for report symbol {trade.symbol}")
        contract_size = _positive(spec, "contract_size")
        source_contract_size = _positive(spec, "source_contract_size", contract_size)
        account_rate = _positive(spec, "profit_currency_to_account_rate", 1.0)
        swap_long = _finite(spec, "swap_long_points")
        swap_short = _finite(spec, "swap_short_points", swap_long)
        digits = int(spec["digits"])
        triple_weekday = int(spec.get("triple_weekday", 2))
        native_nets.append(trade.profit + trade.native_swap + trade.native_commission)
        ftmo_rows.append(
            ftmo_trade_net(
                trade,
                commission_rate_per_side=(
                    _finite(spec, "commission_percent_per_side") / 100.0
                ),
                flat_round_trip_commission_per_lot=_finite(
                    spec, "flat_round_trip_commission_per_lot"
                ),
                swap_long_points=swap_long,
                swap_short_points=swap_short,
                contract_size=contract_size,
                source_contract_size=source_contract_size,
                profit_currency_to_account_rate=account_rate,
                derive_profit_currency_rate_from_pnl=bool(
                    spec.get("derive_profit_currency_rate_from_pnl", False)
                ),
                digits=digits,
                triple_weekday=triple_weekday,
            )
        )
        conservative_rows.append(
            conservative_trade_net(
                trade,
                round_trip_notional_rate=float(
                    spec.get(
                        "internal_round_trip_notional_rate",
                        internal_round_trip_notional_rate,
                    )
                ),
                swap_long_points=swap_long,
                swap_short_points=swap_short,
                contract_size=contract_size,
                source_contract_size=source_contract_size,
                profit_currency_to_account_rate=account_rate,
                derive_profit_currency_rate_from_pnl=bool(
                    spec.get("derive_profit_currency_rate_from_pnl", False)
                ),
                digits=digits,
                triple_weekday=triple_weekday,
            )
        )
    return native_nets, ftmo_rows, conservative_rows


def evaluate_basket_reports(
    summary_specs: Sequence[tuple[int, Path]],
    *,
    cost_spec: Mapping[str, Any],
    coverage_start_year: int | None = None,
    coverage_end_year: int | None = None,
) -> dict[str, Any]:
    symbol_costs = cost_spec.get("symbols")
    if not isinstance(symbol_costs, Mapping) or not symbol_costs:
        raise ValueError("cost specification requires a non-empty symbols object")
    expected_symbols = {str(symbol).upper() for symbol in symbol_costs}
    internal_rate = float(cost_spec.get("internal_round_trip_notional_rate", 0.00005))

    all_trades: list[RoundTrip] = []
    all_native: list[float] = []
    all_ftmo_rows: list[tuple[float, float, float, int]] = []
    all_conservative_rows: list[tuple[float, float, float, int]] = []
    period_years: set[int] = set()
    reports: list[dict[str, Any]] = []

    for year, summary_path in sorted(summary_specs):
        summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
        ok_runs = [
            run
            for run in summary.get("runs") or []
            if str(run.get("status")).upper() == "OK"
        ]
        if not ok_runs:
            raise ValueError(f"{summary_path}: no OK run")
        report_path = Path(str(ok_runs[0]["report_canonical_path"]))
        trades, report_stats = extract_round_trips(report_path, None)
        observed_symbols = {trade.symbol.upper() for trade in trades}
        unknown = sorted(observed_symbols - expected_symbols)
        missing = sorted(expected_symbols - observed_symbols)
        if unknown or missing:
            raise ValueError(
                f"{report_path}: basket symbol mismatch unknown={unknown} missing={missing}"
            )
        native, ftmo_rows, conservative_rows = recost_trades(
            trades,
            symbol_costs,
            internal_round_trip_notional_rate=internal_rate,
        )
        all_trades.extend(trades)
        all_native.extend(native)
        all_ftmo_rows.extend(ftmo_rows)
        all_conservative_rows.extend(conservative_rows)
        period_years.update(report_period_years(str(report_stats.get("period") or "")))
        reports.append(
            {
                "year": year,
                "summary_path": str(summary_path),
                "summary_sha256": file_sha256(summary_path),
                "report_path": str(report_path),
                "report_sha256": file_sha256(report_path),
                "deterministic_ok_run_count": len(ok_runs),
                "native_report": report_stats,
                "observed_symbols": sorted(observed_symbols),
                **summarize_cost_rows(native, ftmo_rows, conservative_rows),
            }
        )

    candidate_years = period_years | {trade.entry_time.year for trade in all_trades}
    if coverage_start_year is not None:
        candidate_years = {year for year in candidate_years if year >= coverage_start_year}
    if coverage_end_year is not None:
        candidate_years = {year for year in candidate_years if year <= coverage_end_year}
    if any(trade.entry_time.year not in candidate_years for trade in all_trades):
        raise ValueError("coverage bounds exclude observed trades")

    def summarize_indices(indices: Sequence[int]) -> dict[str, Any]:
        return summarize_cost_rows(
            [all_native[index] for index in indices],
            [all_ftmo_rows[index] for index in indices],
            [all_conservative_rows[index] for index in indices],
        )

    calendar_years = [
        {
            "year": year,
            **summarize_indices(
                [index for index, trade in enumerate(all_trades) if trade.entry_time.year == year]
            ),
        }
        for year in sorted(candidate_years)
    ]
    per_symbol = {
        symbol: summarize_indices(
            [
                index
                for index, trade in enumerate(all_trades)
                if trade.symbol.upper() == symbol
            ]
        )
        for symbol in sorted(expected_symbols)
    }
    pooled = summarize_indices(list(range(len(all_trades))))
    costed_pf = pooled["ftmo_official_current_cost"]["profit_factor"]
    density_ok = bool(calendar_years) and all(
        row["native_deal_reconstruction"]["trades"] >= DEFAULT_MIN_TRADES_PER_YEAR
        for row in calendar_years
    )
    strict_pass = bool(
        density_ok and costed_pf is not None and costed_pf >= DEFAULT_Q02_PF_FLOOR
    )
    return {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "basis": "native_mt5_model4_multi_symbol_round_trips_recosted_per_ftmo_leg",
        "expected_symbols": sorted(expected_symbols),
        "cost_model": cost_spec,
        "gate": {
            "name": "strict_ftmo_q02_research_gate",
            "profit_factor_floor": DEFAULT_Q02_PF_FLOOR,
            "minimum_trades_per_year": DEFAULT_MIN_TRADES_PER_YEAR,
            "verdict": "PASS" if strict_pass else "FAIL",
        },
        "reports": reports,
        "calendar_years": calendar_years,
        "per_symbol": per_symbol,
        "pooled": pooled,
    }


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary", action="append", required=True, type=parse_summary_spec)
    parser.add_argument("--cost-spec", type=Path, required=True)
    parser.add_argument("--coverage-start-year", type=int)
    parser.add_argument("--coverage-end-year", type=int)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(list(argv) if argv is not None else None)

    cost_spec = json.loads(args.cost_spec.read_text(encoding="utf-8-sig"))
    artifact = evaluate_basket_reports(
        args.summary,
        cost_spec=cost_spec,
        coverage_start_year=args.coverage_start_year,
        coverage_end_year=args.coverage_end_year,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"out": str(args.out), "gate": artifact["gate"], "pooled": artifact["pooled"]}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
