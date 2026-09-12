#!/usr/bin/env python3
"""Capture read-only FTMO symbol/deal cost receipts from an already-running terminal."""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SYMBOLS = ("GBPUSD", "EURUSD", "USDCAD", "USOIL.cash")
EXPECTED_LOGIN = 1514536732
EXPECTED_SERVER = "FTMO-Demo"
EXPECTED_DATA = Path(r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prove_running(exe: Path) -> dict[str, Any]:
    script = (
        "$p=Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe'\" | "
        "Where-Object {$_.ExecutablePath -eq '" + str(exe).replace("'", "''") + "'}; "
        "$p | Select-Object ProcessId,ExecutablePath | ConvertTo-Json -Compress"
    )
    result = subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", script], capture_output=True, text=True, timeout=30, creationflags=0x08000000)
    if result.returncode != 0 or not result.stdout.strip():
        raise RuntimeError("FTMO terminal is not proven already running; refusing initialize")
    value = json.loads(result.stdout)
    rows = value if isinstance(value, list) else [value]
    if len(rows) != 1:
        raise RuntimeError(f"expected exactly one running FTMO terminal, got {len(rows)}")
    return {"process_id": int(rows[0]["ProcessId"]), "executable_path": rows[0]["ExecutablePath"]}


def values(row: Any, fields: tuple[str, ...]) -> dict[str, Any]:
    return {field: getattr(row, field) for field in fields}


def slippage_rows(deals: list[Any], orders: list[Any]) -> tuple[list[dict[str, Any]], str]:
    order_by_ticket = {int(row.ticket): row for row in orders}
    rows = []
    missing_quote = False
    for deal in deals:
        order = order_by_ticket.get(int(deal.order))
        if order is None:
            continue
        requested = float(order.price_open)
        if requested <= 0:
            missing_quote = True
            rows.append({"deal": int(deal.ticket), "order": int(order.ticket), "status": "MISSING_REQUEST_PRICE_MARKET_EXECUTION", "fill_price": float(deal.price), "requested_price": None})
            continue
        # MT5 deal type 0=buy, 1=sell. Positive is adverse in price units.
        adverse = float(deal.price) - requested if int(deal.type) == 0 else requested - float(deal.price)
        rows.append({"deal": int(deal.ticket), "order": int(order.ticket), "status": "REQUEST_PRICE_VS_FILL_ONLY_NO_EXECUTABLE_QUOTE", "fill_price": float(deal.price), "requested_price": requested, "adverse_price_delta": round(adverse, 12), "request_time_msc": int(order.time_setup_msc), "fill_time_msc": int(deal.time_msc)})
        missing_quote = True
    status = "MISSING_NO_FILL" if not deals else ("INCOMPLETE_NO_EXECUTABLE_QUOTE" if missing_quote else "COMPLETE")
    return rows, status


def capture(mt5: Any, symbol: str, start: datetime, end: datetime, generated_at: str, terminal: Any, account: Any, process: dict[str, Any]) -> dict[str, Any]:
    spec = mt5.symbol_info(symbol)
    tick = mt5.symbol_info_tick(symbol)
    if spec is None or tick is None:
        raise RuntimeError(f"symbol info unavailable: {symbol}: {mt5.last_error()}")
    deals = list(mt5.history_deals_get(start, end, group=symbol) or [])
    orders = list(mt5.history_orders_get(start, end, group=symbol) or [])
    trade_deals = [row for row in deals if str(row.symbol) == symbol and int(row.entry) in (0, 1, 2)]
    trade_orders = [row for row in orders if str(row.symbol) == symbol]
    slippage, slippage_status = slippage_rows(trade_deals, trade_orders)
    entry_volume = sum(float(row.volume) for row in trade_deals if int(row.entry) in (0, 2))
    commission = sum(float(row.commission) + float(row.fee) for row in trade_deals)
    commission_status = "OBSERVED_NATIVE_DEALS" if trade_deals and entry_volume > 0 else "MISSING_NO_FILL"
    ask, bid = float(tick.ask), float(tick.bid)
    buy_margin = mt5.order_calc_margin(mt5.ORDER_TYPE_BUY, symbol, 1.0, ask)
    sell_margin = mt5.order_calc_margin(mt5.ORDER_TYPE_SELL, symbol, 1.0, bid)
    return {
        "schema": "qm.ftmo-native-cost-receipt/v1",
        "generated_at_utc": generated_at,
        "mode": "READ_ONLY_ALREADY_RUNNING_TERMINAL_IPC",
        "account": {"login": int(account.login), "server": str(account.server), "currency": str(account.currency), "leverage": int(account.leverage)},
        "terminal": {"process": process, "build": int(terminal.build), "data_path": str(terminal.data_path)},
        "window": {"start_utc": start.isoformat(), "end_utc": end.isoformat()},
        "symbol": symbol,
        "symbol_spec": {key: getattr(spec, key) for key in ("volume_min", "volume_step", "volume_max", "point", "trade_tick_size", "trade_tick_value", "trade_tick_value_profit", "trade_tick_value_loss", "trade_contract_size", "swap_mode", "swap_long", "swap_short", "swap_rollover3days", "trade_calc_mode", "currency_base", "currency_profit", "currency_margin")},
        "quote": {"time_msc": int(tick.time_msc), "bid": bid, "ask": ask, "last": float(tick.last), "source": "symbol_info_tick_at_capture"},
        "margin_1_lot": {"buy_at_ask_account_currency": buy_margin, "sell_at_bid_account_currency": sell_margin, "account_currency": str(account.currency)},
        "native_commission": {"status": commission_status, "deal_commission_plus_fee": round(commission, 8) if commission_status != "MISSING_NO_FILL" else None, "entry_lots": round(entry_volume, 8), "round_trip_usd_per_entry_lot": round(abs(commission) / entry_volume, 8) if commission_status != "MISSING_NO_FILL" else None},
        "fill_slippage": {"status": slippage_status, "observations": slippage, "value_for_cost_model": None, "reason": "No request-time executable quote is captured; request-price/fill deltas are evidence but not a complete slippage estimator." if trade_deals else "No native fill exists for this symbol in the collector window."},
        "deals": [values(row, ("ticket", "order", "time_msc", "type", "entry", "magic", "position_id", "volume", "price", "commission", "swap", "profit", "fee", "symbol", "comment")) for row in trade_deals],
        "orders": [values(row, ("ticket", "time_setup_msc", "time_done_msc", "type", "state", "magic", "position_id", "volume_initial", "volume_current", "price_open", "price_current", "symbol", "comment", "reason")) for row in trade_orders],
        "cost_eligible": commission_status == "OBSERVED_NATIVE_DEALS" and slippage_status == "COMPLETE",
        "authorization": {"terminal_launch": False, "terminal_control": False, "trade_call": False, "order_action": False, "autotrading_toggle": False},
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--terminal-exe", type=Path, required=True)
    parser.add_argument("--start-utc", default="2026-09-06T19:38:00+00:00")
    parser.add_argument("--generated-at-utc", required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    process = prove_running(args.terminal_exe)
    import MetaTrader5 as mt5
    initialized = False
    try:
        initialized = bool(mt5.initialize(path=str(args.terminal_exe), timeout=10_000))
        if not initialized:
            raise RuntimeError(f"read-only MT5 initialize failed: {mt5.last_error()}")
        terminal, account = mt5.terminal_info(), mt5.account_info()
        if terminal is None or account is None:
            raise RuntimeError(f"terminal/account snapshot missing: {mt5.last_error()}")
        if int(account.login) != EXPECTED_LOGIN or str(account.server) != EXPECTED_SERVER:
            raise RuntimeError(f"account identity mismatch: {account.login}/{account.server}")
        if Path(str(terminal.data_path)).resolve() != EXPECTED_DATA.resolve():
            raise RuntimeError(f"data-path mismatch: {terminal.data_path}")
        start = datetime.fromisoformat(args.start_utc.replace("Z", "+00:00"))
        end = datetime.fromisoformat(args.generated_at_utc.replace("Z", "+00:00"))
        args.output_dir.mkdir(parents=True, exist_ok=True)
        paths = []
        for symbol in SYMBOLS:
            receipt = capture(mt5, symbol, start, end, args.generated_at_utc, terminal, account, process)
            path = args.output_dir / f"{symbol.replace('.', '_')}_native_cost_receipt.json"
            path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            paths.append(path)
        manifest = {"schema": "qm.ftmo-native-cost-receipt-manifest/v1", "generated_at_utc": args.generated_at_utc, "receipts": [{"symbol": symbol, "path": path.name, "sha256": sha256(path)} for symbol, path in zip(SYMBOLS, paths)], "count": len(paths)}
        manifest_path = args.output_dir / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(json.dumps(manifest, indent=2))
        return 0
    finally:
        if initialized:
            mt5.shutdown()


if __name__ == "__main__":
    raise SystemExit(main())
