# Evidence Receipt — TAIL_RISK programme (aggressive strategy families)

**Date:** 2026-09-16
**Author:** Kimi (interim Quant Research + Strategy Engineering lead, OWNER_DIRECT_SESSION_DELEGATION)
**Authority:** OWNER-DEC-D3-20260915 directive 3 §17–§21, §43-F (verbatim at
`docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_3_max_factory_utilization_verbatim.md`)
+ OWNER interim directive §7–§8 (TAIL_RISK programme; joint-tail protocol).
**Type:** RESEARCH + SPECIFICATION slice. Append-only/new files only; no commits (central
commit pass handles it); no verdict/gate/DB writes.

## What now exists (all new files)

1. `docs/research/TAIL_RISK_PROGRAMME_2026-09-16.md` — the programme document:
   - Family schema `qm.research-tail-risk-family/v1` (§3) with a complete JSON example;
   - Four fully-specified aggressive families, each with max levels, size progression,
     exposure cap, basket stop, expected mechanism, regime of failure, stress-test
     definition, FTMO/DXZ portfolio role, and explicit invalidation (family-dead) criteria:
     A positive pyramiding (3 levels, 1.0/0.75/0.5, 0.5% giveback/adverse bound, trailing
     1.0×ATR), B negative pyramiding (3 levels hard-bounded, 1.0% basket bound,
     anti-martingale sizing), C bounded martingale (4 finite levels ×2 geometric, 2.0% HARD
     equity stop as terminal failure condition, 15% margin cap, FTMO-excluded), D bounded
     grid/recovery (5 levels at 1.0×ATR spacing, flat units, recovery TP + 1.5% equity
     boundary + 5-session time stop);
   - Joint-tail protocol (§8): 12-step procedure aligned metric-by-metric with
     `PORTFOLIO_TAIL_RISK_RESEARCH.md` §2/§4/§5 — data inputs (sealed Q08/Q14 streams,
     interval equity, news calendar as factory evidence only, farm DB read-only), empirical
     joint tails, λ_L (non-parametric), worst-day overlap vs seed-pinned permutation
     baseline, correlation convergence tail-vs-body, block bootstrap (10-day blocks, 2000
     seed-pinned reps), joint basket escalation, common-symbol/session/margin paths,
     DD clustering, simultaneous recovery escalation, joint gap scenarios, Gaussian-copula
     comparison marked BASELINE ONLY / not a safety argument; proposed thresholds flagged
     PROPOSED_PENDING_OWNER_RATIFICATION (§30).
2. `tools/strategy_farm/config/tail_risk_families.v1.json` — machine-readable family
   definitions (schema `qm.tail-risk-families/v1`), each embedding a complete
   `qm.strategy-risk-contract/v1` contract validated against the machine gate's own
   validator; stress matrix `s01`–`s08` (gap ×1/×2/×3, spread ×2/×3+slippage, news shock,
   margin spike ×1.5, combined worst) with per-family slippage allowances; joint-tail
   protocol block; read-only copy of the ratified book budgets (5%×0.8=4% effective daily
   loss, 11% stop-risk, 0.05 per-sleeve worst fraction).
3. `tools/strategy_farm/tests/test_tail_risk_families_config.py` — 16 hermetic schema tests
   (no DB, no network, no writes; reuses `strategy_risk_contract.validate_contract` /
   `is_unbounded`).

## Verification

- `python -m pytest tools/strategy_farm/tests/test_tail_risk_families_config.py -v`
  → **16 passed in 0.72s** (Python 3.11.9, pytest 9.1.1), fresh run on final files.

## What was deliberately NOT done

- **No EA implementation** for any family — family cards + governed build lanes come after
  OWNER ratification of the family specs.
- **No economic validation** — no backtests, no expectancy claims; every evidence field in
  the config is `EVIDENCE_MISSING`/`NOT_EVALUATED` by design at specification stage.
- **No wave-2 tail-risk engine** — that is Directive-3 §43-F, **f1/f2 for Fable** (prerequisites
  it needs — merged eligibility v2 + tail-risk research doc — are on main; this programme +
  config is the family-level input it consumes). No engine code, no
  `portfolio_tail_risk.json` emission.
- **No threshold ratification** — all thresholds are PROPOSED_PENDING_OWNER_RATIFICATION
  (§30: counterfactual first, versioned contract, tests, reversible; never gate-integrity).
- **No verdict/gate/DB/book writes**; farm DB untouched; FTMO demo / T_Live untouched;
  no commits (central commit pass handles it); existing files unmodified (only the three
  new files above were added).

## Exact next actions

1. **Fable — f1:** wave-2 engine `portfolio/tail_risk_engine.py` per
   `PORTFOLIO_TAIL_RISK_RESEARCH.md` §5, consuming `tail_risk_families.v1.json` (family
   contracts, stress matrix, joint-tail protocol block); emit
   `D:/QM/reports/state/portfolio_tail_risk.json` with `tail_risk_reject` hard guard
   (fail-closed data validity). **Fable — f2:** wire engine output as advisory evidence
   into the OWNER book ceremony (never auto-sizing/deploying).
2. OWNER §30 ratification pass over the proposed thresholds in the config
   (`lambda_L_max_at_alpha_0.05` 0.15, independence-p95 worst-day overlap, 1%/quarter
   joint escalation, 4.0% joint worst-day, 0.2 correlation-convergence delta, slippage
   allowances).
3. Author one house-format card per family (provenance + `risk_contract:` reference;
   H-CW conventions as style template) only after step 2.
4. Sealed Q06 HARSH-class stress runs per family to fill `stress_sequence` /
   `worst_historical_sequence`; then run the joint-tail protocol on any candidate
   multi-sleeve aggressive set.
5. Standing rule until 1–4 complete: any aggressive multi-sleeve book is `EVIDENCE_MISSING`
   for §19 diversification — never present it as "diversification proven".
