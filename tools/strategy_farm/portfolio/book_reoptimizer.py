"""Whole-book re-optimizer (OWNER 2026-07-15: "alles was durch Q08 geht bezweckt eine
komplette Neubewertung des Buches").

On demand (and wired to run when a new EA passes Q08), re-evaluates the ENTIRE book:
takes the current live sleeves + all Q08-survivor candidates, and greedily builds the
Sharpe-optimal sleeve SELECTION, starting from the current book. Reports the recommended
ADD / SWAP moves as a diff vs the live book. Sizing (1% cap, tail<=20%, scale to ~10% DD)
is a SEPARATE downstream step (book_resize) — Sharpe selection is scale-invariant, so the
two are decoupled.

Pairwise correlation is ADVISORY (OWNER-DEC-CBE-20260915 sections 8/68B): the fixed 0.50
cutoff is no longer a hard exclusion. High-correlation admissions are admitted and surfaced
as ``correlation_warnings`` plus a ``dependence_panel`` in the emitted ``risk_diagnostics``
block (the same structure the book builders emit), never silently dropped (section 70).
``--max-corr`` is the advisory reference used to flag warnings; ``--hard-max-corr`` is an
opt-in hard pairwise-correlation cut for explicit experiments only (default: no hard cut).

NEVER auto-changes the live book — output is an OWNER decision package.

CLI:
  python -m tools.strategy_farm.portfolio.book_reoptimizer --out <path> \
      [--max-corr 0.5] [--hard-max-corr 0.7]
"""
from __future__ import annotations
import argparse, json, sys, sqlite3, math
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
    from tools.strategy_farm.portfolio.portfolio_common import load_streams, to_daily_pnl, DEFAULT_COMMON_DIR
    from tools.strategy_farm.portfolio.commission import load_model
    from tools.strategy_farm.portfolio import risk_diagnostics, portfolio_correlation
    from tools.strategy_farm.sqlite_timestamp import normalized_timestamp_sql
else:
    from .portfolio_common import load_streams, to_daily_pnl, DEFAULT_COMMON_DIR
    from .commission import load_model
    from . import risk_diagnostics, portfolio_correlation
    from ..sqlite_timestamp import normalized_timestamp_sql

UPDATED_AT_SQL = normalized_timestamp_sql("updated_at")

DB = r"D:\QM\strategy_farm\state\farm_state.sqlite"
LIVE_BOOK = [(1556,"XAUUSD.DWX"),(10403,"XAUUSD.DWX"),(10440,"NDX.DWX"),(10476,"USDCAD.DWX"),
    (10513,"XAUUSD.DWX"),(10692,"NDX.DWX"),(10706,"GBPUSD.DWX"),(10715,"USDJPY.DWX"),
    (10911,"GDAXI.DWX"),(10919,"XTIUSD.DWX"),(10939,"GBPUSD.DWX"),(11132,"SP500.DWX"),
    (11165,"AUDCAD.DWX"),(11165,"EURUSD.DWX"),(11421,"AUDUSD.DWX"),(11421,"EURUSD.DWX"),
    (11708,"EURUSD.DWX"),(12567,"XAUUSD.DWX"),(12567,"XNGUSD.DWX"),(12778,"AUDUSD.DWX"),
    (12969,"USDJPY.DWX"),(12989,"XAUUSD.DWX"),(13128,"NDX.DWX")]

def q08_survivor_pool(since="2026-07-01"):
    con = sqlite3.connect(DB); con.row_factory = sqlite3.Row
    rows = con.execute("SELECT DISTINCT ea_id,symbol FROM work_items WHERE phase='Q09_PORTFOLIO' "
                       f"AND {UPDATED_AT_SQL}>=datetime(?) AND status='done'", (since,)).fetchall()
    out = []
    for r in rows:
        m = r["ea_id"].replace("QM5_", "")
        try: out.append((int(m), r["symbol"]))
        except ValueError: pass
    return out

def _series(streams, key, all_days):
    dp = to_daily_pnl(streams[key]) if key in streams else {}
    return [dp.get(d, 0.0) for d in all_days]

def _sharpe_dd(book_daily):
    n = len(book_daily)
    if n < 20: return None, None
    mean = sum(book_daily)/n
    var = sum((v-mean)**2 for v in book_daily)/(n-1)
    if var <= 0: return None, None
    sharpe = mean/(var**0.5)*(252**0.5)
    eq=peak=mdd=0.0
    for v in book_daily:
        eq+=v; peak=max(peak,eq); mdd=min(mdd,eq-peak)
    return sharpe, abs(mdd)/100000*100

def _invvol_book_daily(keys, series_by_key, all_days):
    invv = {}
    for k in keys:
        s = series_by_key[k]; nz=[x for x in s if x!=0]
        if len(nz) < 5: invv[k]=0.0; continue
        m=sum(s)/len(s); var=sum((x-m)**2 for x in s)/(len(s)-1)
        invv[k] = 1.0/(var**0.5) if var>0 else 0.0
    tot=sum(invv.values()) or 1.0
    w={k:invv[k]/tot for k in keys}
    return [sum(series_by_key[k][i]*w[k] for k in keys) for i in range(len(all_days))]

def _pearson(a,b):
    co=[(x,y) for x,y in zip(a,b) if x!=0 or y!=0]
    if len(co)<30: return None
    xs=[x for x,_ in co]; ys=[y for _,y in co]
    mx=sum(xs)/len(xs); my=sum(ys)/len(ys)
    num=sum((x-mx)*(y-my) for x,y in co)
    dx=(sum((x-mx)**2 for x in xs))**0.5; dy=(sum((y-my)**2 for y in ys))**0.5
    if dx==0 or dy==0: return None
    return num/(dx*dy)


def correlation_hard_block(cand, book, series, hard_max_corr):
    """Opt-in hard pairwise-correlation exclusion for explicit experiments only.

    Returns True iff ``hard_max_corr`` is set (not None) and the candidate's worst
    absolute measured correlation against an incumbent exceeds it. When
    ``hard_max_corr`` is None (the default) correlation is ADVISORY and this never
    excludes a candidate (OWNER-DEC-CBE-20260915 sections 8/68B).
    """
    if hard_max_corr is None:
        return False
    for m in book:
        r = _pearson(series[cand], series[m])
        if r is not None and abs(r) > hard_max_corr:
            return True
    return False


def build_correlation_diagnostics(book, series, reference):
    """Advisory correlation warnings + dependence panel for a book (no exclusion).

    Mirrors the ``correlation_warnings`` / ``dependence_panel`` structure emitted by
    ``build_book_ftmo.select_under_aggregate_control`` so the reoptimizer's advisory
    correlation view is rendered in the same shape (section 70: never a silent no-op).
    A pair whose measured |r| reaches ``reference`` is admitted-with-WARN.
    """
    final = sorted(book)
    correlation_warnings: list[dict] = []
    dependence_panel: list[dict] = []
    for i in range(len(final)):
        for j in range(i + 1, len(final)):
            r = _pearson(series[final[i]], series[final[j]])
            a = f"{final[i][0]}:{final[i][1]}"
            b = f"{final[j][0]}:{final[j][1]}"
            dependence_panel.append(
                portfolio_correlation.dependence_panel_entry(
                    a, b, pairwise_correlation=r, reference=reference
                )
            )
            if r is not None and abs(r) >= reference:
                correlation_warnings.append({
                    "a": a,
                    "b": b,
                    "correlation": round(abs(r), 8),
                    "signed_correlation": round(r, 8),
                    "threshold": reference,
                    "severity": "WARN",
                    "superseded_hard_cap": risk_diagnostics.SUPERSEDING_DECISION,
                })
    return correlation_warnings, dependence_panel


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--out", default=r"D:\QM\reports\book_reopt\reopt.json")
    ap.add_argument("--max-corr", type=float, default=0.50,
                    help="Advisory pairwise-correlation reference (flags warnings; does NOT exclude).")
    ap.add_argument("--hard-max-corr", type=float, default=None,
                    help="Opt-in HARD pairwise-correlation cut for explicit experiments only "
                         "(default: none - correlation is advisory).")
    ap.add_argument("--since", default="2026-07-01")
    args=ap.parse_args()
    pool = q08_survivor_pool(args.since)
    universe = sorted(set(LIVE_BOOK) | set(pool))
    model=load_model()
    streams=load_streams(DEFAULT_COMMON_DIR, candidates=[(str(e),s) for e,s in universe], commission_model=model)
    keymap={}
    for (e,s) in universe:
        for k in streams:
            if str(k[0])==str(e) and k[1]==s: keymap[(e,s)]=k
    universe=[k for k in universe if k in keymap]
    all_days=sorted({d for (e,s) in universe for d in to_daily_pnl(streams[keymap[(e,s)]])})
    series={k:_series(streams,keymap[k],all_days) for k in universe}
    book=[k for k in LIVE_BOOK if k in keymap]
    pool_only=[k for k in universe if k not in book]

    cur_sh, cur_dd = _sharpe_dd(_invvol_book_daily(book, series, all_days))
    base_sh, base_dd = cur_sh, cur_dd
    moves=[]
    for _ in range(30):
        best=None
        # ADD moves. Correlation is advisory: a candidate is excluded only when the
        # opt-in --hard-max-corr experiment flag is set (OWNER-DEC-CBE-20260915 s8).
        for c in pool_only:
            if c in book: continue
            if correlation_hard_block(c, book, series, args.hard_max_corr): continue
            sh,dd=_sharpe_dd(_invvol_book_daily(book+[c], series, all_days))
            if sh and sh>cur_sh+1e-4 and (best is None or sh>best[1]):
                best=("ADD", sh, dd, c, None)
        # SWAP moves: candidate replaces the weakest incumbent (by standalone sharpe)
        inc_sh=sorted(book, key=lambda k:(_sharpe_dd([x for x in series[k]])[0] or -9))
        weakest=inc_sh[0] if inc_sh else None
        if weakest:
            for c in pool_only:
                if c in book: continue
                newbook=[k for k in book if k!=weakest]+[c]
                if correlation_hard_block(c, [k for k in book if k!=weakest], series, args.hard_max_corr): continue
                sh,dd=_sharpe_dd(_invvol_book_daily(newbook, series, all_days))
                if sh and sh>cur_sh+1e-4 and (best is None or sh>best[1]):
                    best=("SWAP", sh, dd, c, weakest)
        if best is None: break
        kind,sh,dd,c,drop=best
        if kind=="ADD": book=book+[c]
        else: book=[k for k in book if k!=drop]+[c]
        pool_only=[k for k in pool_only if k!=c]
        moves.append({"move":kind,"add":f"{c[0]}:{c[1]}","drop":(f"{drop[0]}:{drop[1]}" if drop else None),
                      "book_sharpe":round(sh,3),"book_maxdd_%":round(dd,3)})
        cur_sh,cur_dd=sh,dd

    # Advisory correlation view of the reoptimized book (never a silent no-op, s70).
    correlation_warnings, dependence_panel = build_correlation_diagnostics(
        book, series, args.max_corr)
    diagnostics = risk_diagnostics.build(
        {},  # the reoptimizer computes no concentration-cap evaluation here
        dependence_panel=dependence_panel,
        correlation_warnings=correlation_warnings,
    )
    out={"as_of_pool_since":args.since,"universe":len(universe),"pool_q08_survivors":len(pool),
         "correlation_policy":{"max_corr_advisory_reference":args.max_corr,
                               "hard_max_corr":args.hard_max_corr,
                               "note":("ADVISORY: pairwise correlation flags warnings and never "
                                       "excludes unless --hard-max-corr is set "
                                       f"({risk_diagnostics.SUPERSEDING_DECISION} s8).")},
         "current_book":{"n":len([k for k in LIVE_BOOK if k in keymap]),"sharpe":round(base_sh,3),"maxdd_%":round(base_dd,3)},
         "reoptimized_book":{"n":len(book),"sharpe":round(cur_sh,3),"maxdd_%":round(cur_dd,3),
                             "sleeves":[f"{k[0]}:{k[1]}" for k in sorted(book)]},
         "recommended_moves":moves,
         "adds":[m["add"] for m in moves if m["move"]=="ADD"],
         "swaps":[{"in":m["add"],"out":m["drop"]} for m in moves if m["move"]=="SWAP"],
         "risk_diagnostics":diagnostics}
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    json.dump(out, open(args.out,"w"), indent=1)
    print(f"current book: {len([k for k in LIVE_BOOK if k in keymap])} sleeves, Sharpe {base_sh:.3f}, DD {base_dd:.2f}%")
    print(f"reoptimized:  {len(book)} sleeves, Sharpe {cur_sh:.3f}, DD {cur_dd:.2f}%  ({len(moves)} moves)")
    for m in moves: print(f"  {m['move']:4} +{m['add']}" + (f" -{m['drop']}" if m['drop'] else "") + f"  -> Sharpe {m['book_sharpe']}")
    print("wrote", args.out)

if __name__=="__main__":
    main()
