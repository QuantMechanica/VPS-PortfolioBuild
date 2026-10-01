# Q08 prescreen measurement boundary — producer/consumer fail-closed fix

Task: `ac9748bc-3fec-408f-aaf6-34253cea5ab0` (ASTRA_Q08_UNMEASURED_SKIP_RETURN_GUARD)
Authority: `decisions/2026-09-26_owner_astra_ftmo_takeover.md`
Inputs read (from `agents/board-advisor`, `docs/ops/evidence/2026-09-26_astra_takeover/q08_prescreen_measurement_boundary/`):
`ACCEPTANCE.json`, `KIMI_CRITIQUE.md`, `observation.json`, `existing_seal_inventory.json`.

## Problem

`tools/strategy_farm/dl089_prescreen_retro.py:disposition()` (the producer) re-authenticates
only *permission to omit measurement* of a held census cell — its return value is literally
`{'unmeasured': True, ...}`. `tools/strategy_farm/dsr_cohort.py:_peer_metric()` (the consumer)
treated any re-authenticated skip as license to extend the trial's return series with a
full zero-filled calendar year, i.e. it silently promoted "we chose not to measure this" into
"we measured zero". KIMI_CRITIQUE.md calls this out precisely: the authenticated artifact is a
screening disposition, not a trade log or a preregistered no-trade policy; treating the zeros as
measured corrupts the DSR cross-section with selection-filtered pseudo-observations.

This behavior was deliberate and OWNER-ratified at the time
(`OWNER-DEC-Q08-SWEEP-ARM-CONTEXT-20260914`, ticket `7d9dd3b5`,
`tools/strategy_farm/tests/test_dsr_cohort_prescreen_skip.py`), but the latest OWNER standard
(realistic evidence, no fabricated returns, full trial accounting) supersedes it per
`ACCEPTANCE.json`/`observation.json`.

## Blast radius (from `existing_seal_inventory.json`, 94 sealed cohort files scanned)

3 files hit the prescreen-skip provenance pattern; 5 directly-linked Q08 work items, all
verdict `INVALID` or `FAIL_HARD` (`665312e1.../QM5_20266`, `914dfeda.../QM5_21507`,
`0abc6911.../QM5_10706`, `cf45aa97.../QM5_10706` → INVALID; `17ab917a.../QM5_10706` →
FAIL_HARD). **No PASS verdict in the inventory depends on this convention.**
`new_holds_installed: false`, `prior_verdicts_changed: false` — this was a read-only audit;
nothing has been retroactively touched by it or by this change.

## Fix (smallest fail-closed boundary)

`tools/strategy_farm/dsr_cohort.py:_peer_metric()`: an authenticated skip (`_dsr_prescreen_skip`
not `None`) is now **only** admitted as a zero-filled measured year if the disposition also
carries a separately authenticated `causal_no_trade_proof` key — distinct from `unmeasured`.
No producer in the codebase sets that key today, so every currently-authenticated skip now
fails closed with a new named reason, `UNMEASURED_PRESCREEN_SKIP_REQUIRES_CAUSAL_NO_TRADE_PROOF`,
instead of silently becoming a measured zero. The arm/year is **not** dropped from the declared
cohort (`_matrix_trial_groups` coverage/count checks are unchanged) — it stays a real,
accounted-for trial that is currently unmeasurable, surfacing as a whole-candidate
`CohortUnavailable` (same shape as every other `CohortUnavailable` reason this producer already
raises), not a silently shrunk passing subset.

- `tools/strategy_farm/dl089_prescreen_retro.py` is **unchanged** — the producer's own
  receipt/contract authentication stack is a separate, already-governed component and is out of
  scope here (recovering/defining `causal_no_trade_proof` is "a separately reviewed
  information-value decision", per the task objective).
- Already-sealed cohort documents on disk (content-addressed under
  `D:\QM\strategy_farm\artifacts\dsr_cohorts\...`) are historical fact and are not rewritten,
  deleted, or reinterpreted by this change. Old decisions/receipts/verdicts remain exactly as
  they were. `dsr_cohort.replay()` is a read-only diagnostic that already has a legitimate
  `UNAVAILABLE` outcome — it will now report that outcome for arms depending on this convention,
  which is the intended, visible divergence between old-contract replay and current admission
  policy; it mutates nothing.
- No OWNER gate added. No code activated in the canonical checkout — `C:/QM/repo` is the live
  factory's imported module source and must never receive a half-reviewed edit to a module the
  worker fleet imports at runtime (2026-09-22 SyntaxError incident). This patch is therefore
  staged as a reviewable diff, not applied to `C:/QM/repo` or merged to `agents/board-advisor`.

Net diff: 46 lines (see `patches/dsr_cohort.py.diff`), additive only inside the existing
`skip is not None` branch of `_peer_metric`.

## Verification

Environment constraint: this worktree (`agents/claude-orchestration-2`) predates
`tools/strategy_farm/dsr_cohort.py` entirely (file does not exist on this branch — the worktree
is thousands of commits behind the line of work this file lives on). Per the hard rule against
writing code into `C:/QM/repo` (the live `agents/board-advisor` checkout the factory imports
from), the fix was developed and tested against a throwaway, package-complete copy of
`tools/strategy_farm` archived from `agents/board-advisor` HEAD into
`sandbox/` (private to this task directory, never imported by any live worker, not committed —
too large/duplicative to keep permanently; the patch files below are the durable artifact).

- `patches/orig/dsr_cohort.py`, `patches/orig/test_dsr_cohort_prescreen_skip.py` — unmodified
  `agents/board-advisor` content (hashes in `verification/source_hashes.json`).
- `patches/dsr_cohort.py.new`, `patches/test_dsr_cohort_prescreen_skip.py.new` — full patched
  contents.
- `patches/dsr_cohort.py.diff`, `patches/test_dsr_cohort_prescreen_skip.py.diff` — unified diffs
  against the above originals.
- `verification/pytest_patched.txt` — with the patch applied: the rewritten
  `test_dsr_cohort_prescreen_skip.py` (9 tests, covering: authenticated skip with nonzero
  early-year fire counts fails closed; the `causal_no_trade_proof` escape hatch is admitted and
  its proof is bound into provenance; a terminal `SKIPPED_PRESCREEN`-shaped row without
  re-authentication is still `UNMEASURED_OR_PRUNED_TRIAL`; no-hold still `INCOMPLETE_TRIAL`; a
  forged/un-reauthenticatable receipt still fails closed under its own named reason; a legacy
  sealed zero-imputed document is unchanged by running the current code path while the
  equivalent live row now fails closed — old-contract replay vs. current policy stay
  distinguishable; a genuine native zero-trade report (real `MEASURED` row, 0 closed trades)
  is still admitted as a real measurement, not an imputed skip zero; an ordinary sibling arm
  still measures correctly while the skip arm fails closed, with both declared arms still
  present in `_matrix_trial_groups` — no silent trial-count shrinkage) — **9/9 pass**; plus a
  broader regression pass of `test_dsr_cohort.py` + `test_dl089_prescreen_retro.py` run in the
  same harness — **16 passed, 2 failed, 4 errors**.
- `verification/pytest_baseline_parity.txt` — the identical broader-regression command run
  against the **unmodified** original `dsr_cohort.py` in the same harness — **same 16 passed, 2
  failed, 4 errors**, proving the failures/errors are pre-existing sandbox-harness gaps (two
  tests `import dsr_cohort` script-style, expecting a sys.path shim this throwaway harness
  doesn't reproduce; `test_dl089_prescreen_retro.py` pulls in `test_opt_census.py`, which needs
  an external doc file not archived into the sandbox) and not regressions introduced by this
  change.
- `verification/source_hashes.json` — sha256 of all four before/after files.

## Not done here (explicitly out of scope per task objective)

- No `causal_no_trade_proof` producer is implemented or designed. Recovering any of the affected
  unmeasured arms is "a separately reviewed information-value decision."
- No rerun of any trial, no change to DSR/FDR formulas, no change to declared trial counts, no
  change to any existing seal, receipt, or verdict.
- No canonical activation: this diff is not applied to `C:/QM/repo` / `agents/board-advisor`.
  `independent_methodology_review` (ACCEPTANCE.json's reviewer) and OWNER should review the diff
  before a maintainer applies it to the canonical `tools/strategy_farm/dsr_cohort.py` and the
  companion test file, and decides whether the in-package test file
  (`tools/strategy_farm/tests/test_dsr_cohort_prescreen_skip.py`) should be replaced wholesale by
  `patches/test_dsr_cohort_prescreen_skip.py.new`, or merged by hand.

## Recommended next step

Independent review of `patches/dsr_cohort.py.diff` (46 lines) against `KIMI_CRITIQUE.md`'s
"smallest safe next action" list, then apply both patches directly to `agents/board-advisor` in
a normal (non-worktree-constrained) review/merge pass, run the full
`tools/strategy_farm/tests/` suite there (this task's sandbox harness could only prove parity on
a subset — the canonical checkout has the full dependency graph), and only then decide whether
`causal_no_trade_proof` recovery work is worth opening as its own task.
