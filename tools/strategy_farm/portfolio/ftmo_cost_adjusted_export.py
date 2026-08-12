#!/usr/bin/env python3
"""Convert sealed Darwinex Q08 lifecycles to FTMO-cost-adjusted daily rows.

Darwinex execution prices remain the execution evidence.  Source commission
and swap are removed, exact pinned FTMO commission/swap terms are inserted,
and the hash-bound calibrated FTMO-minus-DXZ spread delta is charged on both
trade sides.  The resulting evidence class is explicitly weaker than native
FTMO execution and is never emitted from a legacy/incomplete Q08 row.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping, Sequence
from zoneinfo import ZoneInfo

try:
    from .ftmo_daily_net_export import (
        PINNED_COST_SNAPSHOT_SHA256,
        FtmoDailyExportError,
        _atomic_write,
        _cost_term,
        binding,
        sha256_file,
    )
    from .ftmo_report_cost_reconcile import (
        RoundTrip,
        ftmo_trade_commission_sides,
        ftmo_trade_net,
    )
    from .ftmo_spread_calibration import ARTIFACT_SCHEMA as CALIBRATION_SCHEMA
    from .ftmo_spread_calibration import _bucket_name
    from .ftmo_stream_reconciliation import strict_json_loads
except ImportError:  # pragma: no cover - direct script execution
    from ftmo_daily_net_export import (  # type: ignore
        PINNED_COST_SNAPSHOT_SHA256,
        FtmoDailyExportError,
        _atomic_write,
        _cost_term,
        binding,
        sha256_file,
    )
    from ftmo_report_cost_reconcile import (  # type: ignore
        RoundTrip,
        ftmo_trade_commission_sides,
        ftmo_trade_net,
    )
    from ftmo_spread_calibration import ARTIFACT_SCHEMA as CALIBRATION_SCHEMA  # type: ignore
    from ftmo_spread_calibration import _bucket_name  # type: ignore
    from ftmo_stream_reconciliation import strict_json_loads  # type: ignore


EVIDENCE_CLASS = "DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1"
RECEIPT_SCHEMA = "qm.ftmo-cost-adjusted-export-receipt/v1"
MONEY_BASIS = "FULL_POSITION_LIFECYCLE_ACTUAL_V1"
PRAGUE = ZoneInfo("Europe/Prague")
COMPONENT_TOLERANCE = 0.021
MAX_ROWS = 2_000_000


class CostAdjustedExportError(ValueError):
    """The bound inputs cannot support the OWNER-authorized evidence class."""


@dataclass(frozen=True)
class SourceTrade:
    row_id: str
    side: str
    entry_utc: dt.datetime
    exit_utc: dt.datetime
    entry_price: float
    exit_price: float
    mae_acct: float
    net: float
    profit: float
    swap: float
    fee: float
    commission: float
    entry_commission: float
    exit_commission: float
    volume: float
    notional: float
    source_symbol: str


@dataclass(frozen=True)
class AdjustedTrade:
    source: SourceTrade
    source_contract_size: float
    target_volume: float
    account_rate: float
    ftmo_entry_commission_charge: float
    ftmo_exit_commission_charge: float
    ftmo_swap_cash: float
    spread_entry_charge_cash: float
    spread_exit_charge_cash: float


def _finite(value: Any, label: str) -> float:
    if isinstance(value, bool):
        raise CostAdjustedExportError(f"{label}: boolean is not numeric")
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise CostAdjustedExportError(f"{label}: expected finite number") from exc
    if not math.isfinite(number):
        raise CostAdjustedExportError(f"{label}: expected finite number")
    return number


def _parse_utc(value: Any, label: str) -> dt.datetime:
    if isinstance(value, bool):
        raise CostAdjustedExportError(f"{label}: invalid timestamp")
    if isinstance(value, (int, float)):
        try:
            return dt.datetime.fromtimestamp(_finite(value, label), tz=dt.UTC)
        except (OverflowError, OSError, ValueError) as exc:
            raise CostAdjustedExportError(f"{label}: invalid epoch timestamp") from exc
    token = str(value or "").strip()
    try:
        parsed = dt.datetime.fromisoformat(token.replace("Z", "+00:00"))
    except ValueError as exc:
        raise CostAdjustedExportError(f"{label}: invalid UTC timestamp") from exc
    if parsed.tzinfo is None or parsed.utcoffset() != dt.timedelta(0):
        raise CostAdjustedExportError(f"{label}: timestamp must be explicit UTC")
    return parsed.astimezone(dt.UTC)


def _load_q08(path: Path, *, source_symbol: str, sleeve_id: str) -> list[SourceTrade]:
    required = {
        "event",
        "money_basis",
        "magic",
        "side",
        "entry_price",
        "exit_price",
        "time",
        "entry_time",
        "mae_acct",
        "net",
        "profit",
        "swap",
        "fee",
        "commission",
        "entry_commission",
        "exit_commission",
        "volume",
        "notional",
        "symbol",
    }
    trades: list[SourceTrade] = []
    try:
        with path.open(encoding="utf-8", errors="strict") as handle:
            for line_number, line in enumerate(handle, 1):
                if line_number > MAX_ROWS:
                    raise CostAdjustedExportError("Q08 stream exceeds row limit")
                if not line.strip():
                    raise CostAdjustedExportError(f"Q08:{line_number}: blank row")
                try:
                    row = strict_json_loads(line, label=f"Q08:{line_number}")
                except (json.JSONDecodeError, ValueError) as exc:
                    raise CostAdjustedExportError(f"Q08:{line_number}: invalid JSON: {exc}") from exc
                if not isinstance(row, Mapping) or set(row) != required:
                    missing = sorted(required - set(row)) if isinstance(row, Mapping) else sorted(required)
                    extra = sorted(set(row) - required) if isinstance(row, Mapping) else []
                    raise CostAdjustedExportError(
                        f"Q08:{line_number}: exact full-lifecycle fields required; "
                        f"missing={','.join(missing) or '-'} extra={','.join(extra) or '-'}"
                    )
                if row["event"] != "TRADE_CLOSED" or row["money_basis"] != MONEY_BASIS:
                    raise CostAdjustedExportError(f"Q08:{line_number}: event/money basis mismatch")
                if row["symbol"] != source_symbol:
                    raise CostAdjustedExportError(f"Q08:{line_number}: source symbol mismatch")
                side = str(row["side"]).strip().lower()
                if side not in {"buy", "sell"}:
                    raise CostAdjustedExportError(f"Q08:{line_number}: invalid side")
                values = {
                    key: _finite(row[key], f"Q08:{line_number}.{key}")
                    for key in (
                        "entry_price",
                        "exit_price",
                        "mae_acct",
                        "net",
                        "profit",
                        "swap",
                        "fee",
                        "commission",
                        "entry_commission",
                        "exit_commission",
                        "volume",
                        "notional",
                    )
                }
                if any(values[key] <= 0.0 for key in ("entry_price", "exit_price", "volume", "notional")):
                    raise CostAdjustedExportError(f"Q08:{line_number}: non-positive price/volume/notional")
                reconciled = values["profit"] + values["swap"] + values["fee"] + values["commission"]
                if abs(values["net"] - reconciled) > COMPONENT_TOLERANCE:
                    raise CostAdjustedExportError(f"Q08:{line_number}: source net components do not reconcile")
                if abs(
                    values["commission"] - values["entry_commission"] - values["exit_commission"]
                ) > COMPONENT_TOLERANCE:
                    raise CostAdjustedExportError(f"Q08:{line_number}: source commission split mismatch")
                entry = _parse_utc(row["entry_time"], f"Q08:{line_number}.entry_time")
                exit_time = _parse_utc(row["time"], f"Q08:{line_number}.time")
                if exit_time <= entry:
                    raise CostAdjustedExportError(f"Q08:{line_number}: non-positive lifecycle")
                trades.append(
                    SourceTrade(
                        row_id=f"{sleeve_id}:{line_number}",
                        side=side,
                        entry_utc=entry,
                        exit_utc=exit_time,
                        entry_price=values["entry_price"],
                        exit_price=values["exit_price"],
                        mae_acct=values["mae_acct"],
                        net=values["net"],
                        profit=values["profit"],
                        swap=values["swap"],
                        fee=values["fee"],
                        commission=values["commission"],
                        entry_commission=values["entry_commission"],
                        exit_commission=values["exit_commission"],
                        volume=values["volume"],
                        notional=values["notional"],
                        source_symbol=source_symbol,
                    )
                )
    except (OSError, UnicodeError) as exc:
        raise CostAdjustedExportError(f"cannot read Q08 stream: {exc}") from exc
    if not trades:
        raise CostAdjustedExportError("Q08 stream is empty")
    return trades


def _load_calibration(
    path: Path,
    *,
    expected_sha256: str,
    evaluator_symbol: str,
    native_symbol: str,
    source_symbol: str,
) -> tuple[dict[str, Any], dict[str, float], int, str]:
    actual_sha = sha256_file(path)
    if actual_sha != expected_sha256:
        raise CostAdjustedExportError(
            f"calibration SHA-256 mismatch expected={expected_sha256} actual={actual_sha}"
        )
    try:
        artifact = strict_json_loads(path.read_text(encoding="utf-8-sig"), label="calibration")
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
        raise CostAdjustedExportError(f"invalid calibration artifact: {exc}") from exc
    if (
        not isinstance(artifact, Mapping)
        or artifact.get("schema") != CALIBRATION_SCHEMA
        or artifact.get("status") != "PASS"
        or artifact.get("evidence_class") != EVIDENCE_CLASS
    ):
        raise CostAdjustedExportError("calibration artifact is not a PASS for this evidence class")
    matches = [
        pair
        for pair in artifact.get("pairs", [])
        if isinstance(pair, Mapping) and pair.get("evaluator_symbol") == evaluator_symbol
    ]
    if len(matches) != 1:
        raise CostAdjustedExportError("calibration pair is absent or ambiguous")
    pair = dict(matches[0])
    if pair.get("ftmo_symbol") != native_symbol or pair.get("dxz_symbol") != source_symbol:
        raise CostAdjustedExportError("calibration pair would extrapolate across symbols")
    bucket_minutes = artifact.get("session_bucket_minutes")
    if isinstance(bucket_minutes, bool) or not isinstance(bucket_minutes, int) or bucket_minutes <= 0:
        raise CostAdjustedExportError("calibration session bucket contract is invalid")
    buckets: dict[str, float] = {}
    for index, bucket in enumerate(pair.get("session_buckets", [])):
        if not isinstance(bucket, Mapping):
            raise CostAdjustedExportError(f"calibration bucket {index} is invalid")
        name = str(bucket.get("bucket_utc") or "")
        charge = _finite(
            bucket.get("conservative_delta_price_per_side"),
            f"calibration.session_buckets[{index}].charge",
        )
        if not name or charge < 0.0 or name in buckets:
            raise CostAdjustedExportError(f"calibration bucket {index} is invalid/duplicate")
        buckets[name] = charge
    if not buckets:
        raise CostAdjustedExportError("calibration has no admissible session buckets")
    return pair, buckets, bucket_minutes, actual_sha


def _source_contract_size(trade: SourceTrade) -> float:
    size = trade.notional / (trade.entry_price * trade.volume)
    if not math.isfinite(size) or size <= 0.0:
        raise CostAdjustedExportError(f"{trade.row_id}: cannot derive source contract size")
    reconstructed = trade.entry_price * trade.volume * size
    if not math.isclose(reconstructed, trade.notional, rel_tol=0.0, abs_tol=0.02):
        raise CostAdjustedExportError(f"{trade.row_id}: source notional does not reconcile")
    return size


def _account_rate(trade: SourceTrade, source_contract_size: float, profit_currency: str) -> float:
    if profit_currency.upper() == "USD":
        return 1.0
    signed_move = (
        trade.exit_price - trade.entry_price
        if trade.side == "buy"
        else trade.entry_price - trade.exit_price
    )
    source_currency_pnl = signed_move * source_contract_size * trade.volume
    if abs(source_currency_pnl) <= 1e-12:
        raise CostAdjustedExportError(
            f"{trade.row_id}: cannot derive profit-currency conversion from a flat trade"
        )
    rate = trade.profit / source_currency_pnl
    if not math.isfinite(rate) or rate <= 0.0:
        raise CostAdjustedExportError(
            f"{trade.row_id}: derived profit-currency conversion is not positive"
        )
    return rate


def _adjust_trade(
    trade: SourceTrade,
    *,
    term: Mapping[str, Any],
    buckets: Mapping[str, float],
    bucket_minutes: int,
) -> AdjustedTrade:
    source_size = _source_contract_size(trade)
    target_contract = _finite(term["contractSize"], "FTMO.contractSize")
    target_volume = trade.volume * source_size / target_contract
    account_rate = _account_rate(trade, source_size, str(term["profitCurrency"]))
    round_trip = RoundTrip(
        entry_time=trade.entry_utc,
        exit_time=trade.exit_utc,
        symbol=trade.source_symbol,
        side=trade.side,
        volume=trade.volume,
        entry_price=trade.entry_price,
        exit_price=trade.exit_price,
        profit=trade.profit,
        native_swap=trade.swap,
        native_commission=trade.commission,
        native_entry_commission=trade.entry_commission,
        native_exit_commission=trade.exit_commission,
    )
    commission_rate = _finite(term["commission"], "FTMO.commission") / 100.0
    try:
        entry_commission, exit_commission = ftmo_trade_commission_sides(
            round_trip,
            commission_rate_per_side=commission_rate,
            contract_size=target_contract,
            source_contract_size=source_size,
            profit_currency_to_account_rate=account_rate,
        )
        _net, reconciled_commission, swap_cash, _rollovers = ftmo_trade_net(
            round_trip,
            commission_rate_per_side=commission_rate,
            swap_long_points=_finite(term["swapLong"], "FTMO.swapLong"),
            swap_short_points=_finite(term["swapShort"], "FTMO.swapShort"),
            contract_size=target_contract,
            digits=int(_finite(term["digits"], "FTMO.digits")),
            source_contract_size=source_size,
            profit_currency_to_account_rate=account_rate,
        )
    except ValueError as exc:
        raise CostAdjustedExportError(f"{trade.row_id}: cannot apply FTMO terms: {exc}") from exc
    if not math.isclose(
        reconciled_commission,
        entry_commission + exit_commission,
        rel_tol=0.0,
        abs_tol=1e-9,
    ):
        raise CostAdjustedExportError(f"{trade.row_id}: FTMO commission helper mismatch")
    entry_bucket = _bucket_name(trade.entry_utc, bucket_minutes)
    exit_bucket = _bucket_name(trade.exit_utc, bucket_minutes)
    if entry_bucket not in buckets or exit_bucket not in buckets:
        raise CostAdjustedExportError(
            f"{trade.row_id}: calibration lacks entry/exit session bucket "
            f"{entry_bucket}/{exit_bucket}"
        )
    cash_per_price = target_contract * target_volume * account_rate
    return AdjustedTrade(
        source=trade,
        source_contract_size=source_size,
        target_volume=target_volume,
        account_rate=account_rate,
        ftmo_entry_commission_charge=entry_commission,
        ftmo_exit_commission_charge=exit_commission,
        ftmo_swap_cash=swap_cash,
        spread_entry_charge_cash=buckets[entry_bucket] * cash_per_price,
        spread_exit_charge_cash=buckets[exit_bucket] * cash_per_price,
    )


def _date_range(first: dt.date, last: dt.date) -> Sequence[dt.date]:
    return [first + dt.timedelta(days=index) for index in range((last - first).days + 1)]


def _daily_rows(
    trades: Sequence[AdjustedTrade],
    *,
    sleeve_id: str,
    evaluator_symbol: str,
    first_day: dt.date,
    last_day: dt.date,
    initial_equity: float,
    cost_sha256: str,
    calibration_sha256: str,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    events: dict[dt.date, list[tuple[dt.datetime, int, str]]] = defaultdict(list)
    by_id = {trade.source.row_id: trade for trade in trades}
    if len(by_id) != len(trades):
        raise CostAdjustedExportError("duplicate Q08 trade identity")
    for trade in trades:
        entry_day = trade.source.entry_utc.astimezone(PRAGUE).date()
        exit_day = trade.source.exit_utc.astimezone(PRAGUE).date()
        if entry_day < first_day or exit_day > last_day:
            raise CostAdjustedExportError(
                f"{trade.source.row_id}: lifecycle outside declared coverage"
            )
        events[entry_day].append((trade.source.entry_utc, 1, trade.source.row_id))
        events[exit_day].append((trade.source.exit_utc, 0, trade.source.row_id))

    active: dict[str, AdjustedTrade] = {}
    rows: list[dict[str, Any]] = []
    running_balance = initial_equity
    for day in _date_range(first_day, last_day):
        pre_spread_net = 0.0
        spread_charge = 0.0
        trade_opens = 0
        decomposition = {
            "source_profit_cash": 0.0,
            "source_fee_cash": 0.0,
            "source_commission_removed_cash": 0.0,
            "source_swap_removed_cash": 0.0,
            "ftmo_entry_commission_cash": 0.0,
            "ftmo_exit_commission_cash": 0.0,
            "ftmo_swap_cash": 0.0,
        }

        def candidate() -> dict[str, float]:
            active_mae = sum(
                trade.source.mae_acct + min(0.0, trade.ftmo_swap_cash)
                for trade in active.values()
            )
            remaining_spread = sum(
                trade.spread_exit_charge_cash for trade in active.values()
            )
            return {
                "pre_spread_cash": round(min(0.0, pre_spread_net + active_mae), 12),
                "calibrated_spread_charge_cash": round(spread_charge + remaining_spread, 12),
            }

        candidates = [candidate()]
        for _timestamp, event_order, row_id in sorted(
            events.get(day, []), key=lambda item: (item[0], item[1], item[2])
        ):
            trade = by_id[row_id]
            if event_order == 0:
                if row_id not in active:
                    raise CostAdjustedExportError(f"{row_id}: close without active lifecycle")
                active.pop(row_id)
                close_pre_spread = (
                    trade.source.profit
                    + trade.source.fee
                    + trade.ftmo_swap_cash
                    - trade.ftmo_exit_commission_charge
                )
                pre_spread_net += close_pre_spread
                spread_charge += trade.spread_exit_charge_cash
                decomposition["source_profit_cash"] += trade.source.profit
                decomposition["source_fee_cash"] += trade.source.fee
                decomposition["source_commission_removed_cash"] += -trade.source.commission
                decomposition["source_swap_removed_cash"] += -trade.source.swap
                decomposition["ftmo_exit_commission_cash"] += -trade.ftmo_exit_commission_charge
                decomposition["ftmo_swap_cash"] += trade.ftmo_swap_cash
            else:
                if row_id in active:
                    raise CostAdjustedExportError(f"{row_id}: duplicate open")
                active[row_id] = trade
                trade_opens += 1
                pre_spread_net -= trade.ftmo_entry_commission_charge
                spread_charge += trade.spread_entry_charge_cash
                decomposition["ftmo_entry_commission_cash"] += -trade.ftmo_entry_commission_charge
            candidates.append(candidate())

        adjusted_net = pre_spread_net - spread_charge
        if running_balance <= 0.0 or running_balance + adjusted_net <= 0.0:
            raise CostAdjustedExportError(f"{day}: adjusted equity is non-positive")
        low_at_one = min(
            item["pre_spread_cash"] - item["calibrated_spread_charge_cash"]
            for item in candidates
        )
        low_at_one = min(low_at_one, 0.0, adjusted_net)
        decomposition.update(
            {
                "pre_spread_net_cash": round(pre_spread_net, 12),
                "calibrated_spread_delta_cash": round(-spread_charge, 12),
                "adjusted_net_cash": round(adjusted_net, 12),
            }
        )
        rows.append(
            {
                "schema": EVIDENCE_CLASS,
                "evidence_class": EVIDENCE_CLASS,
                "sleeve_id": sleeve_id,
                "symbol": evaluator_symbol,
                "date": day.isoformat(),
                "initial_equity": initial_equity,
                "pre_spread_net_cash": round(pre_spread_net, 12),
                "calibrated_spread_charge_cash": round(spread_charge, 12),
                "intraday_candidates": candidates,
                "net_return": round(adjusted_net / running_balance, 12),
                "intraday_low_return": round(low_at_one / running_balance, 12),
                "trade_count": trade_opens,
                "eligible_start": day.weekday() < 5,
                "flat_at_end": not active,
                "cost_snapshot_sha256": cost_sha256,
                "calibration_sha256": calibration_sha256,
                "cost_decomposition": {
                    key: round(value, 12) for key, value in decomposition.items()
                },
            }
        )
        running_balance += adjusted_net
    if active:
        raise CostAdjustedExportError("declared coverage ends with open lifecycles")
    if sum(row["trade_count"] for row in rows) != len(trades):
        raise CostAdjustedExportError("daily trade counts do not reconcile")
    return rows, {
        "calendar_days": len(rows),
        "first_date": first_day.isoformat(),
        "last_date": last_day.isoformat(),
        "initial_equity": initial_equity,
        "final_equity_at_calibrated_charge": running_balance,
        "trade_count": len(trades),
        "intraday_contract": "EVENT_CANDIDATES_REEVALUATED_AT_EACH_SPREAD_MULTIPLIER",
    }


def export_cost_adjusted_stream(
    *,
    sleeve_id: str,
    evaluator_symbol: str,
    source_symbol: str,
    native_symbol: str,
    ftmo_code: str,
    q08_path: Path,
    cost_snapshot_path: Path,
    calibration_path: Path,
    expected_calibration_sha256: str,
    first_day: dt.date,
    last_day: dt.date,
    initial_equity: float,
    output_path: Path,
    receipt_path: Path,
    replace: bool = False,
    expected_cost_sha256: str = PINNED_COST_SNAPSHOT_SHA256,
) -> dict[str, Any]:
    if not all((sleeve_id, evaluator_symbol, source_symbol, native_symbol, ftmo_code)):
        raise CostAdjustedExportError("sleeve and symbol identities must be non-empty")
    if last_day < first_day:
        raise CostAdjustedExportError("coverage end precedes start")
    initial_equity = _finite(initial_equity, "initial_equity")
    if initial_equity <= 0.0:
        raise CostAdjustedExportError("initial_equity must be positive")
    paths = {
        "q08_trades": q08_path.expanduser().resolve(),
        "cost_snapshot": cost_snapshot_path.expanduser().resolve(),
        "calibration": calibration_path.expanduser().resolve(),
    }
    output_path = output_path.expanduser().resolve()
    receipt_path = receipt_path.expanduser().resolve()
    if output_path == receipt_path or output_path in paths.values() or receipt_path in paths.values():
        raise CostAdjustedExportError("output paths alias each other or an input")
    input_bindings = {name: binding(path) for name, path in paths.items()}
    try:
        term, cost_sha = _cost_term(
            paths["cost_snapshot"], ftmo_code=ftmo_code, expected_sha256=expected_cost_sha256
        )
    except FtmoDailyExportError as exc:
        raise CostAdjustedExportError(str(exc)) from exc
    pair, buckets, bucket_minutes, calibration_sha = _load_calibration(
        paths["calibration"],
        expected_sha256=expected_calibration_sha256,
        evaluator_symbol=evaluator_symbol,
        native_symbol=native_symbol,
        source_symbol=source_symbol,
    )
    trades = _load_q08(paths["q08_trades"], source_symbol=source_symbol, sleeve_id=sleeve_id)
    adjusted = [
        _adjust_trade(trade, term=term, buckets=buckets, bucket_minutes=bucket_minutes)
        for trade in trades
    ]
    rows, construction = _daily_rows(
        adjusted,
        sleeve_id=sleeve_id,
        evaluator_symbol=evaluator_symbol,
        first_day=first_day,
        last_day=last_day,
        initial_equity=initial_equity,
        cost_sha256=cost_sha,
        calibration_sha256=calibration_sha,
    )
    output_text = "".join(
        json.dumps(row, ensure_ascii=False, allow_nan=False, sort_keys=True) + "\n"
        for row in rows
    )
    try:
        _atomic_write(output_path, output_text, replace=replace)
    except FtmoDailyExportError as exc:
        raise CostAdjustedExportError(str(exc)) from exc
    output_binding = binding(output_path)
    receipt = {
        "schema": RECEIPT_SCHEMA,
        "status": "PASS",
        "claim": "HISTORICAL_DIAGNOSTIC_NOT_SELECTION_SEALED",
        "evidence_class": EVIDENCE_CLASS,
        "execution_venue": "DARWINEX_ZERO",
        "target_cost_venue": "FTMO",
        "native_ftmo_execution_claim": False,
        "sleeve_id": sleeve_id,
        "evaluator_symbol": evaluator_symbol,
        "source_symbol": source_symbol,
        "native_symbol": native_symbol,
        "ftmo_code": ftmo_code,
        "cost_snapshot_sha256": cost_sha,
        "calibration_sha256": calibration_sha,
        "calibration_pair": pair,
        "cost_term": term,
        "construction": construction,
        "totals": {
            "source_commission_removed_cash": sum(-trade.source.commission for trade in adjusted),
            "source_swap_removed_cash": sum(-trade.source.swap for trade in adjusted),
            "ftmo_commission_inserted_cash": -sum(
                trade.ftmo_entry_commission_charge + trade.ftmo_exit_commission_charge
                for trade in adjusted
            ),
            "ftmo_swap_inserted_cash": sum(trade.ftmo_swap_cash for trade in adjusted),
            "calibrated_spread_delta_cash": -sum(
                trade.spread_entry_charge_cash + trade.spread_exit_charge_cash
                for trade in adjusted
            ),
        },
        "inputs": input_bindings,
        "output": output_binding,
    }
    receipt_text = json.dumps(
        receipt, ensure_ascii=False, allow_nan=False, indent=2, sort_keys=True
    ) + "\n"
    try:
        _atomic_write(receipt_path, receipt_text, replace=replace)
    except Exception:
        try:
            output_path.unlink()
        except OSError:
            pass
        raise
    return receipt


def _date(value: str) -> dt.date:
    try:
        return dt.date.fromisoformat(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("expected YYYY-MM-DD") from exc


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sleeve-id", required=True)
    parser.add_argument("--symbol", required=True, help="evaluator symbol")
    parser.add_argument("--source-symbol", required=True, help="Darwinex Q08 symbol")
    parser.add_argument("--native-symbol", required=True, help="FTMO native symbol")
    parser.add_argument("--ftmo-code", required=True)
    parser.add_argument("--q08-trades", required=True, type=Path)
    parser.add_argument("--cost-snapshot", required=True, type=Path)
    parser.add_argument("--calibration", required=True, type=Path)
    parser.add_argument("--expected-calibration-sha256", required=True)
    parser.add_argument("--from-date", required=True, type=_date)
    parser.add_argument("--to-date", required=True, type=_date)
    parser.add_argument("--initial-equity", required=True, type=float)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--receipt-out", required=True, type=Path)
    parser.add_argument("--replace", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        receipt = export_cost_adjusted_stream(
            sleeve_id=args.sleeve_id,
            evaluator_symbol=args.symbol,
            source_symbol=args.source_symbol,
            native_symbol=args.native_symbol,
            ftmo_code=args.ftmo_code,
            q08_path=args.q08_trades,
            cost_snapshot_path=args.cost_snapshot,
            calibration_path=args.calibration,
            expected_calibration_sha256=args.expected_calibration_sha256,
            first_day=args.from_date,
            last_day=args.to_date,
            initial_equity=args.initial_equity,
            output_path=args.out,
            receipt_path=args.receipt_out,
            replace=args.replace,
        )
        print(
            json.dumps(
                {
                    "status": "PASS",
                    "evidence_class": EVIDENCE_CLASS,
                    "stream": receipt["output"],
                    "receipt": binding(args.receipt_out),
                }
            )
        )
        return 0
    except (CostAdjustedExportError, FtmoDailyExportError) as exc:
        print(json.dumps({"status": "REFUSED", "evidence_class": EVIDENCE_CLASS, "error": str(exc)}))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
