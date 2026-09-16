# E1-C Option A — full Q09 remeasurement enqueue (8 EVIDENCE_INCOMPLETE rows)

Date: 2026-09-16 ~16:36–16:40Z
Executor: Kimi (interim OWNER delegation), task `e1c-followup`, worktree preflight PASS
(`agent_worktree_preflight.py --task-id e1c-followup --paths docs/ops/evidence tools/strategy_farm/research`,
base `0ef15a4697d7` on `agents/board-advisor`).
Authority: `OWNER-E1C-OPTIONB-20260916` — the 8 EVIDENCE_INCOMPLETE rows of
`docs/ops/evidence/2026-09-16_e1c_optionb/summary.json` route to
FULL_Q09_REMEASUREMENT_REQUIRED (pre-authorized Option A fallback; no new OWNER decision).

## Invariants held

- The 8 original rows and their evidence were NOT touched: all 8 remain `pending`,
  `NEWS_CALENDAR_TAINTED` hold active (verified after all enqueue operations —
  `updated_at` still 2026-08/09, i.e. the autoseal-failure timestamps).
- All enqueues are append-only: cited rows preserved, `historical_work_item_preserved: true`,
  lineage in `append_only_rerun_lineage_work_items`, `rerun_reason` cites OWNER-E1C-OPTIONB-20260916.
- Every command below is the canonical governed path (`farmctl enqueue-backtest`); all
  refusals below are the tool's own fail-closed guards, captured machine-readably in
  `direct_q10_attempts.json` and `append_only_rerun_enqueues.json` in this directory.

## Why the direct Q10_NEWS append-only rerun refuses these rows (verified live)

`farmctl enqueue-backtest --phase Q10_NEWS --append-only-rerun-of <held row>` was attempted
for all 8 (full commands in `direct_q10_attempts.json`). Results:

| EA | held row | refusal |
|---|---|---|
| QM5_12989 | 1cff016c | `append_only_rerun_target_mismatch_or_not_terminal` |
| QM5_1567 | 2604a1f0 | `No done Q09 PASS work_items found` (no EURUSD Q09 PASS) |
| QM5_10847 | 49a059da | `No done Q09 PASS work_items found` (Q09 rows are FAIL) |
| QM5_10815 | 57d8bacd | `q08_evidence_missing_or_unreadable` (its Q09 PASS's Q08 input evidence is unreadable) |
| QM5_12567 | 7bbeef66 | `append_only_rerun_target_mismatch_or_not_terminal` |
| QM5_13301 | 84c6e9e9 | `No done Q09 PASS work_items found` (Q09 rows are FAIL) |
| QM5_10939 | 9639a773 | `q08_evidence_missing_or_unreadable` |
| QM5_13128 | aa80274f | `append_only_rerun_target_mismatch_or_not_terminal` |

Root cause (code-verified, `farmctl.py` `enqueue_cascade_backtest_for_ea`): a *pending*
unsealed Q10_NEWS target is accepted only together with `--scoped-q10-window-seal`, and the
scoped seal requires an exact done **Q09 PASS** predecessor with readable evidence — i.e. the
path manufactures a **review-only, non-claimable** successor (`terminal_claimable: false`),
which is the opposite of a full remeasurement. A fresh (non-rerun) Q10_NEWS enqueue is
refused by `already_pending_or_active` (the held row itself occupies the identity). So the
canonical full-remeasurement entry point is the **Q08 lineage basis**: a fresh append-only
Q08 rerun on the current setfile/ex5 identity, after which the normal pump machinery
(`_spawn_q09_replacements_for_regenerated_q08` → new held Q10_NEWS child → autoseal binds a
fresh sealed v3 plan → measurement on the then-pinned calendar) performs the Q09 news
remeasurement. This is the same class fix as the 2026-09-02 CEO Q10 unblock plan (Group B/C)
and the REPORT.md condition-3 note ("a fresh sealed plan must be built, which is the
remeasurement path anyway").

## Enqueued (3 rows — verified pending in work_items)

| EA | row | phase | append_only_rerun_of | basis |
|---|---|---|---|---|
| QM5_10815 (GDAXI H1) | `74718ef2-2e3c-4432-8f3b-07115b6ba632` | Q08 | e1112871 (FAIL_SOFT) | Q07 PASS 1a7d6630, ex5 13d7064f… |
| QM5_13301 (GDAXI M5) | `f3132f22-11a8-48e4-8b11-39b4fcfc4e59` | Q08 | a3538dc4 (PASS) | Q07 PASS e75520f9, ex5 64d71b74… |
| QM5_1567 (EURUSD H4) | `ceebbe72-4556-4fdb-8f4e-bb623ae22b41` | Q07 (step 1 of 3) | fba298c8 (INFRA_FAIL) | Q06 PASS 5299eb44, ex5 aee0eb60… |

Commands (exact form, all with `--expected-current-ex5-sha256 <current ea_dir ex5 sha>`):

```
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_10815 --phase Q08 \
  --from-work-item-id 1a7d6630-f840-4987-8dda-d38a67d39526 \
  --append-only-rerun-of e1112871-12a0-4ee9-a565-9f9f19ff54aa --rerun-reason "OWNER-E1C-OPTIONB-20260916: ..."
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_13301 --phase Q08 \
  --from-work-item-id e75520f9-8a84-4cc1-957a-d6c32d774a80 \
  --append-only-rerun-of a3538dc4-e7bc-4285-ba2b-6d0858cb3f60 --rerun-reason "OWNER-E1C-OPTIONB-20260916: ..."
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_1567 --phase Q07 \
  --from-work-item-id 5299eb44-8e1d-46c8-938c-06d8c1ac5d52 \
  --append-only-rerun-of fba298c8-4c2c-4162-a194-07cc27e7b805 --rerun-reason "OWNER-E1C-OPTIONB-20260916: ..."
```

Follow-on for QM5_1567 after the Q07 rerun completes done PASS: enqueue the Q08 rerun
(`--from-work-item-id <new Q07 id> --append-only-rerun-of e8c1e63a-e06c-4988-9ae7-54771bc1fe8c`,
same ex5 binding), then the pump spawns the Q10_NEWS successor automatically.

## Refused by the canonical guards (5 rows) — exact blockers and follow-ons

1. **QM5_12567 (7bbeef66)** — `append_only_rerun_already_exists`: the one-rerun-per-target
   dedupe is held by `c089a98d-2879-4151-8bb4-fbe722cb1b46` (2026-08-24 "rb-news-lane-drain2"
   rerun of dc267677), which ended done **INFRA_FAIL**. Follow-on: governed disposition of the
   failed rerun (work_item_supersedes edge, exactly like the D1 disposition waves), then:
   `enqueue-backtest --ea QM5_12567 --phase Q08 --from-work-item-id 9f65d3ba-7719-4d2f-91d7-d6b3c25615fd
   --append-only-rerun-of dc267677-1cec-4ec4-9a44-d5c45dd01876 --rerun-reason "OWNER-E1C-OPTIONB-20260916: ..."`
   (ex5 8d901924fe7dd2cd00c61dac6db78871fdfe34f73e0f003393196992d5143e04).
2. **QM5_10939 (9639a773)** — same class: prior rerun `8234812d-b9ff-4652-b4a3-48bcdc41c2b5`
   (2026-08-24) done **INFRA_FAIL** blocks the dedupe. Follow-on after disposition:
   `enqueue-backtest --ea QM5_10939 --phase Q08 --from-work-item-id ef98d494-b292-49cb-9e78-01c9000b6b8f
   --append-only-rerun-of 811fc617-ee41-456b-8e3a-ce672f93c73c ...` (ex5 812fc52a90f0dba0282aa2fecb3a0b3640c18386c3e2ab7e3b80765a3970278).
3. **QM5_13128 (aa80274f)** — prior rerun `d2d76958-e060-4b65-8074-a63b7c116bf2` (CEO
   2026-09-02 vintage refresh) done **FAIL_SOFT** holds the dedupe. Note: d2d76958 *is* a
   qualifying replacement Q08 (done FAIL_SOFT + append_only_rerun) — per
   `_spawn_q09_replacements_for_regenerated_q08_once` the pump respawns the fresh Q10_NEWS
   child from it as soon as the held row is selectable for activation (its
   Q09_AWAITING_SEALED_PLAN hold was overwritten by the taint hold; respawn resumes in the
   normal post-repin flow). No new enqueue needed unless that respawn is observed to fail.
4. **QM5_12989 (1cff016c)** — its only done Q07 PASS (377350fb) carries a
   `C:\QM\worktrees\codex-orchestration-1\...` setfile path (worktree still on disk, so the
   identity string mismatch blocks the rerun; the enqueue has no reconciliation arm for Q08).
   The `--replacement-setfile` bridge was attempted and refused
   (`replacement_setfile_governed_name_required`): the EA has no versioned
   `*_backtest_s<date>-<seq>.set` governed setfile. Follow-on: mint the governed versioned
   setfile via the canonical setfile generator (owner-side; changes strategy input identity,
   outside this delegation), then the same Q08 rerun command with `--replacement-setfile`.
5. **QM5_10847 (49a059da)** — no Q06/Q07 lineage exists at all for GDAXI (Q05 → Q08 gap;
   failure class "Q08 dependency has no Q07 lineage"). Earliest rebuild point is Q05 from the
   done Q04 PASS; a full Q05→Q06→Q07→Q08→Q09→Q10_NEWS chain rebuild is required. This is the
   OWNER-scoped rebuild/retire class (same as QM5_10148/11476 in
   `2026-09-16_q09_sealed_plan_derivation_owner_package.md`) — recommend an explicit OWNER
   retire-vs-rebuild ruling before spending the chain.

## State machine reminder (marker semantics)

Per `news_calendar_taint._e1c_marker_allows` and the Option-B REPORT: the 8 taint holds stay
until the remeasurement evidence seals. The remeasurement chain itself (fresh Q08/Q07 basis →
pump-spawned Q10_NEWS child → autosealed v3 plan → run) proceeds under the tainted pin for the
non-news phases; the spawned Q10_NEWS children are taint-held by the sweep until the pin lifts
(lift_condition: full remeasurement seal / pin change to an untainted bundle) — at which point
the sealed new evidence is what justifies releasing the 8 original holds in a governed pass.

Receipts: `direct_q10_attempts.json`, `append_only_rerun_enqueues.json` (this directory).
