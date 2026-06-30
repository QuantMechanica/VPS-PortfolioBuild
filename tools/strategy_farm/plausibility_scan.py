"""Plausibility guard: flag statistical-mirage / artifact EA streams before they
reach the book.

Q04 (net-of-cost walk-forward) passes look-ahead / broken-exit artifacts because
the defect is *consistent across folds* (it survives the walk-forward). Concrete
mirages found 2026-06-30: QM5_11180 maxLoss -$3 on 100k (no real stop, PF 240),
QM5_11179 USDJPY 0 losses / 36 trades. This scan catches that class on the Q08
trade streams (net-of-cost), so artifacts are quarantined before portfolio admission.

Verdicts (per ea_id:symbol stream):
  ARTIFACT (hard, auto-quarantine):
    - zero_loss      : 0 losing trades over >= MIN_TRADES
    - no_real_stop   : worst single loss < 0.10 x RISK_FIXED (stop never real)
    - absurd_pf      : net-of-cost PF > 50
  REVIEW (soft, human/Claude look):
    - hi_winrate     : winrate > 0.85 (>= 20 trades)
    - hi_pf          : net-of-cost PF > 10
    - small_stop     : worst loss < 0.30 x RISK_FIXED
    - neg_skew       : winrate > 0.70 and worst loss > 6 x avg loss (penny-collector)
  OK otherwise. Streams with < MIN_TRADES => INSUFFICIENT (not judged).

The quarantine list (ARTIFACT streams that have reached Q04+) is written to
plausibility_quarantine.json for portfolio_admission to exclude.

  python plausibility_scan.py                 # scan all streams, write reports
  python plausibility_scan.py --intraday-only
"""
from __future__ import annotations
import argparse, datetime as dt, json, re, sqlite3, statistics
from collections import defaultdict
from pathlib import Path

_PORT = Path(__file__).resolve().parent / "portfolio"
import sys
sys.path.insert(0, str(_PORT))
from commission import load_model  # type: ignore  # noqa: E402
from portfolio_common import load_streams, DEFAULT_COMMON_DIR, _coerce_ea_int  # type: ignore  # noqa: E402

DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
TESTER_DEFAULTS = Path(r"C:\QM\repo\framework\registry\tester_defaults.json")
REPORT = Path(r"D:\QM\reports\state\plausibility_scan.json")
QUARANTINE = Path(r"D:\QM\reports\state\plausibility_quarantine.json")
INTRADAY = re.compile(r"_(M1|M5|M15|M30)_|scalper|rapidfire|orb", re.I)
MIN_TRADES = 10
DEEP_PHASES = ("Q04", "Q05", "Q06", "Q07", "Q08", "Q09_PORTFOLIO")
PASSISH = ("PASS", "PASS_SOFT", "PASS_LOWFREQ", "FAIL_SOFT", "PASS_PORTFOLIO")


def q04plus_set() -> set[tuple[int, str]]:
    """ea_id,symbol that reached a pass-ish verdict at Q04+ (book-eligible)."""
    if not DB.exists():
        return set()
    c = sqlite3.connect(DB)
    ph = ",".join("?" for _ in DEEP_PHASES); vd = ",".join("?" for _ in PASSISH)
    rows = c.execute(
        f"SELECT DISTINCT ea_id, symbol FROM work_items WHERE phase IN ({ph}) "
        f"AND status='done' AND verdict IN ({vd})", (*DEEP_PHASES, *PASSISH)).fetchall()
    c.close()
    out = set()
    for ea, sym in rows:
        ea_int = _coerce_ea_int(ea)  # QM5_11180 -> 11180 (NOT the '5' in QM5)
        if ea_int is not None and sym:
            out.add((ea_int, str(sym)))
    return out


def classify(trades, risk: float):
    nets = [t.net_of_cost for t in trades]
    n = len(nets)
    if n < MIN_TRADES:
        return "INSUFFICIENT", [], {}
    wins = [x for x in nets if x > 0]; losses = [x for x in nets if x < 0]
    gp = sum(wins); gl = -sum(losses)
    pf = (gp / gl) if gl > 1e-9 else 999.0
    winrate = len(wins) / n
    worst = abs(min(nets)) if nets else 0.0
    avg_loss = abs(statistics.mean(losses)) if losses else 0.0
    comm_zero = sum(1 for t in trades if abs(t.commission_cost) < 1e-9) / n
    m = dict(trades=n, winrate=round(winrate, 3), pf_net=round(pf, 2),
             worst_loss=round(worst, 1), avg_loss=round(avg_loss, 1),
             net=round(sum(nets), 1), loss_count=len(losses), comm_zero_frac=round(comm_zero, 2))
    hard, soft = [], []
    if len(losses) == 0:
        hard.append("zero_loss")
    if worst < 0.10 * risk:
        hard.append("no_real_stop")
    if pf > 50:
        hard.append("absurd_pf")
    if not hard:
        if winrate > 0.85 and n >= 20:
            soft.append("hi_winrate")
        if pf > 10:
            soft.append("hi_pf")
        if worst < 0.30 * risk:
            soft.append("small_stop")
        if winrate > 0.70 and avg_loss > 0 and worst > 6 * avg_loss and pf > 3:
            soft.append("neg_skew")
    verdict = "ARTIFACT" if hard else ("REVIEW" if soft else "OK")
    return verdict, hard + soft, m


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--intraday-only", action="store_true")
    args = ap.parse_args(argv)
    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()

    td = json.load(open(TESTER_DEFAULTS))
    risk = float(td["fixed_risk"]["amount"])
    model = load_model()
    streams = load_streams(DEFAULT_COMMON_DIR, candidates=None, commission_model=model)
    q04plus = q04plus_set()

    results = []
    for (ea, sym), trades in streams.items():
        path_hint = f"{ea}_{sym}"
        if args.intraday_only and not INTRADAY.search(path_hint):
            continue
        verdict, flags, metrics = classify(trades, risk)
        reached = (ea, sym) in q04plus
        results.append(dict(ea_id=ea, symbol=sym, verdict=verdict, flags=flags,
                            reached_q04plus=reached, **metrics))

    by_v = defaultdict(int)
    for r in results:
        by_v[r["verdict"]] += 1
    # quarantine = ARTIFACT that reached Q04+ (book danger)
    quarantine = sorted(f"{r['ea_id']}:{r['symbol']}" for r in results
                        if r["verdict"] == "ARTIFACT" and r["reached_q04plus"])

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(dict(generated_at_utc=now, risk_fixed=risk,
                       counts=dict(by_v), n_quarantine=len(quarantine),
                       results=sorted(results, key=lambda r: (r["verdict"] != "ARTIFACT", not r["reached_q04plus"]))),
                       indent=2))
    QUARANTINE.write_text(json.dumps(dict(generated_at_utc=now, quarantine=quarantine), indent=2))

    print(f"[{now}] scanned {len(results)} streams (risk_fixed=${risk:.0f})")
    print(f"  verdicts: {dict(by_v)}")
    print(f"  quarantine (ARTIFACT reaching Q04+): {len(quarantine)}")
    print("\n=== ARTIFACTS that reached Q04+ (book danger) ===")
    arts = [r for r in results if r["verdict"] == "ARTIFACT" and r["reached_q04plus"]]
    for r in sorted(arts, key=lambda r: -r["pf_net"]):
        print(f"  {r['ea_id']}:{r['symbol']:14} {','.join(r['flags']):24} "
              f"wr={r['winrate']:.2f} pf={r['pf_net']:.1f} worstLoss=${r['worst_loss']:.0f} n={r['trades']}")
    print("\n=== REVIEW that reached Q04+ (top 15 by PF) ===")
    revs = [r for r in results if r["verdict"] == "REVIEW" and r["reached_q04plus"]]
    for r in sorted(revs, key=lambda r: -r["pf_net"])[:15]:
        print(f"  {r['ea_id']}:{r['symbol']:14} {','.join(r['flags']):28} "
              f"wr={r['winrate']:.2f} pf={r['pf_net']:.1f} worstLoss=${r['worst_loss']:.0f} net=${r['net']:.0f} n={r['trades']}")
    print(f"\nreport: {REPORT}\nquarantine: {QUARANTINE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
