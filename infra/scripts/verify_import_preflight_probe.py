"""verify_import_preflight_probe.py

Targeted verifier probe for one DWX symbol using MT5 pre-flight and retry logic.
This is a non-production helper to validate verifier read-path behavior before
patching D:\\QM\\mt5\\T1\\dwx_import\\verify_import.py.
"""
from __future__ import annotations

import argparse
import datetime as dt
import time
from pathlib import Path

import MetaTrader5 as mt5

DEFAULT_TERMINAL = r"D:\QM\mt5\T1\terminal64.exe"
DEFAULT_DONE_DIR = Path(r"D:\QM\mt5\T1\MQL5\Files\imports\done")
SOURCE_OVERRIDES = {
    "GDAXIm": "GDAXI",
    "NDXm": "NDX",
}


def parse_sidecar(path: Path) -> dict[str, str]:
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


def pick_sidecar(done_dir: Path, target_symbol: str) -> Path:
    hits = sorted(done_dir.glob(f"*{target_symbol}*.import.txt"))
    if not hits:
        raise FileNotFoundError(f"no sidecar found for {target_symbol} in {done_dir}")
    return hits[-1]


def mt5_tick_window_count_range(symbol: str, start_s: int, end_s: int) -> int:
    lo = dt.datetime.utcfromtimestamp(start_s)
    hi = dt.datetime.utcfromtimestamp(end_s)
    ticks = mt5.copy_ticks_range(symbol, lo, hi, mt5.COPY_TICKS_ALL)
    return len(list(ticks)) if ticks is not None else 0


def mt5_tick_window_count_from(symbol: str, start_s: int, count: int) -> int:
    ticks = mt5.copy_ticks_from(symbol, start_s, count, mt5.COPY_TICKS_ALL)
    return len(list(ticks)) if ticks is not None else 0


def probe_symbol(
    *,
    target_symbol: str,
    terminal_path: str,
    done_dir: Path,
    retries: int,
    retry_sleep_s: float,
) -> int:
    sidecar = pick_sidecar(done_dir, target_symbol)
    job = parse_sidecar(sidecar)
    t_first = int(job["tick_first_ms"])
    t_last = int(job["tick_last_ms"])
    b_first = int(job["m1_first_s"])
    b_last = int(job["m1_last_s"])

    if not mt5.initialize(path=terminal_path, portable=True):
        print(f"ERROR init: {mt5.last_error()}")
        return 3

    try:
        mt5.symbol_select(target_symbol, True)
        # Pre-flight warm-up to let the terminal populate symbol caches.
        for _ in range(3):
            _ = mt5.copy_rates_from_pos(target_symbol, mt5.TIMEFRAME_M1, 0, 10)
            _ = mt5.copy_ticks_from(target_symbol, int(time.time()) - 120, 10, mt5.COPY_TICKS_ALL)
            time.sleep(0.25)

        mid_s = ((t_first + t_last) // 2) // 1000
        tail_start_s = t_last // 1000 - 600
        tail_end_s = t_last // 1000 + 60

        # Collect both APIs to expose range-vs-from mismatch directly.
        result = {
            "range_head_ticks": 0,
            "range_mid_ticks": 0,
            "range_tail_ticks": 0,
            "from_head_ticks": 0,
            "from_mid_ticks": 0,
            "from_tail_ticks": 0,
            "bars": 0,
            "tail_got_ms": 0,
        }

        for attempt in range(1, retries + 1):
            result["range_head_ticks"] = mt5_tick_window_count_range(
                target_symbol, t_first // 1000, t_first // 1000 + 300
            )
            result["range_mid_ticks"] = mt5_tick_window_count_range(
                target_symbol, mid_s, mid_s + 300
            )
            result["range_tail_ticks"] = mt5_tick_window_count_range(
                target_symbol, tail_start_s, tail_end_s
            )
            result["from_head_ticks"] = mt5_tick_window_count_from(target_symbol, t_first // 1000, 50)
            result["from_mid_ticks"] = mt5_tick_window_count_from(target_symbol, mid_s, 50)
            result["from_tail_ticks"] = mt5_tick_window_count_from(target_symbol, tail_start_s, 50)

            tail_ticks = mt5.copy_ticks_from(target_symbol, tail_start_s, 2000, mt5.COPY_TICKS_ALL)
            tail_ticks = list(tail_ticks) if tail_ticks is not None else []
            result["tail_got_ms"] = int(tail_ticks[-1]["time_msc"]) if tail_ticks else 0

            f0 = dt.datetime.utcfromtimestamp(b_first)
            f1 = dt.datetime.utcfromtimestamp(b_last + 60)
            bars = mt5.copy_rates_range(target_symbol, mt5.TIMEFRAME_M1, f0, f1)
            bars = list(bars) if bars is not None else []
            result["bars"] = len(bars)

            print(
                f"attempt={attempt} "
                f"range(h/m/t)=({result['range_head_ticks']}/{result['range_mid_ticks']}/{result['range_tail_ticks']}) "
                f"from(h/m/t)=({result['from_head_ticks']}/{result['from_mid_ticks']}/{result['from_tail_ticks']}) "
                f"bars={result['bars']} tail_got_ms={result['tail_got_ms']}"
            )

            if result["from_tail_ticks"] > 0:
                break
            time.sleep(retry_sleep_s)

        source = source_symbol_for_target(target_symbol)
        print(f"target={target_symbol} source={source} sidecar={sidecar}")
        print(f"tail_expected_ms={t_last} tail_got_ms={result['tail_got_ms']}")
        print(f"bars_expected={job['m1_count']} bars_got={result['bars']}")

        # Non-zero indicates acceptance still unmet.
        if result["bars"] == 0 or result["tail_got_ms"] == 0:
            return 1
        return 0
    finally:
        mt5.shutdown()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--symbol", required=True, help="Target symbol, for example XAUUSD.DWX")
    ap.add_argument("--terminal", default=DEFAULT_TERMINAL)
    ap.add_argument("--done-dir", default=str(DEFAULT_DONE_DIR))
    ap.add_argument("--retries", type=int, default=5)
    ap.add_argument("--retry-sleep-s", type=float, default=0.8)
    args = ap.parse_args()

    return probe_symbol(
        target_symbol=args.symbol,
        terminal_path=args.terminal,
        done_dir=Path(args.done_dir),
        retries=max(1, int(args.retries)),
        retry_sleep_s=max(0.0, float(args.retry_sleep_s)),
    )


if __name__ == "__main__":
    raise SystemExit(main())
