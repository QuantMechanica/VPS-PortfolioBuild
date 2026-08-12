"""Both FTMO phases, on calendar days, with the dormancy rule enforced.

OWNER set the real KPI on 2026-07-27: we do not want to wait forever for a
payout, so Phase 1 should complete inside ~60 days and Phase 2 inside ~30. OWNER
also confirmed from experience that **FTMO blocks an account after 30 days
without a trade**. Both change the measurement materially.

Three things this does that challenge_firstpassage.py did not:

1. CALENDAR DAYS, NOT TRADING DAYS. Every earlier figure was in trading days and
   was read as if it were calendar days. It is not: 22 trading days is about 30
   calendar days, so the previously reported median of 62 trading days is nearer
   87 calendar days, and the p90 of 375 trading days is about 18 months. Deadlines
   here are calendar, because FTMO's are.

2. DORMANCY ENFORCED. More than 30 calendar days with no closed trade blocks the
   account, which this counts as a failure. This is not a detail. The 0.0% breach
   rate of the earlier three-account book came from 13036/GDAXI being too slow to
   ever breach - and 13036 has a 279-day gap between trades, with three gaps over
   30 days. The sleeve supplying the safety is the sleeve the dormancy rule
   removes. Sonnet made this argument independently
   (docs/ops/evidence/2026-07-27_sonnet_funded_account_book_design.md) and it is
   the strongest objection raised against the first-passage result.

3. BOTH PHASES. Phase 1 needs +10%, Phase 2 needs +5% on a fresh balance, each
   with -5% daily and -10% total. Getting funded requires both. Phase 2 begins on
   the first trading day after Phase 1 completes.

Everything else is inherited unchanged: 1x sizing as the framework enforces it,
target tested on end-of-day balance with all positions closed, four-trading-day
minimum per phase, entry_time coverage required, sleeves with >1% multi-day
positions excluded, and starts that run out of data counted as failures.
"""
import itertools
import json
import sqlite3
import statistics
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

STREAMS = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")
ACCOUNT, DAILY_CAP, TOTAL_CAP = 100_000.0, 0.05, 0.10
P1_TARGET, P2_TARGET = 0.10, 0.05
MIN_DAYS = 500
MIN_TRADING_DAYS = 4
DORMANCY_DAYS = 30           # OWNER-confirmed: FTMO blocks after 30 days idle
# Calendar-day deadlines to sweep. None = FTMO's own rule (no deadline).
DEADLINES = [(30, 15), (45, 23), (60, 30), (90, 45), (120, 60), (None, None)]
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

trades = {}
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
    rows, spans = [], []
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
            spans.append(parse_ts(r.get("entry_time")))
            rows.append((close, net, mae))
    rows.sort()
    if not spans or sum(1 for e in spans if e is not None) < 0.99 * len(spans):
        continue
    multi = sum(1 for e, (c, _, _) in zip(spans, rows) if e and (c - e).days >= 1)
    if 100.0 * multi / len(spans) > 1.0:
        continue
    if len({r[0].date() for r in rows}) >= MIN_DAYS:
        trades[f"{bare}:{sym.replace('.DWX','')}"] = rows

keys = sorted(trades)
all_days = sorted({r[0].date() for rs in trades.values() for r in rs})
by_day = {k: defaultdict(list) for k in keys}
for k in keys:
    for close, net, mae in trades[k]:
        by_day[k][close.date()].append((close, net, mae))
for k in keys:
    for d in by_day[k]:
        by_day[k][d].sort(key=lambda r: r[0])


def run_phase(members, start_i, target, deadline):
    """Run one phase from days[start_i]. Returns (outcome, end_index).

    outcome is 'pass', 'breach', 'dormant', 'expired' or 'censored'. An account
    is dormant once DORMANCY_DAYS calendar days pass with no closed trade; a
    phase expires once `deadline` calendar days pass without reaching target.
    """
    eq = {k: 0.0 for k in members}
    state = {k: "live" for k in members}
    traded = {k: 0 for k in members}
    last = {k: all_days[start_i] for k in members}
    for di in range(start_i, len(all_days)):
        day = all_days[di]
        elapsed = (day - all_days[start_i]).days
        if deadline is not None and elapsed > deadline:
            return "expired", di
        for k in members:
            if state[k] == "live" and (day - last[k]).days > DORMANCY_DAYS:
                state[k] = "dormant"
        if all(state[k] != "live" for k in members):
            return ("dormant" if any(state[k] == "dormant" for k in members)
                    else "breach"), di
        for k in members:
            if state[k] != "live":
                continue
            ev = by_day[k].get(day, ())
            if not ev:
                continue
            last[k] = day
            traded[k] += 1
            realized, floating = 0.0, sum(m for _, _, m in ev)
            for _, net, mae in ev:
                low = realized + floating
                if low <= -DAILY_CAP * ACCOUNT or eq[k] + low <= -TOTAL_CAP * ACCOUNT:
                    state[k] = "breach"
                    break
                floating -= mae
                realized += net
                if realized <= -DAILY_CAP * ACCOUNT or \
                        eq[k] + realized <= -TOTAL_CAP * ACCOUNT:
                    state[k] = "breach"
                    break
            if state[k] != "live":
                continue
            eq[k] += realized
            if eq[k] >= target * ACCOUNT and traded[k] >= MIN_TRADING_DAYS:
                return "pass", di
        if all(state[k] != "live" for k in members):
            return ("dormant" if any(state[k] == "dormant" for k in members)
                    else "breach"), di
    return "censored", len(all_days) - 1


def campaign(members, d1, d2):
    """Full run to funded. Returns list of (outcome, calendar_days_total)."""
    out = []
    for s in range(len(all_days)):
        o1, i1 = run_phase(members, s, P1_TARGET, d1)
        if o1 != "pass":
            out.append((f"p1_{o1}", None))
            continue
        if i1 + 1 >= len(all_days):
            out.append(("p2_censored", None))
            continue
        o2, i2 = run_phase(members, i1 + 1, P2_TARGET, d2)
        total = (all_days[i2] - all_days[s]).days
        out.append((f"p2_{o2}" if o2 != "pass" else "funded",
                    total if o2 == "pass" else None))
    return out


print("FTMO both phases, CALENDAR days, dormancy enforced at "
      f"{DORMANCY_DAYS} days idle = account blocked")
print(f"Phase 1 +{P1_TARGET:.0%}, Phase 2 +{P2_TARGET:.0%}, each -{DAILY_CAP:.0%} daily "
      f"/ -{TOTAL_CAP:.0%} total, 1x sizing, nothing fitted")
print(f"sleeves: {', '.join(keys)}")
print(f"window: {all_days[0]} .. {all_days[-1]}  ({len(all_days)} trading days)")
print()

print("PHASE 1 ONLY, per sleeve, by calendar deadline (pass rate):")
hdr = "".join(f"{(str(d1)+'d' if d1 else 'none'):>9}" for d1, _ in DEADLINES)
print(f"{'sleeve':15}{hdr}{'dormant':>9}")
print("-" * (15 + 9 * len(DEADLINES) + 9))
for k in keys:
    cells = []
    dorm = None
    for d1, _ in DEADLINES:
        res = [run_phase((k,), s, P1_TARGET, d1)[0] for s in range(len(all_days))]
        cells.append(f"{sum(1 for r in res if r=='pass')/len(res):>8.0%}")
        if d1 is None:
            dorm = sum(1 for r in res if r == "dormant") / len(res)
    print(f"{k:15}" + "".join(cells) + f"{dorm:>9.0%}")

print()
print("FUNDED (both phases), by deadline pair. Everything measured, nothing picked:")
print(f"{'d1/d2':>9}{'N':>3}{'funded':>9}{'med d':>7}{'p90 d':>7}   accounts")
print("-" * 95)
for d1, d2 in DEADLINES:
    best = []
    for size in range(1, len(keys) + 1):
        for combo in itertools.combinations(keys, size):
            res = campaign(combo, d1, d2)
            rate = sum(1 for o, _ in res if o == "funded") / len(res)
            times = [t for o, t in res if o == "funded"]
            best.append((rate, size, combo, times))
    best.sort(key=lambda r: (-r[0], r[1]))
    rate, size, combo, times = best[0]
    med = f"{statistics.median(times):.0f}" if times else "-"
    p90 = f"{sorted(times)[int(len(times)*0.9)]:.0f}" if times else "-"
    label = f"{d1}/{d2}" if d1 else "none"
    print(f"{label:>9}{size:>3}{rate:>9.1%}{med:>7}{p90:>7}   {', '.join(combo)}")

print()
print("Failure decomposition at the OWNER-proposed 60/30, best book:")
best = []
for size in range(1, len(keys) + 1):
    for combo in itertools.combinations(keys, size):
        res = campaign(combo, 60, 30)
        best.append((sum(1 for o, _ in res if o == "funded") / len(res), size, combo, res))
best.sort(key=lambda r: (-r[0], r[1]))
rate, size, combo, res = best[0]
counts = defaultdict(int)
for o, _ in res:
    counts[o] += 1
print(f"  book: {', '.join(combo)}   funded {rate:.1%} of {len(res)} starts")
for o, n in sorted(counts.items(), key=lambda x: -x[1]):
    print(f"    {o:16} {n:>5}  {n/len(res):>6.1%}")

# ---- the number OWNER actually needs: which deadline buys which probability?
print()
print("Deadline curve for the fixed book 13213 + 13301 + 9936 (Phase 2 gets half of Phase 1):")
print(f"{'phase1 d':>9}{'phase2 d':>9}{'funded':>9}{'med d':>7}{'p90 d':>7}")
print("-" * 41)
BOOK = tuple(k for k in keys if k != "13036:GDAXI")
for d1 in (60, 90, 120, 150, 180, 240, 300, 365, 450, None):
    d2 = d1 // 2 if d1 else None
    res = campaign(BOOK, d1, d2)
    rate = sum(1 for o, _ in res if o == "funded") / len(res)
    times = [t for o, t in res if o == "funded"]
    med = f"{statistics.median(times):.0f}" if times else "-"
    p90 = f"{sorted(times)[int(len(times)*0.9)]:.0f}" if times else "-"
    lab1 = str(d1) if d1 else "none"
    lab2 = str(d2) if d2 else "none"
    mark = "  <<" if rate >= 0.80 else ""
    print(f"{lab1:>9}{lab2:>9}{rate:>9.1%}{med:>7}{p90:>7}{mark}")
print()
print("Breach never appears in any decomposition above: the book does not blow up,")
print("it runs out of time. The binding constraint is speed, not risk.")
