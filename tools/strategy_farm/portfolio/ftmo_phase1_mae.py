"""FTMO Phase-1 pass/fail probability with intraday-DD (MAE) reconstruction.

The closed-daily prop_challenge_sim can't model the 5%/day + 10%/max limits because
those are INTRADAY equity events (docs: q08-stream reimpl was 4.5x off). This tool
uses the fresh-format q08 streams that carry, per trade, entry_time + mae_acct
(worst floating loss in account currency) and reconstructs a CONSERVATIVE intraday
worst-equity path:

  - each trade is "open" over [entry_day, close_day]; its worst floating = mae_acct
  - open_mae[day] = sum of mae_acct of every trade spanning that day (worst-case: all
    positions simultaneously at their MAE) -> conservative LOWER bound on pass rate
  - equity_low[day] = running realized balance at day-start + open_mae[day]
  - daily breach if the day's dip exceeds 5% of start-of-day equity
  - max breach if equity_low ever <= 90% of 100k
  - pass if realized balance reaches +10% before any breach

Block-bootstrap over calendar days gives P(pass) for a given horizon. Scale per sleeve
= deployment RISK_FIXED / q08 base (inferred per stream from the stop-loss cluster).
Stufe-2 (exact) would need per-bar portfolio equity; this is the conservative Stufe-1.
"""
from __future__ import annotations
import json, glob, os, re, random, collections, statistics, datetime as dt, argparse
from pathlib import Path

Q08 = Path(r"C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/Common/Files/QM/q08_trades")
FDIR = Path(r"C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/81A933A9AFC5DE3C23B15CAB19C63850/MQL5/Presets")
START = 100_000.0
DAILY_LIMIT = 0.05 * START
MAXLOSS_FLOOR = START * (1 - 0.10)
TARGET = START * 1.10
SYMMAP = {"US100": "NDX", "GER40": "GDAXI", "USOIL": "XTIUSD"}


def load_ftmo_book():
    """Return {(ea,symdwx): {'risk_fixed':.., 'tf':..}} from FTMO set files."""
    book = {}
    for f in glob.glob(str(FDIR / "*.set")):
        n = os.path.basename(f)
        raw = open(f, 'rb').read(); txt = raw.decode('utf-16-le', 'ignore') if b'\x00' in raw[:40] else raw.decode('utf-8', 'ignore')
        rf = re.search(r'^RISK_FIXED\s*=\s*([0-9.]+)', txt, re.M)
        ea = re.search(r'QM5_(\d+)', n); sy = re.search(r'r25p1_([A-Za-z0-9.]+)_([HDM]\d+)', n)
        if rf and ea and sy:
            symtok = sy.group(1).replace('.cash', '')
            symdwx = SYMMAP.get(symtok, symtok) + ".DWX"
            book[(int(ea.group(1)), symdwx)] = {"risk_fixed": float(rf.group(1)), "tf": sy.group(2)}
    return book


def load_trades(ea, sym):
    p = Q08 / f"{ea}_{sym.replace('.', '_')}.jsonl"
    if not p.exists():
        return None, False
    rows = []
    fresh = False
    for line in open(p, encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        try:
            o = json.loads(line)
        except Exception:
            continue
        if "mae_acct" in o and "entry_time" in o:
            fresh = True
        rows.append(o)
    return rows, fresh


def infer_base_risk(rows):
    """q08 RISK_FIXED base ~ the stop-loss cluster: use the 20th percentile of losing
    net (a full stop-out ~ -risk). Fallback 1000."""
    losses = sorted(abs(r["net"]) for r in rows if r.get("net", 0) < 0)
    if len(losses) >= 20:
        return statistics.median(losses[int(len(losses) * 0.5):])  # upper-half median of losses
    return 1000.0


def build_daily(book):
    """Return sorted calendar days + realized[day] + open_mae[day] at deployment scale."""
    realized = collections.defaultdict(float)
    open_mae = collections.defaultdict(float)
    loaded, stale = [], []
    for (ea, sym), meta in book.items():
        rows, fresh = load_trades(ea, sym)
        if rows is None or not fresh:
            stale.append((ea, sym)); continue
        loaded.append((ea, sym))
        base = infer_base_risk(rows)
        scale = meta["risk_fixed"] / base if base > 0 else 0.0
        for r in rows:
            net = r["net"] * scale
            mae = min(0.0, r.get("mae_acct", 0.0)) * scale
            cday = dt.datetime.fromtimestamp(r["time"], tz=dt.UTC).date()
            eday = dt.datetime.fromtimestamp(r.get("entry_time", r["time"]), tz=dt.UTC).date()
            realized[cday] += net
            d = eday
            while d <= cday:
                open_mae[d] += mae
                d += dt.timedelta(days=1)
    days = sorted(set(realized) | set(open_mae))
    return days, realized, open_mae, loaded, stale


def evaluate_window(seq):
    """seq = list of (realized, open_mae) tuples for consecutive days. Returns reason."""
    bal = START
    for i, (rz, om) in enumerate(seq, 1):
        day_low = bal + om          # worst intraday before this day's closes realize
        if bal - day_low >= DAILY_LIMIT:      # >5% intraday drop from day-start
            return "daily_breach"
        if day_low <= MAXLOSS_FLOOR:          # >10% below start
            return "max_breach"
        bal += rz
        if bal >= TARGET and i >= 4:
            return "passed"
    return "not_reached"


def bootstrap(pairs, horizon, block, runs, seed):
    rng = random.Random(seed); c = collections.Counter()
    n = len(pairs)
    for _ in range(runs):
        seq = []
        while len(seq) < horizon:
            s = rng.randrange(n)
            for o in range(block):
                seq.append(pairs[(s + o) % n])
                if len(seq) == horizon:
                    break
        c[evaluate_window(seq)] += 1
    return c


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=8000)
    ap.add_argument("--block", type=int, default=5)
    args = ap.parse_args()
    book = load_ftmo_book()
    print(f"FTMO book: {len(book)} sleeves")
    days, realized, open_mae, loaded, stale = build_daily(book)
    print(f"loaded (fresh MAE): {len(loaded)}  |  stale (need re-run): {len(stale)} -> {stale}")
    if not days:
        print("no fresh streams yet"); return
    pairs = [(realized.get(d, 0.0), open_mae.get(d, 0.0)) for d in days]
    tot = sum(realized.values())
    print(f"calendar days {len(days)} ({days[0]}..{days[-1]}), total realized {tot:,.0f} "
          f"(~{tot/START*100:.1f}% of 100k), worst open_mae day {min(open_mae.values()):,.0f}")
    if len(loaded) < len(book):
        print(f"\n[PARTIAL BOOK — {len(loaded)}/{len(book)} sleeves; mechanics test only, not the final number]")
    for h in (30, 60):
        c = bootstrap(pairs, h, args.block, args.runs, 7)
        n = sum(c.values())
        print(f"  horizon {h:3d}d: PASS {c['passed']/n*100:5.1f}%  FAIL {(n-c['passed'])/n*100:5.1f}% "
              f"(daily {c['daily_breach']/n*100:.1f}%, max {c['max_breach']/n*100:.1f}%, not-reached {c['not_reached']/n*100:.1f}%)")


if __name__ == "__main__":
    main()
