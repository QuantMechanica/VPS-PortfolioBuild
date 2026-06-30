"""Per-survivor trade-return SKEW — pyramiding-candidate selector.

Pyramiding (add-to-winners) helps POSITIVE-skew trend/momentum edges (fat right
tail) and HURTS negative-skew mean-reversion (small frequent wins, rare big loss).
This scans the survivor set (EAs that reached Q04+ with a pass-ish verdict) and
ranks them by per-trade net-of-cost skew so we only overlay pyramiding where it
can actually help. Excludes plausibility-quarantine artifacts.

  CANDIDATE  (pyramide): skew >= +0.5 AND payoff(avgWin/|avgLoss|) >= 1.5
  STRONG               : skew >= +1.0 AND payoff >= 2.0
  AVOID (MR)           : skew <= 0  OR (winrate > 0.6 AND payoff < 1.0)

  python survivor_skew.py
"""
from __future__ import annotations
import csv, json, re, sqlite3, statistics, sys
from pathlib import Path

_PORT = Path(__file__).resolve().parent
sys.path.insert(0, str(_PORT))
from commission import load_model  # type: ignore  # noqa: E402
from portfolio_common import load_streams, DEFAULT_COMMON_DIR, _coerce_ea_int  # type: ignore  # noqa: E402

DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
REG = Path(r"C:\QM\repo\framework\registry\ea_id_registry.csv")
QUAR = Path(r"D:\QM\reports\state\plausibility_quarantine.json")
DEEP = ("Q04", "Q05", "Q06", "Q07", "Q08", "Q09_PORTFOLIO")
PASSISH = ("PASS", "PASS_SOFT", "PASS_LOWFREQ", "FAIL_SOFT", "PASS_PORTFOLIO")
MIN_N = 20
# the 13 live book sleeves
BOOK = {(10440,"NDX.DWX"),(10513,"XAUUSD.DWX"),(10692,"NDX.DWX"),(10715,"USDJPY.DWX"),
    (10911,"GDAXI.DWX"),(10939,"GBPUSD.DWX"),(10940,"XAUUSD.DWX"),(11132,"SP500.DWX"),
    (11165,"AUDCAD.DWX"),(11421,"AUDUSD.DWX"),(11421,"EURUSD.DWX"),(12567,"XAUUSD.DWX"),(12567,"XNGUSD.DWX")}


def skew(xs):
    n = len(xs)
    if n < 3:
        return 0.0
    m = sum(xs) / n
    sd = (sum((x - m) ** 2 for x in xs) / n) ** 0.5
    if sd == 0:
        return 0.0
    return (sum((x - m) ** 3 for x in xs) / n) / sd ** 3


def survivors():
    c = sqlite3.connect(DB)
    ph = ",".join("?" for _ in DEEP); vd = ",".join("?" for _ in PASSISH)
    rows = c.execute(f"SELECT DISTINCT ea_id,symbol FROM work_items WHERE phase IN ({ph}) "
                     f"AND status='done' AND verdict IN ({vd})", (*DEEP, *PASSISH)).fetchall()
    c.close()
    out = set()
    for ea, sym in rows:
        e = _coerce_ea_int(ea)
        if e is not None and sym:
            out.add((e, str(sym)))
    return out


def main() -> int:
    slug = {}
    if REG.exists():
        for r in csv.reader(open(REG)):
            if len(r) >= 2 and r[0].strip().isdigit():
                slug[int(r[0])] = r[1]
    quar = set()
    if QUAR.exists():
        for lbl in json.loads(QUAR.read_text()).get("quarantine", []):
            ea, _, sym = str(lbl).partition(":")
            if ea.isdigit():
                quar.add((int(ea), sym))

    surv = survivors()
    model = load_model()
    streams = load_streams(DEFAULT_COMMON_DIR, candidates=sorted(surv), commission_model=model)

    rows = []
    for key, trades in streams.items():
        if key in quar:
            continue
        nets = [t.net_of_cost for t in trades]
        if len(nets) < MIN_N:
            continue
        wins = [x for x in nets if x > 0]; losses = [x for x in nets if x < 0]
        payoff = (statistics.mean(wins) / abs(statistics.mean(losses))) if wins and losses else 99.0
        wr = len(wins) / len(nets)
        sk = skew(nets)
        if sk >= 1.0 and payoff >= 2.0:
            cls = "STRONG"
        elif sk >= 0.5 and payoff >= 1.5:
            cls = "CANDIDATE"
        elif sk <= 0 or (wr > 0.6 and payoff < 1.0):
            cls = "AVOID(MR)"
        else:
            cls = "neutral"
        rows.append(dict(ea=key[0], sym=key[1], slug=slug.get(key[0], "?"), n=len(nets),
                         skew=round(sk, 2), payoff=round(payoff, 2), wr=round(wr, 2),
                         cls=cls, book=key in BOOK, lowN=len(nets) < 30))

    rows.sort(key=lambda r: -r["skew"])
    cand = [r for r in rows if r["cls"] in ("STRONG", "CANDIDATE")]
    print(f"survivors scanned (n>={MIN_N}, ex-quarantine): {len(rows)}")
    print(f"pyramiding candidates (STRONG+CANDIDATE): {len(cand)}\n")
    print(f"{'ea':>6} {'symbol':12} {'slug':32} {'n':>4} {'skew':>6} {'payoff':>7} {'wr':>5} {'class':10} {'book':4}")
    for r in rows:
        b = "BOOK" if r["book"] else ""
        ln = "*" if r["lowN"] else " "
        print(f"{r['ea']:>6} {r['sym']:12} {r['slug'][:32]:32} {r['n']:>4}{ln}{r['skew']:>6} {r['payoff']:>7} {r['wr']:>5} {r['cls']:10} {b:4}")
    print("\n* = n<30 (skew low-confidence)")
    print("\n=== TOP pyramiding candidates ===")
    for r in cand[:15]:
        print(f"  {r['ea']}:{r['sym']:12} {r['slug'][:34]:34} skew={r['skew']:+.2f} payoff={r['payoff']:.2f} {'BOOK' if r['book'] else ''}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
