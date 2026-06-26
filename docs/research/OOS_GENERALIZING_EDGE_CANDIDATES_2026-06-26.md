# Surfacing Cost-Robust, OOS-Generalizing Edges as Candidates (2026-06-26)

Author: Claude. OWNER: "surface the OOS-generalizing edges as candidates." Method: scan every
`q08_trades` stream, recompute net P&L under the **realistic per-class registry commission**
(`live_commission.json`), and apply a 70/30 time-split OOS-tail check. Every number is
reproducible from the streams.

## 1. The scan

- **1,672** EA×symbol streams (≥20 trades) scanned.
- **218** are **net-positive after realistic cost AND net-positive in the OOS tail** (net PF
  >1.05), across **166 distinct EAs**. By class: **103 forex**, 82 index, 33 commodity.
- This confirms the corrected commission finding: **FX edges are real** — the book's empty
  forex column is a *funnel-throughput* gap, not a cost-impossibility.

**Caveat (why these are candidates, not sleeves):** a 70/30 tail split is *coarser* than the
Q04 3-fold walk-forward and cannot catch execution-realism overfit (113×-return / 90%-win
curves). Only the Q05/Q06 stress gates do. So these are edges to **route into the funnel**, not
admit. The gates remain the judge.

## 2. Funnel reality — the gates have already done their job

Cross-referencing the 218 with their pipeline position:

| Bucket | Count | Meaning |
|---|---|---|
| Survived Q05 | 6 | genuine survivors, deep in funnel |
| Passed Q04, then **died at Q05** | 21 | overfit mirages (QM5_10375 WS30 PF 13, QM5_11180 PF 1294) — Q05 correctly rejected |
| Failed Q04 (per-fold variance) | 76 | the strict 3-fold caught what the tail-split missed |
| Reached only Q02/Q03 | 110 | never walk-forward-tested |

**The 6 Q05-survivors** (the near-candidates):

| EA | symbol | net PF | OOS $ | phase | note |
|---|---|---|---|---|---|
| **QM5_10588** | **USDJPY** | 1.16 | +$8.0k | **Q06** | ★ the book's first realistic **forex** sleeve — no FX in the book today |
| QM5_11179 | XAUUSD | 12.48 | +$9.3k | Q07 | high PF = overfit-flavored; XAU already covered |
| QM5_11125 | SP500 | 1.95 | +$2.7k | Q07 | redundant with 11132 |
| QM5_11129 | SP500 | 1.61 | +$1.3k | Q07 | redundant |
| QM5_11124 | SP500 | 1.31 | +$2.8k | Q09 | already on watchlist (FAIL_SOFT, corr +0.57 vs 11132) |
| QM5_12567 | XNGUSD | 9.23 | +$1.2k | Q09 | already certified-adjacent (14<20 floor) |

★ **QM5_10588 USDJPY at Q06 is the single highest-value near-term candidate** — push it
through Q06→Q07→Q08; it would give the book its first uncorrelated FX sleeve.

## 3. The lever this session unlocked — Q02-min-trades resurrection

The decisive find: **36 cost-robust, OOS-generalizing, *diversifying* edges (31 EAs)** were
killed at **Q02 by `MIN_TRADES_NOT_MET`** on the *old* card-coupled floor, despite trading
**≥5/yr** and being net-positive after cost. The **new 5/yr Q02 floor** (this session) rescues
exactly these. Almost all are **forex** (the empty column) + **XAGUSD silver** (a non-gold
commodity). Top edges:

| EA | symbol | trades/yr | net PF | OOS PF | OOS $ |
|---|---|---|---|---|---|
| QM5_12493 | EURUSD | 15.2 | 1.35 | 3.45 | +$9.5k |
| QM5_11478 | USDJPY | 6.8 | 1.72 | 2.22 | +$8.6k |
| QM5_1063 | EURUSD | 6.2 | 1.40 | 2.01 | +$6.4k |
| QM5_12428 | USDCHF | 9.4 | 1.73 | 2.65 | +$3.3k |
| QM5_10856 | XAGUSD | 5.6 | 1.06 | 1.66 | +$3.2k |
| QM5_11387 | GBPUSD | 11.1 | 1.26 | 2.54 | +$3.2k |

**Action taken:** all 36 re-enqueued at Q02 (2022–2024 window, new floor), bumped to the front
of the queue. They will re-enter the cascade (Q03→Q04 walk-forward→Q05 stress→Q08); the gates
judge which are real. Even a 10–20% survival rate would give the book its first FX/silver sleeves.

## 4. Recommended next steps

1. **Watch QM5_10588 USDJPY (Q06)** — the closest FX candidate; ensure it advances Q06→Q08.
2. **Watch the 36 resurrected edges** through the funnel over the next few days; the survivors
   are the diversification the book needs (FX + silver vs today's XAU/SP500/NDX).
3. The 110 Q02/Q03-only edges are a deeper backlog — route in waves if the front runners pan out,
   but don't flood the CPU-bound funnel.

Evidence: `q08_trades` streams; `live_commission.json` (cost model); farm DB `work_items`;
scan artifacts in session scratchpad (`oos_candidates.json`, `routable_edges.json`).
