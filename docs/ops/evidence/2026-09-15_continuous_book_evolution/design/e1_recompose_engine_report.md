# Slice e1_recompose_engine — Continuous book recomposition engine (Phase E)

Date: 2026-09-15. Authority: OWNER-DEC-CBE-20260915 (directive §5–§9, §57–§59, §68E, §70).
Author: implementation subagent (board-advisor worktree). Branch `agents/board-advisor`.

## What this slice does

Builds `tools/strategy_farm/portfolio/recompose/` — a thin, deterministic composition over
the existing ~170-module portfolio package that ingests a **frozen input snapshot** and
emits, per venue, the §58 recomposition object (KEEP/CHANGE, roster, weights, adds, removes,
replaces, expected metrics, marginal contribution, uncertainty, operational risk) with the
full §7 metric set, the §57 venue fitness, the §59 materiality/anti-churn predicate and the
§6 outcome. It does **not** reimplement KPIs/correlations/weighting — it calls
`portfolio_kpi`, `book_builder_common`, `portfolio_correlation`, `concentration_tail`,
`risk_diagnostics`, `portfolio_common`. Adds the three audit-flagged gaps: effective number
of independent bets, explicit downside correlation, holding-time aggregation; plus entry-day
trade-overlap Jaccard and session overlap.

Ran it for real for both venues (ISO week 2026-W38); read-models left in place.

## Files changed / added

New package `tools/strategy_farm/portfolio/recompose/`:
- `__init__.py` — package doc.
- `frozen_snapshot.py` — `freeze()` (schema `qm.recompose-frozen-inputs/v1`): qualified pool
  from `book_build_guard._qualified_pair_rows` (census; NOT `candidate_qualifications`) with a
  durable `candidate_universe.csv` fallback; incumbent roster(s) (DXZ live-24 + planned-v2-28,
  FTMO demo-8); per-pair sealed streams copied byte-for-byte + sha256 pinned; live/demo
  evidence pointers; venue constraints (concentration policy) + FTMO contract sha; self-
  contained snapshot dir; `load_snapshot()` re-hashes every copied stream (§70). Refuses an
  empty pool AND empty incumbent with a reason.
- `metrics.py` — `compute_roster_metrics()` (§7 vector) + `book_by_date()` + `effective_number_of_bets()`.
- `dxz_fitness.py` — `compute_dxz_fitness()` (§57 DXZ objective, deterministic composite).
- `venue_fitness.py` — registry; DXZ local, FTMO via lazy import of
  `tools/strategy_farm/ftmo/ftmo_fitness.py:compute_ftmo_fitness` (degrades to NOT_EVALUATED
  when absent); `register_venue_fitness()` test hook.
- `alternatives.py` — `enumerate_alternatives()` (incumbent, +challenger, −weakest,
  replacements) + `weights_for()` via `book_builder_common.capped_inverse_vol`.
- `materiality.py` — `assess()` (§59: expected improvement + DXZ ratified Sharpe/DD gate,
  seeded block-bootstrap confidence, downside risk, model/live uncertainty, switching cost,
  operational complexity, economic band → `material: bool`; default KEEP). Bootstrap is lazy
  (only when the cheap gates pass) to keep evaluation fast and deterministic.
- `decide.py` — `decide()` maps to the §6 outcome enum (default KEEP; NO_VALID_CHANGE /
  CONTINUE_OBSERVATION when fitness not evaluable).
- `recompose.py` — CLI `freeze` / `evaluate` per the shared contract.

Edited (audit D4):
- `tools/strategy_farm/assemble_stream_bundle.py` — docstring + `DEFAULT_SEARCH_ROOTS`: the
  current v2 sealed bundle (`dxz_v2_20260913/streams_v2b`, `/streams`) is searched ahead of
  the stale July `dxz_final_20260719` fallback. Acceptance stays content-hash gated, so this
  only changes which matching file is found first, never whether a stale file could be
  accepted. Cites the audit + OWNER-DEC-CBE-20260915.

Tests:
- `tools/strategy_farm/tests/test_recompose_engine.py` (new).

Report: this file. Runtime read-models under `D:/QM/reports/...` (below).

## Contracts written (exactly per the shared spec)

- `D:/QM/reports/state/book_evolution_dxz.json` — `qm.book-evolution-venue/v1`.
- `D:/QM/reports/state/book_evolution_ftmo.json` — `qm.book-evolution-venue/v1` (+ `demo_cycle`
  mirrored from `ftmo_challenge_readiness.json` when present).
- `D:/QM/reports/book_evolution/<ISO-week>/<venue>/evaluation.json` + `evidence.md`.
- CLI: `recompose.py freeze --venue dxz|ftmo --out <dir>`; `... evaluate --venue dxz|ftmo
  --snapshot <dir> --out <json>`.
- New snapshot contract `qm.recompose-frozen-inputs/v1` (frozen_snapshot.py).

`ftmo_challenge_readiness.json` and `ftmo_fitness.py:compute_ftmo_fitness` are F1-owned; E1
imports the fitness lazily (degrades to NOT_EVALUATED) and mirrors the readiness `demo_cycle`
if the file exists — both handled without F1 present.

## Tests + pytest summary

`python -X utf8 -m pytest tools/strategy_farm/tests/test_recompose_engine.py -q`
→ `9 passed in 3.36s`.

Neighbour regression sweep (imported/adjacent):
`pytest test_recompose_engine test_assemble_stream_bundle test_concentration_tail
test_dxz_next_book_trigger test_book_build_guard test_dual_book_builders -q`
→ `84 passed, 1 skipped in 6.70s`.

Test coverage maps to the §70 list: reproducibility (freeze once → evaluate twice →
byte-identical evaluation.json), 3-pair pool evaluates with no count condition, empty pool
refuses with reason, venue fitness separate (DXZ vs FTMO objective differ on the same
fixture), materiality default KEEP on noise, change only when improvement clears thresholds,
cap warnings from `risk_diagnostics` carried into output (advisory, book still builds,
dependence panel enriched with downside correlation + trade overlap).

## Real run (ISO week 2026-W38, seed 20260918)

Reproducibility verified on real data: two evaluates of the same snapshot produced
byte-identical `evaluation.json` and read-model.

- **DXZ** — qualified pool **26**, 44 streams present / 0 missing (union of pool + live-24 +
  planned-v2-28; all resolved from `sleeve_streams` / `streams_v2b`). Incumbents evaluated on a
  CONSISTENT capped-inverse-vol weighting at the 11.0 % design budget (decision basis; the
  live book's declared 9.75 % weights are kept for provenance in the read-model incumbent):
  live-24 fitness `0.6951` (ann 11.01 %, maxDD 3.68 %, Sharpe 2.43, ENB 23.3),
  planned-v2-28 fitness `0.7069` (ann 10.44 %, maxDD 2.78 %, Sharpe 2.39, ENB 26.1).
  **Outcome: ADD_SLEEVE** — the single material alternative is **add 10700 XAUUSD.DWX**
  (Δobjective +0.0122, block-bootstrap CI excludes 0, DXZ ratified Sharpe/DD gate PASS).
  This independently corroborates the human-planned v2 cutover, which already adds 10700 as
  one of its 4 new sleeves. `owner_action = REVIEW_PROPOSED_CHANGE` (artifacts prepared; live
  deployment / AutoTrading remain OWNER-only). No advisory concentration cap warning; hard
  portfolio guards pass; 276-entry dependence panel (pairwise + downside corr + trade overlap).
- **FTMO** — qualified pool 26, incumbent = the 8-sleeve demo roster (2.5 % nominal).
  **Outcome: CONTINUE_OBSERVATION** — FTMO_FITNESS (first-passage / breach probability) is
  NOT_EVALUATED (slice F1's `ftmo_fitness.py` not yet importable); `owner_action = NONE`.
  `demo_cycle` mirrored from the (now-present) `ftmo_challenge_readiness.json`
  (roster_hash, 8-sleeve roster, representative=false, validation 0/14 days). This matches the
  honest FTMO state: no rule-faithful representative 2-week demo of a frozen challenge book
  has completed, so no purchase signal.

Incumbent-vs-qualified reconciliation is written explicitly to `evidence.md` (not silently
dropped): live-24 overlaps the qualified-26 by 6; planned-v2-28 overlaps by 10 (matches the
Phase-A snapshot §3); non-qualified incumbents are listed and labelled as needing DL-089
requalification, retained rather than dropped.

## Determinism / boundaries

Deterministic code for all numbers (§26). The only RNG is the §59 materiality block-bootstrap,
seeded from the snapshot `seed`; engine output timestamps are the snapshot freeze instant, so
evaluation is a pure function of the frozen snapshot (§70). No farm-DB write (DB read-only,
mode=ro), no terminal start, no deployment, no AutoTrading toggle, no gate/verdict change, no
evidence rewrite. Backtests/MT5 workers unaffected.

## Rollback

- Delete the `tools/strategy_farm/portfolio/recompose/` package and
  `tools/strategy_farm/tests/test_recompose_engine.py`; revert the `assemble_stream_bundle.py`
  docstring + `DEFAULT_SEARCH_ROOTS` hunk. No other module was modified, so nothing else needs
  reverting. The generated read-models under `D:/QM/reports/` are additive diagnostics; remove
  the `book_evolution_*` files if a clean state is wanted (they contain no verdicts).
- No environment flag gates the slice.

## Items NOT done (with reasons)

- **`portfolio/ftmo_next_book_trigger.py`** — NOT added. The slice says add it "only if the
  audit's design needs it for FTMO KEEP/CHANGE (else leave to F1)". `decide.py` produces the
  FTMO §6 outcome generically (CONTINUE_OBSERVATION / NO_VALID_CHANGE while FTMO_FITNESS is
  NOT_EVALUATED, KEEP/change once F1's fitness lands), so a separate DXZ-style trigger module
  is not required; the FTMO KEEP/CHANGE trigger is left to slice F1 alongside `ftmo_fitness.py`.
- **Swap cost per sleeve** — reported `EVIDENCE_MISSING`. The `portfolio_common.Trade` model
  carries `commission_cost` (modelled round-trip) but not swap, so swap is not invented as
  zero. Transaction cost (commission) IS aggregated.
- **Live-vs-backtest blend in `live_uncertainty`** — the materiality live-uncertainty factor
  currently checks live evidence presence/non-contradiction; the richer `dxz_live_blend_reweight`
  vol blend is left to the live-feed lane (audit dxz_live_book.md §E recommendations 2–3), which
  is separate infrastructure (per-sleeve live attribution refresh does not yet exist / is stale).
- **DXZ comparison budget** — the decision weights every roster (incumbent + alternatives) with
  a CONSISTENT capped-inverse-vol allocator at the 11.0 % design budget so the outcome reflects
  roster COMPOSITION, not a weighting artifact; the live book's actual declared 9.75 % weights
  are preserved for provenance in the read-model incumbent. This is a deliberate modelling
  choice, documented in `evidence.md`.
