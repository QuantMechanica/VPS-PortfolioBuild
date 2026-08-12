# Book3 conservative-bound design v2 — Codex review R2 and implementation

Date: 2026-07-31
Task: `cca77792-d675-4212-ade5-038b208f232e`
Design: `docs/research/FTMO_BOOK3_CONSERVATIVE_BOUND_DESIGN_V2_2026-07-31.md`
Prior review: `docs/ops/evidence/2026-07-31_book3_sealed_validation_review.md`

## Verdict

**Agreement: 92%. Implementation threshold met.**

Design v2 resolves all seven R1 acceptance conditions. In particular, it no
longer claims that already inspected history can be selection-sealed, records
the research-trial lower bound honestly, chooses the exact per-run evidence
streams and current-terms cost snapshot, freezes dependence rules from IS only,
uses conservative lifetime-MAE semantics, and keeps mutable farm state out of
the verdict.

The remaining 8% is irreducible or deliberately deferred rather than a design
contradiction:

1. Existing historical bytes cannot clear the selection-sealed blocker. Every
   result remains `HISTORICAL_DIAGNOSTIC_NOT_SELECTION_SEALED`,
   `strict_qualification=UNVERIFIED`, and `paid_challenge=NO_GO`.
2. Lifetime MAE provides a sufficient conservative lower bound, not an
   event-complete equity reconstruction. The exact-event blocker remains open.
3. A real prepared config and diagnostic result do not exist yet. The required
   separately truncated IS streams must be materialized, reviewed, and committed
   before the implementation-review handoff can authorize one diagnostic run.
4. The dated swap/commission snapshot is a fixed-current-terms counterfactual.
   It does not reconstruct historical venue terms.

## R1 acceptance-condition check

| # | R1 condition | R2 disposition | Implementation enforcement |
|---:|---|---|---|
| 1 | Honest unsealed label and prospective route | Met | Historical label is constant; selection sealing is always false; prospective route is descriptive only. |
| 2 | Trial ledger at least 165 | Met | Every config/result carries `UNKNOWN_LOWER_BOUND_165`. |
| 3 | Exact window, starts, censoring, scenarios, phase and dependence rules | Met | Prague window is fixed to 2022-09-16 through 2025-12-30; exact two-scenario contract; right-censored outcomes are non-passes; phase reset and four dependence views are encoded. |
| 4 | One exact stream provenance contract with full lineage | Met | The 1,143/291/548 stream hashes and each summary/report/receipt/evaluation-manifest hash are hard-bound and verified. Substitute Q08 aggregates are refused. |
| 5 | Actual cost artifact and explicit replacement/margin arithmetic | Met | Cost digest `7eab3bf8…` is mandatory; source commission/swap are removed, target terms inserted, weekday Prague rollovers and Wednesday triple swap applied, and Swing margin is diagnostic only. Missing operands refuse. |
| 6 | Conservative-bound trace label and lifecycle/CE(S)T arithmetic | Met | Full-lifecycle-v1 rows, component reconciliation, half-open intervals, close-before-open ordering, Prague DST, every crossed day, entry commission, daily and total floors are enforced. |
| 7 | No mutable live DB in statistical verdict | Met | Config recursively refuses SQLite/farm-state inputs; module has no DB, terminal, Factory, pipeline, or live-state integration. |

## Implementation

Commit: `d6d2a8dfc` — `feat: add hash-bound Book3 diagnostic evaluator`

Files:

- `tools/strategy_farm/portfolio/book3_bound_eval.py`
- `tools/strategy_farm/tests/test_book3_bound_eval.py`

The implementation exposes two commands only:

```text
book3_bound_eval.py prepare-config --spec <is-only-spec.json> --output <config.json>
book3_bound_eval.py evaluate --config <config.json> \
  --expected-config-sha256 <reviewed-digest> --output <diagnostic.json>
```

Important fail-closed refinements made during implementation review:

- `prepare-config` parses only three separately truncated IS streams. It may
  hash the historical streams to pin identity, but it does not parse holdout
  outcomes to choose block/HAC parameters.
- `evaluate` independently proves that each IS stream is the exact multiset of
  full-stream rows whose entry and close both fall inside the IS window.
- The expected config digest is checked before any stream is opened.
- Full historical stream, lineage, cost, date, claim, scenario, rule, bootstrap,
  and IS-freeze identities are immutable config contracts rather than caller
  preferences.
- The merged Prague-day vector drives raw overlapping outcomes, deterministic
  greedy non-overlap, Bartlett HAC ESS, and flat-boundary moving-block bootstrap
  with full two-phase re-evaluation and frozen half/double sensitivities.

## Focused verification

No real Book3 diagnostic was run.

```text
python -m pytest -q tools/strategy_farm/tests/test_book3_bound_eval.py
16 passed in 0.71s

python -m pytest -q \
  tools/strategy_farm/tests/test_book3_bound_eval.py \
  tools/strategy_farm/tests/test_ftmo_book3_standalone_evaluator.py \
  tools/strategy_farm/tests/test_ftmo_book3_fidelity_gate.py
119 passed in 39.52s

python -m compileall -q \
  tools/strategy_farm/portfolio/book3_bound_eval.py \
  tools/strategy_farm/tests/test_book3_bound_eval.py
PASS

git diff --cached --check
PASS before implementation commit
```

The focused fixtures cover the mandated multi-day intraday breach, CET/CEST
23/25-hour boundaries, config SHA mismatch before evaluation, missing swap
refusal, and right-censor-as-non-pass behavior. They additionally cover
equal-timestamp half-open ordering, an exact-window start edge, source/target
cost replacement, weekend rollover exclusion, no-cut flat-boundary blocks,
exact IS derivation, required lineage, mutable-DB refusal, and strict JSON.

The optional `ruff` module was not installed in this checkout; compile, diff
integrity, focused tests, adjacent Book3 regressions, and CLI help were used as
the available verification set.

## Safety statement

This review and implementation performed no backtest, requeue, database write,
Factory action, terminal launch, T5/T_Live/AutoTrading action, pipeline verdict,
account action, or diagnostic run. It does not authorize a paid challenge or
live use. The next permitted step is Claude's implementation review.
