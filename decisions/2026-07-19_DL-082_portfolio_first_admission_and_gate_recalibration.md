# DL-082 — Portfolio-First Admission & Evidence-Based Gate Recalibration

**Date:** 2026-07-19 (late evening) · **Decided by:** OWNER (chat, verbatim mandate:
"Das Portfolio ist das Ziel … schwächere EAs, die sich diversifizieren, sind wertvoll";
"R1-R4 ist auch zu streng was Quellen betrifft! Lös das alles!") · **Executed by:** Claude
**Evidence basis:** gate-calibration review wf_724a8d70 (4 tracks, session scratchpad
`gatereview/`), FTMO rescreen (`ftmo_rescreen/`), venue_cost_model.json (2026-07-19).

## Ratified changes

### 1. R1 source requirement becomes a TIER, not a gate (implemented tonight)
- r2 (mechanical), r3 (data available), r4 (no ML) stay STRICT PASS-required.
- r1 (track record/source quality) becomes informational: `PASS` / `TIER_A` / `TIER_B`
  / `TIER_C` all admit to build. Rationale: the deterministic pipeline (full-history
  Q02, walk-forward, DSR/PBO) is a far stronger validator than any citation; a
  backtest is cheap. Source tier keeps feeding build PRIORITY (strategy_priority),
  not admissibility.
- approve-card body coverage: scholarly citation (year+DOI/journal) no longer
  mandatory — any explicit source/rationale line qualifies; the mechanical
  completeness checks (Entry/Exit/Stop, .DWX symbols, TF token, frequency) stay strict.
- GUARD (non-negotiable): more admitted trials = more selection bias → DSR/PBO
  duty gets STRONGER; every card still records its true source tier + trial count.

### 2. Q04 cost input correction (not softening)
Flat $7/lot (q04_walkforward.py:41) → per-symbol venue_cost_model.json, dual
variants (DXZ worst-case + FTMO). Net-PF fold THRESHOLDS UNCHANGED. Evidence: 111
distinct index/energy (ea,symbol) keys were net-PF-mean ≥1.0 even AT the punitive $7
and died only on fold weakness; index net-survival 14.5% vs FX 4.0% shows systematic
bias against book-critical classes. Follow-through: re-run the 111-key cohort.

### 3. Q08 recalibration (the one genuinely miscalibrated gate)
Evidence: 0 PASS in 415 all-time records; sub-gates 8.4/8.6/8.10 soft-fail 79–99%
of ALL candidates (no discriminative signal); 8.5 neighborhood 67% INVALID of which
132 = degenerate zero-trade baselines (infra masquerading as verdicts).
- (a) degenerate_baseline (0-trade) → INFRA_RECYCLE (re-derive setfile), never a
  gate outcome. INVALID≠PASS stays intact for genuine invalids.
- (b) 8.4_seasonal / 8.6_chopping_block / 8.10_regime_crisis become frequency-aware;
  where a low-freq survivor structurally cannot satisfy them (e.g. <12 traded months),
  they demote to INFORMATIONAL (recorded, not gate-relevant). Merit teeth unchanged:
  8.5 real breach, cost cushion EDGE_HARD, portfolio_net_pf.
- (c) Q08 gets an explicit PASS state: all merit sub-gates pass + soft-fail set within
  the OWNER-ratified non-merit allowance (codifies the 2026-07-16 EDGE_SOFT/LOW_SAMPLE
  ruling instead of per-case OWNER overrides). Neighborhood-FAIL still disqualifies
  (2026-07-17 ruling unchanged).

### 4. Portfolio lane ("Spur 2") — weaker-but-diversifying EAs become book-relevant
- Q05 dd_above_ceiling no longer auto-RETIREs: verdict becomes
  FAIL_DD_PORTFOLIO_REVIEW → candidate PARKS for marginal-contribution evaluation
  (hard RETIRE stays for pf_below_floor / trades_below_floor).
- New evaluator (v1): candidate joins the sealed composite at its capped
  inverse-vol weight → ΔSharpe/ΔMaxDD/Δworst-day vs incumbent book, OOS-validated
  per the 2026-07-11 weighting methodology, plus regime-split correlation and a
  minimum-contribution criterion (ops-worthiness). Admission remains an OWNER gate.
- Q02 PF floor becomes evidence-strength-conditional per review track C
  (curve parameters from `gatereview/C_analysis.md`); hard bottom stays well above
  cost-noise; PBO/DSR unchanged as the downstream guard.

### 5. Unchanged (deliberately)
Q02 frequency floor 5/yr; Q05 pf/trade floors; Q07 multiseed/DSR/PBO (now MORE
load-bearing); INVALID≠PASS; neighborhood-FAIL disqualifies; Cap 1.0/sleeve;
money/admission gates = OWNER.

## Evidence-regime note
Changes apply going forward. Historical verdicts keep their labels; revived cohorts
(111 Q04 index/energy keys, Q05-DD parks incl. Balke family, FTMO rescues) re-enter
via staged requeues with fresh runs — never by relabeling old evidence.
