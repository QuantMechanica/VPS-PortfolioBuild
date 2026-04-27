"""verify_import_candidate.py

Candidate verifier implementation for DWX investigations.
Does not replace the live verifier on D:. Used to validate proposed changes:
1) use copy_ticks_from windows for mid/tail checks (instead of copy_ticks_range),
2) allow bounded tail tolerance,
3) degrade bars check when MT5 returns zero bars but ticks are present.
"""
from __future__ import annotations

import argparse
import datetime as dt
import sys
import time
from pathlib import Path

import MetaTrader5 as mt5

T1_TERMINAL = r"D:\QM\mt5\T1\terminal64.exe"
DONE_DIR = Path(r"D:\QM\mt5\T1\MQL5\Files\imports\done")
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
        if not line or "=" not in line:
            continue
        k, _, v = line.partition("=")
        out[k.strip()] = v.strip()
    return out


def preflight_symbol(symbol: str, rounds: int = 3) -> None:
    mt5.symbol_select(symbol, True)
    for _ in range(max(1, rounds)):
        _ = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, 0, 10)
        _ = mt5.copy_ticks_from(symbol, int(time.time()) - 120, 10, mt5.COPY_TICKS_ALL)
        time.sleep(0.2)


def copy_ticks_from_list(symbol: str, start_s: int, count: int) -> list:
    arr = mt5.copy_ticks_from(symbol, start_s, count, mt5.COPY_TICKS_ALL)
    return list(arr) if arr is not None else []


def check_one(job: dict[str, str], tail_tolerance_ms: int) -> bool:
    target = job["target_symbol"]
    t_first = int(job["tick_first_ms"])
    t_last = int(job["tick_last_ms"])
    b_first = int(job["m1_first_s"])
    b_last = int(job["m1_last_s"])
    b_count = int(job["m1_count"])

    si = mt5.symbol_info(target)
    if si is None:
        print(f"[FAIL] {target}: not present in MT5")
        return False
    preflight_symbol(target)

    source = source_symbol_for_target(target)
    src_si = mt5.symbol_info(source)
    custom_tv = float(si.trade_tick_value or 0.0)
    broker_tv = float(src_si.trade_tick_value or 0.0) if src_si is not None else 0.0
    spec_ok = src_si is not None and is_symbol_spec_ok(custom_tv, broker_tv)
    rel_err = abs(custom_tv - broker_tv) / broker_tv if broker_tv > 0 else 1.0

    # tick checks use copy_ticks_from windows to avoid range API blind spots.
    head = copy_ticks_from_list(target, t_first // 1000, 50)
    mid_s = ((t_first + t_last) // 2) // 1000
    mid_ticks = copy_ticks_from_list(target, mid_s, 50)
    tail_start_s = t_last // 1000 - 600
    tail_ticks = copy_ticks_from_list(target, tail_start_s, 4000)

    head_t = int(head[0]["time_msc"]) if head else 0
    tail_t = max((int(t["time_msc"]) for t in tail_ticks), default=0)
    head_ok = bool(head) and head_t == t_first
    mid_ok = len(mid_ticks) > 0
    tail_ok = bool(tail_ticks) and abs(t_last - tail_t) <= tail_tolerance_ms

    f0 = dt.datetime.utcfromtimestamp(b_first)
    f1 = dt.datetime.utcfromtimestamp(b_last + 60)
    rates = mt5.copy_rates_range(target, mt5.TIMEFRAME_M1, f0, f1)
    rates = list(rates) if rates is not None else []
    bar_drift = len(rates) - b_count
    bar_ok = abs(bar_drift) <= max(50, b_count * 0.001)

    # If bars are unavailable but ticks are present, classify as runtime bars visibility issue.
    bars_unavailable = len(rates) == 0 and len(mid_ticks) > 0 and len(tail_ticks) > 0

    failures: list[str] = []
    warns: list[str] = []
    if not head_ok:
        failures.append("head")
    if not tail_ok:
        failures.append("tail")
    if not mid_ok:
        failures.append("mid")
    if not spec_ok:
        failures.append("spec")
    if bars_unavailable:
        warns.append("bars_unavailable")
    elif not bar_ok:
        failures.append("bars")

    verdict = "OK" if not failures else "FAIL_" + "_".join(failures)
    if verdict == "OK" and warns:
        verdict = "WARN_" + "_".join(warns)

    print(
        f"[{verdict:>18}] {target}: "
        f"source={source}; custom_tv={custom_tv}; broker_tv={broker_tv}; rel_err={rel_err:.4f}; "
        f"head_ms expected={t_first}/got={head_t}; "
        f"tail_ms expected={t_last}/got={tail_t}; "
        f"tail_tol_ms={tail_tolerance_ms}; "
        f"mid_ticks_probe={len(mid_ticks)}; "
        f"bars expected={b_count:,}/got={len(rates):,} drift={bar_drift:+,}; "
        f"path={si.path}"
    )
    return verdict in ("OK", "WARN_bars_unavailable")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--terminal", default=T1_TERMINAL)
    ap.add_argument("--done-dir", default=str(DONE_DIR))
    ap.add_argument("--symbol", help="Optional single target, e.g. XAUUSD.DWX")
    ap.add_argument("--tail-tolerance-ms", type=int, default=180_000)
    args = ap.parse_args()

    done_dir = Path(args.done_dir)
    if not done_dir.exists():
        print(f"no done dir at {done_dir}", file=sys.stderr)
        return 0

    sidecars = sorted(done_dir.glob("*.import.txt"))
    if not sidecars:
        print("(no archived jobs to verify)")
        return 0

    if not mt5.initialize(path=args.terminal, portable=True):
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
            target = job.get("target_symbol", "")
            if args.symbol and target.upper() != args.symbol.upper():
                continue
            try:
                if not check_one(job, tail_tolerance_ms=max(1, args.tail_tolerance_ms)):
                    overall_ok = False
            except Exception as e:
                print(f"[ERROR] {sc.name}: {e}")
                overall_ok = False
    finally:
        mt5.shutdown()

    return 0 if overall_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
