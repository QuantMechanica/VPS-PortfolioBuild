# Q09_NEWS (historical v3 lane) REVIEW_REQUIRED closure — 2026-09-13

Scope: the 64 `work_items` rows with `phase='Q09_NEWS'`, `status='done'`,
`verdict='REVIEW_REQUIRED'`. `Q09_NEWS` is the **historical (v3-named) storage
lane**; the active NEWS storage phase under `v4` is `Q10_NEWS`
(`farmctl._NEWS_PHASE`, `tools/strategy_farm/farmctl.py:423`).

Purpose: the live-book risk-freeze lift condition `NEWS-CONTRACT-V2`
(`tools/strategy_farm/risk_freeze.py:55-59`) is gated on "Q09 rerun completion".
These 64 rows are the open-review remainder of that lane. None of them can be
adjudicated by the existing governed path, and none of them may be edited.

## Why the existing governed tool does not cover them

`farmctl readjudicate-news-8cell` (`tools/strategy_farm/farmctl.py:19855-20190`)
is the canonical append-only re-adjudication path. It binds the **current**
storage phase only:

* `farmctl.py:19918-19927` refuses any source whose `phase != _NEWS_PHASE`
  with `readjudicate_source_not_done_review_row`;
* `farmctl.py:19828-19835` lists such rows under
  `excluded_historical_phase` / `readjudicate_source_phase_not_current`.

Observed refusal receipts (read-only dry runs, 2026-09-13):

```
python tools/strategy_farm/farmctl.py readjudicate-news-8cell --list
  -> eligible_count 0, excluded_historical_phase_count 1 (317b916e..., phase Q09_NEWS)

python tools/strategy_farm/farmctl.py readjudicate-news-8cell \
  --work-item-id 317b916e-f93f-43ce-9b40-1c43d1639a49
  -> {"readjudicated": false, "reason": "readjudicate_source_not_done_review_row",
      "facts": {"phase": "Q09_NEWS", "status": "done", "verdict": "REVIEW_REQUIRED",
                "matrix_scope": "7x1_target_compliance", "has_q09_news_test_row": true}}

python tools/strategy_farm/farmctl.py readjudicate-news-8cell \
  --work-item-id ba24e7a3-4edf-4dc1-b74d-5854a6b5ecf2
  -> same refusal
```

Therefore an append-only disposition tool is used:
`tools/strategy_farm/apply_q09_news_review_dispositions.py`, built on the
`apply_q09_retire2_dispositions.py` pattern (content-hashed plan, online SQLite
backup, `FactoryMutationLock`, `BEGIN IMMEDIATE` re-validation, INSERT of a
`kind='disposition'` successor row plus a `work_item_supersedes` edge).

**No historical row is updated. No verdict is overwritten or deleted. No
`q09_news_tests` / `q09_news_cells` / `q09_news_arms` row is written** — the
dispositions are adjudication *receipts*, not new seals. Gate thresholds and
`q09_news_contract.adjudicate` are untouched.

## The three classes

### A. SEALED_READJUDICATION — 10 rows

A sibling `q09_news_evidence.json` exists next to the row's
`q09_news_tests.aggregate_path`. The **current**
`q09_news_contract.adjudicate` rule is re-run over those sealed bytes (no tester
run) and its verdict becomes the disposition verdict.

| work_item | EA | symbol | cells | verdict | reason code | chosen temporal |
| --- | --- | --- | --- | --- | --- | --- |
| ba24e7a3 | QM5_11294 | XAUUSD.DWX | 40 | CONFIG_LOCKED | robust_policy_selected | SKIP_DAY |
| 317b916e | QM5_1354 | XAUUSD.DWX | 40 | CONFIG_LOCKED | robust_policy_selected | PRE60 |
| 4263d6b3 | QM5_20266 | XTIUSD.DWX | 40 | CONFIG_LOCKED | off_fallback_no_robust_improvement | OFF |
| 12bf0454 | QM5_21505 | XAGUSD.DWX | 40 | CONFIG_LOCKED | off_fallback_no_robust_improvement | OFF |
| db92d69a | QM5_12849 | XTIUSD.DWX | 40 | CONFIG_LOCKED | off_fallback_no_robust_improvement | OFF |
| c665c1aa | QM5_1537 | XAGUSD.DWX | 40 | CONFIG_LOCKED | off_fallback_no_robust_improvement | OFF |
| 46409fc4 | QM5_11294 | XAUUSD.DWX | 4 | INVALID_EVIDENCE | required_matrix_cells_missing | — |
| cba63d44 | QM5_11294 | XAUUSD.DWX | 23 | INVALID_EVIDENCE | required_matrix_cells_missing | — |
| 29fe5106 | QM5_11881 | GBPUSD.DWX | 32 | INVALID_EVIDENCE | required_matrix_cells_missing | — |
| cfa98980 | QM5_12855 | XTIUSD.DWX | 39 | INVALID_EVIDENCE | required_matrix_cells_missing | — |

A `CONFIG_LOCKED` disposition here is an **adjudication receipt only**: it does
not write a `q09_news_tests` seal, so it confers no downstream admission by
itself. Promotion of these four/six pairs under the active `Q10_NEWS` lane
remains a separate, separately authorized step.

### B. RUN_SMOKE_MISLABEL — 15 rows (created 2026-09-02, ran 2026-09-04)

`verdict_reason = RUN_SMOKE_EVIDENCE_NOT_Q09_NEWS_EXPERIMENT`.
Their `evidence_path` points at an ordinary run_smoke summary
(`"evidence_schema": "run_smoke/v2"`; measured `result` 14x `PASS` / 1x `FAIL`;
`news_calendar.primary_path = news_calendar_2015_2025.csv` in all 15). These
were never sealed Q09_NEWS experiments and carry no `q09_news_tests` row —
which is exactly why a `run_smoke` PASS must not be readable as a NEWS-gate
review.

Root cause chain (all three links required):

1. `tools/strategy_farm/oos_2026_confirmation.py:422` inserts the campaign rows
   with the **hard-coded phase literal `'Q09_NEWS'`** instead of the
   manifest-derived `q09_news_runner.NEWS_PHASE`
   (`ACTIVE_GATE_MANIFEST.storage_phase_for_role("NEWS","NEWS")` = `Q10_NEWS`
   under v4). `oos_2026_confirmation.py:451` repeats the literal in its
   validation.
2. `tools/strategy_farm/farmctl.py:10569` routes the NEWS runner only on
   `elif phase == _NEWS_PHASE:`. A `Q09_NEWS` row never matches, so it falls
   through to the **ordinary run_smoke backtest** command builder.
3. `tools/strategy_farm/terminal_worker.py:7506` short-circuits the sealed-
   sidecar guard (`if str(item["phase"]).upper() != _Q09_NEWS_PHASE: return
   True`, `_Q09_NEWS_PHASE` = `Q10_NEWS` at line 83), and
   `terminal_worker.py:8441-8451` then stamps
   `verdict, reason = "REVIEW_REQUIRED", "diagnostic_non_admission"` on any
   `diagnostic_non_admission` row **without checking that the summary is a
   `q09-live-news-diagnostic-summary/v1` document** — the run_smoke
   `summary.json` in the ordinary report directory satisfies the read.

Result: a run_smoke FAIL becomes a NEWS-lane `REVIEW_REQUIRED` verdict that is
indistinguishable, in any census keyed on `(phase, verdict)`, from a genuine
sealed Q09_NEWS review.

Proposed fix (no gate semantics change; not applied here):

* `oos_2026_confirmation.py:422/451` — derive the phase from
  `q09_news_runner.NEWS_PHASE`, and refuse at enqueue time when the resolved
  phase is not the active NEWS storage phase.
* `terminal_worker.py:8441` — before stamping the diagnostic verdict, require
  `summary.get("schema_version") == q09_news_runner.DIAGNOSTIC_SUMMARY_SCHEMA`
  and `summary.get("diagnostic_non_admission") is True`; otherwise fail closed
  with `INFRA_FAIL / diagnostic_summary_schema_mismatch`. This makes the
  existing `_q09_sidecar_matches` intent phase-independent.
* `terminal_worker.py:7506` — gate `_q09_sidecar_matches` on the **set** of
  NEWS storage lanes (`farmctl._news_read_phases(include_historical=True)`),
  not on the single active one.

### C. EVIDENCE_AGED_OUT — 39 rows (created 2026-08-04 … 2026-08-19)

`verdict_reason = EVIDENCE_AGED_OUT_DL090`. Their `evidence_path` no longer
exists on disk (report retention, DL-090: PASS kept permanently,
infra/invalid ages out). They cannot be adjudicated — re-running the contract
requires the sealed cell aggregates — and they must not keep counting as open
reviews. 7 of the 39 still carry a `q09_news_tests` row whose
`aggregate_path` file is gone.

## q09_news_cells reconciliation for ba24e7a3 (17 vs 40)

**No defect; no mutation.** `q09_news_cells.run_identity_sha256` is a
**globally unique** sealed experiment identity
(`tools/strategy_farm/q09_news_schema.py:1211-1216`). When an append-only rerun
re-encounters a cell another work item already stored, the canonical row is
**reused** after a full deterministic-field match
(`q09_news_schema.py:1333-1342`) and only an append-only occurrence is recorded
(`q09_news_schema.py:1356-1361`).

Measured (read-only):

* `q09_news_cells` where `q09_news_work_item_id = ba24e7a3…` → **17**
* `q09_news_cell_occurrences` where `q09_news_work_item_id = ba24e7a3…` → **40**
* those 40 occurrences map to canonical cells owned by
  `cba63d44-ca33-…` (19), `ba24e7a3-4edf-…` (17), `46409fc4-5bf5-…` (4) = 40;
  **0 unmapped**.

So all 40 payload cells are present and authenticated; 23 of them are
canonically owned by two earlier work items of the same (EA, symbol). Any
"reconciliation" that duplicated them into `q09_news_cells` would violate the
UNIQUE constraint and the append-only design. The correct surface for
"how many cells does this work item have" is
`q09_news_cell_occurrences`, not `q09_news_cells`.

## Not dispositioned (read-only inventory)

* **40 pending** `Q09_NEWS` rows, all from campaign `oos-2026-confirmation-v1`
  (created 2026-09-02T10:10Z), all carrying an **active** hold:
  37 `OOS_WINDOW_MISMATCH`, 3 `NEWS_CALENDAR_TAINTED`. Not claimable today —
  `farmctl.pending_claim_order_sql` excludes any row with an active hold
  (`farmctl.py:2765-2769`). They belong to the **live-book OOS-2026
  requalification chain**, are `diagnostic_non_admission` rows, and are **not**
  inputs to the news-contract gate. They are also latent instances of the same
  phase-literal defect: releasing a hold without fixing
  `oos_2026_confirmation.py:422` would route them into the run_smoke lane again.
* **29 INFRA_FAIL** `Q09_NEWS` rows: 23 from campaign
  `q09-live-news-backfill-20260805-v1`
  (12 `worker_staged_ex5_destination_path_mismatch`,
  8 `summary_missing:launch_fault`,
  2 `shared_bases_history_lock_transient_cap_exhausted`,
  1 `staged_ex5_preflight_failed`) and 6 with a released
  `Q09_AWAITING_SEALED_PLAN` hold and `summary_missing:launch_fault`.
  Infra failures, not verdicts; out of scope for this closure.

Nothing was enqueued and no hold was released.
