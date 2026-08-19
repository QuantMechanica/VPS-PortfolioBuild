#!/usr/bin/env python3
"""Round 8 section 1.3 control: is the loss caused by these sleeves or by book size?

audit_activity_contribution.py shows the extended book losing 10 points of funding
probability at the overlap-constrained floor.  Two explanations fit that:

  (a) the recovered sleeves are individually harmful -- low return, extra
      simultaneous exposure, deeper joint intraday drawdowns
  (b) ANY eight added sleeves would do the same, because more concurrent
      positions means more daily-cap breaches regardless of which sleeves

They are distinguished by measuring each recovered sleeve on its own: add exactly one
to the incumbent pool and re-measure.  If most single additions already cost funding
probability, the character of the sleeves is doing the work.  If single additions are
neutral and only the full set hurts, it is a size effect.

A size reference is measured alongside: eight incumbent sleeves are dropped to form a
15-sleeve book, so the direction of the pure size effect on this basis is visible
rather than assumed.

Read-only.  Prints a table and writes a JSON artifact.
"""
from __future__ import annotations

import datetime as dt
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import audit_activity_contribution as base  # noqa: E402

OUT = Path(r"C:\QM\repo\artifacts\audit_activity_marginal_20260819.json")


def main() -> int:
    recount = json.loads(base.RECOUNT.read_text(encoding="utf-8"))
    incumbent_keys = list(recount["admitted_keys"])
    recovered_keys = list(recount["recovered_keys"])

    sleeves = {}
    for key in incumbent_keys + recovered_keys:
        bare, _, sym = key.partition(":")
        path = base.STREAMS / f"{bare}_{sym}_DWX.jsonl"
        if path.exists():
            sleeves[key] = base.load_stream(path)

    inc = {k: v for k, v in sleeves.items() if k in incumbent_keys}
    ref = base.measure(base.Pool(inc))
    ref_funded = ref["overlap_floor"]["funded_rate"]
    ref_p1 = ref["overlap_floor"]["p1_rate"]
    print(f"incumbent {len(inc)} sleeves   overlap_floor: P1 {ref_p1:.3f}  funded {ref_funded:.3f}")
    print()
    print(f"{'added sleeve':26} {'P1':>7} {'dP1':>7} {'funded':>8} {'dFunded':>8}")

    rows = {}
    for key in recovered_keys:
        pool = dict(inc)
        pool[key] = sleeves[key]
        m = base.measure(base.Pool(pool))
        of = m["overlap_floor"]
        rows[key] = {"p1_rate": of["p1_rate"], "funded_rate": of["funded_rate"],
                     "d_p1": round(of["p1_rate"] - ref_p1, 4),
                     "d_funded": round(of["funded_rate"] - ref_funded, 4)}
        print(f"{key:26} {of['p1_rate']:7.3f} {rows[key]['d_p1']:+7.3f} "
              f"{of['funded_rate']:8.3f} {rows[key]['d_funded']:+8.3f}")

    # Size reference: drop the eight incumbent sleeves with the FEWEST close days,
    # so the comparison is 15 vs 23 with the same measurement basis.
    order = sorted(inc, key=lambda k: len({c for _e, c, _n, _m in inc[k]}))
    smaller = {k: v for k, v in inc.items() if k not in set(order[:8])}
    sm = base.measure(base.Pool(smaller))
    print()
    print(f"size reference: {len(smaller)} sleeves (eight thinnest incumbents dropped)  "
          f"P1 {sm['overlap_floor']['p1_rate']:.3f}  funded {sm['overlap_floor']['funded_rate']:.3f}")

    worse = sum(1 for r in rows.values() if r["d_funded"] < 0)
    better = sum(1 for r in rows.values() if r["d_funded"] > 0)
    print(f"\nsingle additions: {worse} lower funding, {better} raise it, "
          f"{len(rows)-worse-better} neutral")

    payload = {
        "schema": "qm.activity-criterion-marginal/v1",
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "sizing": base.MULT,
        "incumbent_reference": ref,
        "single_additions": rows,
        "size_reference_15": sm,
        "counts": {"worse": worse, "better": better,
                   "neutral": len(rows) - worse - better},
    }
    OUT.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
    print(f"\nartifact: {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
