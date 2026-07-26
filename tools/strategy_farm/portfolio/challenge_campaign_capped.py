"""Campaign pass rate as a function of an exposure cap - deployable without
inventing FTMO's leverage.

The uncapped result (81-83% for three accounts) requires peak concurrent notional
of 66x to 74x account equity on the USDJPY sleeves. Whether an account can carry
that depends entirely on FTMO's margin leverage, and `venue_cost_model.json`
carries commissions but no leverage or margin figures. Inventing one is barred,
and guessing it would decide the whole question:

    at 1:100 FX leverage   74x notional -> 74% margin used, tight but carryable
    at  1:30 FX leverage   74x notional -> 246% of the account, impossible

So the leverage is not assumed. Instead each sleeve's multiplier is capped so its
own peak concurrent notional stays within a stated multiple of equity, and the
pass rate is measured at each cap. Whoever knows the real leverage reads the row
that fits; nothing here depends on knowing it in advance.

Peak CONCURRENT notional is used, not per-trade: overlapping positions inside one
account share its margin. Separate accounts never do, which is another reason the
campaign structure is easier to fund than one merged book.
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
EXPOSURE_CAPS = (5, 10, 20, 30, 50, 75)
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


con = sqlite3.connect("file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro", uri=True)
con.row_factory = sqlite3.Row
latest = {}
for r in con.execute("select ea_id,symbol,phase,verdict from work_items "
                     "where status='done' order by updated_at"):
    latest[(r["ea_id"], str(r["symbol"]).upper(), r["phase"])] = str(r["verdict"] or "")

trades, base_peak = {}, {}
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
    rows, ev = [], []
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
            entry = parse_ts(r.get("entry_time")) or close
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
            try:
                notional = abs(float(r.get("notional") or 0.0))
            except (TypeError, ValueError):
                notional = 0.0
            rows.append((entry, close, net, mae))
            ev.append((entry, +notional))
            ev.append((close, -notional))
    rows.sort(key=lambda r: r[1])
    if len({r[1].date() for r in rows}) < MIN_DAYS:
        continue
    ev.sort(key=lambda x: x[0])
    cur = peak = 0.0
    for _, d in ev:
        cur += d
        peak = max(peak, cur)
    key = f"{bare}:{sym.replace('.DWX','')}"
    trades[key] = rows
    base_peak[key] = peak / ACCOUNT      # exposure multiple at leverage 1.0

keys = sorted(trades)
all_days = sorted({r[1].date() for rs in trades.values() for r in rs})
cut = all_days[int(len(all_days) * SPLIT)]
FAR = datetime(2100, 1, 1).date()

print("peak concurrent notional at leverage 1.0, as a multiple of a 100k account:")
for k in keys:
    print(f"   {k:16} {base_peak[k]:6.1f}x")
print()


def outcomes(members, levs, lo, hi, use_mae):
    day_events = defaultdict(list)
    for k, lev in zip(members, levs):
        for entry, close, net, mae in trades[k]:
            if lo <= close.date() < hi:
                day_events[close.date()].append((close, net * lev, mae * lev))
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
            pending = sum(m for _, _, m in evs) if use_mae else 0.0
            for _, net, mae in evs:
                if use_mae:
                    low = realized + pending
                    if low <= -DAILY_CAP * ACCOUNT or eq + low <= -TOTAL_CAP * ACCOUNT:
                        dead = True
                        break
                    pending -= mae
                realized += net
                if realized <= -DAILY_CAP * ACCOUNT or eq + realized <= -TOTAL_CAP * ACCOUNT:
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


print(f"{'cap':>6}  {'accounts':>9}{'upper':>8}{'lower':>8}   books at their capped leverage")
print("-" * 92)
for cap in EXPOSURE_CAPS:
    # Highest leverage each sleeve may run without exceeding the exposure cap.
    lev_of = {k: cap / base_peak[k] for k in keys if base_peak[k] > 0}
    solo = {}
    for k, lev in lev_of.items():
        if lev < 0.25:
            continue
        up = outcomes((k,), (lev,), cut, FAR, False)
        lo_ = outcomes((k,), (lev,), cut, FAR, True)
        if up and lo_:
            solo[k] = (lev, up, lo_)
    if not solo:
        continue
    order = sorted(solo, key=lambda k: -sum(solo[k][1]) / len(solo[k][1]))
    best = None
    for size in range(1, len(order) + 1):
        for combo in itertools.combinations(order, size):
            n = min(len(solo[k][1]) for k in combo)
            up = sum(1 for i in range(n) if any(solo[k][1][i] for k in combo)) / n
            lo_ = sum(1 for i in range(n) if any(solo[k][2][i] for k in combo)) / n
            if best is None or lo_ > best[1]:
                best = (up, lo_, combo, size)
    up, lo_, combo, size = best
    mark = "  <-- clears 80% on the LOWER bound" if lo_ >= 0.80 else ""
    print(f"{cap:>5}x  {size:>9}{up:>8.1%}{lo_:>8.1%}   "
          f"{', '.join(f'{k}@{solo[k][0]:.1f}x' for k in combo)}{mark}")

print()
print("Cap = peak concurrent notional as a multiple of account equity, PER ACCOUNT.")
print("Margin needed = cap / (broker leverage). At 1:100 a 30x cap uses 30% margin;")
print("at 1:30 the same cap uses 100% and is not carryable. Pick the row that fits")
print("the leverage FTMO actually grants - that figure is not on disk and is not")
print("guessed here.")
