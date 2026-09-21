#!/usr/bin/env python3
"""Velocity H-V1 / H-V2 closed-bar prescreen on .DWX M1 history (0 factory hours; Fable 2026-09-21).

Answers critique 1614737c: measured fire counts, range-width distributions, a named thin-range
floor / wide-range cap, and an indicative closed-bar simulation of two FROZEN target arms per
hypothesis, commission-only (registry model), .DWX spread = 0 (stated, not modelled).

Conventions (all deterministic, no timestamps in the output):
* Bars come from ``hcc_m1_reader_0921.read_year`` (server time stored as-if-UTC). Server time is the
  Darwinex NY-close clock = America/New_York local time + 7 h (GMT+2 in US winter, GMT+3 in US
  summer). Economic anchors are mapped per date with ``zoneinfo`` (Europe/London, America/New_York)
  -> New York local -> server time; never a fixed UTC hour.
* Shift-1 / closed-bar contract: a signal on M15 bar i uses only bars <= i (i is CLOSED when read);
  the entry is the OPEN of the first M1 bar at/after the start of bar i+1. Stops/targets are
  evaluated on M1 bars with the conservative same-bar rule (stop before target).
* H-V1 (EURUSD, GBPUSD): range = the four closed M15 bars in the 60 min before 08:00 Europe/London;
  entry window = the closed M15 bars starting in [08:00, 12:00) London; flat at 16:00 London.
  Precedence: the FIRST M15 bar in the window that trades outside the range decides the day -
  close beyond the range => breakout (B) in the break direction; close back inside (wick-only)
  => failure (F) against the wick side. One trade per symbol per day, B and F mutually exclusive.
* H-V2 (XAUUSD): reference range = the four closed M15 bars in the 60 min before 08:30
  America/New_York; entry window = the closed M15 bars starting in [08:30, 09:30) NY; breakout
  only (a wick-only bar does not decide, scanning continues); flat at 16:00 NY.
* Arms: A15 target = 1.5 x W, A20 target = 2.0 x W; stop distance = W (range width) from entry.
* Thin-range floor / wide-range cap: p10 / p90 of W / ATR(14, H1, Wilder, closed before the anchor)
  measured on the SELECTION period only (2018-07-01..2022-12-31), rounded to 2 dp, then applied
  unchanged to SELECTION and VALIDATION (2023-01-01..2025-12-31).
* Cost: framework/registry/live_commission.json model per trade at RISK_FIXED 1000 -
  forex: max(0.00005 * notional_usd, 5.0 * lots); commodity (XAU): 0.00005 * notional_usd.
"""
from __future__ import annotations

import argparse
import bisect
import calendar
import datetime as dt
import json
import statistics
import sys
from collections import defaultdict
from pathlib import Path
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hcc_m1_reader_0921 import read_year  # noqa: E402

RISK = 1000.0
COMMISSION = json.load(open("C:/QM/repo/framework/registry/live_commission.json", encoding="utf-8"))
NY = ZoneInfo("America/New_York")
LON = ZoneInfo("Europe/London")
UTC = dt.timezone.utc
SEL = (dt.date(2018, 7, 1), dt.date(2022, 12, 31))
VAL = (dt.date(2023, 1, 1), dt.date(2025, 12, 31))
ARMS = {"A15": 1.5, "A20": 2.0}

SPECS = {
    "HV1": {
        "symbols": ["EURUSD.DWX", "GBPUSD.DWX"],
        "tz": LON, "anchor": (8, 0), "window_min": 240, "flat": (16, 0), "failure_variant": True,
        "contract": 100000.0, "cls": "forex",
    },
    "HV2": {
        "symbols": ["XAUUSD.DWX"],
        "tz": NY, "anchor": (8, 30), "window_min": 60, "flat": (16, 0), "failure_variant": False,
        "contract": 100.0, "cls": "commodity",
    },
}


def server_epoch(local_dt: dt.datetime) -> int:
    """Aware local datetime -> Darwinex server epoch (NY local + 7h, stored as-if-UTC)."""
    ny = local_dt.astimezone(NY).replace(tzinfo=None) + dt.timedelta(hours=7)
    return calendar.timegm(ny.timetuple())


def load_symbol(symbol: str, years: range):
    bars = []
    for y in years:
        try:
            bars.extend(read_year(symbol, y))
        except FileNotFoundError:
            continue
    bars.sort(key=lambda r: r[0])
    out, last = [], None
    for r in bars:
        if r[0] != last:
            out.append(r)
            last = r[0]
    return out


def aggregate(m1, period: int):
    agg = {}
    for t, o, h, l, c, *_ in m1:
        k = t - t % period
        a = agg.get(k)
        if a is None:
            agg[k] = [o, h, l, c]
        else:
            a[1] = max(a[1], h)
            a[2] = min(a[2], l)
            a[3] = c
    return agg


def wilder_atr(h1: dict, n: int = 14):
    keys = sorted(h1)
    atr, prev_c, trs = {}, None, []
    val = None
    for k in keys:
        o, h, l, c = h1[k]
        tr = h - l if prev_c is None else max(h - l, abs(h - prev_c), abs(l - prev_c))
        prev_c = c
        if val is None:
            trs.append(tr)
            if len(trs) == n:
                val = sum(trs) / n
        else:
            val = (val * (n - 1) + tr) / n
        if val is not None:
            atr[k] = val
    return keys, atr


def cost_r(cls: str, contract: float, lots: float, price: float) -> float:
    m = COMMISSION["classes"][cls]
    notional = lots * contract * price
    return max(m["pct_rate_rt"] * notional, m["flat_per_lot_rt"] * lots) / RISK


def pct(xs, q):
    if not xs:
        return None
    s = sorted(xs)
    i = (len(s) - 1) * q
    lo, hi = int(i), min(int(i) + 1, len(s) - 1)
    return s[lo] + (s[hi] - s[lo]) * (i - lo)


def simulate_day(spec, m1, times, m15, atr_keys, atr, day: dt.date, floor_cap):
    tz = spec["tz"]
    anchor = server_epoch(dt.datetime(day.year, day.month, day.day, *spec["anchor"], tzinfo=tz))
    flat = server_epoch(dt.datetime(day.year, day.month, day.day, *spec["flat"], tzinfo=tz))
    rng = [m15.get(anchor - 900 * k) for k in (4, 3, 2, 1)]
    present = [b for b in rng if b]
    if len(present) < 3:
        return {"state": "no_range"}
    rh = max(b[1] for b in present)
    rl = min(b[2] for b in present)
    w = rh - rl
    i = bisect.bisect_right(atr_keys, anchor - 3600) - 1  # last H1 bar closed at/before the anchor
    if i < 0 or atr_keys[i] not in atr:
        return {"state": "no_atr"}
    a = atr[atr_keys[i]]
    if w <= 0 or a <= 0:
        return {"state": "no_range"}
    ratio = w / a
    rec = {"state": "valid", "w": w, "ratio": ratio, "atr": a}
    if floor_cap is not None:
        lo, hi = floor_cap
        if ratio < lo:
            rec["state"] = "floor_excluded"
            return rec
        if ratio > hi:
            rec["state"] = "cap_excluded"
            return rec
    decision = None
    k = anchor
    end = anchor + 60 * spec["window_min"]
    while k < end:
        b = m15.get(k)
        if b:
            o, h, l, c = b
            if h > rh or l < rl:
                if c > rh:
                    decision = ("B", +1)
                elif c < rl:
                    decision = ("B", -1)
                elif spec["failure_variant"]:
                    up, dn = h - rh, rl - l
                    decision = ("F", -1) if up >= dn else ("F", +1)
                else:
                    k += 900
                    continue  # H-V2: a wick-only bar does not decide; keep scanning
                break
        k += 900
    if decision is None:
        rec["state"] = "no_signal"
        return rec
    kind, d = decision
    entry_t = k + 900
    j = bisect.bisect_left(times, entry_t)
    if j >= len(times) or times[j] >= flat:
        rec["state"] = "no_entry"
        return rec
    entry = m1[j][1]
    lots = RISK / (w * spec["contract"])
    c_r = cost_r(spec["cls"], spec["contract"], lots, entry)
    rec.update({"kind": kind, "dir": d, "entry": entry, "cost_r": c_r, "arms": {}})
    for arm, mult in ARMS.items():
        stop = entry - d * w
        target = entry + d * mult * w
        res = None
        jj = j
        while jj < len(times) and times[jj] < flat:
            _, o, h, l, c, *_ = m1[jj]
            if d > 0:
                if l <= stop:
                    res = -1.0
                    break
                if h >= target:
                    res = mult
                    break
            else:
                if h >= stop:
                    res = -1.0
                    break
                if l <= target:
                    res = mult
                    break
            jj += 1
        if res is None:
            # Time-stop exit at the CLOSE of the final closed bar before the flat time (2026-09-21 fix
            # after critique 9caac5c7: on holiday early closes the "first bar at/after flat" was the next
            # session's open, i.e. an overnight exit the mechanism never allows).
            px = m1[jj - 1][4]
            res = d * (px - entry) / w
        rec["arms"][arm] = {"gross_r": res, "net_r": res - c_r, "hold_min": (times[min(jj, len(times) - 1)] - entry_t) / 60}
    rec["state"] = "trade"
    return rec


FTMO_SPREAD_HARVEST = {
    # symbol -> (M1 spread harvest of the FTMO venue, point size). Read-only evidence produced by
    # ftmo_m1_bootstrap.py (QM_M1_SpreadHarvest, 2026-04-28..2026-08-07). No harvest exists for the FX majors.
    "XAUUSD.DWX": ("D:/QM/reports/ftmo_spread_calibration/XAUUSD_FTMO_M1.jsonl", 0.01),
}


def spread_sensitivity(symbol: str, med_w_sel, med_w_val):
    """Round-trip spread cost in R at the median range width, from a MEASURED venue harvest only."""
    src = FTMO_SPREAD_HARVEST.get(symbol)
    if src is None:
        return {"status": "GAP", "note": "no measured FTMO/DXZ live spread harvest for this symbol; .DWX history carries zero spread"}
    path, point = src
    try:
        pts = [json.loads(l)["spread_points"] for l in open(path, encoding="utf-8") if l.strip()]
    except OSError:
        return {"status": "GAP", "note": f"harvest unreadable: {path}"}
    med = statistics.median(pts)
    spread_px = med * point
    return {"status": "MEASURED", "source": path, "rows": len(pts), "median_spread_points": med,
            "p90_spread_points": pct(pts, 0.9), "point_size": point, "median_spread_price": round(spread_px, 5),
            "spread_R_at_median_selection_width": round(spread_px / med_w_sel, 4) if med_w_sel else None,
            "spread_R_at_median_validation_width": round(spread_px / med_w_val, 4) if med_w_val else None,
            "note": "one spread per round trip charged against the range-width stop; the harvest is 2026 FTMO venue data, the ranges are 2018-2025 .DWX data"}


def bdays(a: dt.date, b: dt.date) -> int:
    return sum(1 for k in range((b - a).days + 1) if (a + dt.timedelta(k)).weekday() < 5)


def period_stats(trades, a: dt.date, b: dt.date, data_days):
    days = [d for d in data_days if a <= d <= b]
    if not days:
        return None
    a2, b2 = max(a, days[0]), min(b, days[-1])
    bd = bdays(a2, b2)
    out = {"from": a2.isoformat(), "to": b2.isoformat(), "business_days": bd, "days_with_data": len(days)}
    res = {}
    for key, lst in trades.items():
        sel = [(d, r) for d, r in lst if a2 <= d <= b2]
        n = len(sel)
        net = sum(r for _, r in sel)
        gross_w = sum(r for _, r in sel if r > 0)
        gross_l = -sum(r for _, r in sel if r < 0)
        worst = peak = eq = 0.0
        year = None
        for d, r in sel:
            if d.year != year:
                year = d.year
                peak = eq = 0.0
            eq += r
            peak = max(peak, eq)
            worst = max(worst, peak - eq)
        per_year_net = defaultdict(float)
        for d, r in sel:
            per_year_net[str(d.year)] += r
        res[key] = {"trades": n, "wins": sum(1 for _, r in sel if r > 0), "net_R": round(net, 3),
                    "E_R": round(net / n, 4) if n else None, "PF": round(gross_w / gross_l, 3) if gross_l else None,
                    "density_per_bd": round(n / bd, 4) if bd else None, "R_per_bd": round(net / bd, 4) if bd else None,
                    "worst_year_DD_R": round(worst, 2), "net_R_per_year": {y: round(v, 2) for y, v in sorted(per_year_net.items())}}
    out["arms"] = res
    return out


def run(hyp: str, years: range):
    spec = SPECS[hyp]
    result = {"hypothesis": hyp,
              "spec": {k: (str(v) if isinstance(v, ZoneInfo) else v) for k, v in spec.items() if k != "symbols"},
              "selection_period": [SEL[0].isoformat(), SEL[1].isoformat()],
              "validation_period": [VAL[0].isoformat(), VAL[1].isoformat()],
              "risk_fixed": RISK, "commission_model": COMMISSION["model"],
              "commission_class_params": COMMISSION["classes"][spec["cls"]],
              "spread_model": "zero (.DWX custom history carries no spread; live spread is an evidence GAP unless measured separately)",
              "news_filter": "not applied (prescreen is pre-filter; the framework news blackout can only reduce density)",
              "symbols": {}}
    for sym in spec["symbols"]:
        m1 = load_symbol(sym, years)
        times = [r[0] for r in m1]
        m15 = aggregate(m1, 900)
        h1 = aggregate(m1, 3600)
        atr_keys, atr = wilder_atr(h1)
        data_days = sorted({dt.datetime.fromtimestamp(t, UTC).date() for t in times})
        days_all = [d for d in data_days if SEL[0] <= d <= VAL[1] and d.weekday() < 5]
        ratios, widths = [], []
        for d in days_all:
            if not (SEL[0] <= d <= SEL[1]):
                continue
            r = simulate_day(spec, m1, times, m15, atr_keys, atr, d, None)
            if r["state"] in ("valid", "trade", "no_signal", "no_entry"):
                ratios.append(r["ratio"])
                widths.append(r["w"])
        floor = round(pct(ratios, 0.10), 2)
        cap = round(pct(ratios, 0.90), 2)
        dist = {"days": len(ratios), "w_price_p10_p50_p90": [round(pct(widths, q), 5) for q in (0.1, 0.5, 0.9)],
                "w_atr_mult_p10_p50_p90": [round(pct(ratios, q), 3) for q in (0.1, 0.5, 0.9)],
                "thin_range_floor_atr_mult": floor, "wide_range_cap_atr_mult": cap}
        counts = defaultdict(int)
        per_year = defaultdict(lambda: defaultdict(int))
        trades = defaultdict(list)
        costs, entries, holds = [], [], []
        val_ratios, val_widths = [], []
        for d in days_all:
            r = simulate_day(spec, m1, times, m15, atr_keys, atr, d, (floor, cap))
            counts[r["state"]] += 1
            per_year[d.year][r["state"]] += 1
            if VAL[0] <= d <= VAL[1] and "ratio" in r:
                val_ratios.append(r["ratio"])
                val_widths.append(r["w"])
            if r["state"] == "trade":
                per_year[d.year]["kind_" + r["kind"]] += 1
                counts["kind_" + r["kind"]] += 1
                costs.append(r["cost_r"])
                entries.append(r["entry"])
                holds.append(r["arms"]["A15"]["hold_min"])
                for arm, v in r["arms"].items():
                    trades[f"{arm}_{r['kind']}"].append((d, v["net_r"]))
                    trades[f"{arm}_ALL"].append((d, v["net_r"]))
        med_w = pct(widths, 0.5)
        med_px = statistics.median(entries) if entries else None
        result["symbols"][sym] = {
            "coverage": {"first_day": data_days[0].isoformat(), "last_day": data_days[-1].isoformat(), "m1_bars": len(m1),
                         "days_per_year": {str(y): sum(1 for d in data_days if d.year == y) for y in years}},
            "range_distribution_selection": dist,
            "range_distribution_validation": {
                "days": len(val_ratios),
                "w_price_p10_p50_p90": [round(pct(val_widths, q), 5) for q in (0.1, 0.5, 0.9)] if val_widths else None,
                "w_atr_mult_p10_p50_p90": [round(pct(val_ratios, q), 3) for q in (0.1, 0.5, 0.9)] if val_ratios else None,
            },
            "spread_sensitivity": spread_sensitivity(sym, med_w, pct(val_widths, 0.5) if val_widths else None),
            "day_states": dict(sorted(counts.items())),
            "day_states_per_year": {str(y): dict(sorted(v.items())) for y, v in sorted(per_year.items())},
            "cost_r": {"median_per_trade": round(statistics.median(costs), 4) if costs else None,
                       "p90_per_trade": round(pct(costs, 0.9), 4) if costs else None,
                       "at_median_selection_range_width_and_median_entry_price": round(cost_r(spec["cls"], spec["contract"], RISK / (med_w * spec["contract"]), med_px), 4) if (med_w and med_px) else None,
                       "median_entry_price": round(med_px, 5) if med_px else None,
                       "median_selection_range_width": round(med_w, 5) if med_w else None},
            "hold_min_A15_p50": round(pct(holds, 0.5), 1) if holds else None,
            "selection": period_stats(trades, SEL[0], SEL[1], data_days),
            "validation": period_stats(trades, VAL[0], VAL[1], data_days),
        }
        print(f"{hyp} {sym}: days {len(days_all)} floor {floor} cap {cap} states {dict(counts)}", file=sys.stderr)
    return result


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="C:/QM/repo/docs/ops/evidence/2026-09-20_velocity_book/velocity_hv_prescreen_0921.json")
    ap.add_argument("--years", default="2018-2025")
    ap.add_argument("--hyp", default="HV1,HV2")
    ap.add_argument("--emit-artifact-extracts", action="store_true")
    a = ap.parse_args()
    y0, y1 = (int(x) for x in a.years.split("-"))
    full = {"schema": "qm.velocity-hv-prescreen/v1", "reader": "tools/strategy_farm/session_tools/hcc_m1_reader_0921.py",
            "script": "tools/strategy_farm/session_tools/velocity_hv_prescreen_0921.py", "hypotheses": {}}
    for hyp in a.hyp.split(","):
        full["hypotheses"][hyp] = run(hyp, range(y0, y1 + 1))
    Path(a.out).write_text(json.dumps(full, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    if a.emit_artifact_extracts:
        for hyp, rid in (("HV1", "QM-RESEARCH-2026-0009"), ("HV2", "QM-RESEARCH-2026-0010")):
            if hyp in full["hypotheses"]:
                p = Path("C:/QM/repo/strategy-seeds/sources") / rid / "prescreen_extract.json"
                p.write_text(json.dumps({"schema": full["schema"], "script": full["script"], "reader": full["reader"],
                                         "hypothesis": full["hypotheses"][hyp]}, indent=1, sort_keys=True) + "\n",
                             encoding="utf-8", newline="\n")
    for hyp, r in full["hypotheses"].items():
        for sym, s in r["symbols"].items():
            for per in ("selection", "validation"):
                ps = s[per]
                if not ps:
                    continue
                for arm, st in sorted(ps["arms"].items()):
                    print(f"{hyp} {sym:<11}{per[:3].upper()} {arm:<8} n={st['trades']:>4} dens={st['density_per_bd']!s:<7} "
                          f"E[R]={st['E_R']!s:<8} PF={st['PF']!s:<6} DD={st['worst_year_DD_R']!s:<6} R/bd={st['R_per_bd']}")
            d = s["range_distribution_selection"]
            print(f"{hyp} {sym} floor/cap {d['thin_range_floor_atr_mult']}/{d['wide_range_cap_atr_mult']} "
                  f"W p10/50/90 {d['w_price_p10_p50_p90']} cost_R med {s['cost_r']['median_per_trade']} states {s['day_states']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
