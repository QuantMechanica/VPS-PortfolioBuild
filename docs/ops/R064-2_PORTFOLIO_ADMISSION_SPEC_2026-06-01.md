# R-064-2 — Portfolio-relative admission path — Engineering Spec

**Date:** 2026-06-01 · **Authority:** DL-064 R-064-2 (already ratified) · **Execution:** Codex
**Builds on:** Wave-2 portfolio machinery (`portfolio_common`, `portfolio_kpi`).

## Why
The core "Monster" mechanism (Kaspareit / Dalio anti-correlation): an EA that
is mediocre standalone (below the Q02 profitability bar) can be a load-bearing
sleeve **if** it is anti-correlated to the existing book and improves the
portfolio. R-064-2 gives such an EA an admission path — **without** relaxing the
robustness gates.

## Hard rule (do not weaken)
The robustness gates (Q04 WF, Q05/Q06 stress, Q07 multi-seed, Q08 Davey, Q10 OOS)
stay mandatory. R-064-2 relaxes ONLY the *profitability* bar, and ONLY when all
three hold (a ∧ b ∧ c):
- (a) the EA-symbol passed all robustness gates (caller asserts; this module does
  NOT re-judge robustness — it only evaluates diversification);
- (b) low/negative correlation to the current admitted book (≤ `--max-corr`,
  default **0.30**, using the net-of-cost daily series + the existing Pearson
  logic; insufficient-overlap pairs are treated as NOT proven-uncorrelated →
  not admissible on (b));
- (c) adding it **improves** the portfolio: portfolio Sharpe up OR portfolio
  max-DD down vs the book without it (marginal contribution), using `portfolio_kpi`.

## Deliverable — `tools/strategy_farm/portfolio/portfolio_admission.py`
- `current_book(...) -> list[(ea_id,symbol)]`: the admitted book = `portfolio_candidates`
  rows (read via `portfolio_common.read_candidates`); empty today → discovery
  fallback documented.
- `evaluate_candidate(candidate_key, book_keys, common_dir=..., *, max_corr=0.30,
  starting_capital=10_000) -> dict`: returns
  `{admit: bool, reason, standalone_pf, max_corr_to_book, corr_insufficient,
    sharpe_with, sharpe_without, maxdd_with, maxdd_without, diversifies: bool}`.
  Logic: compute the candidate's max correlation to any book member (net-of-cost
  daily series, min-overlap rule from `portfolio_correlation`); compute portfolio
  KPIs with and without the candidate (equal-weight via `portfolio_kpi`).
  `diversifies = (sharpe_with > sharpe_without) or (maxdd_with < maxdd_without)`.
  `admit = (max_corr_to_book <= max_corr and not corr_insufficient and diversifies)`.
  Empty book → admit any robustness-passed EA (first sleeve), reason
  `first_sleeve`.
- CLI: `--candidate ea_id:SYMBOL`, `--all-streams`, `--max-corr`, `--out`
  (artifact `portfolio_admission_<ea>_<sym>.json` in DEFAULT_ARTIFACT_DIR with
  the dict above + `commission_basis`/`degraded`).
- This module is **advisory** in v1: it emits the verdict artifact. Wiring it into
  the gate state machine (so a below-Q02 EA with `admit=true` advances) is a
  SEPARATE controller change (not in this task) — keep it a clean library + CLI.

## Acceptance — `tools/strategy_farm/tests/test_portfolio_admission.py`
- empty book → `admit=true`, reason `first_sleeve`.
- candidate anti-correlated to book + improves Sharpe → `admit=true` even with low
  standalone PF.
- candidate highly correlated to book (corr > max_corr) → `admit=false` (reason
  names the correlation), regardless of standalone PF.
- candidate that worsens both Sharpe and max-DD → `admit=false` (reason
  `no_diversification`).
- insufficient overlap with the book → `admit=false` (not proven uncorrelated).
- stdlib + numpy; reuse portfolio_common/portfolio_kpi; deterministic.

## Constraints
- REUSE portfolio_common + portfolio_kpi; do NOT duplicate the loader/cost rule/KPI.
- Do NOT touch the gate state machine, Q04, scopes, or other agents' code.
- Never admit on (b) or (c) alone — both required (plus robustness asserted by caller).
