from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import os
import re
import statistics
import sys
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, Iterable, Sequence


SCHEMA_VERSION = 3
DXZ_ROUND_TRIP_NOTIONAL_RATE = 0.00005
DXZ_ROUND_TRIP_NOTIONAL_PERCENT = 0.005
DXZ_ROUND_TRIP_NOTIONAL_BASIS_POINTS = 0.5
MONEY_ROUNDING_HALF_WIDTH = 0.005
FLOAT_TOLERANCE = 1e-12
OFFICIAL_COST_SOURCE = "https://help.darwinex.com/execution-costs"
OFFICIAL_ZERO_COST_SOURCE = (
    "https://www.darwinexzero.com/docs/cs/profit-loss-trade-commodities"
)


class CostEvidenceError(RuntimeError):
    """Raised when evidence cannot be bound or evaluated safely."""


class _HtmlTableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.rows: list[list[str]] = []
        self._row: list[str] | None = None
        self._in_cell = False
        self._cell_parts: list[str] = []

    def handle_starttag(
        self, tag: str, attrs: list[tuple[str, str | None]]
    ) -> None:
        del attrs
        tag = tag.lower()
        if tag == "tr":
            self._row = []
        elif tag in {"td", "th"} and self._row is not None:
            self._in_cell = True
            self._cell_parts = []

    def handle_data(self, data: str) -> None:
        if self._in_cell:
            self._cell_parts.append(data)

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        if tag in {"td", "th"} and self._row is not None and self._in_cell:
            self._row.append(" ".join("".join(self._cell_parts).split()))
            self._in_cell = False
            self._cell_parts = []
        elif tag == "tr" and self._row is not None:
            self.rows.append(self._row)
            self._row = None


@dataclass(frozen=True)
class RoundTrip:
    entry_time: str
    exit_time: str
    entry_deal: str
    exit_deal: str
    symbol: str
    side: str
    volume: float
    entry_price: float
    exit_price: float
    gross_pnl: float
    gross_pnl_rounding_half_width: float
    recorded_swap: float
    native_commission: float

    @property
    def signed_move(self) -> float:
        if self.side == "buy":
            return self.exit_price - self.entry_price
        return self.entry_price - self.exit_price


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _canonical_sha256(value: Any) -> str:
    payload = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def _finite(value: Any, label: str) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise CostEvidenceError(f"{label} is not numeric: {value!r}") from exc
    if not math.isfinite(number):
        raise CostEvidenceError(f"{label} is not finite: {value!r}")
    return number


def _round(value: float | None, digits: int = 10) -> float | None:
    if value is None:
        return None
    return round(float(value), digits)


def _read_json_object(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise CostEvidenceError(f"cannot read JSON object {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise CostEvidenceError(f"{path} must contain a JSON object")
    return value


def _read_report_text(path: Path) -> str:
    raw = path.read_bytes()
    encodings: list[str] = []
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        encodings.append("utf-16")
    if raw.startswith(b"\xef\xbb\xbf"):
        encodings.append("utf-8-sig")
    if _looks_utf16le(raw):
        encodings.append("utf-16-le")
    encodings.extend(["utf-8-sig", "utf-8", "utf-16", "utf-16-le"])
    for encoding in dict.fromkeys(encodings):
        try:
            text = raw.decode(encoding)
        except UnicodeError:
            continue
        if "<" in text and ("Deals" in text or "Period" in text):
            return text
    raise CostEvidenceError(f"cannot decode MT5 report {path}")


def _looks_utf16le(raw: bytes) -> bool:
    if len(raw) < 4:
        return False
    sample = raw[: min(len(raw), 512)]
    odd_nuls = sample[1::2].count(0)
    even_nuls = sample[0::2].count(0)
    return odd_nuls > len(sample) // 8 and odd_nuls > even_nuls * 2


def _report_rows(path: Path) -> list[list[str]]:
    parser = _HtmlTableParser()
    parser.feed(_read_report_text(path))
    if not parser.rows:
        raise CostEvidenceError(f"no HTML table rows parsed from {path}")
    return parser.rows


def _normalize_cell(raw: str) -> str:
    return re.sub(r"\s+", " ", raw.strip().rstrip(":").lower())


def _cell_after(rows: Sequence[Sequence[str]], label: str) -> str | None:
    target = _normalize_cell(label)
    for row in rows:
        for index, cell in enumerate(row[:-1]):
            if _normalize_cell(cell) == target:
                return row[index + 1]
    return None


def _parse_number(raw: str) -> float | None:
    match = re.search(r"-?[\d\s\xa0,.]+", raw)
    if not match:
        return None
    value = match.group(0).replace("\xa0", " ").strip().replace(" ", "")
    if "," in value and "." in value:
        value = value.replace(",", "")
    elif "," in value:
        value = value.replace(",", ".")
    try:
        parsed = float(value)
    except ValueError:
        return None
    return parsed if math.isfinite(parsed) else None


def _required_number(raw: Any, label: str) -> float:
    value = _parse_number(str(raw or ""))
    if value is None:
        raise CostEvidenceError(f"missing numeric deal field {label}: {raw!r}")
    return value


def _report_stats(rows: Sequence[Sequence[str]]) -> dict[str, Any]:
    total_trades = _parse_number(_cell_after(rows, "Total Trades") or "")
    return {
        "expert": _cell_after(rows, "Expert"),
        "host_symbol": _cell_after(rows, "Symbol"),
        "period": _cell_after(rows, "Period"),
        "account_currency": _cell_after(rows, "Currency"),
        "history_quality": _cell_after(rows, "History Quality"),
        "report_net": _parse_number(_cell_after(rows, "Total Net Profit") or ""),
        "report_gross_profit": _parse_number(_cell_after(rows, "Gross Profit") or ""),
        "report_gross_loss": _parse_number(_cell_after(rows, "Gross Loss") or ""),
        "report_profit_factor": _parse_number(_cell_after(rows, "Profit Factor") or ""),
        "report_total_trades": None if total_trades is None else int(total_trades),
        "report_equity_drawdown_maximal": _parse_number(
            _cell_after(rows, "Equity Drawdown Maximal") or ""
        ),
    }


def extract_round_trips(path: Path) -> tuple[list[RoundTrip], dict[str, Any]]:
    rows = _report_rows(path)
    stats = _report_stats(rows)
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
        direction = _normalize_cell(str(deal.get("Direction") or ""))
        parsed = {
            "time": str(deal.get("Time") or "").strip(),
            "deal": str(deal.get("Deal") or "").strip(),
            "symbol": symbol,
            "volume": _required_number(deal.get("Volume"), "Volume"),
            "price": _required_number(deal.get("Price"), "Price"),
            "commission": _required_number(deal.get("Commission") or "0", "Commission"),
            "swap": _required_number(deal.get("Swap") or "0", "Swap"),
            "profit": _required_number(deal.get("Profit") or "0", "Profit"),
        }
        if parsed["volume"] <= 0.0:
            raise CostEvidenceError(f"{path}: non-positive deal volume {parsed['volume']}")
        if parsed["price"] <= 0.0:
            raise CostEvidenceError(f"{path}: non-positive deal price {parsed['price']}")

        if direction == "in":
            side = _normalize_cell(str(deal.get("Type") or ""))
            if side not in {"buy", "sell"}:
                raise CostEvidenceError(f"{path}: unsupported entry type {side!r}")
            parsed["side"] = side
            parsed["remaining_volume"] = parsed["volume"]
            open_entries.setdefault((symbol, side), []).append(parsed)
            continue
        if direction != "out":
            continue
        exit_type = _normalize_cell(str(deal.get("Type") or ""))
        entry_side = "buy" if exit_type == "sell" else "sell" if exit_type == "buy" else ""
        key = (symbol, entry_side)
        if not entry_side or not open_entries.get(key):
            raise CostEvidenceError(
                f"{path}: {exit_type!r} exit deal {parsed['deal']} has no matching entry"
            )
        trades.extend(_consume_exit(open_entries[key], parsed))

    remaining = sum(len(queue) for queue in open_entries.values())
    if remaining:
        raise CostEvidenceError(f"{path}: {remaining} entry deals remain open")
    if not trades:
        raise CostEvidenceError(f"{path}: no round trips")
    reported = stats.get("report_total_trades")
    if reported is None or reported != len(trades):
        raise CostEvidenceError(
            f"{path}: parsed {len(trades)} round trips, report says {reported}"
        )
    return trades, stats


def _consume_exit(
    entry_queue: list[dict[str, Any]], exit_deal: dict[str, Any]
) -> list[RoundTrip]:
    exit_volume = float(exit_deal["volume"])
    remaining_exit = exit_volume
    completed: list[RoundTrip] = []
    while remaining_exit > 1e-8:
        if not entry_queue:
            raise CostEvidenceError(
                f"exit deal {exit_deal['deal']} volume exceeds open entry volume"
            )
        entry = entry_queue[0]
        entry_remaining = float(entry["remaining_volume"])
        matched = min(entry_remaining, remaining_exit)
        entry_share = matched / float(entry["volume"])
        exit_share = matched / exit_volume
        entry_profit = float(entry["profit"]) * entry_share
        exit_profit = float(exit_deal["profit"]) * exit_share
        # MT5 entry deals normally have exact zero price P/L.  If an emitter
        # supplies non-zero entry P/L, its own cent display uncertainty is also
        # propagated rather than silently treated as exact.
        half_width = MONEY_ROUNDING_HALF_WIDTH * exit_share
        if abs(entry_profit) > FLOAT_TOLERANCE:
            half_width += MONEY_ROUNDING_HALF_WIDTH * entry_share
        completed.append(
            RoundTrip(
                entry_time=str(entry["time"]),
                exit_time=str(exit_deal["time"]),
                entry_deal=str(entry["deal"]),
                exit_deal=str(exit_deal["deal"]),
                symbol=str(entry["symbol"]),
                side=str(entry["side"]),
                volume=matched,
                entry_price=float(entry["price"]),
                exit_price=float(exit_deal["price"]),
                gross_pnl=entry_profit + exit_profit,
                gross_pnl_rounding_half_width=half_width,
                recorded_swap=(
                    float(entry["swap"]) * entry_share
                    + float(exit_deal["swap"]) * exit_share
                ),
                native_commission=(
                    float(entry["commission"]) * entry_share
                    + float(exit_deal["commission"]) * exit_share
                ),
            )
        )
        entry["remaining_volume"] = entry_remaining - matched
        remaining_exit -= matched
        if float(entry["remaining_volume"]) <= 1e-8:
            entry_queue.pop(0)
    return completed


def _derive_k_unambiguous(trade: RoundTrip) -> dict[str, Any] | None:
    move_abs = abs(trade.signed_move)
    pnl_abs = abs(trade.gross_pnl)
    half_width = trade.gross_pnl_rounding_half_width
    if move_abs <= FLOAT_TOLERANCE or pnl_abs <= half_width:
        return None
    denominator = trade.volume * move_abs
    return {
        "central": pnl_abs / denominator,
        "lower": max(0.0, pnl_abs - half_width) / denominator,
        "upper": (pnl_abs + half_width) / denominator,
    }


def _same_symbol_k_bounds(
    trades: Sequence[RoundTrip],
) -> dict[str, dict[str, float]]:
    values: dict[str, list[dict[str, Any]]] = {}
    for trade in trades:
        derived = _derive_k_unambiguous(trade)
        if derived is not None:
            values.setdefault(trade.symbol, []).append(derived)
    return {
        symbol: {
            "lower": min(row["lower"] for row in rows),
            "central": statistics.median(row["central"] for row in rows),
            "upper": max(row["upper"] for row in rows),
            "observations": float(len(rows)),
        }
        for symbol, rows in values.items()
    }


def evaluate_trades(trades: Sequence[RoundTrip]) -> dict[str, Any]:
    symbol_bounds = _same_symbol_k_bounds(trades)
    evaluated: list[dict[str, Any]] = []
    ambiguous = 0
    unbounded = 0

    for index, trade in enumerate(trades, start=1):
        derived = _derive_k_unambiguous(trade)
        ambiguity_reason: str | None = None
        k_source = "trade_gross_pnl_over_volume_signed_move"
        if derived is None:
            ambiguous += 1
            if abs(trade.signed_move) <= FLOAT_TOLERANCE:
                ambiguity_reason = "ZERO_SIGNED_MOVE"
            elif abs(trade.gross_pnl) <= FLOAT_TOLERANCE:
                ambiguity_reason = "ZERO_GROSS_PNL"
            else:
                ambiguity_reason = "GROSS_PNL_CENT_INTERVAL_CROSSES_ZERO"
            bounds = symbol_bounds.get(trade.symbol)
            if bounds is None:
                unbounded += 1
                evaluated.append(
                    _trade_row(
                        index,
                        trade,
                        k_source="UNBOUNDED_NO_SAME_SYMBOL_OBSERVATION",
                        ambiguity_reason=ambiguity_reason,
                        k=None,
                    )
                )
                continue
            derived = {
                "lower": bounds["lower"],
                "central": bounds["central"],
                "upper": bounds["upper"],
            }
            k_source = "SAME_SYMBOL_OBSERVED_MIN_MEDIAN_MAX_BOUND"
        evaluated.append(
            _trade_row(
                index,
                trade,
                k_source=k_source,
                ambiguity_reason=ambiguity_reason,
                k=derived,
            )
        )

    raw_price = [trade.gross_pnl for trade in trades]
    raw_swap = [trade.gross_pnl + trade.recorded_swap for trade in trades]
    native = [
        trade.gross_pnl + trade.recorded_swap + trade.native_commission
        for trade in trades
    ]
    central_available = unbounded == 0
    central_nets = [float(row["central_cost_adjusted_pnl"]) for row in evaluated if row["central_cost_adjusted_pnl"] is not None]
    conservative_nets = [
        float(row["conservative_cost_adjusted_pnl"])
        for row in evaluated
        if row["conservative_cost_adjusted_pnl"] is not None
    ]
    central_costs = [
        float(row["commission_at_official_0p005pct_rate"]["central_unrounded"])
        for row in evaluated
        if row["commission_at_official_0p005pct_rate"] is not None
    ]
    conservative_costs = [
        float(row["commission_at_official_0p005pct_rate"]["conservative_upper"])
        for row in evaluated
        if row["commission_at_official_0p005pct_rate"] is not None
    ]
    lower_costs = [
        float(row["commission_at_official_0p005pct_rate"]["lower_bound"])
        for row in evaluated
        if row["commission_at_official_0p005pct_rate"] is not None
    ]

    central_metrics = summarize_pnl(central_nets) if central_available else None
    conservative_metrics = summarize_pnl(conservative_nets) if central_available else None
    if central_metrics is not None:
        central_metrics["pf_at_least_1_10"] = _pf_flag(central_metrics, 1.10)
        central_metrics["pf_at_least_1_20"] = _pf_flag(central_metrics, 1.20)
    if conservative_metrics is not None:
        conservative_metrics["pf_at_least_1_10"] = _pf_flag(conservative_metrics, 1.10)
        conservative_metrics["pf_at_least_1_20"] = _pf_flag(conservative_metrics, 1.20)

    status = (
        "UNBOUNDED_AMBIGUOUS_FAIL_CLOSED"
        if unbounded
        else "BOUNDED_AMBIGUOUS_FAIL_CLOSED"
        if ambiguous
        else "COMPLETE"
    )
    return {
        "commission_evidence_status": status,
        "ambiguous_trade_count": ambiguous,
        "unbounded_trade_count": unbounded,
        "same_symbol_k_bounds": {
            symbol: {
                key: int(value) if key == "observations" else _round(value)
                for key, value in bounds.items()
            }
            for symbol, bounds in sorted(symbol_bounds.items())
        },
        "raw_price_pnl": summarize_pnl(raw_price),
        "raw_with_recorded_swap": summarize_pnl(raw_swap),
        "native_report_economics": {
            **summarize_pnl(native),
            "recorded_swap_total": _round(sum(t.recorded_swap for t in trades)),
            "native_commission_total_signed": _round(
                sum(t.native_commission for t in trades)
            ),
            "native_commission_total_absolute": _round(
                sum(abs(t.native_commission) for t in trades)
            ),
        },
        "official_dxz_0p005pct_cost": {
            "central_unrounded_total": _round(sum(central_costs)) if central_available else None,
            "lower_bound_total": _round(sum(lower_costs)) if central_available else None,
            "conservative_upper_total": _round(sum(conservative_costs)) if central_available else None,
            "central_basis": "exit_notional_empirically_validated_against_12778_q07",
            "conservative_basis": (
                "max_entry_exit_notional_k_upper_plus_half_cent_per_trade"
            ),
        },
        "central_cost_adjusted": central_metrics,
        "conservative_cost_adjusted": conservative_metrics,
        "round_trips": evaluated,
    }


def _trade_row(
    index: int,
    trade: RoundTrip,
    *,
    k_source: str,
    ambiguity_reason: str | None,
    k: dict[str, float] | None,
) -> dict[str, Any]:
    base = {
        "index": index,
        "entry_time_mt5_server": trade.entry_time,
        "exit_time_mt5_server": trade.exit_time,
        "entry_deal": trade.entry_deal,
        "exit_deal": trade.exit_deal,
        "symbol": trade.symbol,
        "side": trade.side,
        "volume": _round(trade.volume),
        "entry_price": _round(trade.entry_price),
        "exit_price": _round(trade.exit_price),
        "signed_move": _round(trade.signed_move),
        "gross_pnl": _round(trade.gross_pnl),
        "gross_pnl_cent_rounding_half_width": _round(
            trade.gross_pnl_rounding_half_width
        ),
        "recorded_swap": _round(trade.recorded_swap),
        "native_commission": _round(trade.native_commission),
        "k_source": k_source,
        "ambiguity_reason": ambiguity_reason,
    }
    if k is None:
        return {
            **base,
            "effective_k_account_per_lot_price_unit": None,
            "entry_notional_account": None,
            "exit_notional_account": None,
            "commission_at_official_0p005pct_rate": None,
            "central_cost_adjusted_pnl": None,
            "conservative_cost_adjusted_pnl": None,
        }
    entry = {key: trade.entry_price * trade.volume * value for key, value in k.items()}
    exit_ = {key: trade.exit_price * trade.volume * value for key, value in k.items()}
    central = exit_["central"] * DXZ_ROUND_TRIP_NOTIONAL_RATE
    lower = max(
        0.0,
        exit_["lower"] * DXZ_ROUND_TRIP_NOTIONAL_RATE - MONEY_ROUNDING_HALF_WIDTH,
    )
    conservative = (
        max(entry["upper"], exit_["upper"]) * DXZ_ROUND_TRIP_NOTIONAL_RATE
        + MONEY_ROUNDING_HALF_WIDTH
    )
    return {
        **base,
        "effective_k_account_per_lot_price_unit": {
            key: _round(value) for key, value in k.items()
        },
        "entry_notional_account": {key: _round(value) for key, value in entry.items()},
        "exit_notional_account": {key: _round(value) for key, value in exit_.items()},
        "commission_at_official_0p005pct_rate": {
            "central_unrounded": _round(central),
            "lower_bound": _round(lower),
            "conservative_upper": _round(conservative),
        },
        "central_cost_adjusted_pnl": _round(
            trade.gross_pnl + trade.recorded_swap - central
        ),
        "conservative_cost_adjusted_pnl": _round(
            trade.gross_pnl + trade.recorded_swap - conservative
        ),
    }


def summarize_pnl(values: Sequence[float]) -> dict[str, Any]:
    gross_profit = sum(value for value in values if value > 0.0)
    gross_loss = sum(value for value in values if value < 0.0)
    pf = None if abs(gross_loss) <= FLOAT_TOLERANCE else gross_profit / abs(gross_loss)
    balance = 0.0
    peak = 0.0
    drawdown = 0.0
    for value in values:
        balance += value
        peak = max(peak, balance)
        drawdown = max(drawdown, peak - balance)
    return {
        "trades": len(values),
        "net": _round(sum(values)),
        "gross_profit": _round(gross_profit),
        "gross_loss": _round(gross_loss),
        "profit_factor": _round(pf),
        "close_to_close_max_drawdown": _round(drawdown),
    }


def _pf_flag(metrics: dict[str, Any], floor: float) -> bool:
    pf = metrics.get("profit_factor")
    return bool(pf is not None and float(pf) >= floor)


def _real_ticks_100(history_quality: str | None) -> bool:
    if not history_quality:
        return False
    return bool(re.search(r"\b100(?:\.0+)?%\s+real ticks\b", history_quality, re.I))


def parse_q08_diagnostic(path: Path, evaluation: dict[str, Any]) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    errors: list[str] = []
    for line_number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not raw.strip():
            continue
        try:
            value = json.loads(raw)
        except json.JSONDecodeError as exc:
            errors.append(f"line {line_number}: invalid JSON: {exc.msg}")
            continue
        if not isinstance(value, dict):
            errors.append(f"line {line_number}: not an object")
            continue
        try:
            symbol = str(value.get("symbol") or "").strip()
            notional = _finite(value.get("notional"), f"line {line_number} notional")
        except CostEvidenceError as exc:
            errors.append(str(exc))
            continue
        if not symbol or notional <= 0.0:
            errors.append(f"line {line_number}: symbol/notional invalid")
            continue
        rows.append({"symbol": symbol, "notional": notional})

    derived_rows = [
        row
        for row in evaluation["round_trips"]
        if row.get("entry_notional_account") is not None
    ]
    entry_total = sum(row["entry_notional_account"]["central"] for row in derived_rows)
    exit_total = sum(row["exit_notional_account"]["central"] for row in derived_rows)
    q08_total = sum(row["notional"] for row in rows)
    by_symbol: dict[str, float] = {}
    for row in rows:
        by_symbol[row["symbol"]] = by_symbol.get(row["symbol"], 0.0) + row["notional"]
    return {
        "status": "DIAGNOSTIC_ONLY",
        "valid_rows": len(rows),
        "parse_errors": errors,
        "q08_notional_total": _round(q08_total),
        "q08_notional_by_symbol": {
            key: _round(value) for key, value in sorted(by_symbol.items())
        },
        "derived_entry_notional_total": _round(entry_total),
        "derived_exit_notional_total": _round(exit_total),
        "q08_to_derived_entry_ratio": _round(q08_total / entry_total)
        if entry_total > 0.0
        else None,
        "q08_to_derived_exit_ratio": _round(q08_total / exit_total)
        if exit_total > 0.0
        else None,
        "qualification_use": False,
        "known_history_emitter_defect": (
            "Q08 history rebuild can value historical notional with the emitter's "
            "final quote instead of each trade's entry quote; Q08 notional is therefore "
            "never used as cost truth."
        ),
    }


def _receipt_job(receipt: dict[str, Any]) -> tuple[int, str, str]:
    job = receipt.get("job")
    if not isinstance(job, dict):
        raise CostEvidenceError("receipt.job missing")
    try:
        ea_id = int(job["ea_id"])
        symbol = str(job["symbol"])
        timeframe = str(job["timeframe"])
    except (KeyError, TypeError, ValueError) as exc:
        raise CostEvidenceError("receipt job identity incomplete") from exc
    if ea_id <= 0 or not symbol or not timeframe:
        raise CostEvidenceError("receipt job identity invalid")
    return ea_id, symbol, timeframe


def evaluate_input(receipt_path: Path, report_path: Path, q08_path: Path) -> dict[str, Any]:
    for label, path in (
        ("receipt", receipt_path),
        ("report", report_path),
        ("q08", q08_path),
    ):
        if not path.is_file():
            raise CostEvidenceError(f"explicit {label} input missing: {path}")
    receipt = _read_json_object(receipt_path)
    ea_id, symbol, timeframe = _receipt_job(receipt)
    report_sha = sha256_file(report_path)
    q08_sha = sha256_file(q08_path)
    identity = receipt.get("identity")
    if not isinstance(identity, dict):
        raise CostEvidenceError(f"{receipt_path}: identity missing")
    if identity.get("native_report_sha256") != report_sha:
        raise CostEvidenceError(f"{receipt_path}: explicit report hash does not match receipt")
    if identity.get("q08_stream_sha256") != q08_sha:
        raise CostEvidenceError(f"{receipt_path}: explicit Q08 hash does not match receipt")
    required_true = (
        "native_report_copy_hash_match",
        "native_report_window_match",
        "native_report_trade_count_match",
    )
    false_fields = [name for name in required_true if receipt.get(name) is not True]
    stability = receipt.get("native_report_stability")
    if not isinstance(stability, dict) or stability.get("stable") is not True:
        false_fields.append("native_report_stability.stable")
    if false_fields:
        raise CostEvidenceError(
            f"{receipt_path}: native report technical contract failed: {false_fields}"
        )
    native_metrics = receipt.get("native_metrics")
    if not isinstance(native_metrics, dict):
        raise CostEvidenceError(f"{receipt_path}: native_metrics missing")
    expected_trades = int(native_metrics.get("closed_trades") or 0)
    if expected_trades <= 0:
        raise CostEvidenceError(f"{receipt_path}: native report is empty")

    trades, stats = extract_round_trips(report_path)
    if len(trades) != expected_trades:
        raise CostEvidenceError(
            f"{receipt_path}: receipt says {expected_trades} trades, parsed {len(trades)}"
        )
    evaluation = evaluate_trades(trades)
    reconstructed = float(evaluation["native_report_economics"]["net"])
    report_net = stats.get("report_net")
    if report_net is None:
        raise CostEvidenceError(f"{report_path}: report net missing")
    reconciliation_delta = reconstructed - float(report_net)
    tolerance = MONEY_ROUNDING_HALF_WIDTH * len(trades) + 0.02
    if abs(reconciliation_delta) > tolerance:
        raise CostEvidenceError(
            f"{report_path}: deal reconstruction delta {reconciliation_delta:.6f} "
            f"exceeds tolerance {tolerance:.6f}"
        )
    history_quality = stats.get("history_quality")
    evaluation["input_identity"] = {
        "receipt_path": str(receipt_path.resolve()),
        "receipt_sha256": sha256_file(receipt_path),
        "report_path": str(report_path.resolve()),
        "report_sha256": report_sha,
        "q08_path": str(q08_path.resolve()),
        "q08_sha256": q08_sha,
    }
    evaluation["sleeve"] = {
        "key": f"{ea_id}:{symbol}",
        "ea_id": ea_id,
        "symbol": symbol,
        "timeframe": timeframe,
        "account_currency": stats.get("account_currency"),
        "period": stats.get("period"),
        "history_quality": history_quality,
        "receipt_status": receipt.get("status"),
    }
    evaluation["report_reconciliation"] = {
        "reported_net": _round(float(report_net)),
        "deal_reconstructed_net": _round(reconstructed),
        "delta": _round(reconciliation_delta),
        "tolerance": _round(tolerance),
        "status": "PASS",
        "reported_profit_factor": _round(stats.get("report_profit_factor")),
        "reported_equity_drawdown_maximal": _round(
            stats.get("report_equity_drawdown_maximal")
        ),
    }
    evaluation["q08_notional_cross_check"] = parse_q08_diagnostic(q08_path, evaluation)
    evaluation["scope"] = {
        "commission": {
            "status": evaluation["commission_evidence_status"],
            "rate_round_trip": DXZ_ROUND_TRIP_NOTIONAL_RATE,
            "central_basis": "exit_notional_empirically_validated_against_12778_q07",
            "entry_notional_also_reported": True,
        },
        "spread": {
            "status": "HISTORICAL_TESTER_SPREAD_EMBEDDED_NOT_BROKER_PARITY_CERTIFIED"
            if _real_ticks_100(history_quality)
            else "HISTORICAL_TESTER_SPREAD_NOT_FULLY_EVIDENCED",
            "history_quality": history_quality,
            "current_broker_spread_parity": "NOT_CERTIFIED",
        },
        "swap": {
            "status": "RECORDED_NATIVE_VALUES_INCLUDED",
            "broker_rate_certification": "NOT_EVALUATED",
        },
        "slippage": "NOT_EVALUATED",
        "deployment_eligible": False,
    }
    return evaluation


def validate_formula(
    receipt_path: Path,
    report_path: Path,
    *,
    expected_native_commission: float,
    expected_derived_commission: float,
    native_tolerance: float = 0.011,
    derived_tolerance: float = 0.011,
) -> dict[str, Any]:
    if not receipt_path.is_file() or not report_path.is_file():
        raise CostEvidenceError("formula validation receipt/report input missing")
    trades, stats = extract_round_trips(report_path)
    evaluation = evaluate_trades(trades)
    native = sum(abs(trade.native_commission) for trade in trades)
    derived = evaluation["official_dxz_0p005pct_cost"]["central_unrounded_total"]
    lower = evaluation["official_dxz_0p005pct_cost"]["lower_bound_total"]
    upper = evaluation["official_dxz_0p005pct_cost"]["conservative_upper_total"]
    if derived is None or lower is None or upper is None:
        status = "FAIL_UNAVAILABLE"
    else:
        checks = (
            abs(native - expected_native_commission) <= native_tolerance,
            abs(float(derived) - expected_derived_commission) <= derived_tolerance,
            float(lower) <= native <= float(upper),
        )
        status = "PASS" if all(checks) else "FAIL"
    return {
        "status": status,
        "purpose": "independent_formula_validation_not_a_selected_sleeve_replacement",
        "input_identity": {
            "receipt_path": str(receipt_path.resolve()),
            "receipt_sha256": sha256_file(receipt_path),
            "report_path": str(report_path.resolve()),
            "report_sha256": sha256_file(report_path),
        },
        "report": {
            "expert": stats.get("expert"),
            "account_currency": stats.get("account_currency"),
            "trades": len(trades),
        },
        "expected_native_commission": expected_native_commission,
        "observed_native_commission": _round(native),
        "native_tolerance": native_tolerance,
        "expected_derived_unrounded_commission": expected_derived_commission,
        "observed_derived_unrounded_commission": _round(derived),
        "derived_tolerance": derived_tolerance,
        "derived_lower_bound": _round(lower),
        "derived_conservative_upper": _round(upper),
        "formula": (
            "K=abs(gross_pnl/(volume*signed_move)); "
            "entry_notional=entry_price*volume*K; "
            "central_commission=exit_price*volume*K*0.00005"
        ),
        "finding": (
            "The native tester commission is cent-settled per closing trade. "
            "The unrounded 0.005% (0.5 bp) formula therefore validates near 281.44 while "
            "the summed native settled charges are 281.77."
        ),
        "deployment_eligible": False,
    }


def build_report(
    inputs: Sequence[tuple[Path, Path, Path]],
    *,
    expected_input_count: int,
    as_of_utc: str,
    selection_note: str,
    exclusions: Sequence[tuple[str, str]],
    validation_input: tuple[Path, Path] | None,
    implementation_path: Path | None = None,
) -> dict[str, Any]:
    if len(inputs) != expected_input_count:
        raise CostEvidenceError(
            f"explicit input count {len(inputs)} != expected {expected_input_count}"
        )
    try:
        parsed_as_of = dt.datetime.fromisoformat(as_of_utc.replace("Z", "+00:00"))
    except ValueError as exc:
        raise CostEvidenceError("--as-of-utc must be ISO-8601") from exc
    if parsed_as_of.tzinfo is None:
        raise CostEvidenceError("--as-of-utc must include a UTC offset")
    normalized_as_of = parsed_as_of.astimezone(dt.UTC).replace(microsecond=0).isoformat()

    seen_paths: set[tuple[str, str, str]] = set()
    sleeves: list[dict[str, Any]] = []
    for receipt, report, q08 in inputs:
        resolved = tuple(str(path.resolve()).lower() for path in (receipt, report, q08))
        if resolved in seen_paths:
            raise CostEvidenceError(f"duplicate explicit input tuple: {receipt}")
        seen_paths.add(resolved)
        sleeves.append(evaluate_input(receipt, report, q08))
    sleeves.sort(key=lambda row: (row["sleeve"]["ea_id"], row["sleeve"]["symbol"]))
    keys = [row["sleeve"]["key"] for row in sleeves]
    if len(keys) != len(set(keys)):
        raise CostEvidenceError("duplicate EA/symbol sleeve key in explicit selection")

    implementation = implementation_path or Path(__file__)
    formula_validation = None
    if validation_input is not None:
        formula_validation = validate_formula(
            validation_input[0],
            validation_input[1],
            expected_native_commission=281.77,
            expected_derived_commission=281.44,
        )
        if formula_validation["status"] != "PASS":
            raise CostEvidenceError(
                f"12778 Q07 formula validation failed: {formula_validation['status']}"
            )

    complete = sum(
        row["commission_evidence_status"] == "COMPLETE" for row in sleeves
    )
    bounded = sum(
        row["commission_evidence_status"] == "BOUNDED_AMBIGUOUS_FAIL_CLOSED"
        for row in sleeves
    )
    unbounded = sum(
        row["commission_evidence_status"] == "UNBOUNDED_AMBIGUOUS_FAIL_CLOSED"
        for row in sleeves
    )
    conservative_110 = sum(
        bool((row.get("conservative_cost_adjusted") or {}).get("pf_at_least_1_10"))
        for row in sleeves
    )
    conservative_120 = sum(
        bool((row.get("conservative_cost_adjusted") or {}).get("pf_at_least_1_20"))
        for row in sleeves
    )
    result: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "DXZ_STANDALONE_COST_EVIDENCE",
        "as_of_utc": normalized_as_of,
        "implementation": {
            "path": str(implementation.resolve()),
            "sha256": sha256_file(implementation),
        },
        "selection": {
            "expected_explicit_input_count": expected_input_count,
            "actual_explicit_input_count": len(inputs),
            "unique_ea_symbol_count": len(keys),
            "keys": keys,
            "note": selection_note,
            "exclusions": [
                {"key": key, "reason": reason} for key, reason in exclusions
            ],
        },
        "policy": {
            "scope": "DARWINEX_ZERO_COMMISSION_ONLY",
            "round_trip_notional_rate": DXZ_ROUND_TRIP_NOTIONAL_RATE,
            "round_trip_notional_percent": DXZ_ROUND_TRIP_NOTIONAL_PERCENT,
            "round_trip_notional_basis_points": DXZ_ROUND_TRIP_NOTIONAL_BASIS_POINTS,
            "rate_unit_contract": (
                "0.00005 decimal = 0.005 percent = 0.5 basis points round-trip"
            ),
            "superseded_label_warning": (
                "Schema-v1/v2 fields labelled 5bp were a terminology error; their "
                "numeric rate 0.00005 and all resulting economics were already correct."
            ),
            "official_sources": [OFFICIAL_COST_SOURCE, OFFICIAL_ZERO_COST_SOURCE],
            "central_notional_basis": (
                "exit notional, empirically validated against the known EUR 12778 "
                "Q07 basket and its per-trade native commission"
            ),
            "conservative_notional_basis": (
                "max(entry, exit) with K upper bound and half-cent settlement allowance"
            ),
            "live_commission_registry": {
                "used": False,
                "status": "NOT_DIMENSIONALLY_CERTIFIED",
                "reason": (
                    "The registry max() mixes a USD flat-per-lot fallback with "
                    "EUR tester-account notionals. It is not converted to a common "
                    "currency and is excluded from all DXZ-only results."
                ),
            },
        },
        "formula_validation": formula_validation,
        "summary": {
            "sleeves": len(sleeves),
            "commission_complete": complete,
            "commission_bounded_ambiguous": bounded,
            "commission_unbounded_ambiguous": unbounded,
            "conservative_pf_at_least_1_10": conservative_110,
            "conservative_pf_at_least_1_20": conservative_120,
            "reports_with_100_percent_real_ticks_spread_embedded": sum(
                row["scope"]["spread"]["status"]
                == "HISTORICAL_TESTER_SPREAD_EMBEDDED_NOT_BROKER_PARITY_CERTIFIED"
                for row in sleeves
            ),
            "current_broker_spread_parity_certified": 0,
            "swap_broker_rate_certified": 0,
            "slippage_evaluated": 0,
            "deployment_eligible": False,
        },
        "sleeves": sleeves,
        "limitations": [
            "A 100% real-ticks report means historical spread is embedded in tester prices; it does not certify current or broker-parity spread.",
            "Recorded tester swap is included; current broker swap-rate parity is not certified.",
            "Slippage is NOT_EVALUATED.",
            "Q08 notional is diagnostic only because the history emitter can apply a final quote to historical trades.",
            "This artifact does not establish Card/EA lineage, binary identity, routing, or deployment safety.",
        ],
        "deployment_eligible": False,
    }
    payload_for_hash = dict(result)
    result["integrity"] = {
        "payload_sha256": _canonical_sha256(payload_for_hash),
        "payload_hash_scope": "canonical JSON of the artifact with integrity field omitted",
        "final_file_sha256": "SEE_EXCLUSIVE_SIDECAR",
    }
    return result


def write_immutable_report(report: dict[str, Any], output: Path) -> str:
    sidecar = output.with_name(output.name + ".sha256")
    if output.exists() or sidecar.exists():
        raise CostEvidenceError(f"refusing overwrite: {output} or {sidecar} exists")
    output.parent.mkdir(parents=True, exist_ok=True)
    payload = (
        json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False)
        + "\n"
    ).encode("utf-8")
    try:
        with output.open("xb") as handle:
            handle.write(payload)
        final_sha = hashlib.sha256(payload).hexdigest()
        with sidecar.open("x", encoding="ascii", newline="\n") as handle:
            handle.write(f"{final_sha}  {output.name}\n")
    except Exception:
        # Do not delete an already-created evidence file. A partial exclusive
        # write is visible and must be adjudicated rather than silently erased.
        raise
    try:
        os.chmod(output, 0o444)
        os.chmod(sidecar, 0o444)
    except OSError:
        pass
    return final_sha


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Build immutable DarwinexZero 0.005% (0.5 bp) round-trip cost evidence "
            "from explicit MT5 inputs"
        )
    )
    parser.add_argument(
        "--input",
        action="append",
        nargs=3,
        metavar=("RECEIPT_JSON", "REPORT_HTM", "Q08_JSONL"),
        required=True,
        help="Explicit receipt/report/Q08 tuple; repeat once per selected sleeve",
    )
    parser.add_argument("--expected-input-count", type=int, required=True)
    parser.add_argument("--as-of-utc", required=True)
    parser.add_argument("--selection-note", required=True)
    parser.add_argument(
        "--exclusion",
        action="append",
        nargs=2,
        default=[],
        metavar=("KEY", "REASON"),
    )
    parser.add_argument(
        "--validation-input",
        nargs=2,
        required=True,
        metavar=("Q07_RECEIPT_OR_SUMMARY_JSON", "Q07_REPORT_HTM"),
    )
    parser.add_argument("--output", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    if args.expected_input_count <= 0:
        raise CostEvidenceError("--expected-input-count must be positive")
    report = build_report(
        [tuple(Path(value) for value in item) for item in args.input],
        expected_input_count=args.expected_input_count,
        as_of_utc=args.as_of_utc,
        selection_note=args.selection_note,
        exclusions=[(str(key), str(reason)) for key, reason in args.exclusion],
        validation_input=tuple(Path(value) for value in args.validation_input),
    )
    final_sha = write_immutable_report(report, args.output)
    print(
        json.dumps(
            {
                "output": str(args.output.resolve()),
                "sha256": final_sha,
                "sleeves": len(report["sleeves"]),
                "deployment_eligible": False,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except CostEvidenceError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
