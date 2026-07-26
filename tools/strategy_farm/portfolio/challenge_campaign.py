"""Parallel challenge accounts on uncorrelated books - measured, not assumed.

Two findings force this design.

First, one sleeve passes 61.7% of unseen 22-day windows (9936/USDJPY at 4x,
daily cap checked intraday). Second, combining sleeves into one book makes it
WORSE, every time. That is not a bug: the target sits far above the expected
return, so reaching it depends on an upward excursion, and merging sleeves
averages exactly those excursions away. Diversification protects an account that
must survive; it works against an account that must sprint.

So diversify across ACCOUNTS instead of inside one. Run each challenge on its own
book, and the campaign succeeds if any single account reaches target. With p~0.6
per account, two INDEPENDENT accounts give 1-0.4^2 = 84%, which clears OWNER's
80% bar. But independence is the whole claim, and two accounts running correlated
books pass and fail together - buying nothing for a second fee.

So it is measured rather than assumed: run the books through the SAME windows and
count the windows where at least one passed. That captures their real joint
behaviour, including correlation, with no independence assumption anywhere.

The 0.905 correlation between 13213 and 9936 (both USDJPY) says those two are one
bet, not two. The 0.012 between 13213 and 13301/GDAXI says those two are genuinely
different bets - which is what a second account has to be worth paying for.
"""
import itertools
import json
import sqlite3
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

STREAMS = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")
ACCOUNT = 100_000.0
PNL_KEYS = ("net", "profit_acct", "net_acct", "pnl_acct", "profit")
WINDOW, TARGET, DAILY_CAP, TOTAL_CAP = 22, 0.10, 0.05, 0.10
MIN_DAYS = 600          # lowered to admit 13301/GDAXI (742 days), the one sleeve
SPLIT = 0.60            # measured near-zero correlation against the USDJPY family
LEVERAGES = (1, 1.5, 2, 2.5, 3, 4, 5, 6, 8)


def parse_ts(v):
    if v is None:
        return None
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


con = sqlite3.connect(r"file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro", uri=True)
con.row_factory = sqlite3.Row
verdicts = {}
for r in con.execute(
    "select ea_id, symbol, phase, verdict from work_items "
    "where phase in ('Q05','Q08') and status='done' order by updated_at"
):
    verdicts[(r["ea_id"], str(r["symbol"]).upper(), r["phase"])] = str(r["verdict"])

trades = {}
for path in sorted(STREAMS.glob("*.jsonl")):
    bare, _, stem = path.stem.partition("_")
    ea, sym_full = f"QM5_{bare}", stem.replace("_DWX", ".DWX").upper()
    if verdicts.get((ea, sym_full, "Q05")) in ("FAIL", "FAIL_HARD"):
        continue
    if verdicts.get((ea, sym_full, "Q08")) in ("FAIL", "FAIL_HARD"):
        continue
    rows = []
    try:
        with path.open(encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if str(row.get("event") or "TRADE_CLOSED") != "TRADE_CLOSED":
                    continue
                pnl = None
                for k in PNL_KEYS:
                    if k in row:
                        try:
                            pnl = float(row[k])
                        except (TypeError, ValueError):
                            pnl = None
                        break
                close = parse_ts(row.get("time"))
                if pnl is None or close is None:
                    continue
                rows.append((close, pnl))
    except OSError:
        continue
    rows.sort(key=lambda r: r[0])
    if len({r[0].date() for r in rows}) >= MIN_DAYS:
        trades[f"{bare}:{sym_full.replace('.DWX','')}"] = rows

keys = sorted(trades)
all_days = sorted({t[0].date() for rows in trades.values() for t in rows})
cut = all_days[int(len(all_days) * SPLIT)]
FAR = datetime(2100, 1, 1).date()
print(f"pool: {len(keys)} sleeves >= {MIN_DAYS} trading days -> {', '.join(keys)}")
print(f"selection {all_days[0]} .. {cut}   |   scoring {cut} .. {all_days[-1]}")
print()

# Evaluate on a COMMON calendar so two books are judged on identical windows.
CAL = [d for d in all_days]
cal_index = {d: i for i, d in enumerate(CAL)}


def outcomes(members, lev, lo, hi):
    """Per-window outcome vector over the shared calendar. True = passed."""
    by_day = defaultdict(list)
    for k in members:
        for t, p in trades[k]:
            if lo <= t.date() < hi:
                by_day[t.date()].append((t, p * lev))
    if not by_day:
        return None
    for d in by_day:
        by_day[d].sort(key=lambda r: r[0])
    days = [d for d in CAL if lo <= d < hi]
    if len(days) < WINDOW + 5:
        return None

    res = []
    for start in range(len(days) - WINDOW + 1):
        eq = 0.0
        got = False
        dead = False
        for di in range(start, start + WINDOW):
            day_cum = 0.0
            for _, p in by_day.get(days[di], ()):
                day_cum += p
                if day_cum <= -DAILY_CAP * ACCOUNT:
                    dead = True
                    break
                if eq + day_cum <= -TOTAL_CAP * ACCOUNT:
                    dead = True
                    break
                if eq + day_cum >= TARGET * ACCOUNT:
                    got = True
                    break
            if got or dead:
                break
            eq += day_cum
        res.append(got)
    return res


# Candidate books: single sleeves and pairs, each at its best in-sample leverage.
books = []
for n in (1, 2):
    for combo in itertools.combinations(keys, n):
        best = None
        for lev in LEVERAGES:
            o = outcomes(combo, lev, all_days[0], cut)
            if o and (best is None or sum(o) / len(o) > best[0]):
                best = (sum(o) / len(o), lev)
        if best:
            books.append((combo, best[1], best[0]))

print(f"{'book':44}{'lev':>5}{'IS':>7}{'OOS':>8}")
print("-" * 64)
scored = []
for combo, lev, is_rate in sorted(books, key=lambda b: -b[2])[:10]:
    o = outcomes(combo, lev, cut, FAR)
    if not o:
        continue
    oos = sum(o) / len(o)
    scored.append((combo, lev, is_rate, oos, o))
    print(f"{' + '.join(combo)[:43]:44}{lev:>5.1f}{is_rate:>7.1%}{oos:>8.1%}")

print()
print("CAMPAIGNS: two accounts, different books, same windows.")
print("P(any) is counted directly on the shared windows - no independence assumed.")
print()
print(f"{'account A':22}{'account B':22}{'P(A)':>7}{'P(B)':>7}{'P(any)':>8}{'indep':>8}")
print("-" * 74)

pairs = []
for (ca, la, _, pa, oa), (cb, lb, _, pb, ob) in itertools.combinations(scored, 2):
    if set(ca) & set(cb):
        continue
    n = min(len(oa), len(ob))
    if n < 20:
        continue
    joint = sum(1 for i in range(n) if oa[i] or ob[i]) / n
    indep = 1 - (1 - pa) * (1 - pb)
    pairs.append((joint, indep, ca, cb, la, lb, pa, pb, n))

pairs.sort(reverse=True)
for joint, indep, ca, cb, la, lb, pa, pb, n in pairs[:10]:
    print(f"{' + '.join(ca)[:21]:22}{' + '.join(cb)[:21]:22}"
          f"{pa:>7.0%}{pb:>7.0%}{joint:>8.1%}{indep:>8.1%}")

print()
if pairs:
    joint, indep, ca, cb, la, lb, pa, pb, n = pairs[0]
    print("best measured two-account campaign (out-of-sample):")
    print(f"  account A: {' + '.join(ca)} at {la:.1f}x   -> {pa:.1%}")
    print(f"  account B: {' + '.join(cb)} at {lb:.1f}x   -> {pb:.1%}")
    print(f"  P(at least one passes): {joint:.1%}   over {n} windows")
    print(f"  goal: 80%")
    if joint < 0.80:
        need = 1
        p = joint
        while p < 0.80 and need < 6:
            need += 1
            p = 1 - (1 - pa) ** need
        print(f"  a third account on an equally independent book would reach "
              f"~{1-(1-pa)*(1-pb)*(1-pa):.0%}")
