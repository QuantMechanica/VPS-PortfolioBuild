#!/usr/bin/env python3
"""Reconstruct FTMO request-time executable quotes from read-only MT5 history.

The collector attaches only to the one already-running, identity-pinned FTMO
demo terminal.  It reads order/deal history plus the broker tick archive and
writes immutable receipts beneath D:/QM/reports/ftmo/slippage_stream.  It has no
trading, terminal-control, AutoTrading, or scheduler surface.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping

try:
    from tools.strategy_farm.portfolio.collect_ftmo_native_cost_receipts import (
        EXPECTED_DATA,
        EXPECTED_LOGIN,
        EXPECTED_SERVER,
        SYMBOLS,
        prove_running,
    )
except ModuleNotFoundError:  # pragma: no cover - direct script execution
    from collect_ftmo_native_cost_receipts import (  # type: ignore
        EXPECTED_DATA,
        EXPECTED_LOGIN,
        EXPECTED_SERVER,
        SYMBOLS,
        prove_running,
    )


SCHEMA = "qm.ftmo-request-quote-slippage-stream/v1"
MANIFEST_SCHEMA = "qm.ftmo-request-quote-slippage-manifest/v1"
ALLOWED_OUTPUT_ROOT = Path(r"D:\QM\reports\ftmo\slippage_stream")
MAX_QUOTE_AGE_MSC = 2_000
MARKET_ORDER_TYPES = frozenset({0, 1})


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_utc(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("UTC timestamp must include an offset")
    return parsed.astimezone(timezone.utc)


def validate_window(start: datetime, end: datetime) -> None:
    if start.weekday() != 0:
        raise ValueError("collection window must start on Monday UTC")
    if end <= start or end - start < timedelta(days=5):
        raise ValueError("collection window must cover at least five trading days")


def validate_output_dir(output_dir: Path) -> Path:
    root = ALLOWED_OUTPUT_ROOT.resolve()
    resolved = output_dir.resolve()
    if resolved.parent != root:
        raise ValueError(f"output must be one fresh direct child of {root}")
    if resolved.exists():
        raise ValueError(f"immutable output already exists: {resolved}")
    return resolved


def quote_at_or_before(
    ticks: Iterable[Mapping[str, Any]], reference_time_msc: int
) -> dict[str, Any] | None:
    candidates = [
        tick for tick in ticks
        if int(tick["time_msc"]) <= reference_time_msc
        and float(tick["bid"]) > 0
        and float(tick["ask"]) > 0
    ]
    if not candidates:
        return None
    tick = max(candidates, key=lambda row: int(row["time_msc"]))
    age = reference_time_msc - int(tick["time_msc"])
    return {
        "time_msc": int(tick["time_msc"]),
        "bid": float(tick["bid"]),
        "ask": float(tick["ask"]),
        "flags": int(tick.get("flags") or 0),
        "age_msc": age,
        "fresh": age <= MAX_QUOTE_AGE_MSC,
    }


def reference_contract(order: Any, deal: Any) -> dict[str, Any]:
    order_type = int(order.type)
    if order_type in MARKET_ORDER_TYPES:
        return {
            "kind": "ORDER_REQUEST_TIME",
            "time_msc": int(order.time_setup_msc),
            "basis": "order.time_setup_msc",
        }
    return {
        "kind": "PENDING_TRIGGER_FILL_TIME",
        "time_msc": int(deal.time_msc),
        "basis": "deal.time_msc; original pending-order setup quote is not a fill reference",
    }


def signed_adverse_points(side: int, fill: float, quote: Mapping[str, Any], point: float) -> float:
    if side == 0:  # buy pays ask
        delta = fill - float(quote["ask"])
    elif side == 1:  # sell receives bid
        delta = float(quote["bid"]) - fill
    else:
        raise ValueError(f"unsupported deal side: {side}")
    return round(delta / point, 8)


def _tick_rows(raw: Any) -> list[dict[str, Any]]:
    if raw is None:
        return []
    return [
        {
            "time_msc": int(row["time_msc"]),
            "bid": float(row["bid"]),
            "ask": float(row["ask"]),
            "flags": int(row["flags"]),
        }
        for row in raw
    ]


def capture_symbol(mt5: Any, symbol: str, start: datetime, end: datetime) -> dict[str, Any]:
    spec = mt5.symbol_info(symbol)
    if spec is None or float(spec.point) <= 0:
        raise RuntimeError(f"symbol metadata unavailable: {symbol}: {mt5.last_error()}")
    deals = [
        row for row in list(mt5.history_deals_get(start, end, group=symbol) or [])
        if str(row.symbol) == symbol and int(row.entry) in (0, 1, 2)
        and int(row.type) in (0, 1)
    ]
    orders = {
        int(row.ticket): row
        for row in list(mt5.history_orders_get(start, end, group=symbol) or [])
        if str(row.symbol) == symbol
    }
    observations: list[dict[str, Any]] = []
    for deal in deals:
        order = orders.get(int(deal.order))
        if order is None:
            observations.append({
                "deal_ticket": int(deal.ticket),
                "order_ticket": int(deal.order),
                "status": "INCOMPLETE_ORDER_HISTORY_MISSING",
            })
            continue
        reference = reference_contract(order, deal)
        reference_dt = datetime.fromtimestamp(reference["time_msc"] / 1000, tz=timezone.utc)
        raw_ticks = mt5.copy_ticks_range(
            symbol,
            reference_dt - timedelta(seconds=10),
            reference_dt + timedelta(seconds=1),
            mt5.COPY_TICKS_ALL,
        )
        quote = quote_at_or_before(_tick_rows(raw_ticks), reference["time_msc"])
        status = "COMPLETE" if quote is not None and quote["fresh"] else (
            "INCOMPLETE_NO_PRIOR_QUOTE" if quote is None else "INCOMPLETE_STALE_QUOTE"
        )
        observation: dict[str, Any] = {
            "deal_ticket": int(deal.ticket),
            "order_ticket": int(order.ticket),
            "position_id": int(deal.position_id),
            "magic": int(deal.magic),
            "side": "BUY" if int(deal.type) == 0 else "SELL",
            "entry": int(deal.entry),
            "volume": float(deal.volume),
            "fill_price": float(deal.price),
            "request_time_msc": int(order.time_setup_msc),
            "ack_time_msc": int(order.time_done_msc),
            "fill_time_msc": int(deal.time_msc),
            "reference": reference,
            "quote": quote,
            "status": status,
        }
        if status == "COMPLETE":
            observation["adverse_slippage_points"] = signed_adverse_points(
                int(deal.type), float(deal.price), quote, float(spec.point)
            )
        observations.append(observation)
    complete = sum(row["status"] == "COMPLETE" for row in observations)
    stream_status = (
        "MISSING_NO_FILL" if not observations
        else "COMPLETE" if complete == len(observations)
        else "INCOMPLETE"
    )
    values = [
        float(row["adverse_slippage_points"])
        for row in observations if row["status"] == "COMPLETE"
    ]
    return {
        "symbol": symbol,
        "point": float(spec.point),
        "status": stream_status,
        "fill_count": len(observations),
        "complete_count": complete,
        "observations": observations,
        "value_for_cost_model": (
            {"method": "mean_observed_adverse_points", "points": sum(values) / len(values), "samples": len(values)}
            if stream_status == "COMPLETE" and values else None
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--terminal-exe", required=True, type=Path)
    parser.add_argument("--start-utc", required=True)
    parser.add_argument("--end-utc", required=True)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    start, end = parse_utc(args.start_utc), parse_utc(args.end_utc)
    validate_window(start, end)
    output_dir = validate_output_dir(args.output_dir)
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
        output_dir.mkdir(parents=True)
        receipt_paths: list[Path] = []
        for symbol in SYMBOLS:
            stream = capture_symbol(mt5, symbol, start, end)
            receipt = {
                "schema": SCHEMA,
                "generated_at_utc": datetime.now(timezone.utc).isoformat(),
                "window": {"start_utc": start.isoformat(), "end_utc": end.isoformat()},
                "mode": "READ_ONLY_ALREADY_RUNNING_TERMINAL_IPC",
                "account": {"login": int(account.login), "server": str(account.server)},
                "terminal": {
                    "process": process,
                    "build": int(terminal.build),
                    "data_path": str(terminal.data_path),
                },
                "stream": stream,
                "authorization": {
                    "terminal_launch": False,
                    "terminal_control": False,
                    "trade_call": False,
                    "order_action": False,
                    "autotrading_toggle": False,
                },
            }
            path = output_dir / f"{symbol.replace('.', '_')}_slippage_stream.json"
            path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            receipt_paths.append(path)
        manifest = {
            "schema": MANIFEST_SCHEMA,
            "generated_at_utc": datetime.now(timezone.utc).isoformat(),
            "window": {"start_utc": start.isoformat(), "end_utc": end.isoformat()},
            "receipts": [
                {"symbol": symbol, "path": path.name, "sha256": sha256(path)}
                for symbol, path in zip(SYMBOLS, receipt_paths)
            ],
            "complete_symbols": sum(
                json.loads(path.read_text(encoding="utf-8"))["stream"]["status"] == "COMPLETE"
                for path in receipt_paths
            ),
            "cost_model_eligible": all(
                json.loads(path.read_text(encoding="utf-8"))["stream"]["value_for_cost_model"] is not None
                for path in receipt_paths
            ),
        }
        manifest_path = output_dir / "manifest.json"
        manifest_path.write_text(
            json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        print(json.dumps({**manifest, "manifest_sha256": sha256(manifest_path)}, indent=2))
        return 0 if manifest["cost_model_eligible"] else 2
    finally:
        if initialized:
            mt5.shutdown()


if __name__ == "__main__":
    raise SystemExit(main())
