# Q08.5/8.7 could-not-compute INVALID is INFRA_FAIL, not a terminal block (NARROW C2)

**Date:** 2026-07-25 · **Decided by:** OWNER (2026-07-25 push-directive, explicit veto
invitation) · **Executed by:** Claude · **Branch:** agents/board-advisor · **Status:**
**accepted** (narrow scope; veto window open — OWNER may revert on review).

**Scope guard:** one code change in `framework/scripts/q08_davey/aggregate.py`
(`_aggregate_verdict`) plus tests. No restructuring. Factory ON throughout; DB read-only,
no terminals, no backtests. Codex reviews before commit.

## Problem

Q08 sub-gates 8.5 (neighborhood stability) and 8.7 (PBO) require a **≥2-config
optimization grid / neighborhood-support artifact** that a fixed-param card EA's Q03
never publishes. When that artifact is absent or its lineage cannot be verified, the
sub-gate returns **INVALID** — meaning *the gate could not compute a verdict*, not *the
EA failed robustness*.

`_aggregate_verdict` was collapsing that could-not-compute INVALID into a **terminal
blocking INVALID** (the `blocking_invalid` branch), citing an inline "OWNER 2026-07-17"
comment. Tonight's sweep showed that label is shared by two structurally different
populations.

## The two populations sharing the INVALID label

| population | detail shapes (exact) | count | correct disposition |
|---|---|---|---|
| **Tooling-INVALID** (sub-gate COULD NOT COMPUTE) | `neighborhood_evidence_lineage_invalid:*`, `pbo_refresh_lineage_invalid:*`, `perturbations_runner_output_missing:*`, `insufficient_distinct_configs:*` | **~9 sleeves + stream-stranded** | retry-owed infra → **INFRA_FAIL** |
| **HARD failures** (COMPUTED breach) | `N_perturbation_breaches` (status **FAIL**), any computed `PBO=..%` FAIL | **~53 sleeves** | **fully blocking, UNTOUCHED** |

Counts are the 2026-07-25 sweep separation; exact per-detail counts must be recomputed
against live state at apply/observe time (DB was moving; read-only session).

## Why could-not-compute is a harness state, not a verdict

A tooling-INVALID is the **same class as WP-4 `ACTIVE_TIMEOUT`** and WP-3's
verdict-reason unification: the deterministic process did not reach a merit judgment
because an input artifact was missing/un-verifiable, so the honest taxonomy is
**INFRA_FAIL (retry-owed)**, not a terminal robustness reject. Terminally blocking a
fixed-param card EA on a `≥2-config` grid it *structurally cannot produce* converts a
harness gap into a false robustness failure — exactly the failure mode WP-3/WP-4 exist to
remove. The preserved sub-gate detail (via `farmctl._q08_dominant_invalid_reason`, WP-3)
already carries the honest reason forward on the work item, so INFRA_FAIL loses no
evidence.

## Verified absence of a ratifying record for the block

- The **only** `decisions/2026-07-17_*.md` file is `2026-07-17_t_live_dxz24_weekend_book.md`
  (T_Live weekend book) — unrelated to Q08.
- The actual 07-17 Q08 material —
  `docs/ops/evidence/032d28e1_q08_parameter_type_aware_repair_2026-07-17.md` — governs
  neighborhood/PBO **FAIL** ("A valid perturbation with PF ≤ 1.0 or DD above 1.5× baseline
  remains a hard neighborhood breach"; "the valid DD breach remains a blocking Q08.5
  FAIL") and **explicitly categorizes zero-trade / insufficient cells as *tooling-invalid*
  distinct from breaches** — i.e. it supports, not contradicts, this split.
- Cross-checked in `docs/ops/evidence/2026-07-25_codex_review_wp2346.md` (WP-3 review):
  Q08 aggregate INVALID already maps to INFRA_FAIL at the work-item taxonomy, and the
  observed aggregate shapes are `neighborhood_evidence_lineage_invalid...` (8.5) and
  `insufficient_distinct_configs...` (8.7).

No dated decision record ratifies "an unevaluable could-not-compute INVALID must be a
**terminal** block." The inline "OWNER 2026-07-17" comment overreached the FAIL ruling it
cited.

## Change (narrow)

In `_aggregate_verdict`, split the blocking 8.5/8.7 INVALID label via an **exact-prefix
whitelist** (`_q08_invalid_is_tooling`):

- tooling could-not-compute detail → new `INFRA_FAIL` outcome (retry-owed infra);
- everything else (deterministic defect, unknown/non-tooling INVALID) → **unchanged**
  blocking `INVALID`.

Precedence is preserved: a **COMPUTED FAIL in any sub-gate** (`hard`) still returns
`FAIL_HARD` above this branch; a **genuine blocking INVALID** still returns `INVALID`
above this branch; the tooling branch only fires when it is the *sole* blocking condition.

### Hard boundary (non-negotiable)

- **`N_perturbation_breaches` is UNTOUCHED.** It carries status **FAIL**, never INVALID, so
  it never reaches this classifier and keeps the `FAIL_HARD` path. Same for any computed
  `PBO=..%` FAIL.
- **`baseline_setfile_defect:*` is EXCLUDED from the whitelist** and stays a blocking
  INVALID. It is a *deterministic* build/setgen defect (07-19 RCA): re-derivation re-reads
  the same broken setfile and reproduces it, so it must stay INVALID precisely so the
  stranded-INFRA sweep refuses the doomed re-enqueue. It is not retry-owed.
- `degenerate_baseline` INVALID is already routed to INFRA_RECYCLE upstream (DL-082 §3a);
  it does not reach this branch.

### Exact tooling whitelist (source lines)

- `neighborhood_evidence_lineage_invalid` — `aggregate._neighborhood_lineage_invalid_result` (detail built at `aggregate.py:287`)
- `pbo_refresh_lineage_invalid` — `aggregate._pbo_refresh_invalid_result` (`aggregate.py:351`)
- `perturbations_runner_output_missing` — `sub_8_5_neighborhood.run` (`sub_8_5_neighborhood.py:48`)
- `insufficient_distinct_configs` — `sub_8_7_pbo.run` (`sub_8_7_pbo.py:90`) and `q08_7_pbo_runner.py:398`

## Tests

Added to `framework/scripts/tests/test_q08_davey_subgates.py`: whitelist unit test; both
tooling directions → INFRA_FAIL (8.5 lineage, 8.7 insufficient-configs); both blocking
directions stay INVALID (setfile-defect, unknown non-tooling); and the boundary —
tooling-INVALID + computed FAIL ⇒ FAIL_HARD wins. Existing q08 + verdict-taxonomy suites
stay green (75 in `test_q08_davey_subgates.py`, 104 across the four related suites).

## Authorization & veto

OWNER 2026-07-25 push-directive authorizes this narrow reclassification with an explicit
veto invitation. This record is the standing rationale; OWNER may revert on review, in
which case the `blocking_invalid` branch reverts to catching the tooling class.
