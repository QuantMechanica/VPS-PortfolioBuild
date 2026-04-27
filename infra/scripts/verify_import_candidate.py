"""Candidate replacement for D:\\QM\\mt5\\T1\\dwx_import\\verify_import.py.

Purpose:
- Preserve existing tick/spec checks.
- Replace one-shot full-span M1 read with chunked reads.
- Evaluate bars against terminal-accessible bounds (maxbars), not only raw sidecar count.

This is a repo-side candidate/handoff artifact; it does not mutate production files.
"""
from __future__ import annotations

import argparse
import datetime as dt
import sys
from pathlib import Path

import MetaTrader5 as mt5

T1_TERMINAL = r"D:\QM\mt5\T1\terminal64.exe"
DONE_DIR = Path(r"D:\QM\mt5\T1\MQL5\Files\imports\done")
WINDOW_MS = 5 * 60 * 1000

SOURCE_OVERRIDES = {
    "GDAXIm": "GDAXI",
    "NDXm": "NDX",
}


def source_symbol_for_target(target_symbol: str) -> str:
    root = target_symbol[:-4] if target_symbol.endswith(".DWX") else target_symbol
    return SOURCE_OVERRIDES.get(root) or root


def is_symbol_spec_ok(custom_tick_value: float, broker_tick_value: float) -> bool:
    ctv = float(custom_tick_value or 0.0)
    btv = float(broker_tick_value or 0.0)
    if ctv <= 0 or btv <= 0:
        return False
    return abs(ctv - btv) / btv < 0.05


def parse_kv(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" not in line:
            continue
        k, _, v = line.partition("=")
        out[k.strip()] = v.strip()
    return out


def count_rates_chunked(symbol: str, first_s: int, last_s: int, chunk_days: int) -> tuple[int, int]:
    cur = dt.datetime.utcfromtimestamp(first_s)
    end = dt.datetime.utcfromtimestamp(last_s + 60)
    step = dt.timedelta(days=chunk_days)
    total = 0
    bad_chunks = 0
    while cur < end:
        nxt = min(cur + step, end)
        rates = mt5.copy_rates_range(symbol, mt5.TIMEFRAME_M1, cur, nxt)
        if rates is None:
            bad_chunks += 1
        else:
            total += len(rates)
        cur = nxt
    return total, bad_chunks


def count_rates_from_pos(symbol: str, *, page_size: int = 1000, max_pages: int = 500) -> tuple[int, int]:
    total = 0
    bad_calls = 0
    pos = 0
    for _ in range(max_pages):
        rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, pos, page_size)
        if rates is None:
            bad_calls += 1
            break
        got = len(rates)
        if got <= 0:
            break
        total += got
        pos += got
        if got < page_size:
            break
    return total, bad_calls


def check_one(
    job: dict[str, str],
    *,
    chunk_days: int,
    symbol_filter: str | None,
    tail_basis: str,
    tail_tol_ms: int,
) -> bool:
    target = job["target_symbol"]
    if symbol_filter and target != symbol_filter:
        return True

    t_first = int(job["tick_first_ms"])
    t_last = int(job["tick_last_ms"])
    b_first = int(job["m1_first_s"])
    b_last = int(job["m1_last_s"])
    b_count = int(job["m1_count"])

    si = mt5.symbol_info(target)
    if si is None:
        print(f"[FAIL]  {target}: not present in MT5")
        return False
    mt5.symbol_select(target, True)

    source = source_symbol_for_target(target)
    src_si = mt5.symbol_info(source)
    custom_tv = float(si.trade_tick_value or 0.0)
    broker_tv = float(src_si.trade_tick_value or 0.0) if src_si is not None else 0.0
    spec_ok = src_si is not None and is_symbol_spec_ok(custom_tv, broker_tv)
    rel_err = abs(custom_tv - broker_tv) / broker_tv if broker_tv > 0 else 1.0

    head = mt5.copy_ticks_from(target, t_first // 1000, 50, mt5.COPY_TICKS_ALL)
    head = list(head) if head is not None else []
    last_dt_lo = dt.datetime.utcfromtimestamp(t_last // 1000 - 600)
    last_dt_hi = dt.datetime.utcfromtimestamp(t_last // 1000 + 60)
    tail = mt5.copy_ticks_range(target, last_dt_lo, last_dt_hi, mt5.COPY_TICKS_ALL)
    tail = list(tail) if tail is not None else []

    mid = (t_first + t_last) // 2 // 1000
    mid_lo = dt.datetime.utcfromtimestamp(mid)
    mid_hi = dt.datetime.utcfromtimestamp(mid + 300)
    mid_ticks = mt5.copy_ticks_range(target, mid_lo, mid_hi, mt5.COPY_TICKS_ALL)
    mid_ticks = list(mid_ticks) if mid_ticks is not None else []

    head_ok = bool(head) and int(head[0]["time_msc"]) == t_first
    tail_got = int(tail[-1]["time_msc"]) if tail else 0
    tail_ok = bool(tail) and tail_got == t_last
    source_tail_got = 0
    if source and tail_basis == "source":
        mt5.symbol_select(source, True)
        source_tail = mt5.copy_ticks_range(source, last_dt_lo, last_dt_hi, mt5.COPY_TICKS_ALL)
        source_tail = list(source_tail) if source_tail is not None else []
        source_tail_got = int(source_tail[-1]["time_msc"]) if source_tail else 0
        tail_ok = bool(tail) and bool(source_tail) and abs(tail_got - source_tail_got) <= tail_tol_ms
    mid_ok = len(mid_ticks) > 0

    one_shot = mt5.copy_rates_range(
        target,
        mt5.TIMEFRAME_M1,
        dt.datetime.utcfromtimestamp(b_first),
        dt.datetime.utcfromtimestamp(b_last + 60),
    )
    one_shot_count = 0 if one_shot is None else len(one_shot)
    one_shot_err = mt5.last_error()

    chunked_count, bad_chunks = count_rates_chunked(target, b_first, b_last, chunk_days)
    from_pos_count, from_pos_bad = count_rates_from_pos(target)
    bars_basis = "range"
    if chunked_count <= 0 and from_pos_count > 0:
        chunked_count = from_pos_count
        bad_chunks += from_pos_bad
        bars_basis = "from_pos"

    ti = mt5.terminal_info()
    maxbars = int(getattr(ti, "maxbars", 0) or 0)
    expected_accessible = min(b_count, maxbars) if maxbars > 0 else b_count
    bar_drift = chunked_count - expected_accessible
    bar_ok = chunked_count > 0 and abs(bar_drift) <= max(100, int(expected_accessible * 0.01))

    verdict = "OK"
    failures: list[str] = []
    if not head_ok:
        failures.append("head")
    if not tail_ok:
        failures.append("tail")
    if not mid_ok:
        failures.append("mid")
    if not bar_ok:
        failures.append("bars")
    if not spec_ok:
        failures.append("spec")
    if failures:
        verdict = "FAIL_" + "_".join(failures)

    head_t = head[0]["time_msc"] if head else 0
    tail_t = tail_got
    tail_ref = t_last if tail_basis == "sidecar" else source_tail_got
    tail_delta = (tail_t - tail_ref) if tail_t and tail_ref else None
    print(
        f"[{verdict:>15}] {target}: "
        f"source={source}; custom_tv={custom_tv}; broker_tv={broker_tv}; rel_err={rel_err:.4f}; "
        f"head_ms expected={t_first}/got={head_t}; "
        f"tail_ms expected={t_last}/got={tail_t}; "
        f"tail_basis={tail_basis}; tail_ref_ms={tail_ref}; tail_delta_ms={tail_delta}; "
        f"mid_ticks_5min={len(mid_ticks)}; "
        f"bars_sidecar_expected={b_count:,}; bars_one_shot={one_shot_count:,}; bars_one_shot_err={one_shot_err}; "
        f"bars_from_pos={from_pos_count:,}; bars_chunked={chunked_count:,}; bars_basis={bars_basis}; "
        f"maxbars={maxbars:,}; bars_expected_accessible={expected_accessible:,}; "
        f"bars_drift={bar_drift:+,}; bad_chunks={bad_chunks}; path={si.path}"
    )
    return verdict == "OK"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--symbol", default=None, help="optional exact symbol filter, e.g. WS30.DWX")
    ap.add_argument("--chunk-days", type=int, default=20)
    ap.add_argument(
        "--tail-basis",
        choices=["sidecar", "source"],
        default="sidecar",
        help="sidecar: strict sidecar tick_last_ms match; source: parity with source symbol tail in same window",
    )
    ap.add_argument(
        "--tail-tol-ms",
        type=int,
        default=1000,
        help="max custom-vs-source tail delta when --tail-basis source",
    )
    args = ap.parse_args()

    if not DONE_DIR.exists():
        print(f"no done dir at {DONE_DIR}", file=sys.stderr)
        return 0

    sidecars = sorted(DONE_DIR.glob("*.import.txt"))
    if not sidecars:
        print("(no archived jobs to verify)")
        return 0

    if not mt5.initialize(path=T1_TERMINAL, portable=True):
        print(f"ERROR: mt5.initialize failed: {mt5.last_error()}", file=sys.stderr)
        return 3

    overall_ok = True
    try:
        for sc in sidecars:
            try:
                job = parse_kv(sc)
            except Exception as e:
                print(f"[skip] cannot parse {sc.name}: {e}")
                continue
            try:
                if not check_one(
                    job,
                    chunk_days=args.chunk_days,
                    symbol_filter=args.symbol,
                    tail_basis=args.tail_basis,
                    tail_tol_ms=args.tail_tol_ms,
                ):
                    overall_ok = False
            except Exception as e:
                print(f"[ERROR] {sc.name}: {e}")
                overall_ok = False
    finally:
        mt5.shutdown()
    return 0 if overall_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
