# Cascade-gap health diagnosis — 2026-09-13

Read-only diagnosis of three failing farm-health checks. No DB writes, no
enqueue, no tool applied. Source: `farm_state.sqlite` (mode=ro) at ~20:43-20:50Z.

Companion artifacts (this folder):
- `2026-09-13_q02_stranded_pairs_classification.json` / `.csv` — Check B, produced
  by the read-only `classify_q02_stranded_pairs_report.py` (same cohort predicate
  as the health check).
- `q09_sealed_plan_hold_disposition_proposal_dryrun.json` — Check C, proposal only.

---

## A. `p2_pass_no_p3` — 10 profitable Q02-PASS without Q03 promotion

### The 10 rows
| # | wi (id8) | ea | symbol | summary net | ea_metrics net | Q04 sibling | sibling? | setfile root |
|---|----------|----|--------|-------------|----------------|-------------|----------|--------------|
| 1 | c0cc02a5 | QM5_41331 | XTIUSD.DWX | 3577.78 | 3577.78 | — | YES | opt_census/DL089 |
| 2 | 417a6769 | QM5_41332 | NZDUSD.DWX | 675.17 | 675.17 | — | YES | opt_census/DL089 |
| 3 | bcac7790 | QM5_41333 | XAUUSD.DWX | 18521.14 | 18521.14 | — | YES | opt_census/DL089 |
| 4 | 3150da98 | QM5_41342 | EURUSD.DWX | 590.60 | 590.60 | — | YES | opt_census/DL089 |
| 5 | 88ca31a3 | QM5_41343 | EURUSD.DWX | 3498.27 | 3498.27 | — | YES | opt_census/DL089 |
| 6 | f7d2fdfc | QM5_41344 | EURUSD.DWX | 802.04 | 802.04 | — | YES | opt_census/DL089 |
| 7 | 7589da05 | QM5_41346 | XAUUSD.DWX | 157.01 | 157.01 | — | YES | opt_census/DL089 |
| 8 | 2fc84747 | QM5_41398 | USDJPY.DWX | 46636.78 | 46636.78 | — | YES | opt_census/DL089 |
| 9 | ff75b1c3 | QM5_41335 | AUDUSD.DWX | 4428.72 | 4428.72 | Q04/done/PASS_LOWFREQ | YES | framework/EAs |
| 10 | 7cb4f579 | QM5_1371 | XAUUSD.DWX | 4269.49 | **NO_EM_ROW** | Q04/done/FAIL | **NO** | framework/EAs |

All are `priority_track:true` except #10 (`is_recovery: stranded_infra_fail`).

### Cause (code path)
`farmctl.py` §10c `p2_pass_promoter` (~L22813-22923) computes
`_p3_sibling_exclusion = _measurement_sibling_guard(...)`. The measurement-sibling
set resolved live: **32 members, guard NOT degraded, zero recognizer failures**.
The exclusion clause (`_measurement_sibling_exclusion_clause`, L2069) holds these
EAs at Q02: `AND NOT COALESCE(w.ea_id IN (...siblings...), 0)`. It gates BOTH
Q02->Q03 (`p2_pass_promoter`) and Q02->Q04 (`pump_q04_early_probe`), which is why
rows 1-8 have no Q03 **and** no Q04.

- **Rows 1-9 (QM5_41331/32/33/42/43/44/46/98 + 41335): LEGITIMATE STOP** —
  confirmed members of the measurement-sibling set (DL089 opt-census /
  measurement-only chains). Per the exclusion docstring, running one of these
  chains "is an OWNER decision, never a caller flag." No promotion is a defect.
  The withholding is logged each cycle by `_record_measurement_sibling_promotion_holds`.
- **Row 10 (QM5_1371 XAUUSD): TRANSIENT lag, not a defect.** Non-sibling. Its Q02
  PASS completed 2026-09-13T20:33Z, ~10 min before the snapshot; the last
  ea_metrics refresh was 41 min earlier, so it has **no ea_metrics row yet**. The
  promoter's profit pre-filter (`EXISTS ea_metrics WHERE net_profit>0`, L22841)
  therefore skips it. It self-heals on the next ea_metrics refresh + pump cycle.
  (It already has a terminal Q04/done/FAIL for the same lineage, so a Q03 is
  largely moot.)

**Finding for the orchestrator:** `chk_p2_pass_no_p3` does not subtract the
measurement-sibling set, so it will sit at FAIL as long as profitable census
siblings exist — the FAIL is ~90% benign. Consider mirroring the promoter's
`_measurement_sibling_exclusion_clause` in the health query.

### Governed apply command(s)
- Rows 1-9: **none** — legitimate measurement-sibling hold; promotion is an OWNER
  decision, not an automatic cascade.
- Row 10 (only if you want to force it before self-heal):
  ```
  python -X utf8 tools/strategy_farm/farmctl.py enqueue-backtest \
    --ea QM5_1371 --phase Q03 \
    --from-work-item-id 7cb4f579-e934-4a23-93a7-a501dace54f4
  ```
  (`enqueue-backtest` has no dry-run flag; not executed here.)

### Blockers
None. Row 10 self-heals; rows 1-9 are intentional.

---

## B. `q02_stranded_exhausted_pairs` — 3 infra-exhausted Q02 pairs

Cohort predicate identical to the health check; classifier output beside this file.

| ea | symbol | INFRA rows | primary cause | source agg | canary-eligible | proposed |
|----|--------|-----------|---------------|------------|-----------------|----------|
| QM5_10505 | XAUUSD.DWX | 15 | ONINIT_FAILED | FAIL / ONINIT_FAILED,INCOMPLETE_RUNS / 0 trades | no (latest≠diag source) | repair-first |
| QM5_12582 | XNGUSD.DWX | 13 | ONINIT_FAILED | FAIL / ONINIT_FAILED,INCOMPLETE_RUNS / 0 trades | **YES** | governed single-row canary |
| QM5_20143 | EURUSD.DWX | 13 | NO_HISTORY_TRANSIENT | none readable | no (no readable aggregate) | history preflight first |

Row-level INFRA reason classes across the cohort: `ONINIT_FAILED;INCOMPLETE_RUNS`
=21, `summary_missing_retries_exhausted`=12, `COMPILE_FAILED`=2,
`shared_bases_history_lock_transient_cap_exhausted`=2 (all on QM5_12582 →
`historical_lock_storm=true`), `ACTIVE_TIMEOUT`=1, `NO_HISTORY`=1, mixed=2.

### Decision per pair
All three classify **INVALID_EVIDENCE_DEFECT** with runtime causes — **none is a
structurally-broken / VALID_ZERO_TRADES / PASS-disposition-mismatch pair**, so
**no append-only disposition JSON is warranted** (path (ii) does not apply). All
are fixable-infra (i), gated on a precondition:

- **QM5_12582 / XNGUSD.DWX — (i) canary-ready.** Latest row == diagnostic source
  (`ae468d0f`), registry active, EX5+setfile+evidence present, attempt<12.
  Precondition: explain/repair the OnInit failure and revalidate EX5/setfile/
  calendar hashes first, then ONE governed single-row append-only requeue:
  ```
  python -X utf8 tools/strategy_farm/farmctl.py enqueue-backtest \
    --append-only-rerun-of ae468d0f-2d3c-4595-9d49-6b5b00a25f75 \
    --rerun-reason "Q02 ONINIT_FAILED governed single-row canary after init-cause repair (XNGUSD.DWX)"
  ```
- **QM5_10505 / XAUUSD.DWX — (i) but repair-first, NOT ready.** The diagnostic
  source (`cc347183`) is not the latest row (`7f4fb7d4`); 15× ONINIT_FAILED with
  0 trades means a genuine OnInit cause must be explained/repaired before any
  requeue. Do not blind-requeue.
- **QM5_20143 / EURUSD.DWX — (i) but preflight-first, NOT ready.** No readable
  row-bound aggregate; latest signature is `NO_HISTORY;ONINIT_FAILED`. Requires a
  read-only history-range/coverage preflight for the exact window before any
  requeue (no history re-import authorized).

### Blockers
QM5_10505 and QM5_20143 cannot be requeued until their init cause / history
coverage is explained (per the classifier's abort controls). QM5_12582's canary
is gated on the OWNER-sized review + init-cause repair precondition.

---

## C. `q09_sealed_plan_hold_age` — 2 Q10_NEWS sealed-plan holds

Both fail at `stage=bind_plan`, `reason_code=Q09_AUTOSEAL_BIND_PLAN_FAILED`
(`activation_state=AWAITING_SEALED_PLAN`). The task's hinted causes (missing
anchor binding, news-contract v2 mapping, EURNZD not in the calendar universe)
are **ruled out**: the failure is raised by `q09_news_runner.bind_plan_to_work_item`
in the **Q07 seed-stability lineage check (L1402-1425), before** any
calendar/anchor step; and EURNZD has a full Q02-Q09 PASS lineage.

| held wi (id8) | ea | symbol | hold age | Q08 input | Q07 lineage | root cause |
|---------------|----|--------|----------|-----------|-------------|-----------|
| 08fe4173 | QM5_11476 | USDJPY.DWX | 508 h | 43c9d9d7 FAIL_SOFT, no `promoted_from_work_item` | **0 Q07 rows** for pair | never ran Q07; `_resolve_identity_bound_q07` finds none |
| 8b233bbf | QM5_10148 | EURNZD.DWX | 203 h | 1da1645c PASS, `promoted_from_work_item=bad1b2f7` | Q07 `bad1b2f7` = PASS but **evidence file purged** | `q07_path.is_file()` false |

Detail:
- **QM5_11476:** Q08 (FAIL_SOFT) carries no `promoted_from_work_item`; the fallback
  resolver searches for a Q07 PASS for the same ea/symbol/setfile — none exists
  (pair phases: Q02,Q03,Q04,Q05 FAIL,Q08 FAIL_SOFT,Q09 FAIL — Q06/Q07 never ran).
  Pre-Q07-contract orphan on a failing lineage. **No evidence to restore.**
- **QM5_10148:** Q08 (PASS) hard-references Q07 `bad1b2f7` via
  `promoted_from_work_item` (takes precedence over the fallback resolver). That
  Q07 is a PASS in the DB, but its evidence
  `D:\QM\reports\work_items\bad1b2f7-.../QM5_10148/Q07/EURNZD_DWX\aggregate.json`
  was **purged from disk** (dir present, empty). A fresh Q07 rerun gets a new id
  the Q08 does not reference, so it will not satisfy the bind.

### Fix / governed command
**Do NOT release the hold** (health hint + bind contract: never release
`Q09_AWAITING_SEALED_PLAN` without a validated bound plan).

- **QM5_10148 — restore-first (GRÜN infra repair).** Restore the purged
  `aggregate.json` to the exact `bad1b2f7` evidence path from a `D:\QM\reports`
  backup; autoseal binds on the next Tick cycle. If unrecoverable → OWNER-scoped
  append-only Q07→Q10_NEWS rebuild superseding this held row, or RETIRE.
- **QM5_11476 — governed RETIRE disposition** (no Q07 lineage, failing upstream).
  Follow the `apply_q09_retire2_dispositions.py` pattern (hashed dry-run plan →
  online SQLite backup → FactoryMutationLock → append terminal RETIRE row +
  supersedes edge → close the one hold; originals never edited). **ROT** — needs
  an OWNER decision id first. Dry-run proposal:
  `q09_sealed_plan_hold_disposition_proposal_dryrun.json` (this folder).

### Blockers
- QM5_10148 fix depends on whether the Q07 `aggregate.json` exists in any
  `D:\QM\reports` backup (not scanned here — no backup-restore performed).
- QM5_11476 retire is ROT: requires an OWNER decision id before apply.
