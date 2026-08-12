"""Dormancy exposure for the 60/30 challenge book.

Companion measurement to challenge_book_60d.py, isolating ONE failure mode:
FTMO's dormancy block, which OWNER directed (2026-07-27) we treat as FIXED and
binding at "30 calendar days with no trade = account blocked". The threshold is
NOT an officially published FTMO rule; it must never be cited as one. See the
design write-up docs/ops/evidence/2026-07-27_dormancy_handling_design.md.

For every gate-clean sleeve (same gate + entry_time-coverage + MIN_DAYS pool as
challenge_book_60d.py) this computes:

  - the distribution of gaps between consecutive TRADING days, and
  - P(a fully-observable 60-calendar-day Phase-1 window contains a >30d idle
    trigger), scored day-by-day exactly as challenge_book_60d.phase() does.

Trading-day calendar, three interpretations, because FTMO's wording for what
resets the clock is unknown:

  OPEN   only a new position OPEN resets the clock (holding/closing do not).
         CONSERVATIVE and internally consistent with FTMO's published rule that
         a "Trading Day" for the 4-day minimum requires a position OPENED.
  CLOSE  only a close resets the clock (reference).
  ACTIVE any day a position is held resets the clock (the lenient model
         challenge_book_60d.py itself simulates via its `active` set).

The finding is that these agree to within noise on the current pool: dangerous
sleeves are dangerous under every interpretation and safe sleeves are safe under
every interpretation, so adopting the conservative OPEN model costs ~nothing.

Read-only against farm_state.sqlite and the sleeve streams. Writes nothing.
"""
import json
import sqlite3
import statistics
from collections import defaultdict
from datetime import datetime, timezone, timedelta
from pathlib import Path

STREAMS = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")
MIN_DAYS = 250            # same close-day floor as challenge_book_60d.py
DORMANCY_DAYS = 30        # OWNER-fixed, NOT an official FTMO number
D1 = 60                   # Phase-1 KPI window, calendar days
BUFFER_SAFE = 6           # >=6 calendar-day margin below 30 -> "SAFE", else THIN
EARLY_OK = {"PASS", "PASS_SOFT", "PASS_LOWFREQ"}
Q08_OK = {"PASS", "PASS_SOFT", "MULTI_SEED_PASS", "FAIL_SOFT"}


def parse_ts(v):
    if isinstance(v, (int, float)):
        try:
            return datetime.fromtimestamp(float(v), tz=timezone.utc)
        except Exception:
            return None
    return None


def load_gate_clean():
    con = sqlite3.connect(
        "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro", uri=True)
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
                entry = parse_ts(r.get("entry_time"))
                n += 1
                if entry is not None:
                    cov += 1
                ev.append((entry.date() if entry else close.date(), close.date()))
        if not n or cov < 0.99 * n:
            continue
        if len({c for _, c in ev}) < MIN_DAYS:
            continue
        key = f"{bare}:{sym.replace('.DWX', '')}"
        sleeves[key] = ev
        multi_pct[key] = 100.0 * sum(1 for e, c in ev if (c - e).days >= 1) / len(ev)
    return sleeves, multi_pct


def gap_stats(day_set):
    days = sorted(day_set)
    gaps = sorted((days[i + 1] - days[i]).days for i in range(len(days) - 1))
    if not gaps:
        return None

    def pct(p):
        return gaps[min(len(gaps) - 1, int(p * len(gaps)))]

    return {"n_td": len(days), "median": statistics.median(gaps),
            "p90": pct(0.90), "p95": pct(0.95), "max": max(gaps),
            "n_over_30": sum(1 for g in gaps if g > DORMANCY_DAYS)}


def dormancy_prob(day_set):
    """P(a fully-observable 60d window from each trading day hits a >30d idle).

    Faithful to challenge_book_60d.phase(): walk calendar days, expire at >60,
    dormant at >30 since the last trading day, reset on each trading day. Starts
    whose 60d forward span runs past the last observed trading day are skipped:
    "no trade after data ends" is a boundary artifact, not a real gap, so a
    sleeve whose max real gap <= 30 scores exactly 0.
    """
    days = sorted(day_set)
    ds = set(days)
    horizon = days[-1]
    hits = evaluated = 0
    for s in days:
        if (horizon - s).days < D1:
            continue
        evaluated += 1
        last = s
        for off in range(0, D1 + 1):
            day = s + timedelta(days=off)
            if (day - last).days > DORMANCY_DAYS:
                hits += 1
                break
            if day in ds:
                last = day
    return hits / evaluated if evaluated else 0.0


def active_set(ev):
    """Book's lenient model: every day a position is held (entry..close) resets."""
    s = set()
    for e, c in ev:
        d = e
        while d <= c:
            s.add(d)
            d += timedelta(days=1)
    return s


def main():
    sleeves, multi_pct = load_gate_clean()
    rows = []
    for k in sorted(sleeves):
        ev = sleeves[k]
        go = gap_stats({e for e, c in ev})
        pc = dormancy_prob({c for e, c in ev})
        po = dormancy_prob({e for e, c in ev})
        pa = dormancy_prob(active_set(ev))
        rows.append((k, multi_pct[k], go, po, pc, pa))
    rows.sort(key=lambda r: (r[2]["max"], r[3]))

    print(f"gate-clean pool: {len(rows)} sleeves  "
          f"(gates + entry_time cov>=99% + >={MIN_DAYS} close-days)")
    print(f"dormancy threshold {DORMANCY_DAYS}d (OWNER-fixed), "
          f"Phase-1 window {D1} calendar days\n")
    hdr = (f"{'sleeve':16}{'multi%':>7}{'n_td':>6}{'med':>5}{'p90':>5}{'p95':>5}"
           f"{'max':>5}{'buf':>5}{'>30':>5}{'P60_O':>8}{'P60_C':>8}{'P60_A':>8}   verdict")
    print(hdr)
    print("-" * len(hdr))
    for k, mp, go, po, pc, pa in rows:
        buf = DORMANCY_DAYS - go["max"]
        if go["max"] <= DORMANCY_DAYS and po == 0.0:
            verdict = "SAFE" if buf >= BUFFER_SAFE else "SAFE-THIN"
        elif po <= 0.02:
            verdict = "MARGINAL"
        else:
            verdict = "DISQUALIFIED"
        print(f"{k:16}{mp:>6.0f}%{go['n_td']:>6}{go['median']:>5.0f}{go['p90']:>5.0f}"
              f"{go['p95']:>5.0f}{go['max']:>5.0f}{buf:>5}{go['n_over_30']:>5}"
              f"{po:>8.1%}{pc:>8.1%}{pa:>8.1%}   {verdict}")
    print("\nO/C/A = OPEN (conservative) / CLOSE / ACTIVE(book-lenient) trading calendars")
    print("buf = 30 - max historical open-to-open gap (calendar-day safety margin)")
    print("P60 = P(a fully-observable 60-day window contains a >30d idle trigger)")


if __name__ == "__main__":
    main()
