"""Q08.6 — Chopping Block (Davey signature test).

Remove the top 5% most-profitable trades and recompute profit factor.
The EA passes if PF after removal is still > 1.0.

Rationale (per Davey's 2,000-strategy study): EAs whose edge depends on a
handful of outlier-good trades degrade ~25-30% in real-time. Stripping
those trades stresses the durable component of the edge.
"""

from __future__ import annotations

import math

from .common import make_result, profit_factor, trade_net_profits

GATE_NAME = "8.6_chopping_block"
TOP_PCT_REMOVED = 5.0
PF_FLOOR_AFTER_REMOVAL = 1.0


def run(trades: list[dict], **_) -> dict:
    profits = trade_net_profits(trades)
    n = len(profits)
    if n < 50:
        # DL-082 §3b (frequency-aware). Structural requirement math: the test removes
        # the top 5% of trades (n_remove = max(1, floor(0.05*n))) and recomputes PF on
        # the remainder; Davey's method needs >=50 trades so the removed slice is a
        # stable >=2-3 outliers and the retained sample still yields a meaningful PF.
        # Below 50 trades the chopping block is STRUCTURALLY inapplicable at this
        # frequency class. Demote to INFORMATIONAL (recorded, carrying no soft-fail
        # signal) rather than the old INVALID that the aggregate soft-mapped anyway.
        # At >=50 trades the gate evaluates exactly as before.
        return make_result(GATE_NAME, "INFORMATIONAL",
                           value=n, threshold=50,
                           detail=f"structurally_inapplicable_low_frequency:trades={n}:need>=50",
                           evidence={"n_trades": n})

    pf_full = profit_factor(profits)
    sorted_desc = sorted(profits, reverse=True)
    n_remove = max(1, int(math.floor(n * TOP_PCT_REMOVED / 100.0)))
    kept = sorted_desc[n_remove:]
    pf_after = profit_factor(kept)

    if pf_after is None:
        return make_result(GATE_NAME, "FAIL",
                           value=None, threshold=PF_FLOOR_AFTER_REMOVAL,
                           detail=f"no_losses_after_removal:n_removed={n_remove}",
                           evidence={"pf_full": pf_full, "trades_kept": len(kept)})

    if math.isinf(pf_after):
        return make_result(GATE_NAME, "PASS",
                           value=pf_after, threshold=PF_FLOOR_AFTER_REMOVAL,
                           detail=f"pf_infinite_after_removal:n_removed={n_remove}",
                           evidence={"pf_full": pf_full, "n_removed": n_remove,
                                     "trades_kept": len(kept)})

    status = "PASS" if pf_after > PF_FLOOR_AFTER_REMOVAL else "FAIL"
    detail = f"pf_after_top{int(TOP_PCT_REMOVED)}pct_removal={pf_after:.3f}:floor={PF_FLOOR_AFTER_REMOVAL}"
    return make_result(GATE_NAME, status,
                       value=round(pf_after, 4), threshold=PF_FLOOR_AFTER_REMOVAL,
                       detail=detail,
                       evidence={"pf_full": pf_full, "n_total": n,
                                 "n_removed": n_remove, "trades_kept": len(kept)})
