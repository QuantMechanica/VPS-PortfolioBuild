# Staged recovery attempt — 34 Q02 stranded-exhausted pairs — router task `d1a5e5aa-061b-49a8-ae81-f0c6c2a70683`

Date: 2026-08-29, 06:33-06:50 UTC

## Classification

Ran the canonical read-only classifier
(`tools/strategy_farm/classify_q02_stranded_pairs_report.py`, cohort predicate
identical to `health.chk_q02_stranded_exhausted_pairs`) fresh:
`docs/ops/evidence/2026-08-29_q02_stranded_pairs_classification.{json,csv}`.
Confirms 34 pairs / 422 rows. Primary-cause breakdown: `ACTIVE_TIMEOUT` 16,
`SETFILE_MISSING` 6, `ONINIT_FAILED` 4, `SUMMARY_MISSING_NO_ROW_BOUND_AGGREGATE`
3, `NO_HISTORY_TRANSIENT` 2, `TIMEOUT_METATESTER_HUNG` 2, `LOG_BOMB` 1.

Every single record in the classifier's own output carries `proposed_action`
`REPAIR_OR_PREFLIGHT_THEN_GOVERNED_CANARY`, `REPAIR_SETFILE_BEFORE_ANY_CANARY`,
or `FORENSIC_REVIEW_NO_REQUEUE` — **none** is a bare requeue candidate, and
the tool's own `governed_canary_proposal.status` is explicitly
`PROPOSAL_ONLY_NOT_AUTHORIZED_NOT_EXECUTED` with `candidates: []` in every
cause group. Per standing memory, `ONINIT_FAILED` rows are additionally never
blindly requeued (deterministic OnInit pin defect class).

## Canary attempt and hard blocker found

Per the classifier's release policy ("row 2 remains unqueued until row 1 has
a reviewed terminal disposition"), I attempted exactly one sequential canary
in the largest actionable group (`ACTIVE_TIMEOUT`, 16 pairs) after verifying
the checkable preconditions for `QM5_1383` / `NDX.DWX`
(work item `9210ba34-23f8-419b-bced-bd47a0d25aff`):

- progress-aware reaper mechanism confirmed deployed in current
  `farmctl.py` (`absolute_ceiling_min`/`age_min` age-based reap logic);
- current `.ex5` present, hash `21b3ce37dc9461f9c7a144cfa018048275439dd3550fe83fac63afa4d26d4f6f`;
- current setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `environment: backtest`;
- news calendar directory refreshed 2026-08-28 (within the 336h bound);
- cohort SQL already guarantees no pending/active successor exists.

Ran the canonical path,
`farmctl.py enqueue-backtest --ea QM5_1383 --phase Q02 --from-work-item-id
9210ba34-... --append-only-rerun-of 9210ba34-... --rerun-reason "..." --expected-current-ex5-sha256 21b3ce37...`.
**Refused: `q02_rerun_source_evidence_missing`.** The governed rerun path
(`farmctl._enqueue_q02_append_only_exact_row_rerun`) requires the source
row's evidence log to still exist on disk and be hash-bindable before it will
create a successor; `D:\QM\strategy_farm\logs\work_item_9210ba34-...log` does
not exist.

I then checked all 20 pairs across the three cause groups the classifier
marks as runtime/transient (`ACTIVE_TIMEOUT`, `TIMEOUT_METATESTER_HUNG`,
`NO_HISTORY_TRANSIENT`) for `source_log_exists`/`source_evidence_exists` in
the classification JSON: **all 20 are `False`/`False`.** This is systemic,
not row-specific — every row old enough to be in this >=12-INFRA_FAIL cohort
has already had its backing log/evidence purged, consistent with the known
manual D: disk crisis cleanups (nothing survives before 2026-07-07; several
rows here post-date that but were still swept in later cleanups).

## Verdict

**0/34 pairs requeued this cycle.** The blocker is not the per-cause-group
repair items the classifier lists (setfile regen, OnInit diagnosis, etc.) —
it is a harder, cohort-wide one: the append-only-rerun evidence-binding
contract (deliberately, correctly) refuses to manufacture a successor for a
terminal row whose original evidence is gone, and none of the 34 rows has
surviving evidence. Bypassing that check would mean re-running backtests
without being able to verify what the original terminal disposition actually
observed — a verdict-integrity change, which is ROT under the standing
authorization, not something this ticket may do autonomously.

## Recommendation (Entscheidungsschlange item)

OWNER decision needed on exactly one of:
1. Treat evidence-missing terminal `INFRA_FAIL` rows (this class, currently
   34 pairs / cohort-wide) as requeue-eligible via a narrowly-scoped,
   explicitly-dated repair authority (matching the existing pattern used
   elsewhere in `compile_work_items.py` for other named, task-bound
   exceptions), since the row's aggregate metadata (attempt count, verdict
   reason, timestamps) is still intact even though the raw log file is gone; or
2. Accept these 34 pairs as currently unrecoverable via requeue and route them
   to a disposition review/retire track instead.

No further action taken pending that decision; nothing was mutated in farm
state by this ticket.
