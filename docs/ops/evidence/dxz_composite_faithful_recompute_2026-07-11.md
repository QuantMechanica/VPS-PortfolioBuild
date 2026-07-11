# DXZ composite recompute — faithful, fresh streams (2026-07-11)

After the q08 SL/TP fix cleaned all sleeve streams, the DXZ composite was recomputed with
**capped-inverse-vol weights RECOMPUTED from the fresh Common streams** (s4/d2d methodology:
TOTAL_RISK=9.75, CAP=1.0, portfolio_metrics). Tool: tools/strategy_farm/portfolio/dxz_composite_faithful_recompute.py.

## Methodology verification (exact)
Running this methodology on the FROZEN d2d streams for the S3-15 reproduces the s4/d2d reference
EXACTLY: Sharpe 2.027, MaxDD 5.156% (== decision-doc S3 reference). The methodology is correct.

## Result (fresh live streams)
| book | sleeves | Sharpe | MaxDD | ann % | net |
|---|---|---|---|---|---|
| DXZ-20 | 20 | 2.089 | 4.19% | 8.82 | $72.5k |
| **DXZ-23 (+13128/1556/10706)** | 23 | **2.348** | **3.32%** | 8.54 | $70.2k |

**The 3 new candidates improve the book: Sharpe +12.4%, MaxDD −21%**, at a tiny return cost —
the hallmark of orthogonal diversifiers (smoother equity, not more return).

## Discrepancy with the DRAFT manifest — RESOLVED
The 2026-07-08 DRAFT manifest reported Sharpe 2.890 / max_drawdown_pct 0.2456. That is a DIFFERENT
KPI DEFINITION, not the s4/d2d Sharpe/MaxDD (verified above). It is NOT a stream difference or a bug.
The s4/d2d-methodology KPIs above are the authoritative ones for the current-EA book on clean streams.
