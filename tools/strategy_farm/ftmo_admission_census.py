"""Point 1.1: how many pairs are FTMO-ADMISSIBLE today?

The 19-36 day cost figure I gave was for DXZ-scoped Q09 closure. But the FTMO book has its own
fail-closed admission contract (portfolio/ftmo_q09_admission.py) whose docstring requires either a
7x1 matrix directly targeting FTMO, or a complete 7x4 matrix containing a viable FTMO config.
A DXZ-scoped lock returns FTMO_Q09_SCOPE_NOT_FTMO.

So "34 contract-compliant pairs" under option A may deliver DXZ compliance and still zero FTMO
admissions. Run the real gate rather than reasoning about it.

Positive control: the single CONFIG_LOCKED pair (QM5_11422/USDCAD) MUST return something other
than EVIDENCE_MISSING - it demonstrably has adjudication evidence. If it returns EVIDENCE_MISSING,
my harness is wrong, not the pool.
"""
import collections
import sqlite3
import sys

sys.path.insert(0, r"C:\QM\repo")
sys.path.insert(0, r"C:\QM\repo\tools\strategy_farm")

from tools.strategy_farm.portfolio.ftmo_q09_admission import evaluate_ftmo_q09_admission

DB = r"D:\QM\strategy_farm\state\farm_state.sqlite"
con = sqlite3.connect("file:" + DB + "?mode=ro", uri=True, timeout=25)
con.row_factory = sqlite3.Row

# the Q10 PASS pool
pairs = con.execute(
    "SELECT DISTINCT ea_id, symbol FROM work_items "
    "WHERE phase='Q10' AND verdict LIKE 'PASS%' ORDER BY ea_id, symbol").fetchall()
print("Q10 PASS pairs: %d" % len(pairs))

print("\n=== POSITIVE CONTROL: the one pair with adjudication evidence ===")
ctl = evaluate_ftmo_q09_admission(con, "QM5_11422", "USDCAD.DWX")
print("  QM5_11422/USDCAD.DWX -> admitted=%s reason=%s" % (ctl.get("admitted"), ctl.get("reason_code")))
print("  source_target_compliance=%s deployment_compliance=%s"
      % (ctl.get("source_target_compliance"), ctl.get("deployment_compliance")))
if ctl.get("reason_code") == "FTMO_Q09_EVIDENCE_MISSING":
    print("  !! control returned EVIDENCE_MISSING - harness suspect, do NOT trust the census below")

print("\n=== the pool ===")
tally = collections.Counter()
admitted = []
for p in pairs:
    r = evaluate_ftmo_q09_admission(con, p["ea_id"], p["symbol"])
    tally[r.get("reason_code")] += 1
    if r.get("admitted"):
        admitted.append((p["ea_id"], p["symbol"]))
for k, v in tally.most_common():
    print("   %-34s %d" % (k, v))
print("\n  FTMO-ADMISSIBLE pairs: %d  %s" % (len(admitted), admitted))

print("\n=== how much FTMO-scoped Q09 evidence exists at all? ===")
try:
    for r in con.execute("SELECT target_compliance, COUNT(*) n FROM q09_news_tests GROUP BY target_compliance"):
        print("   q09_news_tests target_compliance=%-8s %d" % (r["target_compliance"], r["n"]))
except Exception as e:
    print("   ", e)
try:
    cols = [c[1] for c in con.execute("PRAGMA table_info(q09_news_cells)")]
    cc = "compliance_mode" if "compliance_mode" in cols else None
    if cc:
        for r in con.execute("SELECT %s m, COUNT(*) n FROM q09_news_cells GROUP BY %s ORDER BY n DESC" % (cc, cc)):
            print("   q09_news_cells compliance_mode=%-8s %d cells" % (r["m"], r["n"]))
except Exception as e:
    print("   ", e)
con.close()
