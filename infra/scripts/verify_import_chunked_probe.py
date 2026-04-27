"""Probe verifier logic with chunked M1 bar reads (non-production).

This script mirrors the key checks from verify_import.py but replaces the
single full-span copy_rates_range call with chunked range reads, so we can
separate:
- API query-shape failures (full-span invalid params)
- real symbol/tail data gaps
"""
from __future__ import annotations

import argparse
import datetime as dt
from pathlib import Path

import MetaTrader5 as mt5

T1_TERMINAL = r"D:\QM\mt5\T1\terminal64.exe"
DONE_DIR = Path(r"D:\QM\mt5\T1\MQL5\Files\imports\done")

SOURCE_OVERRIDES = {"GDAXIm": "GDAXI", "NDXm": "NDX"}
WINDOW_MS = 5 * 60 * 1000


def parse_kv(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" not in line:
            continue
        k, _, v = line.partition("=")
        out[k.strip()] = v.strip()
    return out


def source_symbol_for_target(target_symbol: str) -> str:
    root = target_symbol[:-4] if target_symbol.endswith(".DWX") else target_symbol
    return SOURCE_OVERRIDES.get(root) or root


def count_bars_chunked(symbol: str, start_s: int, end_s: int, chunk_days: int) -> tuple[int, int, int]:
    cur = dt.datetime.utcfromtimestamp(start_s)
    end = dt.datetime.utcfromtimestamp(end_s + 60)
    step = dt.timedelta(days=chunk_days)
    total = 0
    chunks = 0
    bad_chunks = 0
    while cur < end:
        nxt = min(cur + step, end)
        rates = mt5.copy_rates_range(symbol, mt5.TIMEFRAME_M1, cur, nxt)
        chunks += 1
        if rates is None:
            bad_chunks += 1
        else:
            total += len(rates)
        cur = nxt
    return total, chunks, bad_chunks


def find_latest_sidecar(symbol: str) -> Path:
    sidecars = sorted(DONE_DIR.glob(f"*_{symbol}.import.txt"))
    if not sidecars:
        raise FileNotFoundError(f"no sidecar found for {symbol} in {DONE_DIR}")
    return sidecars[-1]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--symbol", default="WS30.DWX")
    ap.add_argument("--chunk-days", type=int, default=20)
    args = ap.parse_args()

    sidecar = find_latest_sidecar(args.symbol)
    job = parse_kv(sidecar)

    t_first = int(job["tick_first_ms"])
    t_last = int(job["tick_last_ms"])
    b_first = int(job["m1_first_s"])
    b_last = int(job["m1_last_s"])
    b_count = int(job["m1_count"])

    if not mt5.initialize(path=T1_TERMINAL, portable=True):
        print(f"init failed: {mt5.last_error()}")
        return 2
    try:
        mt5.symbol_select(args.symbol, True)
        si = mt5.symbol_info(args.symbol)
        if si is None:
            print(f"symbol missing: {args.symbol}")
            return 3

        source = source_symbol_for_target(args.symbol)
        src_si = mt5.symbol_info(source)
        custom_tv = float(si.trade_tick_value or 0.0)
        broker_tv = float(src_si.trade_tick_value or 0.0) if src_si else 0.0

        head = mt5.copy_ticks_from(args.symbol, t_first // 1000, 50, mt5.COPY_TICKS_ALL)
        head = list(head) if head is not None else []
        tail_lo = dt.datetime.utcfromtimestamp(t_last // 1000 - 600)
        tail_hi = dt.datetime.utcfromtimestamp(t_last // 1000 + 60)
        tail = mt5.copy_ticks_range(args.symbol, tail_lo, tail_hi, mt5.COPY_TICKS_ALL)
        tail = list(tail) if tail is not None else []
        mid_lo = dt.datetime.utcfromtimestamp(((t_first + t_last) // 2) // 1000)
        mid_hi = mid_lo + dt.timedelta(minutes=5)
        mid = mt5.copy_ticks_range(args.symbol, mid_lo, mid_hi, mt5.COPY_TICKS_ALL)
        mid = list(mid) if mid is not None else []

        one_shot = mt5.copy_rates_range(
            args.symbol,
            mt5.TIMEFRAME_M1,
            dt.datetime.utcfromtimestamp(b_first),
            dt.datetime.utcfromtimestamp(b_last + 60),
        )
        one_shot_count = 0 if one_shot is None else len(one_shot)
        one_shot_err = mt5.last_error()

        chunked_count, chunks, bad_chunks = count_bars_chunked(
            args.symbol, b_first, b_last, args.chunk_days
        )

        head_got = int(head[0]["time_msc"]) if head else 0
        tail_got = int(tail[-1]["time_msc"]) if tail else 0
        tail_short_s = (t_last - tail_got) / 1000 if tail_got else None

        print(f"symbol={args.symbol} source={source} path={si.path}")
        print(f"sidecar={sidecar}")
        print(f"tick_head expected/got={t_first}/{head_got}")
        print(f"tick_tail expected/got={t_last}/{tail_got}")
        print(f"tick_tail_shortfall_seconds={tail_short_s}")
        print(f"mid_ticks_5min={len(mid)}")
        print(f"bars_expected={b_count}")
        print(f"bars_oneshot_count={one_shot_count} bars_oneshot_err={one_shot_err}")
        print(
            f"bars_chunked_count={chunked_count} chunk_days={args.chunk_days} "
            f"chunks={chunks} bad_chunks={bad_chunks}"
        )
        ti = mt5.terminal_info()
        print(f"terminal_maxbars={getattr(ti, 'maxbars', None)}")
        print(f"custom_tv={custom_tv} broker_tv={broker_tv}")
    finally:
        mt5.shutdown()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

