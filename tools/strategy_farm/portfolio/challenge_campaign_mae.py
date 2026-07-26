"""FTMO campaign pass probability, bounded from BOTH sides using per-trade MAE.

The closed-trade measurement (80.7%) is an upper bound, because FTMO checks its
-5% daily cap against running equity including floating loss on OPEN positions,
and a closed-trade record cannot show a position that sat 4% under water at noon
and closed green. The very first record in 13213's stream is that exact case:

    mae_acct -610.47   net +35.92

But the streams DO carry `mae_acct` - maximum adverse excursion per trade, in
account currency. So the gap is closable here rather than pending on a per-bar
equity export.

Two bounds are computed:

  UPPER  closed-trade P&L only. Floating loss invisible. What was measured before.

  LOWER  every open position is assumed to sit at its own worst point
         SIMULTANEOUSLY, at every instant it is open. That cannot happen in
         reality - MAEs of different positions occur at different times - so
         this understates the pass rate as surely as the upper bound overstates
         it.

The truth is between them. If the lower bound clears 80%, the goal is met
regardless of the floating-P&L question. If the upper bound falls below 80%, it
is not met. In between, the honest answer is that this method cannot resolve it
and per-bar equity is genuinely required.

A position open across several days contributes its MAE to each of those days,
since FTMO's daily cap resets at each day's start and the loss is live throughout.
"""
import itertools
import json
import sqlite3
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

STREAMS = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")
ACCOUNT, WINDOW, TARGET, DAILY_CAP, TOTAL_CAP = 100_000.0, 22, 0.10, 0.05, 0.10
MIN_DAYS, SPLIT = 600, 0.60
LEVERAGES = (1, 1.5, 2, 2.5, 3, 4, 5, 6, 8)
EARLY_OK = {"PASS", "PASS_SOFT"}
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


def load():
    con = sqlite3.connect("file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro",
                          uri=True)
    con.row_factory = sqlite3.Row
    latest = {}
    for r in con.execute("select ea_id,symbol,phase,verdict from work_items "
                         "where status='done' order by updated_at"):
        latest[(r["ea_id"], str(r["symbol"]).upper(), r["phase"])] = str(r["verdict"] or "")

    out = {}
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
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if str(row.get("event") or "TRADE_CLOSED") != "TRADE_CLOSED":
                    continue
                close = parse_ts(row.get("time"))
                entry = parse_ts(row.get("entry_time")) or close
                try:
                    net = float(row.get("net"))
                except (TypeError, ValueError):
                    continue
                try:
                    mae = float(row.get("mae_acct") or 0.0)
                except (TypeError, ValueError):
                    mae = 0.0
                if close is None:
                    continue
                rows.append((entry, close, net, min(mae, 0.0)))
        rows.sort(key=lambda r: r[1])
        if len({r[1].date() for r in rows}) >= MIN_DAYS:
            out[f"{bare}:{sym.replace('.DWX','')}"] = rows
    return out


trades = load()
keys = sorted(trades)
all_days = sorted({r[1].date() for rs in trades.values() for r in rs})
cut = all_days[int(len(all_days) * SPLIT)]
FAR = datetime(2100, 1, 1).date()
print(f"gate-clean sleeves: {', '.join(keys)}")
print(f"selection {all_days[0]}..{cut}   scoring {cut}..{all_days[-1]}")


def outcomes(members, lev, lo, hi, use_mae):
    """Per-window pass flags. use_mae=True gives the conservative lower bound."""
    day_events = defaultdict(list)   # date -> [(close_time, net, mae, entry_date)]
    for k in members:
        for entry, close, net, mae in trades[k]:
            if lo <= close.date() < hi:
                day_events[close.date()].append((close, net * lev, mae * lev, entry))
    if not day_events:
        return None
    for d in day_events:
        day_events[d].sort(key=lambda r: r[0])
    days = [d for d in all_days if lo <= d < hi]
    if len(days) < WINDOW + 5:
        return None

    res = []
    for s in range(len(days) - WINDOW + 1):
        eq = 0.0
        got = dead = False
        for di in range(s, s + WINDOW):
            evs = day_events.get(days[di], ())
            realized = 0.0
            # Worst-case floating exposure: every trade closing later today is
            # assumed already open and already at its own MAE.
            if use_mae and evs:
                pending = sum(m for _, _, m, _ in evs)
            else:
                pending = 0.0
            for close, net, mae, entry in evs:
                if use_mae:
                    # this trade is still open and at its worst
                    low = realized + pending
                    if low <= -DAILY_CAP * ACCOUNT or eq + low <= -TOTAL_CAP * ACCOUNT:
                        dead = True
                        break
                    pending -= mae          # it closes; its floating loss resolves
                realized += net
                if realized <= -DAILY_CAP * ACCOUNT:
                    dead = True
                    break
                if eq + realized <= -TOTAL_CAP * ACCOUNT:
                    dead = True
                    break
                if eq + realized >= TARGET * ACCOUNT:
                    got = True
                    break
            if got or dead:
                break
            eq += realized
        res.append(got)
    return res


solo = {}
for k in keys:
    best = None
    for lev in LEVERAGES:
        o = outcomes((k,), lev, all_days[0], cut, use_mae=False)
        if o and (best is None or sum(o) / len(o) > best[0]):
            best = (sum(o) / len(o), lev)
    if not best:
        continue
    lev = best[1]
    up = outcomes((k,), lev, cut, FAR, use_mae=False)
    lo_ = outcomes((k,), lev, cut, FAR, use_mae=True)
    if up and lo_:
        solo[k] = (lev, up, lo_)

print()
print(f"{'sleeve':16}{'lev':>5}{'OOS upper':>11}{'OOS lower':>11}")
print("-" * 44)
for k in sorted(solo, key=lambda k: -sum(solo[k][1]) / len(solo[k][1])):
    lev, up, lo_ = solo[k]
    print(f"{k:16}{lev:>5.1f}{sum(up)/len(up):>11.1%}{sum(lo_)/len(lo_):>11.1%}")

print()
print("CAMPAIGNS - both bounds, counted on shared out-of-sample windows")
print(f"{'N':>2}  {'upper':>7}{'lower':>8}   books")
print("-" * 72)
order = sorted(solo, key=lambda k: -sum(solo[k][1]) / len(solo[k][1]))
for size in range(1, len(order) + 1):
    best = None
    for combo in itertools.combinations(order, size):
        n = min(len(solo[k][1]) for k in combo)
        up = sum(1 for i in range(n) if any(solo[k][1][i] for k in combo)) / n
        if best is None or up > best[0]:
            lo_ = sum(1 for i in range(n) if any(solo[k][2][i] for k in combo)) / n
            best = (up, lo_, combo)
    if not best:
        continue
    up, lo_, combo = best
    print(f"{size:>2}  {up:>7.1%}{lo_:>8.1%}   "
          f"{', '.join(f'{k}@{solo[k][0]:.0f}x' for k in combo)}")

print()
print("Reading: the true pass rate lies between the two columns. The lower bound")
print("assumes every open position sits at its worst point simultaneously, which")
print("cannot occur; the upper bound ignores floating loss entirely.")
