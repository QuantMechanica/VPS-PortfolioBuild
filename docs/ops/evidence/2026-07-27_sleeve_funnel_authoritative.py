"""Authoritative sleeve-funnel derivation (companion to the .md of the same name).

Admission semantics are taken from where the pipeline ACTUALLY routes
  tools/strategy_farm/farmctl.py:11367  cascade_pass_verdicts   (auto-pump)
  tools/strategy_farm/farmctl.py:12886  phase_prev_verdicts     (enqueue-next)
NOT from any audit-script `required_verdict` set literal (e.g.
tools/strategy_farm/portfolio/ftmo_qualification.py:348 `verdict != "PASS"`,
which is the deliberately-stricter fail-closed PAID-challenge contract).

Read-only (mode=ro). The live DB mutates during the read (the factory pump
rewrites Q09_PORTFOLIO rows continuously), so the .md pins a snapshot; re-running
this against the live DB will drift by a sleeve or two in the sub-500-day
population but never in the 9-qualifying / 16-infra-only decision layer.

Usage:  python 2026-07-27_sleeve_funnel_authoritative.py [path-to-db-or-snapshot]
"""
import json
import sqlite3
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

STREAMS = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")
DB = sys.argv[1] if len(sys.argv) > 1 else "D:/QM/strategy_farm/state/farm_state.sqlite"
DAY_BAR = 500

# ---- routing-derived advancing (pass-ish) verdicts, per gate ----------------
ADVANCING = {
    "Q02": {"PASS"},
    "Q03": {"PASS"},
    "Q04": {"PASS", "PASS_SOFT", "PASS_LOWFREQ"},   # DL-071 soft + DL-076 low-freq
    "Q05": {"PASS"},
    "Q06": {"PASS"},
    "Q07": {"PASS", "MULTI_SEED_PASS"},
    "Q08": {"PASS"},                                 # main line -> Q10
}
Q08_BRANCH = {"FAIL_SOFT"}          # -> Q09_PORTFOLIO branch, campaign-admissible
INFRA = {"INFRA_FAIL", "PENDING_RUNNER"}
GATES = ["Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08"]
ALL_GATES = GATES + ["Q09_PORTFOLIO", "Q10"]


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


con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
con.row_factory = sqlite3.Row
latest, logical_sym = {}, {}
for r in con.execute("select ea_id,symbol,phase,verdict,updated_at,created_at,id "
                     "from work_items where status='done' "
                     "order by updated_at asc, created_at asc, id asc"):
    su = str(r["symbol"]).upper()
    latest[(r["ea_id"], su, r["phase"])] = str(r["verdict"] or "")
    if su.startswith(str(r["ea_id"]).upper() + "_"):   # QM5_<id>_ composite
        logical_sym[r["ea_id"]] = su


def resolve_symbol(ea, sym):
    """A basket EA (owns a QM5_<id>_ composite) is judged as ONE unit under that
    composite; every per-leg stream resolves to it, never to a stray per-leg row
    (a leg can carry an isolated Q10 export or Q02 INFRA that misrepresents the
    basket's real verdict)."""
    lg = logical_sym.get(ea)
    return (lg, True) if lg else (sym, False)


def cls(gate, v):
    if v is None:
        return "absent"
    if v in ADVANCING[gate]:
        return "advancing"
    if gate == "Q08" and v in Q08_BRANCH:
        return "branch"
    if v in INFRA:
        return "infra"
    return "reject"


sleeves = []
for path in sorted(STREAMS.glob("*.jsonl")):
    bare, _, stem = path.stem.partition("_")
    ea = f"QM5_{bare}"
    sym, is_basket = resolve_symbol(ea, stem.replace("_DWX", ".DWX").upper())
    chain = {g: latest.get((ea, sym, g)) for g in ALL_GATES}
    has_any = any(chain[g] is not None for g in ALL_GATES)
    days, n = set(), 0
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
            c = parse_ts(row.get("time"))
            if c:
                days.add(c.date())
                n += 1
    gc = {g: cls(g, chain[g]) for g in GATES}
    rej = [g for g in GATES if gc[g] == "reject"]
    inf = [g for g in GATES if gc[g] == "infra"]
    clean = (has_any and not rej and not inf
             and all(gc[g] in ("advancing", "branch", "absent") for g in GATES))
    infra_only = (has_any and not rej and bool(inf)
                  and all(gc[g] in ("advancing", "branch", "absent", "infra") for g in GATES))
    sleeves.append(dict(ea=ea, sym=sym, bare=bare, is_basket=is_basket, tdays=len(days),
                        n=n, chain=chain, rej=rej, inf=inf, clean=clean,
                        infra_only=infra_only, has_any=has_any))

clean = [s for s in sleeves if s["clean"]]
rejected = [s for s in sleeves if s["has_any"] and not s["clean"]]
infra_only = [s for s in sleeves if s["infra_only"]]
qual = sorted((s for s in clean if s["tdays"] >= DAY_BAR), key=lambda s: -s["tdays"])

print(f"streams={len(sleeves)}  distinct-units={len({(s['ea'],s['sym']) for s in sleeves})}")
print(f"gate-clean={len(clean)}  (short<{DAY_BAR}={len([s for s in clean if s['tdays']<DAY_BAR])}  "
      f"QUALIFYING>={DAY_BAR}={len(qual)})")
print(f"gate-rejected={len(rejected)}  (infra-only={len(infra_only)})")
blk = Counter(f"{g} {s['chain'][g]}" for s in sleeves for g in GATES if cls(g, s['chain'][g]) == "reject")
print("blockers:", blk.most_common())
adv = Counter(f"{g} {s['chain'][g]}" for s in sleeves for g in GATES
              if cls(g, s['chain'][g]) in ("advancing", "branch") and s['chain'][g] != "PASS")
print("non-PASS advancing (NOT blockers):", adv.most_common())
print("\nQUALIFYING:")
for s in qual:
    print(f"  {s['bare']:>6} {s['sym']:14} tdays={s['tdays']:4} "
          + " ".join(f"{g.replace('Q09_PORTFOLIO','Q09P')}={s['chain'][g] or '-'}" for g in ALL_GATES))
