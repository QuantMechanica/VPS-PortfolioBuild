"""Probe MT5 bars/ticks visibility for a custom symbol vs its source symbol.

Read-only diagnostic for DWX investigations. It helps classify cases where:
- broker/source symbol has bars available
- custom *.DWX symbol returns zero/failure on bars APIs
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path

import MetaTrader5 as mt5

T1_TERMINAL = r"D:\QM\mt5\T1\terminal64.exe"
SOURCE_OVERRIDES = {"GDAXIm": "GDAXI", "NDXm": "NDX"}


def source_symbol_for_target(target_symbol: str) -> str:
    root = target_symbol[:-4] if target_symbol.endswith(".DWX") else target_symbol
    return SOURCE_OVERRIDES.get(root) or root


def probe_symbol(symbol: str, lookback_days: int, tick_minutes: int) -> dict[str, object]:
    now = dt.datetime.utcnow()
    lo = now - dt.timedelta(days=lookback_days)

    mt5.symbol_select(symbol, True)
    rates = mt5.copy_rates_range(symbol, mt5.TIMEFRAME_M1, lo, now)
    rates_count = 0 if rates is None else len(rates)
    rates_err = mt5.last_error()

    pos = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, 0, 10)
    pos_count = 0 if pos is None else len(pos)
    pos_err = mt5.last_error()

    ticks = mt5.copy_ticks_from(
        symbol,
        int(now.timestamp()) - (tick_minutes * 60),
        200,
        mt5.COPY_TICKS_ALL,
    )
    ticks_count = 0 if ticks is None else len(ticks)
    ticks_err = mt5.last_error()

    return {
        "symbol": symbol,
        "rates_range_m1_count": rates_count,
        "rates_range_m1_err": list(rates_err) if rates_err is not None else None,
        "rates_from_pos_m1_count": pos_count,
        "rates_from_pos_m1_err": list(pos_err) if pos_err is not None else None,
        "ticks_from_count": ticks_count,
        "ticks_from_err": list(ticks_err) if ticks_err is not None else None,
        "lookback_days": lookback_days,
        "tick_minutes": tick_minutes,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", required=True, help="Custom symbol, e.g. XTIUSD.DWX")
    ap.add_argument("--terminal", default=T1_TERMINAL)
    ap.add_argument("--lookback-days", type=int, default=2)
    ap.add_argument("--tick-minutes", type=int, default=10)
    ap.add_argument("--json-out", default="")
    args = ap.parse_args()

    source = source_symbol_for_target(args.target)

    if not mt5.initialize(path=args.terminal, portable=True):
        print(f"init failed: {mt5.last_error()}")
        return 2

    try:
        target_probe = probe_symbol(args.target, args.lookback_days, args.tick_minutes)
        source_probe = probe_symbol(source, args.lookback_days, args.tick_minutes)
    finally:
        mt5.shutdown()

    source_bars_ok = int(source_probe["rates_range_m1_count"]) > 0 and int(
        source_probe["rates_from_pos_m1_count"]
    ) > 0
    target_bars_missing = int(target_probe["rates_range_m1_count"]) == 0 and int(
        target_probe["rates_from_pos_m1_count"]
    ) == 0
    isolated_custom_bars_visibility_failure = source_bars_ok and target_bars_missing

    payload = {
        "target": args.target,
        "source": source,
        "isolated_custom_bars_visibility_failure": isolated_custom_bars_visibility_failure,
        "target_probe": target_probe,
        "source_probe": source_probe,
    }

    print(
        "target={0} source={1} isolated_custom_bars_visibility_failure={2}".format(
            args.target, source, isolated_custom_bars_visibility_failure
        )
    )
    print(
        "target bars(range/pos)={0}/{1} source bars(range/pos)={2}/{3}".format(
            target_probe["rates_range_m1_count"],
            target_probe["rates_from_pos_m1_count"],
            source_probe["rates_range_m1_count"],
            source_probe["rates_from_pos_m1_count"],
        )
    )

    if args.json_out:
        out = Path(args.json_out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        print(f"json_out={out}")

    return 1 if isolated_custom_bars_visibility_failure else 0


if __name__ == "__main__":
    raise SystemExit(main())
