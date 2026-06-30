"""Watch the intraday (FTMO-sprint) funnel and surface NEW edges reaching Q04+.

Intraday = setfile timeframe in {M1,M5,M15,M30} OR slug {scalper,rapidfire,orb}.
An "edge" = an intraday (ea_id, symbol) reaching a pass-ish verdict at Q04 or
deeper (Q04 PASS/PASS_SOFT/PASS_LOWFREQ, or Q05-Q08 PASS/PASS_SOFT/FAIL_SOFT/
PASS_PORTFOLIO). State is kept in a JSON file; each run appends only NEW edges to
a log so nothing is missed between interactive sessions.

  python monitor_intraday_edges.py            # diff vs state, append new, print
  python monitor_intraday_edges.py --reseed   # rebuild baseline silently

Set up 2026-06-30 for the FTMO intraday focus
(docs/ops/DXZ_FTMO_BOOK_SIZING_REAL_0p75_2026-06-30.md).
"""
from __future__ import annotations
import argparse, datetime as dt, json, re, sqlite3
from pathlib import Path

DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
STATE = Path(r"D:\QM\reports\state\intraday_edge_watch.json")
LOG = Path(r"D:\QM\reports\state\intraday_edge_watch.log")
INTRADAY = re.compile(r"_(M1|M5|M15|M30)_|scalper|rapidfire|orb", re.I)
PASSISH = ("PASS", "PASS_SOFT", "PASS_LOWFREQ", "FAIL_SOFT", "PASS_PORTFOLIO")
DEEP_PHASES = ("Q04", "Q05", "Q06", "Q07", "Q08", "Q09_PORTFOLIO")


def snapshot() -> dict[str, dict]:
    c = sqlite3.connect(DB)
    c.row_factory = sqlite3.Row
    ph = ",".join("?" for _ in DEEP_PHASES)
    vd = ",".join("?" for _ in PASSISH)
    rows = c.execute(
        f"SELECT ea_id,phase,symbol,verdict,setfile_path FROM work_items "
        f"WHERE phase IN ({ph}) AND status='done' AND verdict IN ({vd})",
        (*DEEP_PHASES, *PASSISH),
    ).fetchall()
    c.close()
    out = {}
    for r in rows:
        if not INTRADAY.search(r["setfile_path"] or ""):
            continue
        key = f"{r['ea_id']}|{r['symbol']}|{r['phase']}|{r['verdict']}"
        out[key] = dict(ea_id=r["ea_id"], symbol=r["symbol"], phase=r["phase"], verdict=r["verdict"])
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--reseed", action="store_true", help="rebuild baseline silently (no 'new' report)")
    args = ap.parse_args(argv)

    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()
    current = snapshot()
    prior = {}
    if STATE.exists() and not args.reseed:
        try:
            prior = json.loads(STATE.read_text())
        except Exception:
            prior = {}

    new_keys = sorted(set(current) - set(prior))
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(current, indent=2, sort_keys=True))

    if args.reseed or not prior:
        print(f"[{now}] seeded baseline: {len(current)} intraday edges at Q04+")
        return 0

    if not new_keys:
        print(f"[{now}] no new intraday edges (baseline {len(current)})")
        return 0

    lines = [f"[{now}] {len(new_keys)} NEW intraday edge(s) at Q04+:"]
    # Deeper phases first (Q08 > Q04) so the strongest news leads.
    order = {p: i for i, p in enumerate(reversed(DEEP_PHASES))}
    for k in sorted(new_keys, key=lambda k: order.get(current[k]["phase"], 99)):
        e = current[k]
        lines.append(f"    {e['ea_id']:12} {e['phase']:14} {e['symbol']:12} {e['verdict']}")
    msg = "\n".join(lines)
    print(msg)
    with LOG.open("a", encoding="utf-8") as fh:
        fh.write(msg + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
