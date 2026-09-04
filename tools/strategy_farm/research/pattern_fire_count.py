"""Offline D1 blacklist counter. No farm, terminal or selection-rule mutations.

Bar timestamps are MT5 broker civil time, encoded as epoch seconds without a
timezone conversion. Index zero in evaluate() is the most recent CLOSED bar.
Entry deals are joined to their order creation time: a pending order's gate ran
at creation, not at its later fill. Counts are per distinct filled entry order.
CSV tick ingestion requires explicit UTC or broker time; native TKC is rejected.
"""
from __future__ import annotations

import argparse
import bisect
import calendar
import csv
import gzip
import hashlib
import json
import math
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
from html.parser import HTMLParser
from pathlib import Path
from zoneinfo import ZoneInfo

IDS = tuple(range(3, 61)) + tuple(range(77, 85)) + tuple(range(87, 95)) + (98, 99, 100)
ARMS = tuple(f"{side}_{pid:03d}" for side in ("buy", "sell") for pid in IDS)
MQL_SOURCE_SHA256_LF = "82ec20e7d6492e0cd3d648000338de292282d1247e1d72e7e6f36e702c41261f"
REQUIRED = {90: 101, 91: 101, 82: 22, 83: 22, 87: 21, 88: 21, 89: 21,
            98: 22, 57: 12, 58: 12, 44: 8, 43: 7, 42: 4, 53: 4, 54: 4,
            99: 1, 100: 1}
REQUIRED.update({i: 11 for i in (77, 78, 79, 80, 81, 93, 94)})
REQUIRED.update({i: 6 for i in (35, 36, 37, 38, 84, 92)})


@dataclass(frozen=True)
class Bar:
    time: int
    open: float
    high: float
    low: float
    close: float
    tick_volume: int


@dataclass(frozen=True)
class Entry:
    time: int
    direction: str
    order_id: str
    decision_time: int
    symbol: str


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def required_bars(pid: int) -> int:
    if pid not in IDS:
        raise ValueError(f"unsupported predicate: {pid}")
    return REQUIRED.get(pid, 3)


def mql_sum(values) -> float:
    # Python 3.12+ sum uses compensated float summation; MQL uses sequential
    # double addition. Preserve the latter at strict comparison boundaries.
    result = 0.0
    for value in values:
        result += value
    return result


def evaluate(pid: int, bars: list[Bar]) -> bool:
    """Literal arithmetic/comparison port of QM_PP_Evaluate, newest bar first.

    Raises on missing/invalid history instead of mislabelling it 'never fires'.
    The MQL profile layer fails closed on that history, in BOTH directions.
    """
    if len(bars) < required_bars(pid):
        raise ValueError(f"short history for predicate {pid}")
    for b in bars:
        if b.time <= 0 or b.high < b.low or not all(math.isfinite(v) for v in
                (b.open, b.high, b.low, b.close, b.tick_volume)):
            raise ValueError("invalid bar")
    o, h, l, c, v = ([getattr(b, k) for b in bars] for k in
                     ("open", "high", "low", "close", "tick_volume"))
    r = [hi - lo for hi, lo in zip(h, l)]
    body = [abs(ci - oi) for ci, oi in zip(c, o)]
    bull = [ci > oi for ci, oi in zip(c, o)]
    bear = [ci < oi for ci, oi in zip(c, o)]
    up, lo = h[0] - max(o[0], c[0]), min(o[0], c[0]) - l[0]
    r0, b0 = r[0], body[0]

    def atr(start: int, period: int) -> float:
        if start + period >= len(bars):
            return 0.0
        return mql_sum(max(h[i], c[i + 1]) - min(l[i], c[i + 1])
                   for i in range(start, start + period)) / period

    match pid:
        case 3: return r0 > 0 and b0 <= .10 * r0
        case 4: return r0 > 0 and b0 <= .10 * r0 and up <= .10 * r0 and lo >= .50 * r0
        case 5: return r0 > 0 and b0 <= .10 * r0 and lo <= .10 * r0 and up >= .50 * r0
        case 6 | 8:
            return (r0 > 0 and b0 <= .35 * r0 and lo >= 2 * b0 and up <= .30 * b0
                    and (pid == 6 or c[1] > c[2]))
        case 7 | 9:
            return (r0 > 0 and b0 <= .35 * r0 and up >= 2 * b0 and lo <= .30 * b0
                    and (pid == 7 or c[1] > c[2]))
        case 10: return r0 > 0 and lo >= .66 * r0 and up <= .25 * r0
        case 11: return r0 > 0 and up >= .66 * r0 and lo <= .25 * r0
        case 12: return r0 > 0 and lo >= .50 * r0
        case 13: return r0 > 0 and up >= .50 * r0
        case 14: return r0 > 0 and bull[0] and b0 >= .95 * r0
        case 15: return r0 > 0 and bear[0] and b0 >= .95 * r0
        case 16: return r0 > 0 and bull[0] and lo <= .05 * r0 and b0 >= .60 * r0
        case 17: return r0 > 0 and bear[0] and up <= .05 * r0 and b0 >= .60 * r0
        case 18: return r0 > 0 and .20 * r0 <= b0 <= .35 * r0 and up >= .25 * r0 and lo >= .25 * r0
        case 19: return bear[1] and bull[0] and c[0] >= o[1] and o[0] <= c[1]
        case 20: return bull[1] and bear[0] and o[0] >= c[1] and c[0] <= o[1]
        case 21: return bear[1] and bull[0] and c[0] <= o[1] and o[0] >= c[1] and body[1] > b0
        case 22: return bull[1] and bear[0] and o[0] <= c[1] and c[0] >= o[1] and body[1] > b0
        case 23: return bear[1] and o[0] < l[1] and c[0] > (o[1] + c[1]) * .5 and c[0] < o[1]
        case 24: return bull[1] and o[0] > h[1] and c[0] < (o[1] + c[1]) * .5 and c[0] > o[1]
        case 25: return r[1] > 0 and abs(l[0] - l[1]) <= .05 * r[1] and l[0] < l[2] and l[1] < l[2]
        case 26: return r[1] > 0 and abs(h[0] - h[1]) <= .05 * r[1] and h[0] > h[2] and h[1] > h[2]
        case 27: return bear[2] and r[1] > 0 and body[1] <= .35 * r[1] and bull[0] and c[0] > (o[2] + c[2]) * .5
        case 28: return bull[2] and r[1] > 0 and body[1] <= .35 * r[1] and bear[0] and c[0] < (o[2] + c[2]) * .5
        case 29: return all(bull[:3]) and c[0] > c[1] > c[2] and o[0] <= c[1] and o[1] <= c[2]
        case 30: return all(bear[:3]) and c[0] < c[1] < c[2] and o[0] >= c[1] and o[1] >= c[2]
        case 31: return bear[2] and bull[1] and o[1] >= c[2] and c[1] <= o[2] and body[2] > body[1] and bull[0] and c[0] > h[1]
        case 32: return bull[2] and bear[1] and o[1] <= c[2] and c[1] >= o[2] and body[2] > body[1] and bear[0] and c[0] < l[1]
        case 33: return evaluate(19, bars) and c[0] > h[1]
        case 34: return evaluate(20, bars) and c[0] < l[1]
        case 35 | 36:
            inside = all(h[i] <= h[4] and l[i] >= l[4] for i in (3, 2, 1))
            if pid == 35:
                return bull[4] and all(bear[1:4]) and bull[0] and inside and c[0] > h[4]
            return bear[4] and all(bull[1:4]) and bear[0] and inside and c[0] < l[4]
        case 37 | 38:
            small = r[4] > 0 and all(body[i] <= .5 * r[4] for i in (3, 2, 1))
            if pid == 37: return bull[4] and l[3] > h[4] and small and c[0] > h[4]
            return bear[4] and h[3] < l[4] and small and c[0] < l[4]
        case 39: return h[0] <= h[1] and l[0] >= l[1]
        case 40: return h[0] <= h[1] <= h[2] and l[0] >= l[1] >= l[2]
        case 41: return h[0] >= h[1] and l[0] <= l[1]
        case 42: return all(r0 < r[i] for i in range(1, 4))
        case 43: return all(r0 < r[i] for i in range(1, 7))
        case 44: return atr(1, 5) > 0 and r0 > 1.5 * atr(1, 5)
        case 45: return o[0] > h[1]
        case 46: return o[0] < l[1]
        case 47: return o[0] > h[1] and bull[0]
        case 48: return o[0] < l[1] and bear[0]
        case 49: return o[0] > h[1] and bear[0] and r0 < .5 * r[1]
        case 50: return o[0] < l[1] and bull[0] and r0 < .5 * r[1]
        case 51: return h[0] > h[1] and l[0] > l[1]
        case 52: return l[0] < l[1] and h[0] < h[1]
        case 53: return c[0] > c[1] > c[2] > c[3]
        case 54: return c[0] < c[1] < c[2] < c[3]
        case 55: return c[0] > h[1]
        case 56: return c[0] < l[1]
        case 57: return atr(1, 10) > 0 and r0 < .7 * atr(1, 10)
        case 58: return atr(1, 10) > 0 and r0 > 1.3 * atr(1, 10)
        case 59: return r0 < r[1] < r[2]
        case 60: return r0 > r[1] > r[2]
        case 77 | 78 | 80 | 81:
            bulls = sum(bull[:10])
            bears = 10 - bulls  # MQL deliberately includes dojis in this count.
            if pid == 77: return bulls >= 7 and c[0] > c[9]
            if pid == 78: return 5 <= bulls <= 6
            if pid == 80: return 5 <= bears <= 6
            return bears >= 7 and c[0] < c[9]
        case 79:
            hi, low = max(h[:10]), min(l[:10])
            return hi - low > 0 and abs(c[0] - (hi + low) * .5) < .25 * (hi - low)
        case 82: return atr(1, 20) > 0 and r0 > 2 * atr(1, 20)
        case 83: return atr(0, 20) > 0 and atr(0, 5) > 1.5 * atr(0, 20)
        case 84: return c[4] < c[2] and abs(c[0] - c[1]) < .3 * abs(c[3] - c[4])
        case 87: return atr(0, 20) > 0 and abs(c[0] - mql_sum(c[:20]) / 20) > 2 * atr(0, 20)
        case 88 | 89:
            mean = mql_sum(c[:20]) / 20
            sd = math.sqrt(mql_sum((ci - mean) * (ci - mean) for ci in c[:20]) / 20)
            return sd > 0 and ((c[0] - mean) / sd > 2.5 if pid == 88 else (c[0] - mean) / sd < -2.5)
        case 90 | 91:
            percentile = sum(ri < r0 for ri in r[1:101]) / 100.0
            return percentile >= .90 if pid == 90 else percentile <= .10
        case 92: return h[2] > h[1] and h[2] > h[3] and h[2] > h[4] and c[0] > h[2]
        case 93 | 94:
            path = mql_sum(abs(c[i] - c[i + 1]) for i in range(10))
            return path > 0 and (abs(c[0] - c[10]) / path > .7 if pid == 93 else abs(c[0] - c[10]) / path < .3)
        case 98:
            avg = mql_sum(float(vi) for vi in v[1:21]) / 20
            return avg > 0 and atr(1, 20) > 0 and v[0] > 3 * avg and r0 > 1.5 * atr(1, 20)
        case 99 | 100:
            d = datetime.fromtimestamp(bars[0].time, timezone.utc)
            if pid == 99: return d.weekday() == 4 and 15 <= d.day <= 21
            return d.month in (3, 6, 9, 12) and d.day >= calendar.monthrange(d.year, d.month)[1] - 1
    raise AssertionError(pid)


def civil_epoch(value: str) -> int:
    return int(datetime.strptime(value.strip(), "%Y.%m.%d %H:%M:%S").replace(tzinfo=timezone.utc).timestamp())


class ReportRows(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.rows, self.row, self.cell = [], None, None

    def handle_starttag(self, tag, attrs):
        if tag == "tr": self.row = []
        if tag in ("td", "th") and self.row is not None: self.cell = []

    def handle_data(self, data):
        if self.cell is not None: self.cell.append(data)

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.cell is not None:
            self.row.append(" ".join("".join(self.cell).split()))
            self.cell = None
        if tag == "tr" and self.row is not None:
            self.rows.append(self.row)
            self.row = None


def parse_report(path: Path) -> tuple[list[Entry], list[Entry]]:
    """Return filled entry orders and all candidate orders (diagnostic only).

    English MT5 Orders + Deals layout. Unknown/reversal formats fail explicitly;
    missing Orders is not silently replaced by fill time. Partial fills dedupe.
    """
    raw = path.read_bytes()
    encoding = "utf-16" if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8-sig"
    parser = ReportRows()
    parser.feed(raw.decode(encoding))
    section, orders, entries, saw_deals, saw_orders = "", {}, {}, False, False
    exit_orders = set()
    reported_trades = None
    for row in parser.rows:
        if "Total Trades:" in row:
            reported_trades = int(row[row.index("Total Trades:") + 1].replace(" ", ""))
        if row == ["Orders"]: section, saw_orders = "orders", True
        if row == ["Deals"]: section, saw_deals = "deals", True
        if not row or len(row[0]) != 19 or row[0][4] != ".": continue
        if section == "orders" and len(row) >= 10 and row[2] and row[3].split()[0] in ("buy", "sell"):
            t = civil_epoch(row[0])
            entry = Entry(t, row[3].split()[0].upper(), row[1], t, row[2])
            if row[1] in orders: raise ValueError(f"duplicate order {row[1]}")
            orders[row[1]] = entry
        elif section == "deals" and len(row) >= 8 and row[3] in ("buy", "sell"):
            if row[4] == "out":
                exit_orders.add(row[7])
                continue
            if row[4] != "in": raise ValueError(f"unsupported deal direction {row[4]}")
            order = orders.get(row[7])
            if order is None: raise ValueError(f"entry deal has no creation order: {row[7]}")
            t = civil_epoch(row[0])
            if t < order.time or row[3].upper() != order.direction or row[2] != order.symbol:
                raise ValueError(f"inconsistent entry order {row[7]}")
            entries.setdefault(row[7], Entry(t, order.direction, row[7], order.time, order.symbol))
    if not saw_orders or not saw_deals: raise ValueError("MT5 English Orders/Deals sections required")
    if exit_orders.intersection(entries): raise ValueError("mixed entry/exit order is unsupported")
    if reported_trades is not None and reported_trades != len(entries):
        raise ValueError("report total trades does not match distinct parsed entry orders")
    return list(entries.values()), [e for key, e in orders.items() if key not in exit_orders]


def read_bars(path: Path) -> list[Bar]:
    with path.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        fields = set(reader.fieldnames or [])
        if not {"time", "open", "high", "low", "close"} <= fields or not {"tick_volume", "tickvol"} & fields:
            raise ValueError("D1 CSV requires time, OHLC and tick volume")
        result = [Bar(int(row["time"]), *(float(row[k]) for k in ("open", "high", "low", "close")),
                      int(row.get("tick_volume", row.get("tickvol")))) for row in reader]
    if not result or any(a.time >= b.time for a, b in zip(result, result[1:])):
        raise ValueError("bars must be nonempty, unique, chronological")
    for b in result:
        if b.time % 86400 or b.high < max(b.open, b.close) or b.low > min(b.open, b.close) or b.tick_volume < 0:
            raise ValueError("invalid D1 OHLC/volume or non-midnight broker timestamp")
        evaluate(99, [b])
    return result


def broker_epoch(utc: datetime) -> int:
    """NY 17:00 close: New York civil time + seven hours, GMT+2/+3."""
    if utc.tzinfo is None: raise ValueError("UTC tick timestamp must carry timezone")
    civil = utc.astimezone(ZoneInfo("America/New_York")).replace(tzinfo=None) + timedelta(hours=7)
    return int(civil.replace(tzinfo=timezone.utc).timestamp())


def build_tick_cache(archive: Path, output: Path, timestamp_basis: str) -> dict:
    """Ingest transparent monthly CSV/CSV.GZ with time_msc,bid columns.

    No inferred TKC decoding, timezone guessing, ask-price candles or gap filling.
    Native archive needs a separately governed, lossless export first.
    """
    paths = sorted(archive.glob("*.csv")) + sorted(archive.glob("*.csv.gz"))
    paths = sorted(paths)
    if not paths:
        raise ValueError(f"no transparent tick CSV in {archive}; native .tkc decoding is unsupported")
    months = [p.name[:6] for p in paths]
    if len(months) != len(set(months)) or any(len(m) != 6 or not m.isdigit() for m in months):
        raise ValueError("require exactly one YYYYMM.csv[.gz] per month")
    if timestamp_basis not in ("utc", "broker"): raise ValueError("explicit tick timestamp basis required")
    grouped, sources, previous = {}, [], -1
    for path in paths:
        opener = gzip.open if path.suffix == ".gz" else open
        with opener(path, "rt", encoding="utf-8-sig", newline="") as f:
            for row in csv.DictReader(f):
                stamp, bid = int(row["time_msc"]), float(row["bid"])
                if stamp < previous or not math.isfinite(bid) or bid <= 0:
                    raise ValueError(f"invalid/out-of-order tick in {path}")
                previous = stamp
                t = stamp // 1000
                if timestamp_basis == "utc": t = broker_epoch(datetime.fromtimestamp(t, timezone.utc))
                day = t // 86400 * 86400
                if day not in grouped: grouped[day] = [bid, bid, bid, bid, 0]
                b = grouped[day]
                b[1], b[2], b[3], b[4] = max(b[1], bid), min(b[2], bid), bid, b[4] + 1
        sources.append({"path": str(path), "sha256": sha256(path)})
    if not grouped: raise ValueError("tick source is empty")
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f); w.writerow(["time", "open", "high", "low", "close", "tick_volume"])
        for day, values in sorted(grouped.items()): w.writerow([day, *values])
    manifest = {"schema": "qm.d1_tick_cache.v1", "source_kind": "transparent_tick_csv",
                "timestamp_basis": timestamp_basis, "broker_day": "America/New_York + 7h",
                "sources": sources, "bars": len(grouped), "cache_sha256": sha256(output),
                "tester_spot_check_verified": False}
    output.with_suffix(".provenance.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def count_entries(entries: list[Entry], bars: list[Bar]) -> tuple[dict[str, int], list[dict]]:
    counts, alignment = dict.fromkeys(ARMS, 0), []
    times = [b.time for b in bars]
    for entry in entries:
        # iBarShift(exact=false) current D1 bar then closed_shift=1; strict day
        # presence rejects weekend/gap guesses. Friday is Monday's prior bar.
        day = entry.decision_time // 86400 * 86400
        current = bisect.bisect_left(times, day)
        if current == len(times) or times[current] != day or current < 101:
            raise ValueError(f"missing current/prior D1 history for order {entry.order_id}")
        window = list(reversed(bars[max(0, current - 120):current]))
        fired = [pid for pid in IDS if evaluate(pid, window)]
        if entry.direction not in ("BUY", "SELL"): raise ValueError("unknown entry side")
        for pid in fired: counts[f"{entry.direction.lower()}_{pid:03d}"] += 1
        alignment.append({**asdict(entry), "reference_bar_time": window[0].time, "fired_predicates": fired})
    return counts, alignment


def count_program(program: str, symbol: str, reports: dict[int, Path], bars_path: Path) -> dict:
    source = Path(__file__).resolve().parents[3] / "framework/include/QM/QM_PatternPermission.mqh"
    if hashlib.sha256(source.read_text(encoding="utf-8").encode()).hexdigest() != MQL_SOURCE_SHA256_LF:
        raise ValueError("MQL predicate source changed; port and fixtures require review")
    bars, years, order_years, alignments, sources = read_bars(bars_path), {}, {}, {}, []
    for year, report in sorted(reports.items()):
        entries, orders = parse_report(report)
        if any(e.symbol != symbol for e in entries + orders): raise ValueError("report symbol mismatch")
        if any(datetime.fromtimestamp(e.time, timezone.utc).year != year for e in entries):
            raise ValueError("entry outside declared baseline year")
        years[str(year)], alignments[str(year)] = count_entries(entries, bars)
        order_years[str(year)], _ = count_entries(orders, bars)
        sources.append({"year": year, "path": str(report), "sha256": sha256(report),
                        "entry_orders": len(entries), "all_orders": len(orders)})
    if not reports: raise ValueError("at least one baseline report is required")
    totals = {arm: sum(row[arm] for row in years.values()) for arm in ARMS}
    provenance_path = bars_path.with_suffix(".provenance.json")
    provenance = json.loads(provenance_path.read_text()) if provenance_path.exists() else {"source_kind": "unverified_csv"}
    if provenance.get("cache_sha256") not in (None, sha256(bars_path)): raise ValueError("stale cache provenance")
    return {"schema": "qm.pattern_fire_count.v1", "program_id": program, "symbol": symbol,
            "predicate_source_sha256_lf": MQL_SOURCE_SHA256_LF, "counter_sha256": sha256(Path(__file__)),
            "declared_trial_count": 154, "reference_timeframe": "D1", "years_observed": sorted(reports),
            "counts_by_year": years, "total": totals, "never_fires_observed_years": [a for a in ARMS if not totals[a]],
            "all_order_counts_by_year_diagnostic": order_years, "entry_alignment": alignments,
            "baseline_reports": sources, "bars_path": str(bars_path), "bars_sha256": sha256(bars_path),
            "bars_provenance": provenance, "safe_to_skip": False}


def write_result(result: dict, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    years = list(result["counts_by_year"])
    with output.with_suffix(".csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f); w.writerow(["arm", *years, "total"])
        for arm in ARMS: w.writerow([arm, *(result["counts_by_year"][y][arm] for y in years), result["total"][arm]])


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="command", required=True)
    build = sub.add_parser("build-bars")
    build.add_argument("--archive", type=Path, required=True)
    build.add_argument("--output", type=Path, required=True)
    build.add_argument("--timestamp-basis", choices=("utc", "broker"), required=True)
    count = sub.add_parser("count")
    count.add_argument("--program", required=True); count.add_argument("--symbol", required=True)
    count.add_argument("--bars", type=Path, required=True); count.add_argument("--output", type=Path, required=True)
    count.add_argument("--report", action="append", required=True, help="YEAR=path/to/report.htm")
    args = ap.parse_args()
    if args.command == "build-bars":
        print(json.dumps(build_tick_cache(args.archive, args.output, args.timestamp_basis), indent=2))
    else:
        reports = {}
        for value in args.report:
            year, path = value.split("=", 1)
            if int(year) in reports: raise ValueError("duplicate baseline year")
            reports[int(year)] = Path(path)
        write_result(count_program(args.program, args.symbol, reports, args.bars), args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
