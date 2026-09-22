#!/usr/bin/env python3
"""Collect matched FTMO/Darwinex spreads and D2g6 fill slippage read-only.

The collector attaches sequentially to two *already-running*, identity-pinned
MT5 processes.  It never starts or controls a terminal and has no trading API
surface.  Broker tick history supplies one bid/ask observation per UTC minute;
only minutes present at both venues are appended to the matched ledger.

The operational ledgers are append-only and idempotent.  Derived CSV/JSON
views are replaced atomically.  A spread charge is eligible only when one
symbol has at least 60 exact matched minutes across at least three named
sessions including the 21Z rollover hour.  Missing coverage remains
UNMEASURED and is never represented by a numeric zero.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import math
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

import numpy as np


TASK_ID = "629043f6-b913-4df3-aab2-7adb79455c53"
SCHEMA = "qm.ftmo-venue-matched-measurement/v2"
SPREAD_ROW_SCHEMA = "qm.ftmo-dxz-matched-spread-minute/v2"
SLIPPAGE_ROW_SCHEMA = "qm.ftmo-d2g6-slippage-deal/v2"
SUMMARY_SCHEMA = "qm.ftmo-d2g6-slippage-summary/v1"
STATE_SCHEMA = "qm.ftmo-venue-matched-collector-state/v2"

STUDY_START = dt.datetime(2026, 9, 18, tzinfo=dt.timezone.utc)
MIN_MATCHED_MINUTES = 60
MIN_SESSION_COUNT = 3
MAX_REQUEST_QUOTE_AGE_MSC = 2_000

OUTPUT_ROOT = Path(
    rf"D:\QM\reports\ftmo\venue_matched_measurement\task_{TASK_ID}"
    r"\v2_clock_normalized"
)
FTMO_EXE = Path(r"C:\Program Files\FTMO Global Markets MT5 Terminal\terminal64.exe")
FTMO_DATA = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal"
    r"\81A933A9AFC5DE3C23B15CAB19C63850"
)
DXZ_EXE = Path(r"C:\QM\mt5\T_Live\MT5_Base\terminal64.exe")
DXZ_DATA = Path(r"C:\QM\mt5\T_Live\MT5_Base")

SYMBOL_MAP: dict[str, dict[str, str]] = {
    # The running Darwinex-Live account uses native broker names.  ``.DWX`` is
    # the factory/custom-history alias and is added only to simulator keys.
    "USDJPY": {"FTMO": "USDJPY", "DXZ": "USDJPY"},
    "XAUUSD": {"FTMO": "XAUUSD", "DXZ": "XAUUSD"},
    "USDCAD": {"FTMO": "USDCAD", "DXZ": "USDCAD"},
    "GBPUSD": {"FTMO": "GBPUSD", "DXZ": "GBPUSD"},
    "EURUSD": {"FTMO": "EURUSD", "DXZ": "EURUSD"},
}
D2G6_MAGICS = frozenset(
    {132130000, 107060001, 107000003, 114220004, 104030002, 412190000}
)


class CollectionError(RuntimeError):
    """A fail-closed collection or evidence-contract error."""


@dataclass(frozen=True)
class TerminalSpec:
    venue: str
    executable: Path
    data_path: Path
    login: int
    server: str
    portable: bool


FTMO = TerminalSpec(
    venue="FTMO",
    executable=FTMO_EXE,
    data_path=FTMO_DATA,
    login=1514536732,
    server="FTMO-Demo",
    portable=False,
)
DXZ = TerminalSpec(
    venue="DXZ",
    executable=DXZ_EXE,
    data_path=DXZ_DATA,
    login=4000090541,
    server="Darwinex-Live",
    portable=True,
)


SESSION_WINDOWS: tuple[tuple[str, int], ...] = (
    ("ASIA_00Z", 0),
    ("EUROPE_08Z", 8),
    ("US_14Z", 14),
    ("ROLLOVER_21Z", 21),
)


def utc_iso(value: dt.datetime) -> str:
    return value.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat().replace(
        "+00:00", "Z"
    )


def parse_utc(value: str) -> dt.datetime:
    parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise CollectionError("timestamp must include a UTC offset")
    return parsed.astimezone(dt.timezone.utc)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def percentile(values: Sequence[float], quantile: float) -> float | None:
    if not values:
        return None
    return round(float(np.percentile(np.asarray(values, dtype=float), quantile)), 8)


def session_name(minute_epoch: int) -> str:
    hour = dt.datetime.fromtimestamp(minute_epoch, dt.timezone.utc).hour
    if hour == 21:
        return "ROLLOVER_21Z"
    if 0 <= hour < 7:
        return "ASIA"
    if 7 <= hour < 13:
        return "EUROPE"
    if 13 <= hour < 21:
        return "US"
    return "OFF_SESSION"


def session_sample_windows(
    start: dt.datetime, end: dt.datetime
) -> list[tuple[str, dt.datetime, dt.datetime]]:
    """Return bounded one-hour windows for four market sessions per weekday."""
    start = start.astimezone(dt.timezone.utc)
    end = end.astimezone(dt.timezone.utc)
    if end <= start:
        raise CollectionError("collection end must be later than start")
    day = start.date()
    windows: list[tuple[str, dt.datetime, dt.datetime]] = []
    while day <= end.date():
        if day.weekday() < 5:
            for label, hour in SESSION_WINDOWS:
                left = dt.datetime.combine(
                    day, dt.time(hour=hour), tzinfo=dt.timezone.utc
                )
                right = left + dt.timedelta(hours=1)
                bounded_left, bounded_right = max(left, start), min(right, end)
                if bounded_left < bounded_right:
                    windows.append((label, bounded_left, bounded_right))
        day += dt.timedelta(days=1)
    return windows


def contiguous_hour_windows(
    start: dt.datetime, end: dt.datetime
) -> list[tuple[str, dt.datetime, dt.datetime]]:
    start = start.astimezone(dt.timezone.utc)
    end = end.astimezone(dt.timezone.utc)
    if end <= start:
        raise CollectionError("collection end must be later than start")
    cursor = start
    result: list[tuple[str, dt.datetime, dt.datetime]] = []
    while cursor < end:
        right = min(end, cursor + dt.timedelta(hours=1))
        result.append(("INCREMENTAL", cursor, right))
        cursor = right
    return result


def _processes_for(executable: Path) -> set[int]:
    try:
        import psutil
    except ImportError as exc:  # pragma: no cover - environment dependency
        raise CollectionError("psutil is required for the no-start guard") from exc
    expected = os.path.normcase(str(executable.resolve()))
    result: set[int] = set()
    for process in psutil.process_iter(["pid", "exe"]):
        try:
            actual = process.info.get("exe")
            if actual and os.path.normcase(str(Path(actual).resolve())) == expected:
                result.add(int(process.info["pid"]))
        except (OSError, psutil.Error):
            continue
    return result


def prove_preexisting_process(spec: TerminalSpec) -> set[int]:
    processes = _processes_for(spec.executable)
    if len(processes) != 1:
        raise CollectionError(
            f"{spec.venue}_terminal_requires_exactly_one_preexisting_process:"
            f"count={len(processes)}"
        )
    return processes


def _terminal_identity(mt5: Any, spec: TerminalSpec, before: set[int]) -> dict[str, Any]:
    after = _processes_for(spec.executable)
    if after != before:
        raise CollectionError(
            f"{spec.venue}_process_set_changed_during_readonly_attach:"
            f"before={sorted(before)}:after={sorted(after)}"
        )
    terminal, account = mt5.terminal_info(), mt5.account_info()
    if terminal is None or account is None:
        raise CollectionError(f"{spec.venue}_terminal_or_account_info_missing")
    if int(account.login) != spec.login or str(account.server) != spec.server:
        raise CollectionError(
            f"{spec.venue}_account_identity_mismatch:"
            f"login={account.login}:server={account.server}"
        )
    actual_data = Path(str(terminal.data_path)).resolve()
    if os.path.normcase(str(actual_data)) != os.path.normcase(
        str(spec.data_path.resolve())
    ):
        raise CollectionError(
            f"{spec.venue}_data_path_mismatch:{actual_data}!={spec.data_path.resolve()}"
        )
    return {
        "venue": spec.venue,
        "process_ids": sorted(before),
        "executable": str(spec.executable.resolve()),
        "data_path": str(actual_data),
        "account_login_masked": "*" * max(0, len(str(spec.login)) - 3)
        + str(spec.login)[-3:],
        "account_server": str(account.server),
        "terminal_build": int(terminal.build),
        "terminal_connected": bool(terminal.connected),
        "terminal_trade_allowed_observed": bool(terminal.trade_allowed),
        "autotrading_touched": False,
        "orders_sent": 0,
        "terminal_control_actions": 0,
    }


def _tick_dicts(raw: Any) -> Iterable[dict[str, Any]]:
    if raw is None:
        return []
    return (
        {
            "time_msc": int(row["time_msc"]),
            "bid": float(row["bid"]),
            "ask": float(row["ask"]),
        }
        for row in raw
    )


def first_quote_per_minute(
    raw: Any, *, server_minus_utc_hours: int = 0
) -> dict[int, dict[str, Any]]:
    """Pick the first complete bid/ask quote in each real UTC minute."""
    result: dict[int, dict[str, Any]] = {}
    offset_msc = server_minus_utc_hours * 3_600_000
    for tick in _tick_dicts(raw):
        if (
            not math.isfinite(tick["bid"])
            or not math.isfinite(tick["ask"])
            or tick["bid"] <= 0
            or tick["ask"] < tick["bid"]
        ):
            continue
        raw_time_msc = int(tick["time_msc"])
        utc_time_msc = raw_time_msc - offset_msc
        minute = utc_time_msc // 60_000 * 60
        normalized = {
            **tick,
            "time_msc": utc_time_msc,
            "server_time_msc": raw_time_msc,
        }
        current = result.get(minute)
        if current is None or normalized["time_msc"] < current["time_msc"]:
            result[minute] = normalized
    return result


def infer_server_offset(mt5: Any, symbol: str, observed_at: dt.datetime) -> dict[str, Any]:
    """Infer the live broker-wall offset and bind it to one current tick."""
    tick = mt5.symbol_info_tick(symbol)
    if tick is None or int(tick.time_msc) <= 0:
        raise CollectionError(f"cannot infer server offset: no current tick for {symbol}")
    observed_msc = int(observed_at.astimezone(dt.timezone.utc).timestamp() * 1000)
    raw_msc = int(tick.time_msc)
    offset = int(round((raw_msc - observed_msc) / 3_600_000.0))
    if offset < -12 or offset > 14:
        raise CollectionError(f"server offset outside civil range:{symbol}:{offset}")
    normalized_msc = raw_msc - offset * 3_600_000
    lag_msc = observed_msc - normalized_msc
    if lag_msc < -300_000 or lag_msc > 900_000:
        raise CollectionError(
            f"server offset inference is not live:{symbol}:offset={offset}:lag_msc={lag_msc}"
        )
    return {
        "method": "nearest whole-hour from current broker tick to wall-clock UTC",
        "symbol": symbol,
        "server_minus_utc_hours": offset,
        "raw_server_tick_time_msc": raw_msc,
        "normalized_tick_time_utc": utc_iso(
            dt.datetime.fromtimestamp(normalized_msc / 1000, dt.timezone.utc)
        ),
        "normalized_tick_lag_msc": lag_msc,
        "status": "PASS_LIVE_OFFSET_INFERENCE",
    }


def quote_at_or_before(raw: Any, reference_time_msc: int) -> dict[str, Any] | None:
    candidates = [
        row
        for row in _tick_dicts(raw)
        if row["time_msc"] <= reference_time_msc
        and row["bid"] > 0
        and row["ask"] >= row["bid"]
    ]
    if not candidates:
        return None
    chosen = max(candidates, key=lambda row: row["time_msc"])
    age = reference_time_msc - int(chosen["time_msc"])
    return {
        **chosen,
        "age_msc": age,
        "fresh": age <= MAX_REQUEST_QUOTE_AGE_MSC,
    }


def _copy_ticks(
    mt5: Any, symbol: str, start: dt.datetime, end: dt.datetime
) -> Any:
    return mt5.copy_ticks_range(symbol, start, end, mt5.COPY_TICKS_INFO)


def capture_spreads(
    mt5: Any,
    spec: TerminalSpec,
    windows: Sequence[tuple[str, dt.datetime, dt.datetime]],
    *,
    server_minus_utc_hours: int,
) -> tuple[dict[str, dict[int, dict[str, Any]]], dict[str, Any]]:
    result: dict[str, dict[int, dict[str, Any]]] = {}
    diagnostics: dict[str, Any] = {}
    for canonical, aliases in SYMBOL_MAP.items():
        symbol = aliases[spec.venue]
        info = mt5.symbol_info(symbol)
        if info is None:
            result[canonical] = {}
            diagnostics[canonical] = {
                "symbol": symbol,
                "status": "UNMEASURED_SYMBOL_INFO_MISSING",
                "last_error": list(mt5.last_error()),
            }
            continue
        collected: dict[int, dict[str, Any]] = {}
        errors: list[dict[str, Any]] = []
        for label, start, end in windows:
            # This MT5 build exposes broker-wall epochs through Python. Shift
            # the requested real-UTC window into that domain, then normalize
            # each returned tick before venue matching.
            shifted_start = start + dt.timedelta(hours=server_minus_utc_hours)
            shifted_end = end + dt.timedelta(hours=server_minus_utc_hours)
            raw = _copy_ticks(mt5, symbol, shifted_start, shifted_end)
            if raw is None:
                errors.append(
                    {
                        "session": label,
                        "start_utc": utc_iso(start),
                        "end_utc": utc_iso(end),
                        "last_error": list(mt5.last_error()),
                    }
                )
                continue
            for minute, quote in first_quote_per_minute(
                raw, server_minus_utc_hours=server_minus_utc_hours
            ).items():
                existing = collected.get(minute)
                if existing is None or quote["time_msc"] < existing["time_msc"]:
                    collected[minute] = quote
        result[canonical] = collected
        diagnostics[canonical] = {
            "symbol": symbol,
            "status": "MEASURED" if collected else "UNMEASURED_NO_TICKS",
            "minute_count": len(collected),
            "point": float(info.point),
            "digits": int(info.digits),
            "query_errors": errors,
        }
    return result, diagnostics


def _history_rows(mt5: Any, start: dt.datetime, end: dt.datetime) -> tuple[list[Any], list[Any]]:
    deals = list(mt5.history_deals_get(start, end) or [])
    orders = list(mt5.history_orders_get(start, end) or [])
    return deals, orders


def _request_price(
    mt5: Any, order: Any, deal: Any
) -> tuple[float | None, str, dict[str, Any] | None]:
    order_type = int(order.type)
    native = float(order.price_open)
    # Pending orders retain their submitted trigger/limit price in history.
    if order_type not in (0, 1) and native > 0:
        return native, "NATIVE_PENDING_ORDER_PRICE_OPEN", None
    reference_time = int(order.time_setup_msc)
    reference_dt = dt.datetime.fromtimestamp(reference_time / 1000, dt.timezone.utc)
    raw = mt5.copy_ticks_range(
        str(deal.symbol),
        reference_dt - dt.timedelta(seconds=10),
        reference_dt + dt.timedelta(seconds=1),
        mt5.COPY_TICKS_INFO,
    )
    quote = quote_at_or_before(raw, reference_time)
    if quote is None or not quote["fresh"]:
        return None, "UNRECOVERABLE_REQUEST_QUOTE", quote
    side = int(deal.type)
    if side == 0:
        return float(quote["ask"]), "EXECUTABLE_ASK_AT_ORDER_SETUP", quote
    if side == 1:
        return float(quote["bid"]), "EXECUTABLE_BID_AT_ORDER_SETUP", quote
    return None, "UNSUPPORTED_DEAL_SIDE", quote


def _slippage_values(
    *, deal_side: int, request_price: float, fill_price: float, symbol_info: Any
) -> tuple[float, float]:
    adverse_price = (
        fill_price - request_price if deal_side == 0 else request_price - fill_price
    )
    adverse_bps = adverse_price / request_price * 10_000.0
    tick_size = float(symbol_info.trade_tick_size or symbol_info.point)
    tick_value_loss = float(
        symbol_info.trade_tick_value_loss or symbol_info.trade_tick_value or 0.0
    )
    tick_value_profit = float(
        symbol_info.trade_tick_value_profit or symbol_info.trade_tick_value or 0.0
    )
    tick_value = tick_value_loss if adverse_price >= 0 else tick_value_profit
    if tick_size <= 0 or tick_value <= 0:
        raise CollectionError(f"invalid tick-value metadata for {symbol_info.name}")
    adverse_usd = adverse_price / tick_size * tick_value
    return round(adverse_bps, 8), round(adverse_usd, 8)


def capture_slippage(
    mt5: Any,
    start: dt.datetime,
    end: dt.datetime,
    *,
    server_minus_utc_hours: int,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    shifted_start = start + dt.timedelta(hours=server_minus_utc_hours)
    shifted_end = end + dt.timedelta(hours=server_minus_utc_hours)
    deals, orders = _history_rows(mt5, shifted_start, shifted_end)
    order_by_ticket = {int(row.ticket): row for row in orders}
    rows: list[dict[str, Any]] = []
    offset_msc = server_minus_utc_hours * 3_600_000
    for deal in deals:
        if int(getattr(deal, "magic", 0)) not in D2G6_MAGICS:
            continue
        if int(getattr(deal, "type", -1)) not in (0, 1):
            continue
        symbol = str(getattr(deal, "symbol", ""))
        if symbol not in SYMBOL_MAP:
            continue
        raw_deal_time_msc = int(deal.time_msc)
        utc_deal_time_msc = raw_deal_time_msc - offset_msc
        row: dict[str, Any] = {
            "schema": SLIPPAGE_ROW_SCHEMA,
            "deal_ticket": int(deal.ticket),
            "order_ticket": int(deal.order),
            "position_id": int(deal.position_id),
            "magic": int(deal.magic),
            "server_time_msc": raw_deal_time_msc,
            "server_time_broker": dt.datetime.fromtimestamp(
                raw_deal_time_msc / 1000, dt.timezone.utc
            ).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3],
            "server_minus_utc_hours": server_minus_utc_hours,
            "time_utc_msc": utc_deal_time_msc,
            "time_utc": utc_iso(
                dt.datetime.fromtimestamp(utc_deal_time_msc / 1000, dt.timezone.utc)
            ),
            "symbol": symbol,
            "side": "BUY" if int(deal.type) == 0 else "SELL",
            "entry": int(deal.entry),
            "entry_label": {
                0: "IN",
                1: "OUT",
                2: "INOUT",
                3: "OUT_BY",
            }.get(int(deal.entry), f"UNKNOWN_{int(deal.entry)}"),
            "volume": float(deal.volume),
            "fill_price": float(deal.price),
        }
        order = order_by_ticket.get(int(deal.order))
        if order is None:
            row.update(
                {
                    "status": "UNMEASURED_ORDER_HISTORY_MISSING",
                    "request_price": None,
                    "request_price_source": None,
                    "slippage_bps": None,
                    "slippage_usd_per_lot": None,
                }
            )
            rows.append(row)
            continue
        row.update(
            {
                "order_type": int(order.type),
                "request_time_msc": int(order.time_setup_msc),
                "request_time_utc_msc": int(order.time_setup_msc) - offset_msc,
                "request_time_utc": utc_iso(
                    dt.datetime.fromtimestamp(
                        (int(order.time_setup_msc) - offset_msc) / 1000,
                        dt.timezone.utc,
                    )
                ),
                "ack_time_msc": int(order.time_done_msc),
                "ack_time_utc_msc": int(order.time_done_msc) - offset_msc,
                "native_order_price_open": float(order.price_open),
            }
        )
        request_price, source, quote = _request_price(mt5, order, deal)
        row["request_price"] = request_price
        row["request_price_source"] = source
        row["request_quote"] = quote
        if request_price is None or request_price <= 0:
            row.update(
                {
                    "status": "UNMEASURED_REQUEST_PRICE_UNRECOVERABLE",
                    "slippage_bps": None,
                    "slippage_usd_per_lot": None,
                }
            )
            rows.append(row)
            continue
        info = mt5.symbol_info(symbol)
        if info is None:
            row.update(
                {
                    "status": "UNMEASURED_SYMBOL_INFO_MISSING",
                    "slippage_bps": None,
                    "slippage_usd_per_lot": None,
                }
            )
            rows.append(row)
            continue
        bps, usd = _slippage_values(
            deal_side=int(deal.type),
            request_price=request_price,
            fill_price=float(deal.price),
            symbol_info=info,
        )
        row.update(
            {
                "status": "MEASURED",
                "slippage_bps": bps,
                "slippage_usd_per_lot": usd,
                "tick_size": float(info.trade_tick_size or info.point),
                "tick_value_profit": float(
                    info.trade_tick_value_profit or info.trade_tick_value or 0.0
                ),
                "tick_value_loss": float(
                    info.trade_tick_value_loss or info.trade_tick_value or 0.0
                ),
            }
        )
        rows.append(row)
    rows.sort(key=lambda row: (row["time_utc_msc"], row["deal_ticket"]))
    return rows, {
        "history_deal_count": len(deals),
        "history_order_count": len(orders),
        "d2g6_trade_deal_count": len(rows),
        "measured_count": sum(row["status"] == "MEASURED" for row in rows),
        "unmeasured_count": sum(row["status"] != "MEASURED" for row in rows),
    }


def capture_terminal(
    spec: TerminalSpec,
    windows: Sequence[tuple[str, dt.datetime, dt.datetime]],
    *,
    slippage_start: dt.datetime | None = None,
    slippage_end: dt.datetime | None = None,
) -> tuple[
    dict[str, dict[int, dict[str, Any]]],
    dict[str, Any],
    list[dict[str, Any]],
    dict[str, Any],
]:
    before = prove_preexisting_process(spec)
    try:
        import MetaTrader5 as mt5
    except ImportError as exc:  # pragma: no cover - environment dependency
        raise CollectionError("MetaTrader5 package is required") from exc
    initialized = False
    try:
        initialized = bool(
            mt5.initialize(
                path=str(spec.executable), timeout=10_000, portable=spec.portable
            )
        )
        if not initialized:
            raise CollectionError(
                f"{spec.venue}_readonly_initialize_failed:{mt5.last_error()}"
            )
        identity = _terminal_identity(mt5, spec, before)
        clock = infer_server_offset(
            mt5,
            SYMBOL_MAP["EURUSD"][spec.venue],
            dt.datetime.now(dt.timezone.utc),
        )
        identity["clock_normalization"] = clock
        offset = int(clock["server_minus_utc_hours"])
        spreads, diagnostics = capture_spreads(
            mt5, spec, windows, server_minus_utc_hours=offset
        )
        identity["symbols"] = diagnostics
        slippage: list[dict[str, Any]] = []
        slippage_diag: dict[str, Any] = {"status": "NOT_APPLICABLE"}
        if spec.venue == "FTMO" and slippage_start and slippage_end:
            slippage, slippage_diag = capture_slippage(
                mt5,
                slippage_start,
                slippage_end,
                server_minus_utc_hours=offset,
            )
            slippage_diag["status"] = "CAPTURED"
        return spreads, identity, slippage, slippage_diag
    finally:
        if initialized:
            mt5.shutdown()


def matched_spread_rows(
    ftmo: Mapping[str, Mapping[int, Mapping[str, Any]]],
    dxz: Mapping[str, Mapping[int, Mapping[str, Any]]],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for symbol in SYMBOL_MAP:
        ftmo_rows = ftmo.get(symbol) or {}
        dxz_rows = dxz.get(symbol) or {}
        for minute in sorted(set(ftmo_rows).intersection(dxz_rows)):
            left, right = ftmo_rows[minute], dxz_rows[minute]
            ftmo_mid = (float(left["bid"]) + float(left["ask"])) / 2.0
            dxz_mid = (float(right["bid"]) + float(right["ask"])) / 2.0
            ftmo_bps = (float(left["ask"]) - float(left["bid"])) / ftmo_mid * 10_000.0
            dxz_bps = (float(right["ask"]) - float(right["bid"])) / dxz_mid * 10_000.0
            rows.append(
                {
                    "schema": SPREAD_ROW_SCHEMA,
                    "minute_epoch": int(minute),
                    "minute_utc": utc_iso(
                        dt.datetime.fromtimestamp(minute, dt.timezone.utc)
                    ),
                    "utc_date": dt.datetime.fromtimestamp(
                        minute, dt.timezone.utc
                    ).date().isoformat(),
                    "utc_hour": dt.datetime.fromtimestamp(
                        minute, dt.timezone.utc
                    ).hour,
                    "session": session_name(minute),
                    "symbol": symbol,
                    "ftmo_symbol": SYMBOL_MAP[symbol]["FTMO"],
                    "dxz_symbol": SYMBOL_MAP[symbol]["DXZ"],
                    "ftmo_tick_time_msc": int(left["time_msc"]),
                    "ftmo_server_tick_time_msc": int(left["server_time_msc"]),
                    "ftmo_bid": float(left["bid"]),
                    "ftmo_ask": float(left["ask"]),
                    "ftmo_spread_bps": round(ftmo_bps, 8),
                    "dxz_tick_time_msc": int(right["time_msc"]),
                    "dxz_server_tick_time_msc": int(right["server_time_msc"]),
                    "dxz_bid": float(right["bid"]),
                    "dxz_ask": float(right["ask"]),
                    "dxz_spread_bps": round(dxz_bps, 8),
                    "ftmo_minus_dxz_bps": round(ftmo_bps - dxz_bps, 8),
                }
            )
    rows.sort(key=lambda row: (row["minute_epoch"], row["symbol"]))
    return rows


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    rows: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            if not line.strip():
                continue
            try:
                value = json.loads(line)
            except json.JSONDecodeError as exc:
                raise CollectionError(f"{path}:{number}: invalid JSONL") from exc
            if not isinstance(value, dict):
                raise CollectionError(f"{path}:{number}: row must be an object")
            rows.append(value)
    return rows


def append_unique_jsonl(
    path: Path,
    rows: Sequence[Mapping[str, Any]],
    *,
    key_fields: Sequence[str],
) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    existing = read_jsonl(path)
    keys = {
        tuple(row.get(field) for field in key_fields)
        for row in existing
    }
    additions: list[dict[str, Any]] = []
    for row in rows:
        key = tuple(row.get(field) for field in key_fields)
        if key in keys:
            continue
        additions.append(dict(row))
        keys.add(key)
    if not additions:
        return 0
    with path.open("a", encoding="utf-8", newline="\n") as handle:
        for row in additions:
            handle.write(json.dumps(row, sort_keys=True, separators=(",", ":")) + "\n")
        handle.flush()
        os.fsync(handle.fileno())
    return len(additions)


def _atomic_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    os.replace(temporary, path)


def _atomic_csv(path: Path, rows: Sequence[Mapping[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    fields = [
        "minute_utc",
        "utc_date",
        "utc_hour",
        "session",
        "symbol",
        "ftmo_symbol",
        "ftmo_tick_time_msc",
        "ftmo_server_tick_time_msc",
        "ftmo_bid",
        "ftmo_ask",
        "ftmo_spread_bps",
        "dxz_symbol",
        "dxz_tick_time_msc",
        "dxz_server_tick_time_msc",
        "dxz_bid",
        "dxz_ask",
        "dxz_spread_bps",
        "ftmo_minus_dxz_bps",
    ]
    with temporary.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    os.replace(temporary, path)


def spread_measurement(
    rows: Sequence[Mapping[str, Any]], *, generated_at: dt.datetime
) -> tuple[dict[str, Any], dict[str, float]]:
    results: list[dict[str, Any]] = []
    table: dict[str, float] = {}
    for symbol in SYMBOL_MAP:
        selected = [row for row in rows if row.get("symbol") == symbol]
        sessions = sorted({str(row["session"]) for row in selected})
        dates = sorted({str(row["utc_date"]) for row in selected})
        rollover = sum(row["session"] == "ROLLOVER_21Z" for row in selected)
        eligible = (
            len(selected) >= MIN_MATCHED_MINUTES
            and len(sessions) >= MIN_SESSION_COUNT
            and rollover > 0
        )
        deltas = [float(row["ftmo_minus_dxz_bps"]) for row in selected]
        p90 = percentile(deltas, 90)
        charge = max(0.0, float(p90)) if eligible and p90 is not None else None
        if charge is not None:
            table[f"{symbol}.DWX"] = round(charge, 8)
        reasons: list[str] = []
        if len(selected) < MIN_MATCHED_MINUTES:
            reasons.append(
                f"matched_minutes={len(selected)}<{MIN_MATCHED_MINUTES}"
            )
        if len(sessions) < MIN_SESSION_COUNT:
            reasons.append(f"sessions={len(sessions)}<{MIN_SESSION_COUNT}")
        if rollover == 0:
            reasons.append("rollover_21z_minutes=0")
        results.append(
            {
                "symbol": symbol,
                "status": "MEASURED" if eligible else "UNMEASURED",
                "matched_minute_count": len(selected),
                "minimum_required": MIN_MATCHED_MINUTES,
                "utc_dates": dates,
                "session_count": len(sessions),
                "sessions": sessions,
                "rollover_21z_minute_count": rollover,
                "ftmo_spread_bps": {
                    "p50": percentile(
                        [float(row["ftmo_spread_bps"]) for row in selected], 50
                    ),
                    "p90": percentile(
                        [float(row["ftmo_spread_bps"]) for row in selected], 90
                    ),
                },
                "dxz_spread_bps": {
                    "p50": percentile(
                        [float(row["dxz_spread_bps"]) for row in selected], 50
                    ),
                    "p90": percentile(
                        [float(row["dxz_spread_bps"]) for row in selected], 90
                    ),
                },
                "ftmo_minus_dxz_bps": {
                    "p50": percentile(deltas, 50),
                    "p90": p90,
                },
                "additional_spread_bps_rt": (
                    round(charge, 8) if charge is not None else None
                ),
                "unmeasured_reasons": reasons,
            }
        )
    return (
        {
            "schema": SCHEMA,
            "generated_at_utc": utc_iso(generated_at),
            "status": "MEASURED_ALL_SYMBOLS"
            if len(table) == len(SYMBOL_MAP)
            else "PARTIAL_UNMEASURED",
            "rule": (
                "max(0, p90(FTMO_spread_bps-DXZ_spread_bps)) over exact UTC "
                "matched minutes; >=60 minutes, >=3 sessions, and 21Z coverage required"
            ),
            "symbols": results,
            "eligible_spread_bps_rt_by_symbol": table,
        },
        table,
    )


def _summary_stats(rows: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    bps = [float(row["slippage_bps"]) for row in rows]
    usd = [float(row["slippage_usd_per_lot"]) for row in rows]
    return {
        "n": len(rows),
        "slippage_bps": {"p50": percentile(bps, 50), "p90": percentile(bps, 90)},
        "slippage_usd_per_lot": {
            "p50": percentile(usd, 50),
            "p90": percentile(usd, 90),
        },
    }


def slippage_summary(
    rows: Sequence[Mapping[str, Any]], *, generated_at: dt.datetime
) -> tuple[dict[str, Any], dict[str, float]]:
    measured = [row for row in rows if row.get("status") == "MEASURED"]
    by_symbol: dict[str, Any] = {}
    table: dict[str, float] = {}
    for symbol in sorted({str(row["symbol"]) for row in rows}.union(SYMBOL_MAP)):
        all_symbol = [row for row in rows if row.get("symbol") == symbol]
        selected = [row for row in measured if row.get("symbol") == symbol]
        entries = [row for row in selected if int(row.get("entry", -1)) in (0, 2)]
        exits = [row for row in selected if int(row.get("entry", -1)) in (1, 3)]
        entry_p90 = percentile(
            [float(row["slippage_usd_per_lot"]) for row in entries], 90
        )
        exit_p90 = percentile(
            [float(row["slippage_usd_per_lot"]) for row in exits], 90
        )
        rt = None
        if entry_p90 is not None and exit_p90 is not None:
            rt = max(0.0, entry_p90) + max(0.0, exit_p90)
            table[f"{symbol}.DWX"] = round(rt, 8)
        by_hour: dict[str, Any] = {}
        for hour in range(24):
            hour_rows = [
                row
                for row in selected
                if dt.datetime.fromtimestamp(
                    int(row["time_utc_msc"]) / 1000, dt.timezone.utc
                ).hour
                == hour
            ]
            by_hour[f"{hour:02d}"] = _summary_stats(hour_rows)
        by_day: dict[str, Any] = {}
        daily_by_hour: dict[str, Any] = {}
        for date in sorted(
            {
                dt.datetime.fromtimestamp(
                    int(row["time_utc_msc"]) / 1000, dt.timezone.utc
                ).date().isoformat()
                for row in selected
            }
        ):
            date_rows = [
                row
                for row in selected
                if dt.datetime.fromtimestamp(
                    int(row["time_utc_msc"]) / 1000, dt.timezone.utc
                ).date().isoformat()
                == date
            ]
            by_day[date] = _summary_stats(date_rows)
            daily_by_hour[date] = {
                f"{hour:02d}": _summary_stats(
                    [
                        row
                        for row in date_rows
                        if dt.datetime.fromtimestamp(
                            int(row["time_utc_msc"]) / 1000, dt.timezone.utc
                        ).hour
                        == hour
                    ]
                )
                for hour in range(24)
            }
        by_symbol[symbol] = {
            "status": "MEASURED_ROUND_TRIP" if rt is not None else "UNMEASURED",
            "deal_count": len(all_symbol),
            "measured_deal_count": len(selected),
            "unmeasured_deal_count": len(all_symbol) - len(selected),
            "entry_measured_count": len(entries),
            "exit_measured_count": len(exits),
            "all_deals": _summary_stats(selected),
            "by_utc_hour": by_hour,
            "by_utc_date": by_day,
            "daily_by_utc_hour": daily_by_hour,
            "round_trip_rule": (
                "max(0,p90(entry USD/lot))+max(0,p90(exit USD/lot)); "
                "requires at least one measured entry and exit"
            ),
            "additional_slippage_usd_per_lot_rt": (
                round(rt, 8) if rt is not None else None
            ),
        }
    return (
        {
            "schema": SUMMARY_SCHEMA,
            "generated_at_utc": utc_iso(generated_at),
            "deal_count": len(rows),
            "measured_deal_count": len(measured),
            "symbols": by_symbol,
            "eligible_slippage_usd_per_lot_rt_by_symbol": table,
        },
        table,
    )


class _ExclusiveLock:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.handle: Any = None

    def __enter__(self) -> "_ExclusiveLock":
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.handle = self.path.open("a+b")
        try:
            if os.name == "nt":
                import msvcrt

                if self.handle.tell() == 0:
                    self.handle.write(b"\0")
                    self.handle.flush()
                self.handle.seek(0)
                msvcrt.locking(self.handle.fileno(), msvcrt.LK_NBLCK, 1)
            else:  # pragma: no cover - Windows production path
                import fcntl

                fcntl.flock(self.handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as exc:
            self.handle.close()
            self.handle = None
            raise CollectionError(f"collector_lock_exists:{self.path}") from exc
        self.handle.seek(0)
        self.handle.truncate()
        self.handle.write(f"pid={os.getpid()}\n".encode())
        self.handle.flush()
        return self

    def __exit__(self, exc_type: Any, exc: Any, tb: Any) -> None:
        if self.handle is None:
            return
        if os.name == "nt":
            import msvcrt

            self.handle.seek(0)
            msvcrt.locking(self.handle.fileno(), msvcrt.LK_UNLCK, 1)
        else:  # pragma: no cover - Windows production path
            import fcntl

            fcntl.flock(self.handle.fileno(), fcntl.LOCK_UN)
        self.handle.close()
        self.handle = None


def collect_once(
    *,
    output_root: Path = OUTPUT_ROOT,
    start: dt.datetime,
    end: dt.datetime,
    session_only: bool,
) -> dict[str, Any]:
    start, end = start.astimezone(dt.timezone.utc), end.astimezone(dt.timezone.utc)
    if start < STUDY_START:
        start = STUDY_START
    windows = (
        session_sample_windows(start, end)
        if session_only
        else contiguous_hour_windows(start, end)
    )
    if not windows:
        raise CollectionError("no eligible collection windows")
    output_root = output_root.resolve()
    spread_ledger = output_root / "spread_matched.jsonl"
    slippage_ledger = output_root / "slippage_ledger.jsonl"
    with _ExclusiveLock(output_root / ".collector.lock"):
        ftmo_rows, ftmo_identity, slippage_rows, slippage_diag = capture_terminal(
            FTMO,
            windows,
            slippage_start=STUDY_START,
            slippage_end=end,
        )
        dxz_rows, dxz_identity, _, _ = capture_terminal(DXZ, windows)
        new_spreads = matched_spread_rows(ftmo_rows, dxz_rows)
        spread_additions = append_unique_jsonl(
            spread_ledger,
            new_spreads,
            key_fields=("symbol", "minute_epoch"),
        )
        slippage_additions = append_unique_jsonl(
            slippage_ledger,
            slippage_rows,
            key_fields=("deal_ticket",),
        )
        all_spreads = read_jsonl(spread_ledger)
        all_spreads.sort(key=lambda row: (row["minute_epoch"], row["symbol"]))
        all_slippage = read_jsonl(slippage_ledger)
        all_slippage.sort(
            key=lambda row: (row["time_utc_msc"], row["deal_ticket"])
        )
        measurement, spread_table = spread_measurement(
            all_spreads, generated_at=end
        )
        slip_summary, slip_table = slippage_summary(
            all_slippage, generated_at=end
        )
        measurement["slippage"] = slip_summary
        measurement["slippage_usd_per_lot_rt_by_symbol"] = slip_table
        _atomic_csv(output_root / "spread_matched.csv", all_spreads)
        _atomic_json(output_root / "measurements.json", measurement)
        _atomic_json(output_root / "spread_bps_rt_by_symbol.json", spread_table)
        _atomic_json(
            output_root / "slippage_usd_per_lot_rt_by_symbol.json", slip_table
        )
        _atomic_json(output_root / "slippage_daily_summary.json", slip_summary)
        state = {
            "schema": STATE_SCHEMA,
            "task_id": TASK_ID,
            "collected_at_utc": utc_iso(end),
            "window": {
                "start_utc": utc_iso(start),
                "end_utc": utc_iso(end),
                "session_only": session_only,
                "query_window_count": len(windows),
            },
            "status": measurement["status"],
            "new_spread_rows": spread_additions,
            "total_spread_rows": len(all_spreads),
            "new_slippage_rows": slippage_additions,
            "total_slippage_rows": len(all_slippage),
            "ftmo": ftmo_identity,
            "dxz": dxz_identity,
            "slippage_capture": slippage_diag,
            "authorization": {
                "terminal_launch": False,
                "terminal_control": False,
                "trade_call": False,
                "order_action": False,
                "autotrading_toggle": False,
            },
            "outputs": {},
        }
        for path in (
            spread_ledger,
            slippage_ledger,
            output_root / "spread_matched.csv",
            output_root / "measurements.json",
            output_root / "spread_bps_rt_by_symbol.json",
            output_root / "slippage_usd_per_lot_rt_by_symbol.json",
            output_root / "slippage_daily_summary.json",
        ):
            if path.exists():
                state["outputs"][path.name] = {
                    "path": str(path),
                    "sha256": sha256_file(path),
                    "size_bytes": path.stat().st_size,
                }
        _atomic_json(output_root / "collector_state.json", state)
        return state


def scheduled_collect(
    *, now: dt.datetime | None = None, output_root: Path = OUTPUT_ROOT
) -> dict[str, Any]:
    """Collect a 45-minute overlap window for the existing 30-minute pulse."""
    end = (now or dt.datetime.now(dt.timezone.utc)).astimezone(dt.timezone.utc)
    start = max(STUDY_START, end - dt.timedelta(minutes=45))
    return collect_once(
        output_root=output_root,
        start=start,
        end=end,
        session_only=False,
    )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-root", type=Path, default=OUTPUT_ROOT)
    parser.add_argument("--start-utc")
    parser.add_argument("--end-utc")
    parser.add_argument(
        "--session-sample-only",
        action="store_true",
        help="query only 00Z, 08Z, 14Z and 21Z one-hour windows per weekday",
    )
    args = parser.parse_args(argv)
    end = parse_utc(args.end_utc) if args.end_utc else dt.datetime.now(dt.timezone.utc)
    start = (
        parse_utc(args.start_utc)
        if args.start_utc
        else max(STUDY_START, end - dt.timedelta(minutes=45))
    )
    state = collect_once(
        output_root=args.output_root,
        start=start,
        end=end,
        session_only=bool(args.session_sample_only),
    )
    print(json.dumps(state, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
