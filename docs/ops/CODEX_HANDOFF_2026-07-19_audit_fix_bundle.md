# Codex Handoff — Audit Fix Bundle (2026-07-19 evening)

Prepared by Claude (board-advisor) after the full factory/project audit + Wave-1/2
fix sprint. Scratchpad root for all referenced artifacts:
`C:\Users\ADMINI~1\AppData\Local\Temp\1\claude\C--QM-repo\8415ee13-8ac0-4c8d-8f33-871720aba17a\scratchpad\`

Already landed by Claude tonight (do not redo): quota governor primary_window fix
(67f902df2), PID-reuse guard in start_terminal_workers (dd5f42268), Q08
deterministic-defect sweep skip + self-describing INVALID reason (4adad6e73),
5 param-empty/duplicate Q08 setfiles repaired (see git log), cockpit decisions
panel (b96adc823), Dashboard_Hourly ExecutionTimeLimit PT5M->PT30M, news-calendar
live-week append (D:\QM\data\news_calendar, backups alongside), nightly backup
script deployed (scripts/backup_nightly.ps1, registration = OWNER), D: reclaim
(ndx_rebuild archived to G: + deleted; 206GB stale pipeline .log tester journals
deleted per manifest `scratchpad\retention\TIER1_deletion_manifest.csv`).

## P0 — URGENT (factory actively degraded)

1. **Restore `_stop_pid_tree` in farmctl.py and land the managed-codex WIP in ONE
   commit.** Your in-place fail-closed refactor deleted `_stop_pid_tree`;
   committed `terminal_worker.py` calls it at lines 1667/1678/1689/1787 — every
   worker that reaches a child-stop path dies with AttributeError (all
   `terminal_worker_*.err` files, 2026-07-19). Ready diff:
   `scratchpad\workerenv\fix1_farmctl_restore_stop_pid_tree.diff` (child-tree
   kill is legitimately exempt from the controller fail-closed policy). Land
   with explicit pathspecs incl. the untracked modules (managed_codex.py,
   process_identity.py, codex_kill_safety_audit.py, supervisor + tests) —
   committing the modified files without the untracked ones breaks every
   farmctl import and the pump (import graph verified). After landing, Claude
   runs the Factory_OFF/Factory_ON cycle.

## P1 — This week

2. **Extend the log pruner to `reports\pipeline*`.** `D:\QM\reports\pipeline` was
   99.7% raw tester `.log` journals (339/340 GB), never programmatically read
   (`terminal_worker.py:_mirror_real_phase_artifacts` docstring: convenience
   surface only). `prune_workitem_logs.py` already does exactly this for
   work_items on a 3h task — clone the logic. Analysis:
   `scratchpad\retention\` (log_composition.csv, candidate_logs_ALL.csv).
3. **Q08 staged requeue** (after item 1 + factory cycle): Buckets A (13 triples,
   requeue now) + B (5, setfiles repaired tonight — requeue) + C (3 transient,
   retry ok) per `scratchpad\q08\staged_requeue_list.json`.
4. **gen_setfile.ps1: Find-CardPath-null must fall through to ea_input_defaults**
   instead of emitting `card_defaults_source=not_found` with zero strategy
   params (root cause of the whole setgen param-empty class).
5. **ablate.py `mutate_setfile` appends override keys without checking for an
   existing assignment** -> duplicate `strategy_*` lines whenever the parent
   setfile carries the key (QM5_10706 ablation_02 was the live case). Replace
   in place instead of blind append.
6. **QM_NewsLoadCsv column misalignment** (`QM_NewsFilter.mqh:415-428`): assumes
   `date,time,currency@2,impact@3`; primary file layout puts event_name at 2
   (currency reads as event name), secondary puts Currency at 3 (impact reads
   as currency -> UNKNOWN, 0 HIGH rows). Net effect: the CSV news filter was
   inert in the TESTER for both files. Live is unaffected (live routing uses
   the native MT5 calendar, `QM_NewsFilter.mqh:1020-1043`). Fix the parser per
   real layouts; NOTE the evidence-regime implication: future backtests will
   then genuinely news-filter (conservative shift) — flag in the change note.
7. **Land refresh v2 + coverage check (warn-only).** Drafts:
   `scratchpad\calfix\refresh_news_calendar_v2.ps1` (real FF weekly fetch,
   idempotent append, stale flag) and
   `scratchpad\calfix\QM_NewsFilter_coverage_check.patch` — Claude's decision:
   convert from fail-closed to WARN-ONLY before landing (live uses the native
   calendar; a content gap must not brick EA init).
8. **HygieneReboot launch failure**: task result 1 on 07-11 + 07-18, script
   never even started (no log ever written; every code path logs). Diagnosis
   dossier: `scratchpad\opsmisc\i_hygiene_reboot_diagnosis.md`. Fix before
   Sat 07-25 06:00; do NOT disable (load-bearing LSM mitigation; recovery
   chain AutoLogon->T_Live_ON->Factory_ON verified intact).
9. **Registry: re-key ea_id 12784** (only real dual-active collision; 9197/9198/
   11857 are dead orphan rows). Plan + uniqueness lint (tested, FAIL on 12784):
   `scratchpad\opsmisc\iv_registry_dual_id_rekey_plan.md` + `iv_ea_id_uniqueness_lint.py`
   -> wire lint into farmctl health. Compile steps wait for the build unblock.
10. **Cockpit/health Codex 5h% consumers**: same API window move as the governor
    fix — if any surface displays Codex hour_pct it has been mislabeled since
    07-12; check `health.py` / `render_cockpit.py` consumers.

## P1.11 — OWNER directive 2026-07-19 evening (news-source architecture)

OWNER (verbatim intent): live EAs must source news events from the native
MetaTrader calendar or ForexFactory THEMSELVES — no dependency on scripted CSV
jobs — and must function independently of this VPS environment.

Current state: live decisions already use ONLY the native MT5 calendar (verified:
NEWS_LIVE_CALENDAR_SELFTEST healthy, 253-257 events/7d on T_Live). BUT
QM_NewsInit still REQUIRES the CSV files (hardcoded D:\QM\data\news_calendar,
mtime-stale + zero-rows gates) even outside the tester — a live EA deployed on a
foreign machine would fail init over a file it never uses.

Change: outside MQL_TESTER, drop the CSV requirement entirely (no file-presence,
no stale gate); the live health gate is the native-calendar selftest (keep
fail-closed only when a news axis is ACTIVE and the native calendar is empty).
Inside the tester the CSV remains the news source (MT5 tester has no native
calendar — structural limitation), maintained by your refresh v2. Touches
QM_Common.mqh:179-205 + QM_NewsFilter init path; framework include change ->
coordinate the recompile wave (admits recompile before next session).

## Still with Claude (not yours)

- Category-C review/landing (55 DXZ/FTMO requal code paths, board-advisor lane).
- REVIEW-300 batch adjudication (after item 1).
- Silent-failure meta-monitor (Gmail channel) — Claude specs, build possibly routed to you later.
- FTMO V3: card `strategy-seeds/cards/spx-intraday-mom_card.md` approve + build,
  EURUSD.DWX history-sync repair (NDX playbook), Gotobi Q03 completion.
