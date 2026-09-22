#!/usr/bin/env python3
"""Capture the pinned FTMO incident without sending a trading request.

The collector refuses to initialize MetaTrader5 unless exactly one instance of
the expected FTMO terminal is already running.  It calls only terminal/account/
symbol/history inventory methods; it never selects a symbol, checks or sends an
order, controls the terminal, or changes AutoTrading.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

import psutil


TASK_ID = "6fa7831a-1a6d-42b6-9307-dfc39eb12b6c"
TERMINAL_EXE = Path(r"C:\Program Files\FTMO Global Markets MT5 Terminal\terminal64.exe")
DATA_DIR = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal"
    r"\81A933A9AFC5DE3C23B15CAB19C63850"
)
EXPECTED_LOGIN = 1514536732
EXPECTED_SERVER = "FTMO-Demo"
PULSE = Path(r"D:\QM\reports\state\ftmo_trial_pulse.json")
EA_13213 = DATA_DIR / "MQL5/Files/QM/QM5_13213_ea-13213.log"
EA_10403 = DATA_DIR / "MQL5/Files/QM/QM5_10403_ea-10403.log"
JOURNAL_21 = DATA_DIR / "logs/20260921.log"
JOURNAL_22 = DATA_DIR / "logs/20260922.log"
SYMBOLS = {
    "USDJPY": "USDJPY",
    "XAUUSD": "XAUUSD",
    "USDCAD": "USDCAD",
    # Governed strategy symbol XTIUSD maps to the FTMO native symbol below.
    "XTIUSD": "USOIL.cash",
    "GBPUSD": "GBPUSD",
    "EURUSD": "EURUSD",
}
TARGET_ORDER_TICKETS = {546985040, 546985290, 547007430}
TARGET_DEAL_TICKETS = {524247545}
TRADE_MODE_LABELS = {
    0: "SYMBOL_TRADE_MODE_DISABLED",
    1: "SYMBOL_TRADE_MODE_LONGONLY",
    2: "SYMBOL_TRADE_MODE_SHORTONLY",
    3: "SYMBOL_TRADE_MODE_CLOSEONLY",
    4: "SYMBOL_TRADE_MODE_FULL",
}
ORDER_STATE_LABELS = {
    0: "ORDER_STATE_STARTED",
    1: "ORDER_STATE_PLACED",
    2: "ORDER_STATE_CANCELED",
    3: "ORDER_STATE_PARTIAL",
    4: "ORDER_STATE_FILLED",
    5: "ORDER_STATE_REJECTED",
    6: "ORDER_STATE_EXPIRED",
    7: "ORDER_STATE_REQUEST_ADD",
    8: "ORDER_STATE_REQUEST_MODIFY",
    9: "ORDER_STATE_REQUEST_CANCEL",
}


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def iso_utc(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def file_binding(path: Path) -> dict[str, Any]:
    stat = path.stat()
    return {
        "path": str(path),
        "bytes": stat.st_size,
        "sha256": sha256(path),
    }


def normalized(path: str | Path) -> str:
    return os.path.normcase(os.path.normpath(str(path)))


def ftmo_processes() -> list[psutil.Process]:
    expected = normalized(TERMINAL_EXE)
    return [
        process
        for process in psutil.process_iter(["pid", "exe", "create_time"])
        if normalized(process.info.get("exe") or "") == expected
    ]


def numbered_lines(path: Path, encoding: str) -> list[dict[str, Any]]:
    text = path.read_bytes().decode(encoding, errors="strict").lstrip("\ufeff")
    return [
        {"line": index, "text": line.lstrip("\ufeff")}
        for index, line in enumerate(text.splitlines(), start=1)
    ]


def selected_log_evidence() -> tuple[dict[str, Any], int]:
    ea13213 = numbered_lines(EA_13213, "utf-8")
    ea10403 = numbered_lines(EA_10403, "utf-8")
    j21 = numbered_lines(JOURNAL_21, "utf-16-le")
    j22 = numbered_lines(JOURNAL_22, "utf-16-le")

    prior_usdjpy = [
        row for row in ea13213
        if '"ts_utc":"2026-09-21T03:00:' in row["text"]
        and any(marker in row["text"] for marker in ('"ENTRY_ACCEPTED"', '"TM_OPEN"'))
    ]
    incident = [
        row for row in ea13213
        if '"ts_utc":"2026-09-22T03:00:' in row["text"]
    ]
    xau_accepted = [
        row for row in ea10403
        if '"ts_utc":"2026-09-21T22:05:' in row["text"]
        and any(marker in row["text"] for marker in ('"ENTRY_ACCEPTED"', '"TM_OPEN"'))
    ]
    reconnect = [
        row for row in j21
        if "23:01:" in row["text"]
        and any(marker in row["text"] for marker in ("authorized on", "trading has been enabled"))
    ]
    journal_incident = [
        row for row in j22
        if any(marker in row["text"] for marker in ("XAUUSD", "USDCAD", "USDJPY"))
    ]

    incident_json = next(
        json.loads(row["text"])
        for row in incident
        if '"BROKER_TRADE_DISABLED"' in row["text"]
    )
    utc_value = datetime.fromisoformat(incident_json["ts_utc"].replace("Z", "+00:00"))
    broker_value = datetime.fromisoformat(incident_json["ts_broker"])
    # ts_broker is second-resolution while ts_utc carries milliseconds.
    offset_seconds = round(
        (broker_value - utc_value.replace(tzinfo=None)).total_seconds()
    )
    if offset_seconds != 3 * 3600:
        raise RuntimeError(f"unexpected broker UTC offset: {offset_seconds}")

    return ({
        "files": {
            "ea_13213": file_binding(EA_13213),
            "ea_10403": file_binding(EA_10403),
            "journal_20260921": file_binding(JOURNAL_21),
            "journal_20260922": file_binding(JOURNAL_22),
        },
        "ea_13213_prior_day_same_anchor_success": prior_usdjpy,
        "ea_13213_incident": incident,
        "ea_10403_xau_orders_accepted_before_account_close": xau_accepted,
        "journal_reauthorization_and_trade_enable": reconnect,
        "journal_cross_symbol_timeline": journal_incident,
        "clock_binding": {
            "ea_ts_utc": incident_json["ts_utc"],
            "ea_ts_broker": incident_json["ts_broker"],
            "broker_utc_offset_seconds": offset_seconds,
            "journal_clock": "Europe/Berlin local time (UTC+02 on 2026-09-22)",
            "finding": (
                "Journal 05:00 is 03:00Z and 06:00 FTMO server time; it is not "
                "05:00 server time."
            ),
        },
    }, offset_seconds)


def history_time(value: int, broker_offset_seconds: int) -> dict[str, Any] | None:
    if not value:
        return None
    # On this terminal/account, history integer times render as the same wall
    # clock shown by the EA's ts_broker.  Bind that interpretation to the
    # independently measured +03 offset above instead of labelling it UTC.
    broker_wall = datetime.fromtimestamp(value, timezone.utc).replace(tzinfo=None)
    inferred_utc = (broker_wall - timedelta(seconds=broker_offset_seconds)).replace(
        tzinfo=timezone.utc
    )
    return {
        "raw_epoch": int(value),
        "server_wall_time": broker_wall.isoformat(timespec="seconds"),
        "inferred_utc": iso_utc(inferred_utc),
        "europe_berlin": inferred_utc.astimezone(ZoneInfo("Europe/Berlin")).isoformat(
            timespec="seconds"
        ),
    }


def capture_mt5(broker_offset_seconds: int) -> dict[str, Any]:
    processes = ftmo_processes()
    if len(processes) != 1:
        raise RuntimeError(
            f"expected exactly one already-running FTMO terminal, got {len(processes)}"
        )
    pinned_pid = processes[0].pid

    import MetaTrader5 as mt5

    initialized = False
    try:
        initialized = bool(mt5.initialize(path=str(TERMINAL_EXE), timeout=10_000))
        if not initialized:
            raise RuntimeError(f"read-only initialize failed: {mt5.last_error()}")
        terminal = mt5.terminal_info()
        account = mt5.account_info()
        if terminal is None or account is None:
            raise RuntimeError(f"terminal/account snapshot missing: {mt5.last_error()}")
        if Path(str(terminal.data_path)).resolve() != DATA_DIR.resolve():
            raise RuntimeError(f"terminal data path mismatch: {terminal.data_path}")
        if int(account.login) != EXPECTED_LOGIN or str(account.server) != EXPECTED_SERVER:
            raise RuntimeError(f"account identity mismatch: {account.login}/{account.server}")

        symbols: list[dict[str, Any]] = []
        for logical, broker_symbol in SYMBOLS.items():
            info = mt5.symbol_info(broker_symbol)
            if info is None:
                raise RuntimeError(f"symbol_info unavailable: {broker_symbol}: {mt5.last_error()}")
            trade_mode = int(info.trade_mode)
            symbols.append({
                "logical_symbol": logical,
                "broker_symbol": broker_symbol,
                "selected": bool(info.select),
                "visible": bool(info.visible),
                "custom": bool(info.custom),
                "symbol_trade_mode": trade_mode,
                "symbol_trade_mode_label": TRADE_MODE_LABELS.get(trade_mode, "UNKNOWN"),
                "symbol_start_time": int(info.start_time),
                "symbol_expiration_time": int(info.expiration_time),
                "trade_execution_mode": int(info.trade_exemode),
                "last_quote_epoch": int(info.time),
                "bid": float(info.bid),
                "ask": float(info.ask),
                "path": str(info.path),
                "description": str(info.description),
            })

        positions = list(mt5.positions_get() or [])
        orders = list(mt5.orders_get() or [])
        start = datetime(2026, 9, 20, tzinfo=timezone.utc)
        end = utc_now() + timedelta(days=1)
        history_orders = list(mt5.history_orders_get(start, end) or [])
        history_deals = list(mt5.history_deals_get(start, end) or [])

        selected_orders = []
        for row in history_orders:
            if int(row.ticket) not in TARGET_ORDER_TICKETS:
                continue
            selected_orders.append({
                "ticket": int(row.ticket),
                "symbol": str(row.symbol),
                "magic": int(row.magic),
                "position_id": int(row.position_id),
                "order_type": int(row.type),
                "state": int(row.state),
                "state_label": ORDER_STATE_LABELS.get(int(row.state), "UNKNOWN"),
                "reason": int(row.reason),
                "volume_initial": float(row.volume_initial),
                "volume_current": float(row.volume_current),
                "price_open": float(row.price_open),
                "comment": str(row.comment),
                "time_setup": history_time(int(row.time_setup), broker_offset_seconds),
                "time_done": history_time(int(row.time_done), broker_offset_seconds),
                "time_expiration": history_time(
                    int(row.time_expiration), broker_offset_seconds
                ),
            })

        selected_deals = []
        for row in history_deals:
            if int(row.ticket) not in TARGET_DEAL_TICKETS:
                continue
            selected_deals.append({
                "ticket": int(row.ticket),
                "order": int(row.order),
                "position_id": int(row.position_id),
                "symbol": str(row.symbol),
                "magic": int(row.magic),
                "deal_type": int(row.type),
                "entry": int(row.entry),
                "reason": int(row.reason),
                "volume": float(row.volume),
                "price": float(row.price),
                "profit": float(row.profit),
                "comment": str(row.comment),
                "time": history_time(int(row.time), broker_offset_seconds),
            })

        after = ftmo_processes()
        if len(after) != 1 or after[0].pid != pinned_pid:
            raise RuntimeError("FTMO process identity changed during capture")

        return {
            "capture_utc": iso_utc(utc_now()),
            "mode": "READ_ONLY_ALREADY_RUNNING_TERMINAL_IPC",
            "process": {
                "pid": pinned_pid,
                "executable": str(TERMINAL_EXE),
                "already_running_before_initialize": True,
                "same_pid_after_capture": True,
            },
            "terminal": {
                "connected": bool(terminal.connected),
                "build": int(terminal.build),
                "data_path": str(terminal.data_path),
                "terminal_trade_allowed": bool(terminal.trade_allowed),
                "tradeapi_disabled": bool(terminal.tradeapi_disabled),
            },
            "account": {
                "login": int(account.login),
                "server": str(account.server),
                "name": str(account.name),
                "trade_mode": int(account.trade_mode),
                "account_trade_allowed": bool(account.trade_allowed),
                "account_trade_expert": bool(account.trade_expert),
                "leverage": int(account.leverage),
                "balance": float(account.balance),
                "equity": float(account.equity),
            },
            "symbols": symbols,
            "current_inventory": {
                "positions": len(positions),
                "pending_orders": len(orders),
            },
            "account_close_history": {
                "orders": sorted(selected_orders, key=lambda row: row["ticket"]),
                "deals": sorted(selected_deals, key=lambda row: row["ticket"]),
                "time_interpretation": (
                    "History integer times align with broker wall time on this account; UTC is "
                    "derived using the +03 offset independently bound from EA ts_utc/ts_broker."
                ),
            },
        }
    finally:
        if initialized:
            mt5.shutdown()


def pulse_evidence() -> dict[str, Any]:
    pulse = json.loads(PULSE.read_text(encoding="utf-8"))
    return {
        "file": file_binding(PULSE),
        "checked_at_utc": pulse.get("checked_at_utc"),
        "verdict": pulse.get("verdict"),
        "effective_state": pulse.get("effective_state"),
        "terminal_up": pulse.get("terminal_up"),
        "alarms": pulse.get("alarms"),
        "open_positions": pulse.get("open_positions"),
        "pending_orders": pulse.get("pending_orders"),
        "equity": pulse.get("equity"),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    logs, broker_offset_seconds = selected_log_evidence()
    result = {
        "schema": "qm.ftmo-trade-disabled-readonly-capture/v1",
        "task_id": TASK_ID,
        "authorization": {
            "terminal_launch": False,
            "terminal_restart": False,
            "terminal_control": False,
            "symbol_select": False,
            "trade_call": False,
            "order_check": False,
            "order_send": False,
            "order_modify_or_cancel": False,
            "autotrading_toggle": False,
        },
        "logs": logs,
        "terminal_snapshot": capture_mt5(broker_offset_seconds),
        "pulse": pulse_evidence(),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(result, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
    args.output.write_text(payload, encoding="utf-8")
    print(json.dumps({
        "output": str(args.output),
        "sha256": hashlib.sha256(payload.encode("utf-8")).hexdigest(),
        "bytes": len(payload.encode("utf-8")),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
