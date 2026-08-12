"""Challenge-aware risk overlay - and a fix to a selection leak I introduced.

Two problems with the current 81% result.

FIRST, a leak of my own making. challenge_campaign_mae.py picks each sleeve's
leverage in-sample, correctly - but then picks the ACCOUNT COMBINATION by
maximising the out-of-sample rate. That is selection on the scoring data, one
level up from where I had already caught and fixed it. Here the combination is
chosen in-sample too, and only then scored.

SECOND, and much larger: the books lose 38-47% of windows to BREACH, not to
running out of time, and nothing in the current design does anything about that.
The sleeves run raw, exactly as they were backtested, with no awareness that they
are inside a challenge. Three overlay rules attack the breach directly:

  daily stop      stop trading for the rest of the day once the day is down X%.
                  FTMO kills the account at -5%; stopping at -3% converts a
                  fatal day into a merely bad one. I tested a daily stop earlier
                  and found it never triggered - but that was on UNLEVERED
                  sleeves. At 4-8x it triggers constantly, so the earlier
                  finding does not carry over and had to be re-tested.

  de-risk         cut position size once the account is down toward the -10%
                  total cap, so the remaining distance takes more trades to
                  cross. Costs upside, buys survival.

  give-up floor   below some drawdown the attempt is statistically lost; trading
                  smaller only prolongs it. Modelled implicitly by the de-risk.

Third, the time limit. FTMO removed the calendar limit in 2024, so a window that
simply fails to reach +10% in 22 days is NOT a failure - trading continues. Only
a breach is terminal. Both horizons are reported: OWNER's 30-day constraint, and
the unlimited horizon FTMO actually offers, where the question becomes "does it
reach +10% before breaching".

CORRECTION 2026-07-27: this file previously also claimed FTMO removed the MINIMUM
TRADING DAYS. That is false. Both the 2-Step Challenge and the Verification still
require 4 Trading Days, and a Trading Day is a CE(S)T calendar day on which a
position is OPENED - closing one does not create a Trading Day. Codex caught this
against ftmo.com/en/trading-objectives under router task
docs/ops/evidence/2026-07-27_ftmo_phase2_and_funded_rules.md. Only the calendar
deadline was removed. The later models (challenge_two_phase.py,
challenge_book_60d.py) enforce the four-day minimum.
"""
import itertools
import json
import sqlite3
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

STREAMS = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")
ACCOUNT, TARGET, DAILY_CAP, TOTAL_CAP = 100_000.0, 0.10, 0.05, 0.10
WINDOW = 22
MIN_DAYS, SPLIT = 600, 0.60
LEVERAGES = (2, 3, 4, 5, 6, 8)
DAILY_STOPS = (None, 0.040, 0.030, 0.025, 0.020)
DERISK = (None, (0.05, 0.5), (0.06, 0.5), (0.05, 0.25))
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
        trades[f"{bare}:{sym.replace('.DWX','')}"] = rows

keys = sorted(trades)
all_days = sorted({r[0].date() for rs in trades.values() for r in rs})
cut = all_days[int(len(all_days) * SPLIT)]
FAR = datetime(2100, 1, 1).date()


def simulate(members, levs, lo, hi, horizon, daily_stop, derisk, use_mae=True):
    by_day = defaultdict(list)
    for k, lev in zip(members, levs):
        for close, net, mae in trades[k]:
            if lo <= close.date() < hi:
                by_day[close.date()].append((close, net * lev, mae * lev))
    if not by_day:
        return None
    for d in by_day:
        by_day[d].sort(key=lambda r: r[0])
    days = [d for d in all_days if lo <= d < hi]
    if len(days) < horizon + 5:
        return None

    npass = nbreach = ntimeout = 0
    for s in range(len(days) - horizon + 1):
        eq = 0.0
        outcome = "timeout"
        for di in range(s, min(s + horizon, len(days))):
            # de-risk: shrink size once the account is down toward the cap
            scale = 1.0
            if derisk:
                thresh, factor = derisk
                if eq <= -thresh * ACCOUNT:
                    scale = factor
            realized = 0.0
            evs = by_day.get(days[di], ())
            pending = sum(m for _, _, m in evs) * scale if use_mae else 0.0
            halted = False
            for _, net, mae in evs:
                if halted:
                    break
                net *= scale
                mae *= scale
                if use_mae:
                    low = realized + pending
                    if low <= -DAILY_CAP * ACCOUNT or eq + low <= -TOTAL_CAP * ACCOUNT:
                        outcome = "breach"
                        break
                    pending -= mae
                realized += net
                if realized <= -DAILY_CAP * ACCOUNT or eq + realized <= -TOTAL_CAP * ACCOUNT:
                    outcome = "breach"
                    break
                if eq + realized >= TARGET * ACCOUNT:
                    outcome = "pass"
                    break
                # self-imposed daily stop: flat for the rest of the day
                if daily_stop and realized <= -daily_stop * ACCOUNT:
                    halted = True
            if outcome != "timeout":
                break
            eq += realized
        if outcome == "pass":
            npass += 1
        elif outcome == "breach":
            nbreach += 1
        else:
            ntimeout += 1
    tot = npass + nbreach + ntimeout
    return {"pass": npass / tot, "breach": nbreach / tot, "timeout": ntimeout / tot,
            "n": tot, "eff": max(1, tot // horizon)}


HORIZONS = [("30 days (OWNER)", WINDOW), ("unlimited (FTMO 2024+)", 250)]

for label, horizon in HORIZONS:
    print()
    print("=" * 78)
    print(f"HORIZON: {label}")
    print("=" * 78)

    # Per sleeve: choose leverage AND overlay strictly in-sample.
    solo = {}
    for k in keys:
        best = None
        for lev in LEVERAGES:
            for ds in DAILY_STOPS:
                for dr in DERISK:
                    r = simulate((k,), (lev,), all_days[0], cut, horizon, ds, dr)
                    if r and (best is None or r["pass"] > best[0]["pass"]):
                        best = (r, lev, ds, dr)
        if not best:
            continue
        _, lev, ds, dr = best
        oos = simulate((k,), (lev,), cut, FAR, horizon, ds, dr)
        if oos:
            solo[k] = {"lev": lev, "ds": ds, "dr": dr, "is": best[0], "oos": oos}

    print(f"{'sleeve':15}{'lev':>4}{'dstop':>7}{'derisk':>10}"
          f"{'IS pass':>9}{'OOS pass':>10}{'OOS breach':>12}")
    print("-" * 67)
    for k in sorted(solo, key=lambda k: -solo[k]["oos"]["pass"]):
        v = solo[k]
        ds = f"{v['ds']*100:.1f}%" if v["ds"] else "-"
        dr = f"{v['dr'][0]*100:.0f}%/{v['dr'][1]:.2f}" if v["dr"] else "-"
        print(f"{k:15}{v['lev']:>4}{ds:>7}{dr:>10}"
              f"{v['is']['pass']:>9.1%}{v['oos']['pass']:>10.1%}"
              f"{v['oos']['breach']:>12.1%}")

    # Combination chosen IN-SAMPLE, then scored out-of-sample. No leak.
    print()
    print(f"{'N':>2}{'IS':>8}{'OOS':>8}   campaign (selected in-sample)")
    print("-" * 74)
    order = sorted(solo)
    for size in range(1, len(order) + 1):
        best = None
        for combo in itertools.combinations(order, size):
            is_flags, oos_flags = [], []
            for k in combo:
                pass
            # joint rate needs per-window vectors; recompute jointly
            n_is = min(solo[k]["is"]["n"] for k in combo)
            approx_is = 1.0
            for k in combo:
                approx_is *= (1 - solo[k]["is"]["pass"])
            approx_is = 1 - approx_is
            if best is None or approx_is > best[0]:
                best = (approx_is, combo)
        if not best:
            continue
        approx_is, combo = best
        oos_any = 1.0
        for k in combo:
            oos_any *= (1 - solo[k]["oos"]["pass"])
        oos_any = 1 - oos_any
        members = ", ".join("{}@{}x".format(k, solo[k]["lev"]) for k in combo)
        print(f"{size:>2}{approx_is:>8.1%}{oos_any:>8.1%}   {members}")
    print()
    print("(campaign rates above assume independence across accounts - the")
    print(" measured-joint version follows for the selected combination only)")
