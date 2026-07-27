"""Build the best book for OWNER's 60/30 KPI. Two levers, both previously unused.

OWNER decided on 2026-07-27 to keep the 60-day Phase 1 / 30-day Phase 2 target
and improve the book rather than relax the deadline. At 1x with the current
four-sleeve pool that KPI sits at 9.1%, and the failure decomposition says
exactly where to push:

    p1_expired 72.0%   p2_expired 16.9%   funded 9.1%   breach 0.0%

**Breach is 0.0% at every deadline.** The book never uses its risk budget. For a
deadline problem that is not prudence, it is waste: the whole -5% daily / -10%
total allowance is sitting idle while 72% of attempts simply run out of time.

Lever 1 - SIZE. Under an unlimited horizon, size is pure variance and lowers
P(pass); challenge_firstpassage.py measured that decay and it is why raising the
risk cap was rejected yesterday. Under a *deadline* the sign flips back: size is
what reaches the target in time. Neither regime was ever measured at 60 days -
the sprint work used 22 days, the first-passage work used no deadline at all.
Leverages are swept only up to 5.0, the ceiling QM_FrameworkSetRiskCapPct already
enforces (QM_Common.mqh:315, OWNER-ratified 2026-07-05). Nothing here proposes
weakening that ceiling.

Lever 2 - POOL. 52 sleeves were excluded for holding positions over a day,
because the earlier model could not bound their intraday exposure. It can now:
entry_time is present in 119 of 189 streams, so a position's span is known even
though its path is not. Each open position is charged its FULL adverse excursion
on EVERY day it is open. That is deliberately pessimistic - the true worst day is
at most this - so admitting a sleeve under this bound is conservative, not
optimistic. It is what challenge_campaign_mae.py's docstring claimed to do and
never did.

Accounts are independent by construction: separate FTMO accounts, separate
equity, separate caps. So a book's outcome is the OR over its members, and each
(sleeve, leverage) can be simulated once and combined afterwards.

Inherited unchanged: calendar-day deadlines, dormancy at 30 idle days = blocked,
target on end-of-day balance, four trading days minimum per phase, both phases,
starts that run out of data counted as failures, nothing fitted on the scoring
period.
"""
import itertools
import json
import sqlite3
import statistics
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

STREAMS = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")
ACCOUNT, DAILY_CAP, TOTAL_CAP = 100_000.0, 0.05, 0.10
P1_TARGET, P2_TARGET = 0.10, 0.05
D1, D2 = 60, 30
# 250 rather than 500: the 500-day floor was inherited from the sprint-era
# work, where a long window was needed for stability. A 60-day KPI resolves
# in ~43 trading days, so a 250-day sleeve still yields ~200 starts. Halving
# the floor more than doubles the pool, 7 -> 15, and admits 10128 and 10145,
# the only two sleeves ever marked challenge_ready.
MIN_DAYS, MIN_TRADING_DAYS, DORMANCY_DAYS = 250, 4, 30
LEVERAGES = (1.0, 2.0, 3.0, 4.0, 5.0)
# The overlay was measured and did not help: a daily stop changed the best
# book from 65.2% to 64.3%, inside noise. Kept as one option, not a grid.
DAILY_STOPS = (None, 0.030)
DERISK = (None,)
EARLY_OK = {"PASS", "PASS_SOFT", "PASS_LOWFREQ"}
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

sleeves, multi_pct = {}, {}
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
    ev, cov, n = [], 0, 0
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
            entry = parse_ts(r.get("entry_time"))
            n += 1
            if entry is not None:
                cov += 1
            ev.append((entry.date() if entry else close.date(), close.date(), net, mae))
    # span must be known: a missing entry_time is unknown exposure, not zero.
    if not n or cov < 0.99 * n:
        continue
    if len({c for _, c, _, _ in ev}) < MIN_DAYS:
        continue
    ev.sort(key=lambda x: (x[1], x[0]))
    key = f"{bare}:{sym.replace('.DWX','')}"
    sleeves[key] = ev
    multi_pct[key] = 100.0 * sum(1 for e, c, _, _ in ev if (c - e).days >= 1) / len(ev)

keys = sorted(sleeves)
all_days = sorted({c for ev in sleeves.values() for _, c, _, _ in ev})
day_index = {d: i for i, d in enumerate(all_days)}

# Per sleeve: closes by day, and the pessimistic floating charge by day.
closes = {k: defaultdict(list) for k in keys}
floating = {k: defaultdict(float) for k in keys}
active = {k: set() for k in keys}
for k in keys:
    for entry, close, net, mae in sleeves[k]:
        closes[k][close].append((net, mae))
        active[k].add(close)
        active[k].add(entry)
        # charge the full adverse excursion on every day the position is open
        i0 = day_index.get(entry)
        i1 = day_index[close]
        if i0 is None:
            i0 = i1
        for i in range(i0, i1 + 1):
            floating[k][all_days[i]] += mae
            active[k].add(all_days[i])


def phase(k, cfg, start_i, target, deadline):
    """One phase for one account, with the risk overlay applied.

    cfg = (leverage, daily_stop, derisk). daily_stop halts trading for the rest
    of the day once the day is down that fraction of the account - FTMO kills at
    -5%, so stopping at -2% turns a fatal day into a bad one. derisk = (threshold,
    factor) shrinks size once the account is down toward the total cap. Both are
    implementable: the framework already carries an equity DD guard.
    """
    lev, dstop, dr = cfg
    eq, traded, last = 0.0, 0, all_days[start_i]
    for di in range(start_i, len(all_days)):
        day = all_days[di]
        if (day - all_days[start_i]).days > deadline:
            return "expired", di
        if (day - last).days > DORMANCY_DAYS:
            return "dormant", di
        if day in active[k]:
            last = day
        sc = lev
        if dr and eq <= -dr[0] * ACCOUNT:
            sc = lev * dr[1]
        float_low = floating[k].get(day, 0.0) * sc
        if float_low and (eq + float_low <= -TOTAL_CAP * ACCOUNT
                          or float_low <= -DAILY_CAP * ACCOUNT):
            return "breach", di
        todays = closes[k].get(day)
        if not todays:
            continue
        traded += 1
        realized = 0.0
        for net, mae in todays:
            if dstop and realized <= -dstop * ACCOUNT:
                break                      # flat for the rest of the day
            realized += net * sc
            if realized <= -DAILY_CAP * ACCOUNT or eq + realized <= -TOTAL_CAP * ACCOUNT:
                return "breach", di
        eq += realized
        if eq >= target * ACCOUNT and traded >= MIN_TRADING_DAYS:
            return "pass", di
    return "censored", len(all_days) - 1


def funded_flags(k, cfg):
    """Boolean per start: does this account reach funded within D1 then D2?"""
    out, times, why = [], [], defaultdict(int)
    for s in range(len(all_days)):
        o1, i1 = phase(k, cfg, s, P1_TARGET, D1)
        if o1 != "pass":
            out.append(False)
            why[f"p1_{o1}"] += 1
            continue
        if i1 + 1 >= len(all_days):
            out.append(False)
            why["p2_censored"] += 1
            continue
        o2, i2 = phase(k, cfg, i1 + 1, P2_TARGET, D2)
        if o2 == "pass":
            out.append(True)
            times.append((all_days[i2] - all_days[s]).days)
            why["funded"] += 1
        else:
            out.append(False)
            why[f"p2_{o2}"] += 1
    return out, times, why


print(f"Optimising the book for OWNER's {D1}/{D2} calendar-day KPI")
print(f"pool: {len(keys)} sleeves pass gates + entry_time coverage + >={MIN_DAYS} trading days")
nm = sum(1 for k in keys if multi_pct[k] > 1.0)
print(f"      of which {nm} hold positions over a day and are admitted under the")
print(f"      pessimistic bound (full adverse excursion charged on every open day)")
print(f"window: {all_days[0]} .. {all_days[-1]}   {len(all_days)} trading days")
print()

CFGS = [(L, ds, dr) for L in LEVERAGES for ds in DAILY_STOPS for dr in DERISK]
results = {}
for k in keys:
    for cfg in CFGS:
        results[(k, cfg)] = funded_flags(k, cfg)
    sys.stdout.write(".")
    sys.stdout.flush()
print()
print()

# ---- IS/OOS split. Leverage and combination are chosen on the selection period
# only; the scoring period decides nothing. Without this the whole table is a
# best-of-35 fit, which is the exact error class that produced 90.2% yesterday.
SPLIT = 0.60
cut_i = int(len(all_days) * SPLIT)
cut = all_days[cut_i]
IS = range(0, cut_i)
OOS = range(cut_i, len(all_days))


def rate_on(flags, idx):
    sel = [flags[s] for s in idx]
    return (sum(sel) / len(sel)) if sel else float("nan")


print(f"selection {all_days[0]}..{cut}   scoring {cut}..{all_days[-1]}")
print(f"grid: {len(CFGS)} configs per sleeve (leverage x daily stop x de-risk)")
print()
print("Config per sleeve. IS chooses; OOS only reports. breach = share of starts blown up:")
print(f"{'sleeve':16}{'multi%':>7}{'lev':>5}{'dstop':>7}{'derisk':>9}"
      f"{'IS':>8}{'OOS':>8}{'breach':>8}{'1x OOS':>8}")
print("-" * 84)
ranked = []
for k in keys:
    best = None
    for cfg in CFGS:
        f, _, _ = results[(k, cfg)]
        r_is = rate_on(f, IS)
        if best is None or r_is > best[0]:
            best = (r_is, cfg)
    r_is, cfg = best
    f, t, why = results[(k, cfg)]
    oos = rate_on(f, OOS)
    br = (why.get("p1_breach", 0) + why.get("p2_breach", 0)) / len(f)
    flat = rate_on(results[(k, (1.0, None, None))][0], OOS)
    lev, ds, dr = cfg
    ranked.append((r_is, oos, cfg, k))
    print(f"{k:16}{multi_pct[k]:>6.0f}%{lev:>5.0f}"
          f"{(f'{ds*100:.1f}%' if ds else '-'):>7}"
          f"{(f'{dr[0]*100:.0f}%/{dr[1]:.2f}' if dr else '-'):>9}"
          f"{r_is:>8.1%}{oos:>8.1%}{br:>8.0%}{flat:>8.1%}")
ranked.sort(reverse=True)

TOP = [(k, cfg) for r_is, oos, cfg, k in ranked if r_is > 0][:10]
print()
print("Book chosen IN-SAMPLE at each size; OOS counted on shared starts, never assumed:")
print(f"{'N':>2}{'IS':>8}{'OOS':>8}{'med d':>7}{'p90 d':>7}   accounts")
print("-" * 118)
sizes = {}
for size in range(1, min(6, len(TOP)) + 1):
    best = None
    for combo in itertools.combinations(TOP, size):
        if len({k for k, _ in combo}) < size:
            continue
        flags = [any(results[m][0][s] for m in combo) for s in range(len(all_days))]
        r_is = rate_on(flags, IS)
        if best is None or r_is > best[0]:
            best = (r_is, combo, flags)
    if not best:
        continue
    r_is, combo, flags = best
    oos = rate_on(flags, OOS)
    sizes[size] = oos
    tt = sorted(t for m in combo for t in results[m][1])
    med = f"{statistics.median(tt):.0f}" if tt else "-"
    p90 = f"{tt[int(len(tt)*0.9)]:.0f}" if tt else "-"
    members = ", ".join(f"{k}@{c[0]:.0f}x" + (f"/{c[1]*100:.0f}%" if c[1] else "")
                        for k, c in combo)
    mark = "  <<" if oos >= 0.80 else ""
    print(f"{size:>2}{r_is:>8.1%}{oos:>8.1%}{med:>7}{p90:>7}   {members}{mark}")

print()
print(f"baseline: the same KPI at 1x with no overlay was 9.1%.")
print("Leverage, overlay and combination are all picked on the selection period alone.")
print()
print("FEE ECONOMICS - N accounts means N fees whether or not any passes.")
print(f"{'N':>2}{'OOS':>8}{'fees/funding':>15}{'~days to funded':>17}")
print("-" * 42)
for size, oos in sizes.items():
    rounds = 1.0 / oos if oos else float("inf")
    print(f"{size:>2}{oos:>8.1%}{size/oos if oos else float('inf'):>15.1f}"
          f"{rounds*(D1+D2):>17.0f}")
print()
print("A wide parallel book buys speed; a single account retried sequentially is")
print("cheaper per funding. Both columns are the same measurement, priced differently.")
