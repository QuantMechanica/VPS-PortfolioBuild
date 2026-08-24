# Evidence — rb-orthogonal-strategies

Date: 2026-08-24

Ticket evidence filename retains the requested `2026-08-23_<ticket>.md` convention.

Scope: research census + 20 incoming G0 Strategy Card drafts. No build, backtest, enqueue, verdict, registry, factory, portfolio, deploy, `T_Live`, or gate-criteria mutation.

## What changed

1. Added a read-only, deterministic heterogeneous-card census and Q08-frontier join: `tools/strategy_farm/orthogonal_card_census.py`.
2. Added a reproducible, fail-closed generator for exactly 20 incoming Wave-2 cards: `tools/strategy_farm/generate_orthogonal_wave2_cards.py`.
3. Added unit tests for taxonomy/carrier requirements, Q08 joining, exactly four cards per mechanism, literal timeframes, declared parameter counts, registered DWX targets, and refusal to overwrite existing cards.
4. Added the Wave-2 research report: `docs/research/ORTHOGONAL_WAVE2_2026-08-24.md`.
5. Wrote 20 drafts to canonical G0 intake `D:/QM/strategy_farm/artifacts/cards_draft/`; all use `status: DRAFT`, `g0_status: PENDING_REVIEW`, and pending IDs rather than registry EA IDs.

Implementation pointers (line numbers before the ticket commit):

- taxonomy labels and canonical family/mechanism rules: `tools/strategy_farm/orthogonal_card_census.py:42`, `:97`, `:119`;
- heterogeneous front-matter parser and Q08 census join: `tools/strategy_farm/orthogonal_card_census.py:145`, `:178`, `:205`;
- five four-card specification groups: `tools/strategy_farm/generate_orthogonal_wave2_cards.py:65`, `:121`, `:170`, `:217`, `:268`;
- rendering and fail-closed external writer: `tools/strategy_farm/generate_orthogonal_wave2_cards.py:323`, `:414`;
- generator invariants: `tools/strategy_farm/tests/test_generate_orthogonal_wave2_cards.py:12-45`;
- census and frontier-join unit coverage: `tools/strategy_farm/tests/test_orthogonal_card_census.py:27-81`;
- distribution, selection rationale, and 20-file manifest: `docs/research/ORTHOGONAL_WAVE2_2026-08-24.md:21`, `:38`, `:53`, `:85`.

## Measured evidence

Command:

```powershell
python tools/strategy_farm/orthogonal_card_census.py `
  --approved-dir D:/QM/strategy_farm/artifacts/cards_approved `
  --census-csv D:/QM/reports/rebaseline/census_2026-08-23.csv
```

Observed:

- approved root cards: 3,272;
- Q08-valid census: 26 pairs / 26 EAs;
- joined approved cards: 20; unjoined EAs: 6;
- selected mechanism counts (approved / joined frontier): index volatility-liquidity reversal `0/0`, FX local-session inventory drift `1/0`, carry-unwind crisis momentum `2/0`, FX benchmark-fix rebalancing `4/0`, scheduled-announcement risk premium `8/0`;
- explicit raw `family`, `mechanism`, and `strategy_family` fields in the legacy runtime corpus: zero;
- worktree approved-seed duplicate guard: 675 cards, 133 `QM5_41*.md`, 165 commodity-monthly-momentum classifications, and 174 cross-instrument-RV classifications. This is why monthly commodity and XAU/XAG RV were not selected even though runtime synchronization is stale.

Source files: `D:/QM/reports/rebaseline/census_2026-08-23.csv`, `D:/QM/strategy_farm/artifacts/cards_approved/`, `strategy-seeds/cards/approved/`, and `framework/registry/dwx_symbol_matrix.csv`.

## Card validation

Command (run once per generated card):

```powershell
python C:/QM/repo/framework/scripts/skill_card_schema_lint.py --card <card>
```

Observed aggregate: `LINT_CARD_COUNT=20 LINT_FAILURES=0`. Every result was `status=ok`, with no forbidden ML-library token and no missing `## Hypothesis`, `## Rules`, or `## Risk` section.

## Test output

Targeted unit tests before intake write:

```text
python -m pytest tools/strategy_farm/tests/test_generate_orthogonal_wave2_cards.py tools/strategy_farm/tests/test_orthogonal_card_census.py -q
........                                                                 [100%]
8 passed in 0.86s
```

Full required suite:

```text
python -m pytest tools/strategy_farm/tests -q
4 failed, 4629 passed, 4 skipped, 2 warnings, 42 subtests passed in 1746.68s (0:29:06)
```

The four failures reproduce in isolation (`4 failed in 1.60s`) and are outside this ticket's changed paths:

1. `test_build_gate_hardening.py::test_qm5_411xx_sources_have_no_unbounded_numeric_buffers` — seven pre-existing `framework/EAs/QM5_411xx` buffer-bound findings; first reported at `QM5_41134...mq5:599`.
2. `test_execution_contract_lint.py::test_20030_20032_bindings_follow_deployed_calendar_but_remain_blocked` — fixture expects primary calendar SHA `42b02a...` and coverage end `2026-08-21`; current dependency reports SHA `d487e6...` and `2026-08-29`.
3. `test_execution_contract_lint.py::test_20009_ftmo_news_calendar_is_exact_and_evidence_bound` — the same external primary/secondary calendar refresh invalidates frozen fixture hashes.
4. `test_opt_census_dispatch.py::test_opt_census_ranks_tier6_not_priority` — existing dispatch SQL returns rank 6 while the active-v4-derived expectation is 7.

These failures were not repaired because doing so would mutate unrelated EA safety, calendar evidence contracts, or gate dispatch semantics, beyond this research-only ticket. The two new test files pass in both the targeted and full-suite runs.

## Safety assertions

- State DB was not written. The frontier came from the pre-existing read-only census CSV; no SQL write connection was opened.
- No card was placed in `cards_approved`; all 20 went to `cards_draft` for cross-agent G0.
- The generator refuses to overwrite any existing filename.
- No backtest/build/registry/factory/verdict command was executed.
- `C:/QM/mt5/T_Live` was not read or touched, and AutoTrading/factory state was not changed.

## Rollback

1. Revert the ticket commit using `git revert <commit>` to remove the two modules, two test files, research report, and this evidence file.
2. Remove only the 20 exact pending filenames listed in `docs/research/ORTHOGONAL_WAVE2_2026-08-24.md` from `D:/QM/strategy_farm/artifacts/cards_draft/`. They are unapproved drafts; no approved card, EA registry row, magic row, task, work item, or verdict depends on them.
3. Do not delete or modify any other file in `cards_draft`; the directory contained pre-existing user/agent drafts before this ticket.
