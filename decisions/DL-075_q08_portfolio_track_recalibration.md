# DL-075 — Q08 portfolio-track recalibration: seasonal/chopping/regime are SOFT, not HARD

Date: 2026-06-21
Status: DECIDED (OWNER-authorized 2026-06-21)
Author: Claude

## Context
Q08 is the Davey 10-sub-gate single-EA robustness battery. 0 EAs have ever cleared it
hard. Evidence audit (145 Q08 aggregates, 49 with sufficient sample) showed:
- The killers are **8.4 seasonal, 8.6 chopping-block, 8.10 regime/crisis** (single-EA
  robustness across conditions) + low statistical sample on low-frequency edges.
- It is NOT overfitting (8.7 PBO passes ~106×) nor parameter instability (8.5 passes).
- ~96 of 145 Q08 runs came back **INVALID** — not broken, but **low-frequency edges the
  Davey statistics cannot evaluate** (e.g. 33 trades < the DSR ≥60-daily-returns floor),
  often blocked by a single non-evaluable gate (8.10 regime INVALID).

## OWNER reasoning (the reframe)
Period/regime-dependence of a SINGLE EA is precisely the risk the **Q09 anti-correlation
portfolio** eliminates by diversification. Requiring each EA to individually survive every
season/regime double-counts the robustness bar and walls off low-freq / regime-dependent
edges that would be valuable *in a portfolio*. The win mechanism is the portfolio, not the
standalone EA.

## Decision
In `framework/scripts/q08_davey/aggregate.py` `_aggregate_verdict`, the three
condition-robustness sub-gates **8.4 / 8.6 / 8.10** can only contribute a **SOFT** signal:
they never HARD-fail and never block the verdict as INVALID. A non-PASS on any of them
yields `EDGE_SOFT` → the EA gets **FAIL_SOFT** and flows to the **Q09 portfolio track**,
where combined/anti-correlated robustness is the real gate.

**Unchanged / still HARD (profitability is non-negotiable):** `portfolio_net_pf` (net
PF < 1 → FAIL_HARD), `cost_cushion` EDGE_HARD, and the other sub-gates (8.1/8.2 DSR
significance when *computable*/8.3/8.5/8.7/8.8/8.9). Genuine non-low-sample INVALID on
those still returns INVALID. Q09/Q11 portfolio gates remain strict.

## Measured effect (re-classification of existing 145 aggregates, no re-backtest)
- OLD: INVALID 96 / FAIL_HARD 16 / FAIL_SOFT 24 / FAIL 9
- NEW: **FAIL_SOFT 130** / FAIL_HARD 14 / INVALID 1
- 94 INVALID → FAIL_SOFT (low-freq/regime EAs now reach the portfolio track); 14 remain
  FAIL_HARD (genuine profitability fails — protection intact).

## Application
Applies automatically to all FUTURE Q08 runs. The existing cohort re-verdicts on its next
Q08 run (the 5 nucleus re-runs already queued will get new verdicts); a controlled
re-enqueue/re-aggregation of the backlog can promote the rest into Q09 when the factory is
stable. Does NOT soften profitability — only moves single-EA condition-robustness to the
portfolio layer where it belongs.

Supersedes the per-EA-hard interpretation of 8.4/8.6/8.10 in the Q08 frontier
(see [[project_qm_full_funnel_audit_2026-06-09]], DL-070/071/072).
