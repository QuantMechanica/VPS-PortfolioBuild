#!/usr/bin/env python3
"""Independently compare the bound calendar to QM5_1537's legacy D1 rank.

This deliberately reimplements the pre-rework MQL algorithm instead of importing
the calendar builder.  It is the bounded D1-only equivalence harness required by
router task a96ddcdd-fc8b-49f7-9e6e-f87964a2522d.
"""

from __future__ import annotations

import argparse
import bisect
import csv
import hashlib
import json
import math
import struct
from datetime import datetime, timezone
from pathlib import Path


LEGACY_SOURCE_SHA256 = "97E76AA58FA00F61360A9F6F251E36D6338474F3DE333351C7A7C3997526A073"
SYMBOLS = [
    "XAUUSD.DWX", "XAGUSD.DWX", "XNGUSD.DWX", "XTIUSD.DWX",
    "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX", "SP500.DWX",
    "AUDCAD.DWX", "AUDCHF.DWX", "AUDJPY.DWX", "AUDNZD.DWX", "AUDUSD.DWX",
    "CADCHF.DWX", "CADJPY.DWX", "CHFJPY.DWX", "EURAUD.DWX", "EURCAD.DWX",
    "EURCHF.DWX", "EURGBP.DWX", "EURJPY.DWX", "EURNZD.DWX", "EURUSD.DWX",
    "GBPAUD.DWX", "GBPCAD.DWX", "GBPCHF.DWX", "GBPJPY.DWX", "GBPNZD.DWX",
    "GBPUSD.DWX", "NZDCAD.DWX", "NZDCHF.DWX", "NZDJPY.DWX", "NZDUSD.DWX",
    "USDCAD.DWX", "USDCHF.DWX", "USDJPY.DWX",
]


def cache_vectors(path: Path) -> tuple[list[int], list[float]]:
    raw = path.read_bytes()
    if struct.unpack_from("<I", raw, 0)[0] != 502:
        raise ValueError(f"unsupported cache version: {path}")
    count = struct.unpack_from("<I", raw, 428)[0]
    times = list(struct.unpack_from(f"<{count}Q", raw, 432))
    offset = 432 + count * 8
    for label in ("open", "high", "low"):
        vector_count = struct.unpack_from("<I", raw, offset)[0]
        if vector_count != count:
            raise ValueError(f"{path}: {label} count mismatch")
        offset += 4 + count * 8
    if struct.unpack_from("<I", raw, offset)[0] != count:
        raise ValueError(f"{path}: close count mismatch")
    offset += 4
    closes = list(struct.unpack_from(f"<{count}d", raw, offset))
    return times, closes


def month(epoch: int) -> int:
    value = datetime.fromtimestamp(epoch, timezone.utc)
    return value.year * 100 + value.month


def legacy_vol(times: list[int], closes: list[float], asof: int) -> float | None:
    end = bisect.bisect_left(times, asof)
    if end < 270:
        return None
    total = 0.0
    total_sq = 0.0
    for index in range(252):
        newest = closes[end - 1 - index]
        older = closes[end - 2 - index]
        value = math.log(newest / older)
        total += value
        total_sq += value * value
    mean = total / 252.0
    variance = (total_sq - 252.0 * mean * mean) / 251.0
    return math.sqrt(max(0.0, variance)) * math.sqrt(252.0) * 100.0


def first_bars(times: list[int]) -> dict[int, int]:
    result: dict[int, int] = {}
    for timestamp in times:
        result.setdefault(month(timestamp), timestamp)
    return result


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def verify(args: argparse.Namespace) -> dict[str, object]:
    source_hash = file_sha256(args.legacy_source)
    if source_hash != LEGACY_SOURCE_SHA256:
        raise ValueError(
            f"legacy source drift: {source_hash} != {LEGACY_SOURCE_SHA256}; "
            "run the harness against the expected pre-rework source"
        )
    data = {
        symbol: cache_vectors(args.history_root / symbol / "cache" / "Daily.hc")
        for symbol in SYMBOLS
    }
    rows: dict[tuple[int, str], dict[str, str]] = {}
    with args.calendar.open(encoding="ascii", newline="") as handle:
        for row in csv.DictReader(handle):
            key = (int(row["month_key"]), row["host_symbol"])
            if key in rows:
                raise ValueError(f"duplicate calendar row {key}")
            rows[key] = row

    compared = 0
    failures: list[dict[str, object]] = []
    slot = {symbol: index for index, symbol in enumerate(SYMBOLS)}
    for host in SYMBOLS:
        for month_key, asof in sorted(first_bars(data[host][0]).items()):
            if not args.from_month <= month_key <= args.to_month:
                continue
            ranked: list[tuple[str, float]] = []
            for candidate in SYMBOLS:
                value = legacy_vol(*data[candidate], asof)
                if value is not None:
                    ranked.append((candidate, value))
            ranked.sort(key=lambda item: (-item[1], slot[item[0]]))
            names = [item[0] for item in ranked]
            expected_rank = names.index(host) if host in names else -1
            expected_selected = int(0 <= expected_rank < min(3, len(names)))
            expected_top = (names[:3] + ["", "", ""])[:3]
            expected_vol = dict(ranked).get(host, 0.0)
            actual = rows.get((month_key, host))
            compared += 1
            reasons: list[str] = []
            if actual is None:
                reasons.append("missing_row")
            else:
                if int(actual["host_rank"]) != expected_rank:
                    reasons.append("rank")
                if int(actual["valid_count"]) != len(ranked):
                    reasons.append("valid_count")
                if int(actual["selected"]) != expected_selected:
                    reasons.append("selected")
                actual_top = [actual["selected_1"], actual["selected_2"], actual["selected_3"]]
                if actual_top != expected_top:
                    reasons.append("top_three")
                if abs(float(actual["host_vol_pct"]) - expected_vol) > 5e-10:
                    reasons.append("host_vol_pct")
                if int(actual["asof_epoch"]) != asof:
                    reasons.append("asof_epoch")
            if reasons:
                failures.append({
                    "month_key": month_key,
                    "host_symbol": host,
                    "reasons": reasons,
                })

    report: dict[str, object] = {
        "status": "PASS" if not failures else "FAIL",
        "verified_at_utc": datetime.now(timezone.utc).isoformat(),
        "legacy_source": str(args.legacy_source.resolve()),
        "legacy_source_sha256": source_hash,
        "calendar": str(args.calendar.resolve()),
        "calendar_sha256": file_sha256(args.calendar),
        "history_root": str(args.history_root.resolve()),
        "from_month": args.from_month,
        "to_month": args.to_month,
        "host_months_compared": compared,
        "failure_count": len(failures),
        "failures": failures[:100],
        "algorithm": {
            "minimum_daily_bars": 270,
            "log_returns": 252,
            "sample_variance_denominator": 251,
            "annualization_days": 252,
            "top_n": 3,
            "tie_break": "basket_slot_ascending",
            "asof": "first host D1 bar in month; candidate closes strictly before asof",
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return report


def parser() -> argparse.ArgumentParser:
    ea_dir = Path(__file__).resolve().parents[1]
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--history-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\Bases\Custom\history"))
    result.add_argument("--legacy-source", type=Path, default=ea_dir / "QM5_1537_aa-vol-sma10.mq5")
    result.add_argument("--calendar", type=Path, default=ea_dir / "calendar" / "QM5_1537_monthly_sleeves_v1.csv")
    result.add_argument("--output", type=Path, default=ea_dir / "calendar" / "QM5_1537_equivalence_201807_202212.json")
    result.add_argument("--from-month", type=int, default=201807)
    result.add_argument("--to-month", type=int, default=202212)
    return result


def main() -> int:
    args = parser().parse_args()
    report = verify(args)
    print(json.dumps({key: report[key] for key in (
        "status", "host_months_compared", "failure_count", "calendar_sha256",
        "legacy_source_sha256",
    )}, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
