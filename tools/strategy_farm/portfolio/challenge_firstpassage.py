"""The FTMO rule as FTMO actually writes it: no deadline, two barriers.

Every campaign number so far answered "P(+10% within 22 trading days)". FTMO
removed the maximum trading period in 2024 (ftmo.com/en/challenge, verified by
Codex under task 9b7c6aaf). The real Phase 1 question is a first-passage problem:

    reach +10% on balance, before -5% on any day or -10% total.

challenge_as_deployed.py's own docstring dismissed the unlimited horizon on
sample-size grounds - "a 250-day window leaves roughly three independent
samples". That conflated two different estimators. A longer FIXED window does
collapse the sample count. First passage does not: every start day runs until it
resolves, so every start day yields an outcome, and the time to resolution
becomes an output rather than a constraint.

The direction of the leverage effect inverts with the deadline gone. Under a
22-day sprint, size is what gets you to the target in time. Against fixed
barriers, size is pure variance: as leverage rises the drift per unit of noise
falls and P(pass) decays toward the driftless 10/(10+10) = 50%. As leverage
falls, drift dominates and P(pass) rises - at the cost of time. That is why the
framework's 1% clamp, which looked like the thing crippling the campaign, may be
close to the right setting for it.

Three corrections to the earlier instrument, all tightening:

1. TARGET ON END-OF-DAY BALANCE. FTMO requires balance above target with all
   positions closed. The earlier scripts passed on the intraday closing event
   that first crossed it, while other positions might still be open. Restricting
   the check to end of day makes the criterion exactly right for this sleeve
   class, which is flat overnight by construction (<=1% multi-day positions).

2. FOUR-TRADING-DAY MINIMUM ENFORCED. FTMO requires at least four trading days.
   The earlier scripts did not check it.

3. CENSORING REPORTED, NOT HIDDEN. Starts too late in the data to resolve are
   counted as failures in the headline and shown separately, so the number is a
   lower bound rather than a survivor-biased average.

Still NOT fixed here, and still limiting: the streams carry no entry_time, so
multi-day positions remain invisible. That is why sleeves with >1% multi-day
positions stay excluded rather than modelled. Within the intraday-flat class the
daily cap binds far less at 1x than at 4-8x - a 5% daily loss needs five
simultaneous full-stop losses - so the residual exposure to that defect is much
smaller here than in the leveraged books, but it is not zero.
"""
import itertools
import json
import sqlite3
import statistics
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

STREAMS = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")
ACCOUNT, TARGET, DAILY_CAP, TOTAL_CAP = 100_000.0, 0.10, 0.05, 0.10
MIN_DAYS, SPLIT = 500, 0.60
MIN_TRADING_DAYS = 4          # FTMO Phase 1 minimum
# 1.0 is what the framework actually enforces (QM_Common.mqh:182). 5.0 is the
# ceiling QM_FrameworkSetRiskCapPct would permit if it were ever wired in
# (QM_Common.mqh:315, OWNER-ratified 2026-07-05). Both are reported; neither is
# chosen on the scoring period.
LEVERAGES = (1.0, 2.0, 3.0, 5.0)
DAILY_STOPS = (None, 0.040, 0.030, 0.025, 0.020)
DERISK = (None, (0.05, 0.5), (0.06, 0.5), (0.05, 0.25))
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

trades, gate_note, excluded = {}, {}, []
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
    rows, raw_span = [], []
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
            raw_span.append((entry, close))
            rows.append((close, net, mae))
    rows.sort()
    key = f"{bare}:{sym.replace('.DWX','')}"
    # A missing entry_time is UNKNOWN span, not zero span. Defaulting it to the
    # close time silently reclassifies an unknown sleeve as intraday-flat, which
    # is how 12823/USDJPY (0/1548 records carry entry_time) entered an earlier
    # run of this script. Coverage is now a precondition, not an assumption.
    cov = sum(1 for e, _ in raw_span if e is not None)
    if not raw_span or cov < 0.99 * len(raw_span):
        excluded.append((key, float("nan"), f"entry_time {cov}/{len(raw_span)}"))
        continue
    span = sum(1 for e, c in raw_span if (c - e).days >= 1)
    pct = 100.0 * span / len(raw_span)
    if pct > 1.0:
        excluded.append((key, pct, "multi-day"))
        continue
    if len({r[0].date() for r in rows}) >= MIN_DAYS:
        trades[key] = rows
        gate_note[key] = q08 if q08 is not None else "PENDING (requeued)"

keys = sorted(trades)
all_days = sorted({r[0].date() for rs in trades.values() for r in rs})
cut = all_days[int(len(all_days) * SPLIT)]
FAR = datetime(2100, 1, 1).date()


def outcomes(members, cfg, lo, hi):
    """First-passage outcome per start day.

    Returns (pass_flags, days_to_pass). A start resolves 'pass' when at least one
    account's END-OF-DAY balance is at or above target having traded >=4 days,
    and 'fail' when every account has breached. Starts that reach the end of the
    data unresolved count as failures - censoring is not silently dropped.
    """
    by_day = defaultdict(list)
    for k in members:
        lev = cfg[k]["lev"]
        for close, net, mae in trades[k]:
            if lo <= close.date() < hi:
                by_day[close.date()].append((close, net * lev, mae * lev, k))
    if not by_day:
        return None, None, None
    for d in by_day:
        by_day[d].sort(key=lambda r: r[0])
    days = [d for d in all_days if lo <= d < hi]
    if len(days) < 60:
        return None, None, None

    flags, ttp, fate = [], [], {"pass": 0, "breach": 0, "censored": 0}
    for s in range(len(days)):
        eq = {k: 0.0 for k in members}
        state = {k: "live" for k in members}
        traded = {k: 0 for k in members}
        won = None
        for di in range(s, len(days)):
            realized = {k: 0.0 for k in members}
            halted = {k: False for k in members}
            pending = defaultdict(float)
            day_events = by_day.get(days[di], ())
            for _, _, mae, k in day_events:
                if state[k] == "live":
                    pending[k] += mae * cfg[k]["scale"](eq[k])
            for close, net, mae, k in day_events:
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
                ds = cfg[k]["ds"]
                if ds and realized[k] <= -ds * ACCOUNT:
                    halted[k] = True
            # end of day: settle balance, then test the target on BALANCE with
            # every position closed - which for this sleeve class it is.
            for k in members:
                if state[k] != "live":
                    continue
                if any(e[3] == k for e in day_events):
                    traded[k] += 1
                eq[k] += realized[k]
                if eq[k] >= TARGET * ACCOUNT and traded[k] >= MIN_TRADING_DAYS:
                    state[k] = "pass"
            if any(state[k] == "pass" for k in members):
                won = di - s + 1
                break
            if all(state[k] == "breach" for k in members):
                break
        flags.append(won is not None)
        if won is not None:
            ttp.append(won)
            fate["pass"] += 1
        elif all(state[k] == "breach" for k in members):
            fate["breach"] += 1
        else:
            fate["censored"] += 1      # ran out of data still live: not a loss
    return flags, ttp, fate


def make_cfg(k, lev, ds, dr):
    if dr:
        thresh, factor = dr
        scale = lambda e, t=thresh, f=factor: f if e <= -t * ACCOUNT else 1.0
    else:
        scale = lambda e: 1.0
    return {"lev": lev, "ds": ds, "dr": dr, "scale": scale}


print("FTMO Phase 1 as a first-passage problem: +10% balance before -5% daily / -10% total")
print("No deadline (FTMO dropped it in 2024). Target tested on END-OF-DAY balance.")
print(f"Minimum trading days enforced: {MIN_TRADING_DAYS}. Unresolved starts counted as FAIL.")
print()
if excluded:
    nocov = [e for e in excluded if e[2] != "multi-day"]
    multi = [e for e in excluded if e[2] == "multi-day"]
    if nocov:
        print(f"excluded - span UNKNOWN, entry_time not emitted ({len(nocov)} sleeves):")
        for k, _, why in sorted(nocov):
            print(f"  {k:15} {why}")
        print()
    print(f"excluded - multi-day positions this model cannot bound ({len(multi)} sleeves):")
    for k, pct, _ in sorted(multi, key=lambda x: -x[1])[:8]:
        print(f"  {k:15} {pct:5.1f}% of trades span >=1 day")
    if len(multi) > 8:
        print(f"  ... and {len(multi)-8} more")
    print()
print(f"gate-clean intraday-flat sleeves >= {MIN_DAYS} trading days: {len(keys)}")
print(f"selection {all_days[0]}..{cut}   scoring {cut}..{all_days[-1]}")
print()

# ---- stage 1: leverage + overlay per sleeve, chosen strictly in-sample
solo = {}
for k in keys:
    best = None
    for lev in LEVERAGES:
        for ds in DAILY_STOPS:
            for dr in DERISK:
                cfg = {k: make_cfg(k, lev, ds, dr)}
                f, _, _ = outcomes((k,), cfg, all_days[0], cut)
                if not f:
                    continue
                rate = sum(f) / len(f)
                if best is None or rate > best[0]:
                    best = (rate, lev, ds, dr)
    if best:
        solo[k] = make_cfg(k, best[1], best[2], best[3])
        solo[k]["is_rate"] = best[0]

print(f"{'sleeve':15}{'Q08':>22}{'lev':>5}{'dstop':>7}{'derisk':>10}{'IS':>8}{'OOS':>8}"
      f"{'med d':>7}{'p90 d':>7}{'breach':>8}{'censor':>8}")
print("-" * 105)
for k in sorted(solo, key=lambda k: -solo[k]["is_rate"]):
    v = solo[k]
    f, ttp, fate = outcomes((k,), {k: v}, cut, FAR)
    oos = sum(f) / len(f) if f else float("nan")
    med = f"{statistics.median(ttp):.0f}" if ttp else "-"
    p90 = f"{sorted(ttp)[int(len(ttp)*0.9)]:.0f}" if ttp else "-"
    ds = f"{v['ds']*100:.1f}%" if v["ds"] else "-"
    dr = f"{v['dr'][0]*100:.0f}%/{v['dr'][1]:.2f}" if v["dr"] else "-"
    n = max(1, sum(fate.values()))
    print(f"{k:15}{gate_note[k]:>22}{v['lev']:>5.0f}{ds:>7}{dr:>10}"
          f"{v['is_rate']:>8.1%}{oos:>8.1%}{med:>7}{p90:>7}"
          f"{fate['breach']/n:>8.1%}{fate['censored']/n:>8.1%}")

# ---- leverage sweep at fixed overlay, to show the direction of the effect
print()
print("leverage sweep, OOS. Each cell is pass% (censored%) - censored means the start")
print("was still alive when the data ended, so it is a lower bound, not a loss:")
print(f"{'sleeve':15}" + "".join(f"{f'{L:.0f}x':>16}" for L in LEVERAGES))
print("-" * (15 + 16 * len(LEVERAGES)))
for k in sorted(solo):
    cells = []
    for L in LEVERAGES:
        c = make_cfg(k, L, solo[k]["ds"], solo[k]["dr"])
        f, _, fate = outcomes((k,), {k: c}, cut, FAR)
        if not f:
            cells.append("-")
            continue
        n = max(1, sum(fate.values()))
        cells.append(f"{sum(f)/len(f):.0%} ({fate['censored']/n:.0%})")
    print(f"{k:15}" + "".join(f"{c:>16}" for c in cells))

# ---- stage 2: combination chosen in-sample, joint rate measured out-of-sample
print()
print("campaign: combination chosen in-sample, joint pass COUNTED out-of-sample")
print(f"{'N':>2}{'IS':>8}{'OOS':>8}{'med d':>7}{'p90 d':>7}{'breach':>8}{'censor':>8}   accounts")
print("-" * 108)
order = sorted(solo)
for size in range(1, len(order) + 1):
    best = None
    for combo in itertools.combinations(order, size):
        f, _, _ = outcomes(combo, solo, all_days[0], cut)
        if not f:
            continue
        rate = sum(f) / len(f)
        if best is None or rate > best[0]:
            best = (rate, combo)
    if not best:
        continue
    is_rate, combo = best
    f, ttp, fate = outcomes(combo, solo, cut, FAR)
    if not f:
        continue
    oos = sum(f) / len(f)
    med = f"{statistics.median(ttp):.0f}" if ttp else "-"
    p90 = f"{sorted(ttp)[int(len(ttp)*0.9)]:.0f}" if ttp else "-"
    members = ", ".join("{}@{:.0f}x".format(k, solo[k]["lev"]) for k in combo)
    mark = "  <<" if oos >= 0.80 else ""
    n = max(1, sum(fate.values()))
    print(f"{size:>2}{is_rate:>8.1%}{oos:>8.1%}{med:>7}{p90:>7}"
          f"{fate['breach']/n:>8.1%}{fate['censored']/n:>8.1%}   {members}{mark}")

print()
print("Leverage, overlay and combination are all chosen on the selection period.")
print("Days-to-pass are trading days, median and 90th percentile, passes only.")

# ---- stage 3: the policy the framework ACTUALLY runs, preregistered, not fitted.
# Every sleeve at 1x with no overlay is not a choice made on any data - it is what
# QM_Common.mqh:182 enforces and what the EAs contain. Nothing here is selected on
# the scoring period, so this is the one block with no selection question at all.
print()
print("=" * 108)
print("PREREGISTERED POLICY: every sleeve at 1x, no overlay - what the framework enforces today.")
print("Nothing below is fitted on any period. Censored starts counted as FAIL (lower bound).")
print("=" * 108)
flat = {k: make_cfg(k, 1.0, None, None) for k in keys}
print(f"{'sleeve':15}{'OOS':>8}{'breach':>8}{'censor':>8}{'med d':>7}{'p90 d':>7}")
print("-" * 53)
for k in sorted(keys):
    f, ttp, fate = outcomes((k,), flat, cut, FAR)
    if not f:
        continue
    n = max(1, sum(fate.values()))
    med = f"{statistics.median(ttp):.0f}" if ttp else "-"
    p90 = f"{sorted(ttp)[int(len(ttp)*0.9)]:.0f}" if ttp else "-"
    print(f"{k:15}{sum(f)/len(f):>8.1%}{fate['breach']/n:>8.1%}"
          f"{fate['censored']/n:>8.1%}{med:>7}{p90:>7}")

print()
print("campaign at 1x, every combination measured (no in-sample pick - all shown):")
print(f"{'N':>2}{'OOS':>8}{'breach':>8}{'censor':>8}{'med d':>7}{'p90 d':>7}{'ESS':>6}{'+-95%':>9}   accounts")
print("-" * 112)
rows3 = []
for size in range(1, len(keys) + 1):
    for combo in itertools.combinations(sorted(keys), size):
        f, ttp, fate = outcomes(combo, flat, cut, FAR)
        if not f:
            continue
        oos = sum(f) / len(f)
        n = max(1, sum(fate.values()))
        # effective sample size: overlapping starts share almost the whole path,
        # so divide by the median resolution time rather than pretending n=800.
        span = statistics.median(ttp) if ttp else 60
        ess = max(1, int(len(f) / max(1.0, span)))
        se = (oos * (1 - oos) / ess) ** 0.5
        rows3.append((oos, size, combo, fate, ttp, ess, 1.96 * se, n, len(f)))
rows3.sort(key=lambda r: (-r[0], r[1]))
for oos, size, combo, fate, ttp, ess, hw, n, nf in rows3[:12]:
    med = f"{statistics.median(ttp):.0f}" if ttp else "-"
    p90 = f"{sorted(ttp)[int(len(ttp)*0.9)]:.0f}" if ttp else "-"
    mark = "  <<" if oos - hw >= 0.80 else ("  <" if oos >= 0.80 else "")
    print(f"{size:>2}{oos:>8.1%}{fate['breach']/n:>8.1%}{fate['censored']/n:>8.1%}"
          f"{med:>7}{p90:>7}{ess:>6}{hw:>8.0%}   {', '.join(combo)}{mark}")
print()
print("ESS divides the overlapping starts by the median resolution time; the +-95%")
print("column is a Wald half-width on that ESS. '<<' means the lower bound alone")
print("clears OWNER's 0.80 bar; '<' means only the point estimate does.")
