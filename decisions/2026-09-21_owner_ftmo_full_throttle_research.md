# OWNER-DEC-FTMO-FULL-THROTTLE-20260921 — Full-throttle FTMO R&D: Sunday is a checkpoint, not a research freeze (OWNER 2026-09-21 ~21:05Z)

- **Status:** controlling OWNER clarification, binding; extends OWNER-DEC-FTMO-DUAL-TRACK-20260921 and OWNER-DEC-FTMO-FINAL-MEGA-20260921.
  Verbatim: `docs/ops/evidence/2026-09-21_ftmo_full_throttle_override/owner_directive_verbatim.md`.
- **Correction of posture:** parking useful research (NNFX recovery packages, retest candidates, Second-Chance, optimisation lineages,
  rebuilds) "until after Sunday" is not the operating model. Sunday 2026-09-27 = clean incumbent Demo launch checkpoint; research never
  freezes. Only real reasons park a task: provider unavailable, missing prerequisite data, invalid evidence, unresolved semantic defect,
  unsafe resource collision, unsatisfied dependency, or materially lower expected value than all running work. "Sunday is close" is not one.

## Binding changes

1. **Primary pre-payout KPI = `P80_DAYS_TO_FIRST_NET_FTMO_PAYOUT`** — the earliest calendar day by which ≥ 80 % of realistic account-level
   paths have produced the first positive net FTMO payout (`NOT_ACHIEVED` if fewer than 80 % ever pay out). Track also P50/P90 days,
   `P_PAYOUT_WITHIN_30D/45D/60D/90D`, `P_PAYOUT_EVER`. Objective: push the payout-time distribution left while keeping payout probability
   high. Candidates are judged by marginal book value; every surviving sleeve reports BOOK_WITHOUT/WITH_CANDIDATE_P80, DELTA_P80_DAYS,
   DELTA_PAYOUT_PROBABILITY, DELTA_MAX_LOSS, DELTA_DAILY_LOSS, DELTA_COST_STRESS. Pareto frontier x = P80 days, y = P_PAYOUT_EVER.
2. **Three continuous tracks:** A = Sunday incumbent / production readiness (critical, must not monopolise capacity); B = new edge
   discovery (new strategies, cross-market/session effects, complex multi-condition and multi-symbol rules, offline statistical/ML
   discovery, original hypotheses); C = existing-edge improvement / recovery (NNFX unresolved strategies, Second-Chance, optimisation,
   exits/trailing, session variants, symbol expansion, risk weighting, recombination) — never parked for Sunday.
3. **Unpark now** with a classification `RUN_NOW / REAL_BLOCKER / LOW_EXPECTED_VALUE / DUPLICATE / REJECT` for every item parked only
   because of Sunday. Applied 2026-09-21 21:1xZ: N-RECOVERY `cd3b761c` and R-RECOVERY `df1cae9b` → RUN_NOW (TODO on the Codex lane);
   BR1–BR3 tickets stay BACKLOG classified REJECT on the family-B3 result (0/16 cells; result attached).
4. **Capacity:** Codex simultaneously on production (KS, harness v2, simulator, genesis) and offensive research (hypothesis scanners, ML
   discovery tooling, cross-symbol analysis, MQL5 candidates, optimisation, NNFX recovery, retest candidates, Second-Chance, review) in
   parallel where paths are independent; Antigravity generating/attacking hypotheses; **Kimi discovery wave when it returns ~midday
   2026-09-22** (`FTMO_MECHANICAL_EDGE_DISCOVERY_WAVE`: broad statistical/ML + cross-market discovery over the full symbol universe and
   all historical QM results; original hypotheses, not literature summaries); deterministic Python and MT5 as before.
5. **Offline ML/statistical discovery is encouraged** (trees, rule lists, boosting, clustering, symbolic regression, association rules,
   mutual information, regime/change-point detection, lead/lag, conditional returns, event studies); every effect becomes a fully
   mechanical rule; no runtime ML (HR14 unchanged). **Complex mechanical and multi-symbol strategies are allowed** (symbol A gates
   symbol B) with correct timestamps, closed data, no look-ahead, reproducible tester implementation, deterministic time conversion.
6. **Cross-symbol research is P0** across indices (SP500↔NDX↔WS30, DAX→US open, overnight→cash, divergence/relative strength,
   session transmission), metals (XAU↔XAG, XAU↔USDJPY, XAU↔indices, London→NY gold), FX (EURUSD↔GBPUSD, EURUSD↔USDJPY, USDJPY↔indices,
   USD basket, London→NY, WMR fix), energy (WTI momentum, oil↔CAD, session effects, commodity momentum clusters); full symbol universe,
   single-symbol and cross-symbol edges.
7. **Multiple independent hypotheses per role; families continue (B3 done → B4/B5…); optimisation is an offensive lane** (objective
   DELTA_P80, not PF); **synthesis of concepts** is allowed; **data-mining discipline** (count hypotheses/variants/features/symbols/
   thresholds; chronological holdouts, FDR, deflated Sharpe, bootstrap, pre-registration, neighbouring robustness; evidence bar scales
   with the search size). Research may fail fast (90–99 % rejection before MT5 is healthy); success is cheap early deaths + real
   candidates reaching MT5 quickly. `ACTIVE_EDGE_DISCOVERY_PROGRAMMES = 0` while capacity exists and the book is slow = orchestration
   failure. Track `HYPOTHESIS_TO_CANARY_TIME`.
8. **Hypothesis output format (§28)** for every surviving idea: HYPOTHESIS_ID, ECONOMIC_RATIONALE, SYMBOLS, EXECUTION_SYMBOL,
   REFERENCE_SYMBOLS, TIMEFRAME, SESSION, ENTRY_RULE, STOP_RULE, EXIT_RULE, RISK_RULE, EXPECTED_BOOK_ROLE, EXPECTED_OVERLAP,
   COST_SENSITIVITY, FALSIFICATION_TEST, DISCOVERY_SAMPLE, VALIDATION_SAMPLE.
9. **Sunday incumbent and shadow stay separate:** only fully validated material candidates enter the incumbent; everything else continues
   in the shadow at maximum speed.
10. **Required report fields:** P50/P80/P90_DAYS_TO_FIRST_NET_PAYOUT, PAYOUT_30D/45D/60D/90D, INCUMBENT_BOOK, SHADOW_BOOK,
    DELTA_SHADOW_P80, ACTIVE_EDGE_DISCOVERY_PROGRAMMES, NEW_ORIGINAL_HYPOTHESES, NEW_CROSS_SYMBOL_HYPOTHESES, NEW_ML_DISCOVERED_PATTERNS,
    NNFX_ACTIVE_CANDIDATES, BREAK_RETEST_ACTIVE_CANDIDATES, OPTIMIZATION_ACTIVE_LINEAGES, PRESCREEN_SURVIVORS, NEW_Q02_CANARIES,
    NEW_Q04_SURVIVORS, NEW_MARGINAL_BOOK_POSITIVE_SLEEVES, BEST_P80_IMPROVEMENT, STRONGEST_MISSING_BOOK_ROLE.

Recorded by Fable 2026-09-21 ~21:1xZ. Invariants unchanged (evidence immutability, no secrets, HR14, bounded risk, FTMO compliance,
production discipline, §68A gate versioning; sole OWNER approval = paid Challenge purchase).
