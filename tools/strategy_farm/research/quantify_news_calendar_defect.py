"""Quantify the news-calendar timestamp defect (2026-09-05).

Read-only over D:/QM/data/news_calendar/*.csv and the native MT5 calendar exports
D:/QM/mt5/T_Export/MQL5/Files/T_EXPORT_<CCY>_HIGH_2018_2025_NATIVE.csv.

Outputs (under --out):
  stored_tod_histogram.csv   per file, currency, event, year: stored UTC time-of-day counts
  native_join_deltas.csv     per matched (FF row, native row): delta_hours = stored_utc - native_utc
  summary.json               headline counts
"""
from __future__ import annotations

import argparse
import calendar as _cal
import csv
import json
import hashlib
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

CAL_DIR = Path(r"D:/QM/data/news_calendar")
FF = CAL_DIR / "forex_factory_calendar_clean.csv"
PRIMARY = CAL_DIR / "news_calendar_2015_2025.csv"
NATIVE_DIR = Path(r"D:/QM/mt5/T_Export/MQL5/Files")
CCYS = ("USD", "EUR", "GBP", "JPY")

# FF event name -> native event name (USD high-impact, exact native names from the export)
NAME_MAP_USD = {
    "Non-Farm Employment Change": "Nonfarm Payrolls",
    "Unemployment Rate": "Unemployment Rate",
    "Average Hourly Earnings m/m": "Average Hourly Earnings m/m",
    "CPI m/m": "CPI m/m",
    "Core CPI m/m": "Core CPI m/m",
    "CPI y/y": "CPI y/y",
    "PPI m/m": "PPI m/m",
    "Retail Sales m/m": "Retail Sales m/m",
    "Core Retail Sales m/m": "Core Retail Sales m/m",
    "Unemployment Claims": "Initial Jobless Claims",
    "Core PCE Price Index m/m": "Core PCE Price Index m/m",
    "Philly Fed Manufacturing Index": "Philadelphia Fed Manufacturing Index",
    "JOLTS Job Openings": "JOLTS Job Openings",
    "ISM Manufacturing PMI": "ISM Manufacturing PMI",
    "ISM Services PMI": "ISM Non-Manufacturing PMI",
    "ADP Non-Farm Employment Change": "ADP Nonfarm Employment Change",
    "CB Consumer Confidence": "CB Consumer Confidence Index",
    "Crude Oil Inventories": "EIA Crude Oil Stocks Change",
    "Federal Funds Rate": "Fed Interest Rate Decision",
    "FOMC Press Conference": "FOMC Press Conference",
    "Core Durable Goods Orders m/m": "Durable Goods Orders m/m",
    "Advance GDP q/q": "GDP q/q",
    "Prelim GDP q/q": "GDP q/q",
    "Final GDP q/q": "GDP q/q",
}
ET_0830_CLASS = {
    "Non-Farm Employment Change", "Unemployment Rate", "Average Hourly Earnings m/m", "CPI m/m", "Core CPI m/m",
    "CPI y/y", "PPI m/m", "Core PPI m/m", "Retail Sales m/m", "Core Retail Sales m/m", "Unemployment Claims",
    "Advance GDP q/q", "Prelim GDP q/q", "Final GDP q/q", "Core Durable Goods Orders m/m",
    "Philly Fed Manufacturing Index", "Empire State Manufacturing Index", "Building Permits",
    "Core PCE Price Index m/m", "Trade Balance",
}


def nth_sunday(year: int, month: int, n: int) -> int:
    first = datetime(year, month, 1).weekday()  # Mon=0
    first_sunday = 1 + (6 - first) % 7
    return first_sunday + 7 * (n - 1)


def us_dst_interval(year: int) -> tuple[datetime, datetime]:
    start = datetime(year, 3, nth_sunday(year, 3, 2), 7, tzinfo=timezone.utc)
    end = datetime(year, 11, nth_sunday(year, 11, 1), 6, tzinfo=timezone.utc)
    return start, end


def broker_offset_hours(utc: datetime) -> int:
    s, e = us_dst_interval(utc.year)
    return 3 if s <= utc < e else 2


def broker_epoch_to_utc(raw: int) -> datetime:
    wall = datetime.fromtimestamp(raw, tz=timezone.utc)
    cands = []
    for off in (2, 3):
        cand = wall - timedelta(hours=off)
        if broker_offset_hours(cand) == off:
            cands.append(cand)
    if len(cands) != 1:
        # ambiguous/invalid: prefer standard time like QM_BrokerToUTC
        return wall - timedelta(hours=2)
    return cands[0]


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_ff() -> list[dict]:
    rows = []
    with FF.open(encoding="utf-8", errors="replace", newline="") as f:
        for r in csv.DictReader(f):
            try:
                dt = datetime.strptime(r["DateTime_UTC"], "%Y.%m.%d %H:%M").replace(tzinfo=timezone.utc)
            except ValueError:
                continue
            rows.append({"file": "ff_clean", "ccy": r["Currency"], "impact": r["Impact"], "event": r["Event"], "utc": dt})
    return rows


def load_primary() -> list[dict]:
    rows = []
    with PRIMARY.open(encoding="utf-8", errors="replace", newline="") as f:
        for r in csv.DictReader(f):
            try:
                dt = datetime.strptime(r["datetime"], "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)
            except ValueError:
                continue
            rows.append({"file": "primary", "ccy": r["currency"], "impact": r["impact"], "event": r["event_name"], "utc": dt})
    return rows


def load_native(ccy: str) -> list[dict]:
    p = NATIVE_DIR / f"T_EXPORT_{ccy}_HIGH_2018_2025_NATIVE.csv"
    rows = []
    with p.open(encoding="utf-8", errors="replace", newline="") as f:
        for r in csv.DictReader(f):
            raw = int(r["broker_time"])
            # NOTE: despite the column name, broker_time in the NATIVE export is TRUE UTC (verified: NFP 2023-02-03 raw=1675431000 = 13:30Z)
            rows.append({"ccy": ccy, "event": r["event_name"], "utc": datetime.fromtimestamp(raw, tz=timezone.utc), "broker_epoch": raw})
    return rows


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)

    ff = load_ff()
    prim = load_primary()

    # 1) stored time-of-day histogram (High + Medium, four currencies)
    hist = defaultdict(Counter)
    for r in ff + prim:
        if r["ccy"] not in CCYS or r["impact"].lower() not in ("high", "medium"):
            continue
        hist[(r["file"], r["ccy"], r["event"], r["utc"].year)][r["utc"].strftime("%H:%M")] += 1
    with (out / "stored_tod_histogram.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["file", "currency", "event", "year", "n", "top_times"])
        for (fl, ccy, ev, y), c in sorted(hist.items()):
            w.writerow([fl, ccy, ev, y, sum(c.values()), "; ".join(f"{t}x{n}" for t, n in c.most_common(4))])

    # 2) native join for USD (exact name map) -> delta hours
    native = load_native("USD")
    by_name = defaultdict(list)
    for n in native:
        by_name[n["event"]].append(n)
    deltas = []
    unmatched = Counter()
    for r in ff:
        if r["ccy"] != "USD" or r["event"] not in NAME_MAP_USD or r["utc"].year < 2018:
            continue
        cands = by_name.get(NAME_MAP_USD[r["event"]], [])
        best = None
        for n in cands:
            d = (r["utc"] - n["utc"]).total_seconds() / 3600.0
            if abs(d) <= 36 and (best is None or abs(d) < abs(best[0])):
                best = (d, n)
        if best is None:
            unmatched[r["event"]] += 1
            continue
        deltas.append({"event": r["event"], "native_event": best[1]["event"], "stored_utc": r["utc"].isoformat(),
                       "native_utc": best[1]["utc"].isoformat(), "native_broker_epoch": best[1]["broker_epoch"],
                       "delta_hours": round(best[0], 2), "year": r["utc"].year,
                       "et0830_class": r["event"] in ET_0830_CLASS})
    with (out / "native_join_deltas.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(deltas[0].keys()))
        w.writeheader(); w.writerows(deltas)

    # summary
    def bucket(d):
        if abs(d) <= 0.01: return "exact"
        if abs(d) <= 1.01: return "within_1h"
        if -17.5 <= d <= -15.5: return "shift_-16_-17h"
        return "other"
    summ = {"files": {"ff_clean": {"path": str(FF), "sha256": sha256(FF), "rows": len(ff)},
                      "primary": {"path": str(PRIMARY), "sha256": sha256(PRIMARY), "rows": len(prim)},
                      "native_usd": {"path": str(NATIVE_DIR / 'T_EXPORT_USD_HIGH_2018_2025_NATIVE.csv'), "rows": len(native)}},
            "native_join_usd": {"matched": len(deltas), "unmatched_by_event": dict(unmatched)},
            "delta_buckets_all": dict(Counter(bucket(d["delta_hours"]) for d in deltas)),
            "delta_buckets_et0830": dict(Counter(bucket(d["delta_hours"]) for d in deltas if d["et0830_class"])),
            "delta_buckets_other": dict(Counter(bucket(d["delta_hours"]) for d in deltas if not d["et0830_class"])),
            "per_event": {}, "per_year_et0830": {}}
    pe = defaultdict(Counter)
    for d in deltas:
        pe[d["event"]][bucket(d["delta_hours"])] += 1
    summ["per_event"] = {k: dict(v) for k, v in sorted(pe.items())}
    py = defaultdict(Counter)
    for d in deltas:
        if d["et0830_class"]:
            py[d["year"]][bucket(d["delta_hours"])] += 1
    summ["per_year_et0830"] = {str(k): dict(v) for k, v in sorted(py.items())}
    # coverage per month (both files)
    cov = defaultdict(Counter)
    for r in ff + prim:
        cov[r["file"]][r["utc"].strftime("%Y-%m")] += 1
    months = [f"{y}-{m:02d}" for y in range(2015, 2027) for m in range(1, 13) if f"{y}-{m:02d}" <= "2026-09"]
    summ["coverage_zero_months"] = {fl: [m for m in months if cov[fl][m] == 0] for fl in cov}
    # primary vs ff identical instants? (same event/ccy/date -> same stored time)
    key_ff = {(r["ccy"], r["event"], r["utc"]) for r in ff}
    same = sum(1 for r in prim if (r["ccy"], r["event"], r["utc"]) in key_ff)
    summ["primary_rows_with_identical_ff_instant"] = {"n": same, "of": len(prim)}
    (out / "summary.json").write_text(json.dumps(summ, indent=1), encoding="utf-8")
    print(json.dumps({k: summ[k] for k in ("native_join_usd", "delta_buckets_all", "delta_buckets_et0830", "delta_buckets_other", "per_year_et0830", "coverage_zero_months", "primary_rows_with_identical_ff_instant")}, indent=1))


if __name__ == "__main__":
    main()
