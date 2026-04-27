"""check_dwx_csv_tail_alignment.py

Fast preflight for DWX CSV consistency:
- compares latest timestamp in <symbol>_...csv (tick) vs <symbol>_..._M1.csv
- exits non-zero when tails are stale/misaligned beyond threshold
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path


def read_last_line(path: Path) -> str:
    with path.open("rb") as f:
        f.seek(0, 2)
        size = f.tell()
        if size == 0:
            return ""
        pos = size - 1
        # Skip trailing newline chars first.
        while pos >= 0:
            f.seek(pos)
            b = f.read(1)
            if b not in (b"\n", b"\r"):
                break
            pos -= 1
        if pos < 0:
            return ""
        # Walk to start-of-line.
        while pos > 0:
            f.seek(pos)
            if f.read(1) == b"\n":
                pos += 1
                break
            pos -= 1
        f.seek(pos)
        return f.readline().decode("utf-8", errors="replace").strip()


def parse_tick_ts(line: str) -> dt.datetime:
    # 2026.04.06 02:59:59.867,....
    stamp = line.split(",", 1)[0].strip()
    return dt.datetime.strptime(stamp, "%Y.%m.%d %H:%M:%S.%f")


def parse_m1_ts(line: str) -> dt.datetime:
    # 2026.04.13,02:59:00,....
    parts = line.split(",")
    stamp = f"{parts[0].strip()} {parts[1].strip()}"
    return dt.datetime.strptime(stamp, "%Y.%m.%d %H:%M:%S")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--symbol", required=True, help="Symbol root, e.g. XAUUSD")
    ap.add_argument(
        "--csv-dir",
        default=r"D:\QM\reports\setup\tick-data-timezone",
        help="Directory containing TDM CSV exports",
    )
    ap.add_argument(
        "--max-gap-hours",
        type=float,
        default=1.0,
        help="Maximum allowed abs(tick_tail - m1_tail) in hours",
    )
    ap.add_argument("--json-out", help="Optional path to write JSON result")
    args = ap.parse_args()

    csv_dir = Path(args.csv_dir)
    tick_path = csv_dir / f"{args.symbol}_GMT+2_US-DST.csv"
    m1_path = csv_dir / f"{args.symbol}_GMT+2_US-DST_M1.csv"
    if not tick_path.exists() or not m1_path.exists():
        print("missing_csv")
        return 2

    tick_tail = read_last_line(tick_path)
    m1_tail = read_last_line(m1_path)
    if not tick_tail or not m1_tail:
        print("empty_csv_tail")
        return 3

    tick_dt = parse_tick_ts(tick_tail)
    m1_dt = parse_m1_ts(m1_tail)
    gap_hours = (m1_dt - tick_dt).total_seconds() / 3600.0
    aligned = abs(gap_hours) <= float(args.max_gap_hours)

    payload = {
        "generated_at_local": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
        "symbol": args.symbol,
        "tick_csv": str(tick_path),
        "m1_csv": str(m1_path),
        "tick_tail_line": tick_tail,
        "m1_tail_line": m1_tail,
        "tick_tail_iso": tick_dt.isoformat(),
        "m1_tail_iso": m1_dt.isoformat(),
        "gap_hours_m1_minus_tick": round(gap_hours, 3),
        "max_gap_hours": float(args.max_gap_hours),
        "aligned": aligned,
    }
    if args.json_out:
        out = Path(args.json_out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(json.dumps(payload, indent=2))
    return 0 if aligned else 1


if __name__ == "__main__":
    raise SystemExit(main())
