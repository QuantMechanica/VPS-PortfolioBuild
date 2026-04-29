"""Rebuild a TDM-style M1 CSV from a tick CSV (streaming, constant memory).

Input tick format:
    YYYY.MM.DD HH:MM:SS.mmm,<bid>,<ask>

Output M1 format:
    YYYY.MM.DD,HH:MM:00,<open>,<high>,<low>,<close>,<tick_count>
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
from typing import TextIO


def _fmt_price(value: float) -> str:
    text = f"{value:.10f}".rstrip("0").rstrip(".")
    return text if text else "0"


def _flush_bar(out: TextIO, minute_key: str, o: float, h: float, l: float, c: float, ticks: int) -> None:
    date_part = minute_key[:10]
    time_part = minute_key[11:] + ":00"
    line = f"{date_part},{time_part},{_fmt_price(o)},{_fmt_price(h)},{_fmt_price(l)},{_fmt_price(c)},{ticks}\n"
    out.write(line)


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def rebuild_m1(tick_csv: Path, out_csv: Path) -> dict[str, object]:
    if not tick_csv.exists():
        raise FileNotFoundError(f"tick csv not found: {tick_csv}")

    out_csv.parent.mkdir(parents=True, exist_ok=True)
    tmp_csv = out_csv.with_suffix(out_csv.suffix + ".tmp")

    lines_in = 0
    malformed = 0
    bars_out = 0

    current_minute = ""
    o = h = l = c = 0.0
    ticks = 0

    with tick_csv.open("r", encoding="utf-8", errors="replace") as src, tmp_csv.open("w", encoding="utf-8", newline="") as out:
        for raw in src:
            line = raw.strip()
            if not line:
                continue
            lines_in += 1
            parts = line.split(",")
            if len(parts) < 2:
                malformed += 1
                continue

            ts = parts[0].strip()
            bid_raw = parts[1].strip()
            if len(ts) < 16:
                malformed += 1
                continue

            try:
                bid = float(bid_raw)
            except ValueError:
                malformed += 1
                continue

            minute_key = ts[:16]
            if current_minute == "":
                current_minute = minute_key
                o = h = l = c = bid
                ticks = 1
                continue

            if minute_key == current_minute:
                if bid > h:
                    h = bid
                if bid < l:
                    l = bid
                c = bid
                ticks += 1
                continue

            _flush_bar(out, current_minute, o, h, l, c, ticks)
            bars_out += 1

            current_minute = minute_key
            o = h = l = c = bid
            ticks = 1

        if current_minute:
            _flush_bar(out, current_minute, o, h, l, c, ticks)
            bars_out += 1

    old_exists = out_csv.exists()
    old_sha = _sha256_file(out_csv) if old_exists else None
    new_sha = _sha256_file(tmp_csv)

    if old_exists and old_sha == new_sha:
        tmp_csv.unlink(missing_ok=True)
        replaced = False
    else:
        tmp_csv.replace(out_csv)
        replaced = True

    return {
        "tick_csv": str(tick_csv),
        "m1_csv": str(out_csv),
        "lines_in": lines_in,
        "bars_out": bars_out,
        "malformed": malformed,
        "replaced": replaced,
        "sha256": new_sha,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tick-csv", required=True)
    ap.add_argument("--m1-csv", required=True)
    args = ap.parse_args()

    result = rebuild_m1(Path(args.tick_csv), Path(args.m1_csv))
    print("status=ok")
    for k, v in result.items():
        print(f"{k}={v}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
