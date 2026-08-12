"""The campaign number, with every shortcut removed.

What changed versus the earlier 81%:

1. SELECTION LEAK FIXED. challenge_campaign_mae.py chose the account combination
   by maximising the OUT-OF-SAMPLE rate. Here leverage, overlay and combination
   are all chosen in-sample; the scoring period decides nothing.

2. RISK OVERLAY ADDED. The books were losing 38-47% of windows to breach with no
   defence at all - the sleeves ran exactly as backtested, unaware they were
   inside a challenge. Two rules, both chosen in-sample:
     daily stop  go flat for the rest of the day once down X% - FTMO kills at
                 -5%, so stopping at -2% turns a fatal day into a bad one;
     de-risk     shrink size once the account is down toward the -10% cap.
   A daily stop was tested earlier and found never to trigger, but that was on
   UNLEVERED sleeves; at 4-8x it triggers constantly, so that finding did not
   carry over and had to be re-run.

3. JOINT RATE MEASURED, NOT ASSUMED. The overlay script's campaign column
   multiplies (1-p) across accounts. That independence assumption is known to be
   optimistic here - an earlier pair measured 69.4% against a 72.5% prediction.
   This counts windows where at least one account passed.

Horizon is OWNER's 30 days (~22 trading days). FTMO itself dropped the time limit
in 2024, and at an unlimited horizon these books look far better - but a 250-day
window leaves roughly three independent samples in the scoring period, so those
figures are directional at best and are not the basis for a decision.
"""
import itertools
import json
import sqlite3
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

STREAMS = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")
ACCOUNT, TARGET, DAILY_CAP, TOTAL_CAP = 100_000.0, 0.10, 0.05, 0.10
# 500 rather than 600: 13301/GDAXI has 551 trading days and its measured
# correlation against the USDJPY family is +0.009/+0.012 -- the closest thing to
# an independent bet in the pool. 500 days still leaves ~470 windows / ~21
# independent samples per sleeve, so the bar costs little and buys a diversifier.
WINDOW, MIN_DAYS, SPLIT = 22, 500, 0.60
LEVERAGES = (2, 3, 4, 5, 6, 8)
DAILY_STOPS = (None, 0.040, 0.030, 0.025, 0.020)
DERISK = (None, (0.05, 0.5), (0.06, 0.5), (0.05, 0.25))
EARLY_OK = {"PASS", "PASS_SOFT", "PASS_LOWFREQ"}  # Q04_PASSISH, farmctl/analyze_q04_survivor_cohort.py:37
Q08_OK = {"PASS", "PASS_SOFT", "MULTI_SEED_PASS", "FAIL_SOFT"}


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
        pass
    for f in ("%Y.%m.%d %H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y.%m.%d %H:%M"):
        try:
            return datetime.strptime(t[:19], f)
        except ValueError:
            continue
    return None


con = sqlite3.connect("file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro", uri=True)
con.row_factory = sqlite3.Row
latest = {}
for r in con.execute("select ea_id,symbol,phase,verdict from work_items "
                     "where status='done' order by updated_at"):
    latest[(r["ea_id"], str(r["symbol"]).upper(), r["phase"])] = str(r["verdict"] or "")

trades, gate_note = {}, {}
for path in sorted(STREAMS.glob("*.jsonl")):
    bare, _, stem = path.stem.partition("_")
    ea, sym = f"QM5_{bare}", stem.replace("_DWX", ".DWX").upper()
    bad = [g for g in ("Q02", "Q03", "Q04", "Q05", "Q06", "Q07")
           if (ea, sym, g) in latest and latest[(ea, sym, g)] not in EARLY_OK]
    q08 = latest.get((ea, sym, "Q08"))
    if q08 is not None and q08 not in Q08_OK:
        bad.append("Q08")
    if bad:
        continue
    rows = []
    with path.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                r = json.loads(line)
            except json.JSONDecodeError:
                continue
            if str(r.get("event") or "TRADE_CLOSED") != "TRADE_CLOSED":
                continue
            close = parse_ts(r.get("time"))
            if close is None:
                continue
            try:
                net = float(r.get("net"))
            except (TypeError, ValueError):
                continue
            try:
                mae = min(float(r.get("mae_acct") or 0.0), 0.0)
            except (TypeError, ValueError):
                mae = 0.0
            rows.append((close, net, mae))
    rows.sort()
    if len({r[0].date() for r in rows}) >= MIN_DAYS:
        key = f"{bare}:{sym.replace('.DWX','')}"
        trades[key] = rows
        gate_note[key] = q08 if q08 is not None else "PENDING (requeued)"

keys = sorted(trades)
all_days = sorted({r[0].date() for rs in trades.values() for r in rs})
cut = all_days[int(len(all_days) * SPLIT)]
FAR = datetime(2100, 1, 1).date()


def flags(members, cfg, lo, hi):
    """Per-window pass flags for a set of accounts run as one campaign leg each."""
    by_day = defaultdict(list)
    for k in members:
        lev = cfg[k]["lev"]
        for close, net, mae in trades[k]:
            if lo <= close.date() < hi:
                by_day[close.date()].append((close, net * lev, mae * lev, k))
    if not by_day:
        return None
    for d in by_day:
        by_day[d].sort(key=lambda r: r[0])
    days = [d for d in all_days if lo <= d < hi]
    if len(days) < WINDOW + 5:
        return None

    out = []
    for s in range(len(days) - WINDOW + 1):
        # each account is independent: its own equity, its own caps
        eq = {k: 0.0 for k in members}
        state = {k: "live" for k in members}
        for di in range(s, s + WINDOW):
            realized = {k: 0.0 for k in members}
            halted = {k: False for k in members}
            pending = defaultdict(float)
            for _, _, mae, k in by_day.get(days[di], ()):
                if state[k] == "live":
                    sc = cfg[k]["scale"](eq[k])
                    pending[k] += mae * sc
            for close, net, mae, k in by_day.get(days[di], ()):
                if state[k] != "live" or halted[k]:
                    continue
                sc = cfg[k]["scale"](eq[k])
                net *= sc
                mae *= sc
                low = realized[k] + pending[k]
                if low <= -DAILY_CAP * ACCOUNT or eq[k] + low <= -TOTAL_CAP * ACCOUNT:
                    state[k] = "breach"
                    continue
                pending[k] -= mae
                realized[k] += net
                if realized[k] <= -DAILY_CAP * ACCOUNT or \
                        eq[k] + realized[k] <= -TOTAL_CAP * ACCOUNT:
                    state[k] = "breach"
                    continue
                if eq[k] + realized[k] >= TARGET * ACCOUNT:
                    state[k] = "pass"
                    continue
                ds = cfg[k]["ds"]
                if ds and realized[k] <= -ds * ACCOUNT:
                    halted[k] = True
            for k in members:
                if state[k] == "live":
                    eq[k] += realized[k]
            if all(state[k] != "live" for k in members) and \
                    any(state[k] == "pass" for k in members):
                break
        out.append(any(state[k] == "pass" for k in members))
    return out


def make_cfg(k, lev, ds, dr):
    if dr:
        thresh, factor = dr
        scale = lambda e, t=thresh, f=factor: f if e <= -t * ACCOUNT else 1.0
    else:
        scale = lambda e: 1.0
    return {"lev": lev, "ds": ds, "dr": dr, "scale": scale}


# ---- stage 1: per-sleeve leverage + overlay, chosen strictly in-sample
solo = {}
for k in keys:
    best = None
    for lev in LEVERAGES:
        for ds in DAILY_STOPS:
            for dr in DERISK:
                cfg = {k: make_cfg(k, lev, ds, dr)}
                f = flags((k,), cfg, all_days[0], cut)
                if not f:
                    continue
                rate = sum(f) / len(f)
                if best is None or rate > best[0]:
                    best = (rate, lev, ds, dr)
    if best:
        solo[k] = make_cfg(k, best[1], best[2], best[3])
        solo[k]["is_rate"] = best[0]

print(f"gate-clean sleeves: {len(solo)}")
print(f"selection {all_days[0]}..{cut}   scoring {cut}..{all_days[-1]}")
print()
print(f"{'sleeve':15}{'Q08':>22}{'lev':>5}{'dstop':>7}{'derisk':>10}{'IS':>8}{'OOS':>8}")
print("-" * 75)
for k in sorted(solo, key=lambda k: -solo[k]["is_rate"]):
    v = solo[k]
    f = flags((k,), {k: v}, cut, FAR)
    oos = sum(f) / len(f) if f else float("nan")
    v["oos_flags"] = f
    ds = f"{v['ds']*100:.1f}%" if v["ds"] else "-"
    dr = f"{v['dr'][0]*100:.0f}%/{v['dr'][1]:.2f}" if v["dr"] else "-"
    print(f"{k:15}{gate_note[k]:>22}{v['lev']:>5}{ds:>7}{dr:>10}"
          f"{v['is_rate']:>8.1%}{oos:>8.1%}")

# ---- stage 2: combination chosen IN-SAMPLE, joint rate MEASURED out-of-sample
print()
print("campaign: combination chosen in-sample, joint pass COUNTED out-of-sample")
print(f"{'N':>2}{'IS':>8}{'OOS':>8}{'95% CI':>16}   accounts")
print("-" * 86)
order = sorted(solo)
best_rows = []
for size in range(1, len(order) + 1):
    best = None
    for combo in itertools.combinations(order, size):
        f = flags(combo, solo, all_days[0], cut)
        if not f:
            continue
        rate = sum(f) / len(f)
        if best is None or rate > best[0]:
            best = (rate, combo)
    if not best:
        continue
    is_rate, combo = best
    f = flags(combo, solo, cut, FAR)
    if not f:
        continue
    oos = sum(f) / len(f)
    eff = max(1, len(f) // WINDOW)
    se = (oos * (1 - oos) / eff) ** 0.5
    lo_ci, hi_ci = max(0.0, oos - 1.96 * se), min(1.0, oos + 1.96 * se)
    members = ", ".join("{}@{}x".format(k, solo[k]["lev"]) for k in combo)
    mark = "  <<" if oos >= 0.80 else ""
    print(f"{size:>2}{is_rate:>8.1%}{oos:>8.1%}   {lo_ci:>6.0%}..{hi_ci:<6.0%}   {members}{mark}")
    best_rows.append((size, is_rate, oos, lo_ci, hi_ci, combo))

print()
print("Every figure above: leverage, overlay and combination all chosen on the")
print("selection period alone. The scoring period decides nothing, and the joint")
print("pass rate is counted on shared windows rather than assuming independence.")
