from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Sequence

try:
    from .prop_challenge_optimizer import (
        _extract_report_stats,
        _normalize_cell,
        _parse_report_datetime,
        _parse_report_number,
        _report_rows,
    )
except ImportError:  # pragma: no cover - direct script execution
    from prop_challenge_optimizer import (  # type: ignore
        _extract_report_stats,
        _normalize_cell,
        _parse_report_datetime,
        _parse_report_number,
        _report_rows,
    )


DEFAULT_Q02_PF_FLOOR = 1.20
DEFAULT_MIN_TRADES_PER_YEAR = 5


@dataclass(frozen=True)
class RoundTrip:
    entry_time: dt.datetime
    exit_time: dt.datetime
    symbol: str
    side: str
    volume: float
    entry_price: float
    exit_price: float
    profit: float
    native_swap: float
    native_commission: float


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def extract_round_trips(
    report_path: Path,
    expected_symbol: str | None,
) -> tuple[list[RoundTrip], dict[str, Any]]:
    rows = _report_rows(report_path)
    report_stats = _extract_report_stats(rows)
    in_deals = False
    headers: list[str] = []
    open_entries: dict[tuple[str, str], list[dict[str, Any]]] = {}
    trades: list[RoundTrip] = []

    for row in rows:
        if len(row) == 1 and _normalize_cell(row[0]) == "deals":
            in_deals = True
            headers = []
            continue
        if not in_deals:
            continue
        if row and _normalize_cell(row[0]) == "time":
            headers = row
            continue
        if not headers or len(row) < len(headers):
            continue

        deal = dict(zip(headers, row))
        symbol = str(deal.get("Symbol") or "").strip()
        if not symbol:
            continue
        if expected_symbol is not None and symbol != expected_symbol:
            continue
        direction = _normalize_cell(str(deal.get("Direction") or ""))
        parsed = {
            "time": _parse_report_datetime(str(deal.get("Time") or "")),
            "symbol": symbol,
            "volume": _required_number(deal.get("Volume"), "Volume"),
            "price": _required_number(deal.get("Price"), "Price"),
            "commission": _parse_report_number(str(deal.get("Commission") or "0")) or 0.0,
            "swap": _parse_report_number(str(deal.get("Swap") or "0")) or 0.0,
            "profit": _parse_report_number(str(deal.get("Profit") or "0")) or 0.0,
        }

        if direction == "in":
            side = _normalize_cell(str(deal.get("Type") or ""))
            if side not in {"buy", "sell"}:
                raise ValueError(f"{report_path}: unsupported entry type {side!r}")
            parsed["side"] = side
            parsed["remaining_volume"] = float(parsed["volume"])
            open_entries.setdefault((symbol, side), []).append(parsed)
            continue
        if direction != "out":
            continue
        exit_type = _normalize_cell(str(deal.get("Type") or ""))
        entry_side = "buy" if exit_type == "sell" else "sell" if exit_type == "buy" else ""
        entry_key = (symbol, entry_side)
        if not entry_side or not open_entries.get(entry_key):
            raise ValueError(f"{report_path}: {exit_type} exit has no matching entry")
        try:
            trades.extend(_consume_exit_deal(open_entries[entry_key], parsed))
        except ValueError as exc:
            raise ValueError(f"{report_path}: {exc}") from exc

    remaining = sum(len(queue) for queue in open_entries.values())
    if remaining:
        raise ValueError(f"{report_path}: {remaining} entry deals remain open")
    if not trades:
        label = expected_symbol or "supported-symbol"
        raise ValueError(f"{report_path}: no {label} round trips")
    if report_stats.get("total_trades") != len(trades):
        raise ValueError(
            f"{report_path}: parsed {len(trades)} trades, native report says "
            f"{report_stats.get('total_trades')}"
        )
    return trades, report_stats


def _consume_exit_deal(
    entry_queue: list[dict[str, Any]],
    exit_deal: dict[str, Any],
) -> list[RoundTrip]:
    """FIFO-match one exit deal into report-counted close fragments."""
    exit_volume = float(exit_deal["volume"])
    if exit_volume <= 0.0:
        raise ValueError("exit volume must be positive")
    remaining_exit = exit_volume
    completed: list[RoundTrip] = []
    tolerance = 1e-8
    while remaining_exit > tolerance:
        if not entry_queue:
            raise ValueError(f"exit volume {exit_volume} exceeds open entry volume")
        entry = entry_queue[0]
        entry_remaining = float(entry.get("remaining_volume", entry["volume"]))
        matched_volume = min(entry_remaining, remaining_exit)
        exit_share = matched_volume / exit_volume

        entry_share = matched_volume / float(entry["volume"])
        entry["remaining_volume"] = entry_remaining - matched_volume
        remaining_exit -= matched_volume
        completed.append(
            RoundTrip(
                entry_time=entry["time"],
                exit_time=exit_deal["time"],
                symbol=str(entry["symbol"]),
                side=str(entry["side"]),
                volume=matched_volume,
                entry_price=float(entry["price"]),
                exit_price=float(exit_deal["price"]),
                profit=(
                    float(entry["profit"]) * entry_share
                    + float(exit_deal["profit"]) * exit_share
                ),
                native_swap=(
                    float(entry["swap"]) * entry_share
                    + float(exit_deal["swap"]) * exit_share
                ),
                native_commission=(
                    float(entry["commission"]) * entry_share
                    + float(exit_deal["commission"]) * exit_share
                ),
            )
        )
        if float(entry["remaining_volume"]) <= tolerance:
            entry_queue.pop(0)
    return completed


def _required_number(raw: Any, label: str) -> float:
    value = _parse_report_number(str(raw or ""))
    if value is None:
        raise ValueError(f"missing numeric deal field {label}: {raw!r}")
    return float(value)


def swap_rollover_units(entry_time: dt.datetime, exit_time: dt.datetime, triple_weekday: int = 2) -> int:
    """Return swap-day units for broker-wallclock timestamps.

    Weekday is the session date ending at each crossed midnight. Wednesday is
    three units by the common MT5 metals convention. Saturday and Sunday do not
    create new swap units.
    """
    if exit_time < entry_time:
        raise ValueError("exit_time must not precede entry_time")
    if exit_time == entry_time:
        return 0
    cursor = dt.datetime.combine(
        entry_time.date() + dt.timedelta(days=1),
        dt.time.min,
        tzinfo=entry_time.tzinfo,
    )
    units = 0
    while cursor <= exit_time:
        session_day = cursor.date() - dt.timedelta(days=1)
        if session_day.weekday() < 5:
            units += 3 if session_day.weekday() == triple_weekday else 1
        cursor += dt.timedelta(days=1)
    return units


def ftmo_trade_net(
    trade: RoundTrip,
    *,
    commission_rate_per_side: float,
    swap_long_points: float,
    swap_short_points: float | None,
    contract_size: float,
    digits: int,
    flat_round_trip_commission_per_lot: float = 0.0,
    source_contract_size: float | None = None,
    profit_currency_to_account_rate: float = 1.0,
    derive_profit_currency_rate_from_pnl: bool = False,
    triple_weekday: int = 2,
) -> tuple[float, float, float, int]:
    source_size = contract_size if source_contract_size is None else source_contract_size
    target_volume = trade.volume * source_size / contract_size
    account_rate = _profit_currency_rate(
        trade,
        source_contract_size=source_size,
        fallback_rate=profit_currency_to_account_rate,
        derive_from_pnl=derive_profit_currency_rate_from_pnl,
    )
    point_value_per_lot = contract_size * (10.0 ** -digits)
    rollover_units = swap_rollover_units(trade.entry_time, trade.exit_time, triple_weekday)
    commission = (
        (trade.entry_price + trade.exit_price)
        * contract_size
        * target_volume
        * commission_rate_per_side
        * account_rate
    ) + flat_round_trip_commission_per_lot * target_volume
    selected_swap_points = (
        swap_long_points
        if trade.side == "buy"
        else swap_long_points if swap_short_points is None else swap_short_points
    )
    swap = selected_swap_points * point_value_per_lot * target_volume * rollover_units * account_rate
    return trade.profit + swap - commission, commission, swap, rollover_units


def conservative_trade_net(
    trade: RoundTrip,
    *,
    round_trip_notional_rate: float,
    swap_long_points: float,
    swap_short_points: float | None,
    contract_size: float,
    digits: int,
    source_contract_size: float | None = None,
    profit_currency_to_account_rate: float = 1.0,
    derive_profit_currency_rate_from_pnl: bool = False,
    triple_weekday: int = 2,
) -> tuple[float, float, float, int]:
    source_size = contract_size if source_contract_size is None else source_contract_size
    target_volume = trade.volume * source_size / contract_size
    account_rate = _profit_currency_rate(
        trade,
        source_contract_size=source_size,
        fallback_rate=profit_currency_to_account_rate,
        derive_from_pnl=derive_profit_currency_rate_from_pnl,
    )
    point_value_per_lot = contract_size * (10.0 ** -digits)
    rollover_units = swap_rollover_units(trade.entry_time, trade.exit_time, triple_weekday)
    commission = (
        trade.entry_price
        * contract_size
        * target_volume
        * round_trip_notional_rate
        * account_rate
    )
    selected_swap_points = (
        swap_long_points
        if trade.side == "buy"
        else swap_long_points if swap_short_points is None else swap_short_points
    )
    swap = selected_swap_points * point_value_per_lot * target_volume * rollover_units * account_rate
    return trade.profit + swap - commission, commission, swap, rollover_units


def _profit_currency_rate(
    trade: RoundTrip,
    *,
    source_contract_size: float,
    fallback_rate: float,
    derive_from_pnl: bool,
) -> float:
    if source_contract_size <= 0.0:
        raise ValueError("source_contract_size must be positive")
    if fallback_rate <= 0.0:
        raise ValueError("profit_currency_to_account_rate must be positive")
    if not derive_from_pnl:
        return fallback_rate

    signed_move = (
        trade.exit_price - trade.entry_price
        if trade.side == "buy"
        else trade.entry_price - trade.exit_price
    )
    source_profit_currency_pnl = signed_move * source_contract_size * trade.volume
    if abs(source_profit_currency_pnl) <= 1e-12:
        return fallback_rate
    derived_rate = trade.profit / source_profit_currency_pnl
    if derived_rate <= 0.0:
        raise ValueError(
            "cannot derive a positive profit-currency conversion rate "
            f"from trade P/L ({trade.profit} / {source_profit_currency_pnl})"
        )
    return derived_rate


def summarize_nets(nets: Sequence[float]) -> dict[str, Any]:
    gross_profit = sum(value for value in nets if value > 0.0)
    gross_loss = sum(value for value in nets if value < 0.0)
    profit_factor = None if gross_loss == 0.0 else gross_profit / abs(gross_loss)
    balance = 0.0
    peak = 0.0
    max_drawdown = 0.0
    for value in nets:
        balance += value
        peak = max(peak, balance)
        max_drawdown = max(max_drawdown, peak - balance)
    return {
        "trades": len(nets),
        "net_profit": round(sum(nets), 2),
        "gross_profit": round(gross_profit, 2),
        "gross_loss": round(gross_loss, 2),
        "profit_factor": None if profit_factor is None else round(profit_factor, 6),
        "close_to_close_max_drawdown": round(max_drawdown, 2),
    }


def summarize_cost_rows(
    native_nets: Sequence[float],
    ftmo_rows: Sequence[tuple[float, float, float, int]],
    conservative_rows: Sequence[tuple[float, float, float, int]],
) -> dict[str, Any]:
    ftmo_nets = [row[0] for row in ftmo_rows]
    conservative_nets = [row[0] for row in conservative_rows]
    return {
        "native_deal_reconstruction": summarize_nets(native_nets),
        "ftmo_official_current_cost": {
            **summarize_nets(ftmo_nets),
            "commission_total": round(sum(row[1] for row in ftmo_rows), 2),
            "swap_total": round(sum(row[2] for row in ftmo_rows), 2),
            "swap_rollover_units": sum(row[3] for row in ftmo_rows),
        },
        "internal_conservative_current_swap": {
            **summarize_nets(conservative_nets),
            "commission_total": round(sum(row[1] for row in conservative_rows), 2),
            "swap_total": round(sum(row[2] for row in conservative_rows), 2),
            "swap_rollover_units": sum(row[3] for row in conservative_rows),
        },
    }


def report_period_years(period: str) -> set[int]:
    match = re.search(
        r"\((\d{4})\.\d{2}\.\d{2}\s+-\s+(\d{4})\.\d{2}\.\d{2}\)",
        period,
    )
    if not match:
        return set()
    start_year, end_year = (int(value) for value in match.groups())
    if end_year < start_year:
        raise ValueError(f"invalid report period: {period}")
    return set(range(start_year, end_year + 1))


def evaluate_reports(
    summary_specs: Sequence[tuple[int, Path]],
    *,
    expected_symbol: str,
    ftmo_commission_percent_per_side: float,
    ftmo_swap_long_points: float,
    ftmo_swap_short_points: float | None,
    contract_size: float,
    digits: int,
    ftmo_flat_round_trip_commission_per_lot: float = 0.0,
    source_contract_size: float | None = None,
    profit_currency_to_account_rate: float = 1.0,
    derive_profit_currency_rate_from_pnl: bool = False,
    internal_round_trip_notional_rate: float,
    triple_weekday: int = 2,
    coverage_start_year: int | None = None,
    coverage_end_year: int | None = None,
    source_metadata: dict[str, Any] | None = None,
) -> dict[str, Any]:
    if coverage_start_year is not None and coverage_end_year is not None:
        if coverage_end_year < coverage_start_year:
            raise ValueError("coverage_end_year must not precede coverage_start_year")
    all_native: list[float] = []
    all_ftmo: list[float] = []
    all_conservative: list[float] = []
    all_trades: list[RoundTrip] = []
    all_ftmo_rows: list[tuple[float, float, float, int]] = []
    all_conservative_rows: list[tuple[float, float, float, int]] = []
    period_years: set[int] = set()
    years: list[dict[str, Any]] = []
    ftmo_rate = ftmo_commission_percent_per_side / 100.0

    for year, summary_path in sorted(summary_specs):
        summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
        ok_runs = [run for run in summary.get("runs") or [] if str(run.get("status")).upper() == "OK"]
        if not ok_runs:
            raise ValueError(f"{summary_path}: no OK run")
        representative = ok_runs[0]
        report_path = Path(str(representative["report_canonical_path"]))
        trades, report_stats = extract_round_trips(report_path, expected_symbol)
        period_years.update(report_period_years(str(report_stats.get("period") or "")))

        native_nets = [trade.profit + trade.native_swap + trade.native_commission for trade in trades]
        ftmo_rows = [
            ftmo_trade_net(
                trade,
                commission_rate_per_side=ftmo_rate,
                flat_round_trip_commission_per_lot=ftmo_flat_round_trip_commission_per_lot,
                swap_long_points=ftmo_swap_long_points,
                swap_short_points=ftmo_swap_short_points,
                contract_size=contract_size,
                source_contract_size=source_contract_size,
                profit_currency_to_account_rate=profit_currency_to_account_rate,
                derive_profit_currency_rate_from_pnl=derive_profit_currency_rate_from_pnl,
                digits=digits,
                triple_weekday=triple_weekday,
            )
            for trade in trades
        ]
        conservative_rows = [
            conservative_trade_net(
                trade,
                round_trip_notional_rate=internal_round_trip_notional_rate,
                swap_long_points=ftmo_swap_long_points,
                swap_short_points=ftmo_swap_short_points,
                contract_size=contract_size,
                source_contract_size=source_contract_size,
                profit_currency_to_account_rate=profit_currency_to_account_rate,
                derive_profit_currency_rate_from_pnl=derive_profit_currency_rate_from_pnl,
                digits=digits,
                triple_weekday=triple_weekday,
            )
            for trade in trades
        ]
        ftmo_nets = [row[0] for row in ftmo_rows]
        conservative_nets = [row[0] for row in conservative_rows]
        all_native.extend(native_nets)
        all_ftmo.extend(ftmo_nets)
        all_conservative.extend(conservative_nets)
        all_trades.extend(trades)
        all_ftmo_rows.extend(ftmo_rows)
        all_conservative_rows.extend(conservative_rows)

        years.append(
            {
                "year": year,
                "summary_path": str(summary_path),
                "summary_sha256": file_sha256(summary_path),
                "report_path": str(report_path),
                "report_sha256": file_sha256(report_path),
                "deterministic_ok_run_count": len(ok_runs),
                "native_report": report_stats,
                **summarize_cost_rows(native_nets, ftmo_rows, conservative_rows),
            }
        )

    calendar_years: list[dict[str, Any]] = []
    observed_years = {trade.entry_time.year for trade in all_trades}
    candidate_years = period_years | observed_years
    if coverage_start_year is not None:
        candidate_years = {year for year in candidate_years if year >= coverage_start_year}
    if coverage_end_year is not None:
        candidate_years = {year for year in candidate_years if year <= coverage_end_year}
    excluded_observed_years = observed_years - candidate_years
    if excluded_observed_years:
        raise ValueError(
            "coverage bounds exclude observed trades in years: "
            + ", ".join(str(year) for year in sorted(excluded_observed_years))
        )
    for calendar_year in sorted(candidate_years):
        indices = [index for index, trade in enumerate(all_trades) if trade.entry_time.year == calendar_year]
        calendar_years.append(
            {
                "year": calendar_year,
                **summarize_cost_rows(
                    [all_native[index] for index in indices],
                    [all_ftmo_rows[index] for index in indices],
                    [all_conservative_rows[index] for index in indices],
                ),
            }
        )

    pooled = summarize_cost_rows(all_native, all_ftmo_rows, all_conservative_rows)
    min_trades_ok = bool(calendar_years) and all(
        row["native_deal_reconstruction"]["trades"] >= DEFAULT_MIN_TRADES_PER_YEAR
        for row in calendar_years
    )
    costed_pf = pooled["ftmo_official_current_cost"]["profit_factor"]
    strict_pass = bool(min_trades_ok and costed_pf is not None and costed_pf >= DEFAULT_Q02_PF_FLOOR)
    return {
        "schema_version": 2,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "basis": "native_mt5_model4_round_trips_recosted_to_ftmo_snapshot",
        "expected_symbol": expected_symbol,
        "cost_model": {
            "official_snapshot": source_metadata or {},
            "ftmo_commission_percent_per_side": ftmo_commission_percent_per_side,
            "ftmo_flat_round_trip_commission_per_lot": ftmo_flat_round_trip_commission_per_lot,
            "ftmo_swap_long_points": ftmo_swap_long_points,
            "ftmo_swap_short_points": ftmo_swap_short_points,
            "source_contract_size": contract_size if source_contract_size is None else source_contract_size,
            "contract_size": contract_size,
            "equivalent_volume_basis": "source_volume_x_source_contract_size_divided_by_ftmo_contract_size",
            "profit_currency_to_account_rate": profit_currency_to_account_rate,
            "derive_profit_currency_rate_from_pnl": derive_profit_currency_rate_from_pnl,
            "digits": digits,
            "point_value_per_lot": contract_size * (10.0 ** -digits),
            "triple_swap_weekday": triple_weekday,
            "internal_round_trip_notional_rate": internal_round_trip_notional_rate,
            "data_coverage_start_year": coverage_start_year,
            "data_coverage_end_year": coverage_end_year,
            "spread_basis": "native MT5 bid/ask ticks already included",
            "swap_basis": "current FTMO snapshot applied to every historical rollover; deployment-cost stress, not historical swap reconstruction",
        },
        "gate": {
            "name": "strict_ftmo_q02_research_gate",
            "profit_factor_floor": DEFAULT_Q02_PF_FLOOR,
            "minimum_trades_per_year": DEFAULT_MIN_TRADES_PER_YEAR,
            "verdict": "PASS" if strict_pass else "FAIL",
        },
        "years": years,
        "calendar_years": calendar_years,
        "pooled": pooled,
    }


def parse_summary_spec(raw: str) -> tuple[int, Path]:
    year_raw, separator, path_raw = raw.partition("=")
    if not separator:
        raise argparse.ArgumentTypeError("summary must be YEAR=PATH")
    try:
        year = int(year_raw)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"invalid year: {year_raw}") from exc
    path = Path(path_raw)
    if not path.exists():
        raise argparse.ArgumentTypeError(f"summary does not exist: {path}")
    return year, path


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Re-cost native MT5 round trips to an FTMO symbol snapshot")
    parser.add_argument("--summary", action="append", required=True, type=parse_summary_spec)
    parser.add_argument("--symbol", required=True)
    parser.add_argument("--commission-percent-per-side", required=True, type=float)
    parser.add_argument("--flat-round-trip-commission-per-lot", type=float, default=0.0)
    parser.add_argument("--swap-long-points", required=True, type=float)
    parser.add_argument("--swap-short-points", type=float)
    parser.add_argument("--contract-size", required=True, type=float)
    parser.add_argument("--source-contract-size", type=float)
    parser.add_argument("--profit-currency-to-account-rate", type=float, default=1.0)
    parser.add_argument("--derive-profit-currency-rate-from-pnl", action="store_true")
    parser.add_argument("--digits", required=True, type=int)
    parser.add_argument("--internal-round-trip-notional-rate", type=float, default=0.00005)
    parser.add_argument("--triple-weekday", type=int, default=2)
    parser.add_argument("--coverage-start-year", type=int)
    parser.add_argument("--coverage-end-year", type=int)
    parser.add_argument("--snapshot-date", required=True)
    parser.add_argument("--source-url", default="https://ftmo.com/wp-json/ftmo/symbols")
    parser.add_argument("--source-page-url", default="https://ftmo.com/en/symbols/")
    parser.add_argument("--ftmo-symbol-code")
    parser.add_argument("--commission-type", default="percent")
    parser.add_argument("--swap-type", default="points")
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args(list(argv) if argv is not None else None)

    artifact = evaluate_reports(
        args.summary,
        expected_symbol=args.symbol,
        ftmo_commission_percent_per_side=args.commission_percent_per_side,
        ftmo_flat_round_trip_commission_per_lot=args.flat_round_trip_commission_per_lot,
        ftmo_swap_long_points=args.swap_long_points,
        ftmo_swap_short_points=args.swap_short_points,
        contract_size=args.contract_size,
        source_contract_size=args.source_contract_size,
        profit_currency_to_account_rate=args.profit_currency_to_account_rate,
        derive_profit_currency_rate_from_pnl=args.derive_profit_currency_rate_from_pnl,
        digits=args.digits,
        internal_round_trip_notional_rate=args.internal_round_trip_notional_rate,
        triple_weekday=args.triple_weekday,
        coverage_start_year=args.coverage_start_year,
        coverage_end_year=args.coverage_end_year,
        source_metadata={
            "as_of": args.snapshot_date,
            "api_url": args.source_url,
            "page_url": args.source_page_url,
            "symbol_code": args.ftmo_symbol_code or args.symbol,
            "commission_type": args.commission_type,
            "swap_type": args.swap_type,
        },
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, default=str) + "\n", encoding="utf-8")
    print(json.dumps({"out": str(args.out), "gate": artifact["gate"], "pooled": artifact["pooled"]}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
