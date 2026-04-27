"""Probe MT5 M1 range-read behavior for DWX verifier investigations.

Read-only diagnostic helper.
It compares:
1) one-shot copy_rates_range over the full requested span
2) chunked copy_rates_range over smaller windows

Use this to confirm whether verifier bar-count failures are caused by
MT5 range query limits/invalid-param windows rather than symbol-level
import corruption.
"""
from __future__ import annotations

import argparse
import datetime as dt
from dataclasses import dataclass
from pathlib import Path

import MetaTrader5 as mt5

T1_TERMINAL_DEFAULT = r"D:\QM\mt5\T1\terminal64.exe"
DONE_DIR_DEFAULT = Path(r"D:\QM\mt5\T1\MQL5\Files\imports\done")


@dataclass
class Span:
    start: dt.datetime
    end: dt.datetime


def parse_sidecar_kv(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" not in line:
            continue
        k, _, v = line.partition("=")
        out[k.strip()] = v.strip()
    return out


def load_span_from_latest_sidecar(done_dir: Path, symbol: str) -> tuple[Span, int, Path]:
    pattern = f"*_{symbol}.import.txt"
    sidecars = sorted(done_dir.glob(pattern))
    if not sidecars:
        raise FileNotFoundError(f"no sidecar matched {pattern} in {done_dir}")
    latest = sidecars[-1]
    kv = parse_sidecar_kv(latest)
    first_s = int(kv["m1_first_s"])
    last_s = int(kv["m1_last_s"])
    expected = int(kv["m1_count"])
    span = Span(
        start=dt.datetime.utcfromtimestamp(first_s),
        end=dt.datetime.utcfromtimestamp(last_s + 60),
    )
    return span, expected, latest


def count_oneshot(symbol: str, span: Span) -> tuple[int, tuple[int, str]]:
    rates = mt5.copy_rates_range(symbol, mt5.TIMEFRAME_M1, span.start, span.end)
    if rates is None:
        return 0, mt5.last_error()
    return len(rates), mt5.last_error()


def count_chunked(symbol: str, span: Span, chunk_days: int) -> tuple[int, int, int]:
    total = 0
    chunks = 0
    bad_chunks = 0
    cur = span.start
    delta = dt.timedelta(days=chunk_days)
    while cur < span.end:
        nxt = min(cur + delta, span.end)
        rates = mt5.copy_rates_range(symbol, mt5.TIMEFRAME_M1, cur, nxt)
        chunks += 1
        if rates is None:
            bad_chunks += 1
        else:
            total += len(rates)
        cur = nxt
    return total, chunks, bad_chunks


def count_tail_window(symbol: str, span: Span, tail_hours: int) -> tuple[int, tuple[int, str], dt.datetime, dt.datetime]:
    tail_start = max(span.start, span.end - dt.timedelta(hours=tail_hours))
    tail_end = span.end
    rates = mt5.copy_rates_range(symbol, mt5.TIMEFRAME_M1, tail_start, tail_end)
    if rates is None:
        return 0, mt5.last_error(), tail_start, tail_end
    return len(rates), mt5.last_error(), tail_start, tail_end


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--terminal", default=T1_TERMINAL_DEFAULT)
    ap.add_argument("--done-dir", default=str(DONE_DIR_DEFAULT))
    ap.add_argument("--symbol", default="WS30.DWX")
    ap.add_argument("--chunk-days", type=int, default=20)
    ap.add_argument("--tail-hours", type=int, default=24)
    args = ap.parse_args()

    done_dir = Path(args.done_dir)
    span, expected, sidecar = load_span_from_latest_sidecar(done_dir, args.symbol)

    if not mt5.initialize(path=args.terminal, portable=True):
        err = mt5.last_error()
        print(f"init failed: {err}")
        return 2
    try:
        mt5.symbol_select(args.symbol, True)
        si = mt5.symbol_info(args.symbol)
        one_count, one_err = count_oneshot(args.symbol, span)
        chunk_count, chunks, bad_chunks = count_chunked(args.symbol, span, args.chunk_days)
        tail_count, tail_err, tail_start, tail_end = count_tail_window(args.symbol, span, args.tail_hours)

        print(f"symbol={args.symbol}")
        print(f"sidecar={sidecar}")
        if si is not None:
            print(
                f"symbol_info_selected={si.select} visible={si.visible} custom={si.custom} "
                f"path={si.path}"
            )
        print(f"span_start_utc={span.start.isoformat()} span_end_utc={span.end.isoformat()}")
        print(f"m1_expected_count={expected}")
        print(f"oneshot_count={one_count} oneshot_last_error={one_err}")
        print(
            f"chunked_count={chunk_count} chunk_days={args.chunk_days} "
            f"chunks={chunks} bad_chunks={bad_chunks}"
        )
        print(
            f"tail_window_count={tail_count} tail_hours={args.tail_hours} "
            f"tail_start_utc={tail_start.isoformat()} tail_end_utc={tail_end.isoformat()} "
            f"tail_last_error={tail_err}"
        )
        drift = chunk_count - expected
        print(f"chunked_drift={drift}")
    finally:
        mt5.shutdown()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
