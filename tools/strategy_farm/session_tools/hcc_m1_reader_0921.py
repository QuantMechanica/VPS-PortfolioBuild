#!/usr/bin/env python3
"""Read-only MT5 custom-history (.hcc) M1 reader for the Velocity prescreen (Fable, 2026-09-21).

Layout (decoded 2026-09-21 against T2 EURUSD.DWX/2026.hcc and validated against the
QM_M1_SpreadHarvest JSONL export of the same terminal — see ``validate``):

* 228-byte file header (magic 0x01f6, UTF-16 copyright, "History", symbol).
* Table of 18-byte entries from offset 228: ``<HHIHII`` = day_index, m1_bars, ?, ?, block_size,
  block_offset (ends when the entry no longer describes a block inside the file).
* Each day block: 129-byte header (symbol name + counters), then ``m1_bars + 1`` records of 60 bytes
  ``<q4dqiq`` = time, open, high, low, close, tick_volume, spread, real_volume. Record 0 of a block is
  the day summary bar (time = 00:00 server time) and is skipped; the rest are M1 bars.
* Timestamps are broker/server time stored as if UTC (identical to the harvest ``ts`` convention).

The reader never writes under ``Bases/`` and tolerates a terminal holding its own copy locked
(PermissionError) by falling back to the next terminal's content-identical archive.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import struct
import sys
from pathlib import Path

HEADER = 228
ENTRY = struct.Struct("<HHIHII")
BLOCK_HDR = 129
REC = struct.Struct("<q4dqiq")
TERMINALS = [f"D:/QM/mt5/T{i}/Bases/Custom/history" for i in (2, 3, 4, 5, 6, 7, 8, 9, 10, 1)]


def _open_year(symbol: str, year: int) -> tuple[bytes, str]:
    last = None
    for root in TERMINALS:
        p = Path(root) / symbol / f"{year}.hcc"
        if not p.exists():
            continue
        try:
            with open(p, "rb") as fh:
                return fh.read(), str(p)
        except PermissionError as exc:  # terminal holds its copy open
            last = exc
            continue
    raise FileNotFoundError(f"{symbol}/{year}.hcc unreadable in every terminal ({last})")


def read_year(symbol: str, year: int):
    """Yield (time_epoch_server, open, high, low, close, tick_volume, spread) M1 bars in file order."""
    b, _ = _open_year(symbol, year)
    n = len(b)
    o = HEADER
    while o + ENTRY.size <= n:
        _day, nbars, _x, _y, size, off = ENTRY.unpack_from(b, o)
        if off == 0 or off >= n or size == 0 or off + size > n:
            break
        o += ENTRY.size
        if nbars == 0:
            continue
        base = off + BLOCK_HDR
        expect = BLOCK_HDR + REC.size * (nbars + 1)
        if expect != size:
            raise ValueError(f"{symbol}/{year}: block at {off} size {size} != {expect}")
        for k in range(1, nbars + 1):
            t, op, hi, lo, cl, tv, sp, _rv = REC.unpack_from(b, base + REC.size * k)
            yield t, op, hi, lo, cl, tv, sp


def validate(symbol: str, year: int, harvest: Path) -> dict:
    bars = {t: (op, hi, lo, cl, tv) for t, op, hi, lo, cl, tv, _ in read_year(symbol, year)}
    matched = mismatched = missing = 0
    n = 0
    with open(harvest, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            r = json.loads(line)
            n += 1
            t = int(dt.datetime.strptime(r["ts"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc).timestamp())
            ref = bars.get(t)
            if ref is None:
                missing += 1
                continue
            if (ref[0], ref[1], ref[2], ref[3], ref[4]) == (r["open"], r["high"], r["low"], r["close"], r["tick_volume"]):
                matched += 1
            else:
                mismatched += 1
    return {"symbol": symbol, "year": year, "harvest_rows": n, "hcc_bars": len(bars), "matched": matched,
            "mismatched": mismatched, "missing_in_hcc": missing}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    v = sub.add_parser("validate")
    v.add_argument("--symbol", default="EURUSD.DWX")
    v.add_argument("--year", type=int, default=2026)
    v.add_argument("--harvest", default="D:/QM/mt5/T1/MQL5/Files/QM/m1_harvest/DXZ_FACTORY_20260905T045440Z_fd5816ec_EURUSD_DWX_M1.jsonl")
    c = sub.add_parser("count")
    c.add_argument("--symbol", required=True)
    c.add_argument("--years", default="2018-2025")
    a = ap.parse_args()
    if a.cmd == "validate":
        print(json.dumps(validate(a.symbol, a.year, Path(a.harvest)), indent=1))
    else:
        y0, y1 = (int(x) for x in a.years.split("-"))
        for y in range(y0, y1 + 1):
            bars = list(read_year(a.symbol, y))
            first = dt.datetime.fromtimestamp(bars[0][0], dt.UTC) if bars else None
            last = dt.datetime.fromtimestamp(bars[-1][0], dt.UTC) if bars else None
            print(a.symbol, y, len(bars), first, last)
    return 0


if __name__ == "__main__":
    sys.exit(main())
