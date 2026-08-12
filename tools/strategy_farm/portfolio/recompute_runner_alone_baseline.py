"""Arm-R (runner-alone) P(pass) baseline on the FRESH 588af557 vintage.

Preregistration binding (docs/ops/evidence/2026-07-28_measurement_preregistration.md):
  - PRIMARY KPI = first passage, no deadline (2.4); 1x sizing only (3).
  - Window truncated to the established common window 2018-07-02..2025-12-31 (2.2).
  - Baseline MUST be recomputed on this window from the fresh slot-0 stream, NOT
    the archived 1,252-trade stale-calendar file (2.2).

The runner slot-0 stream is proven 1.000000 identical to standalone 9936 at the
same vintage (2026-07-27_multisym_step1_EXECUTED.md:50), so the fresh standalone
588af557 stream is the valid Arm-R proxy the task directs us to use.

METHOD: the first-passage outcome function below is copied VERBATIM (single-sleeve
specialisation, scale==1) from tools/strategy_farm/portfolio/challenge_firstpassage.py
:157-235 so the Answer agent's Arm-R anchor uses the identical estimator it will use
for Arm-B. Nothing is re-invented. The secondary 60/30 KPI replicates
challenge_book_60d.py:191-255 (phase/funded_flags) at 1x.

Input stream: the fresh 9936 USDJPY.DWX q08 TRADE_CLOSED stream harvested from the
588af557 run (rows=1143, sum(net)=132405.79, sha256 352b9e3e...), stable copy at
D:/QM/reports/work_items/588af557-.../q08_trades_9936_USDJPY_DWX.fresh.jsonl.
"""
import json
import statistics
from collections import defaultdict
from datetime import datetime, timezone, date
from pathlib import Path

STREAM = Path(r"D:\QM\reports\work_items\588af557-300f-4e25-82a4-81974b04380a\QM5_9936\20260727_215505\q08_trades_9936_USDJPY_DWX.fresh.jsonl")
ACCOUNT, TARGET, DAILY_CAP, TOTAL_CAP = 100_000.0, 0.10, 0.05, 0.10
MIN_TRADING_DAYS = 4
WIN_LO, WIN_HI = date(2018, 7, 2), date(2025, 12, 31)   # inclusive common window
LEV = 1.0                                                # preregistered 1x policy


def parse_ts(v):
    if isinstance(v, (int, float)):
        try:
            return datetime.fromtimestamp(float(v), tz=timezone.utc)
        except Exception:
            return None
    t = str(v).strip()
    try:
        return datetime.fromisoformat(t.replace("Z", "+00:00"))
    except ValueError:
        return None


# ---- load fresh stream, truncate to window (both endpoints inclusive, per 2.2)
rows = []
with STREAM.open(encoding="utf-8", errors="replace") as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        r = json.loads(line)
        close = parse_ts(r.get("time"))
        if close is None:
            continue
        cd = close.date()
        if not (WIN_LO <= cd <= WIN_HI):
            continue
        net = float(r.get("net"))
        mae = min(float(r.get("mae_acct") or 0.0), 0.0)
        rows.append((close, net, mae))
rows.sort()
all_days = sorted({c.date() for c, _, _ in rows})


def outcomes_single(lev, day_lo=None, day_hi=None):
    """First passage for ONE sleeve. Copied from challenge_firstpassage.outcomes()
    (:157-235), specialised to a single member with constant scale()==1 (1x, no
    daily-stop, no de-risk). Returns (flags, days_to_pass, fate).

    day_lo/day_hi optionally restrict BOTH the start set and the event set to a
    sub-window (used to reproduce challenge_firstpassage's OOS scoring split)."""
    lo = day_lo or all_days[0]
    hi = day_hi or all_days[-1]
    by_day = defaultdict(list)
    for close, net, mae in rows:
        if lo <= close.date() <= hi:
            by_day[close.date()].append((close, net * lev, mae * lev))
    for d in by_day:
        by_day[d].sort(key=lambda r: r[0])
    days = [d for d in all_days if lo <= d <= hi]
    flags, ttp, fate = [], [], {"pass": 0, "breach": 0, "censored": 0}
    for s in range(len(days)):
        eq = 0.0
        state = "live"
        traded = 0
        won = None
        for di in range(s, len(days)):
            realized = 0.0
            halted = False
            pending = 0.0
            day_events = by_day.get(days[di], ())
            for _, _, mae in day_events:
                if state == "live":
                    pending += mae            # scale==1
            for close, net, mae in day_events:
                if state != "live" or halted:
                    continue
                low = realized + pending
                if low <= -DAILY_CAP * ACCOUNT or eq + low <= -TOTAL_CAP * ACCOUNT:
                    state = "breach"
                    continue
                pending -= mae
                realized += net
                if realized <= -DAILY_CAP * ACCOUNT or \
                        eq + realized <= -TOTAL_CAP * ACCOUNT:
                    state = "breach"
                    continue
            if state == "live":
                if day_events:
                    traded += 1
                eq += realized
                if eq >= TARGET * ACCOUNT and traded >= MIN_TRADING_DAYS:
                    state = "pass"
            if state == "pass":
                won = di - s + 1
                break
            if state == "breach":
                break
        flags.append(won is not None)
        if won is not None:
            ttp.append(won)
            fate["pass"] += 1
        elif state == "breach":
            fate["breach"] += 1
        else:
            fate["censored"] += 1
    return flags, ttp, fate


# ---- SECONDARY: 60/30 deadline KPI, replicated from challenge_book_60d.py:191-255
D1, D2, P1_TARGET, P2_TARGET, DORMANCY_DAYS = 60, 30, 0.10, 0.05, 30
closes_by_day = defaultdict(list)
floating = defaultdict(float)
active = set()
day_index = {d: i for i, d in enumerate(all_days)}
# reconstruct entry dates for the floating (per-open-day MAE) charge
entries = {}
with STREAM.open(encoding="utf-8", errors="replace") as fh:
    ev = []
    for line in fh:
        line = line.strip()
        if not line:
            continue
        r = json.loads(line)
        close = parse_ts(r.get("time"))
        entry = parse_ts(r.get("entry_time"))
        if close is None:
            continue
        cd = close.date()
        if not (WIN_LO <= cd <= WIN_HI):
            continue
        net = float(r.get("net"))
        mae = min(float(r.get("mae_acct") or 0.0), 0.0)
        ed = entry.date() if entry else cd
        ev.append((ed, cd, net, mae))
for ed, cd, net, mae in ev:
    closes_by_day[cd].append((net, mae))
    active.add(cd)
    active.add(ed)
    i0 = day_index.get(ed, day_index[cd])
    i1 = day_index[cd]
    for i in range(i0, i1 + 1):
        floating[all_days[i]] += mae
        active.add(all_days[i])


def phase60(start_i, target, deadline, lev):
    eq, traded, last = 0.0, 0, all_days[start_i]
    for di in range(start_i, len(all_days)):
        day = all_days[di]
        if (day - all_days[start_i]).days > deadline:
            return "expired", di
        if (day - last).days > DORMANCY_DAYS:
            return "dormant", di
        if day in active:
            last = day
        float_low = floating.get(day, 0.0) * lev
        if float_low and (eq + float_low <= -TOTAL_CAP * ACCOUNT
                          or float_low <= -DAILY_CAP * ACCOUNT):
            return "breach", di
        todays = closes_by_day.get(day)
        if not todays:
            continue
        traded += 1
        realized = 0.0
        for net, mae in todays:
            realized += net * lev
            if realized <= -DAILY_CAP * ACCOUNT or eq + realized <= -TOTAL_CAP * ACCOUNT:
                return "breach", di
        eq += realized
        if eq >= target * ACCOUNT and traded >= MIN_TRADING_DAYS:
            return "pass", di
    return "censored", len(all_days) - 1


def funded60(lev):
    out, why = [], defaultdict(int)
    for s in range(len(all_days)):
        o1, i1 = phase60(s, P1_TARGET, D1, lev)
        if o1 != "pass":
            out.append(False)
            why[f"p1_{o1}"] += 1
            continue
        if i1 + 1 >= len(all_days):
            out.append(False)
            why["p2_censored"] += 1
            continue
        o2, i2 = phase60(i1 + 1, P2_TARGET, D2, lev)
        if o2 == "pass":
            out.append(True)
            why["funded"] += 1
        else:
            out.append(False)
            why[f"p2_{o2}"] += 1
    return out, why


# ---- report
def summarise(flags, ttp, fate):
    n = len(flags)
    p = (sum(flags) / n) if n else float("nan")
    med = statistics.median(ttp) if ttp else None
    ess = max(1, int(n / max(1.0, med))) if med else 1
    hw = 1.96 * ((p * (1 - p) / ess) ** 0.5)
    return {
        "p_pass": round(p, 4),
        "start_days": n,
        "pass": fate["pass"], "breach": fate["breach"], "censored": fate["censored"],
        "median_days_to_pass": med,
        "p90_days_to_pass": (sorted(ttp)[int(len(ttp) * 0.9)] if ttp else None),
        "ESS": ess,
        "wald_95_halfwidth_pp": round(hw * 100, 1),
        "p_pass_95_interval_pp": [round((p - hw) * 100, 1), round((p + hw) * 100, 1)],
    }


flags, ttp, fate = outcomes_single(LEV)
n = len(flags)
npass = sum(flags)
p = npass / n if n else float("nan")
med = statistics.median(ttp) if ttp else None
ess = max(1, int(n / max(1.0, med))) if med else 1
se = (p * (1 - p) / ess) ** 0.5
hw = 1.96 * se

# OOS-split variant (challenge_firstpassage SPLIT=0.60 scoring window) to bridge to
# the prior published archived-vintage 75.3% figure (same estimator, later starts).
cut = all_days[int(len(all_days) * 0.60)]
fO, tO, faO = outcomes_single(LEV, cut, all_days[-1])

f60, why60 = funded60(LEV)
p60 = sum(f60) / len(f60) if f60 else float("nan")

out = {
    "arm": "R (runner-alone, 9936 fresh 588af557 vintage)",
    "sizing": "1x (QM_Common.mqh:182 clamp; preregistration section 3)",
    "window": f"{WIN_LO}..{WIN_HI}",
    "stream_rows_in_window": len(rows),
    "trading_days": n,
    "primary_first_passage_full_window": summarise(flags, ttp, fate),
    "primary_first_passage_oos_split_0p60": {
        **summarise(fO, tO, faO),
        "scoring_from": str(cut),
        "note": "same estimator restricted to challenge_firstpassage SPLIT=0.60 "
                "scoring window; brackets the prior archived-vintage 75.3% figure.",
    },
    "secondary_60_30_deadline": {
        "p_pass": round(p60, 4),
        "decomp": dict(why60),
        "note": "OWNER sprint objective, NOT an FTMO rule (preregistration 2.4).",
    },
}
print(json.dumps(out, indent=2))
