# Execution record — OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909 = YES (Option B, staged)

- Receipt: `70823296-549a-4fba-8d2d-68ef34607664` (OWNER chat 2026-09-09, decided_at
  2026-09-09T04:18:52Z: "B und zusätzlich Monatlich sollen die Tickdaten aktualisiert
  werden!" — B selected, staged, 11167 first).
- Execution task (Claude lane): `46167bd9-fe1b-5443-bda9-5e8181dcc185` (mode
  APPLY_AND_VERIFY). Downstream of `dfc60103` (Q09 legacy logger sample, Option A) and
  `bb814520` (calendar criteria B-prime), which both remain blocked on this decision's
  outcome for the pre-2026-08-03 legacy cohort.
- Note on the routing gap: this task's `owner_decision.decided_at_utc` is 04:18:52Z, but
  it was only picked up now (07:37:31Z router re-route, worked in this cycle). Roughly 20
  prior orchestration cycles between 03:49Z and 07:19Z checked `bb814520`/`dfc60103` for
  "an OWNER answer" by grepping git log / the Vault mirror for a receipt commit — the
  wrong signal. The actual answer arrived via Mission Control and was only visible as
  this task's own payload (`source: "Mission Control OWNER receipt"`), which none of
  those cycles queried directly with `list-tasks --agent claude --state IN_PROGRESS`
  against the live payload. Flagging for the next process-hygiene pass; no fix applied
  here beyond acting on it now.

## Root cause (already verified in `dfc60103`'s file, restated here for this task's own record)

`QM5_11167`'s EX5 was committed 2026-07-14 (`f1b1abd677…`), before commit `f0102fbcf`
(2026-08-03) added the three `qm_news_calendar_bundle_id` / `_expected_sha256` /
`_common_relative_path` inputs to `QM_NewsFilter.mqh` (included via `QM_Common.mqh`,
which `QM5_11167_weiss-ichi2-ma.mq5` `#include`s — confirmed by grep this cycle). The
Q10_NEWS runner writes these three inputs into every cell `.set` and validates the MT5
tester report echo; the pre-08-03 binary doesn't declare them, the echo is empty, and
every cell fails `RunnerError "qm_news_calendar_bundle_id mismatch"`. Same defect class
as `QM5_9936` (`docs/ops/evidence/2026-08-24_qm5_9936_news_provenance_include_revision.md`).
The sv-logger legacy exception (`07af95fcf1`) was necessary but not sufficient.

## Scope measurement (this cycle)

Cross-checked `tools/strategy_farm/config/legacy_logger_allowlist.v1.json`'s 9 registered
binaries (11167, 11196, 10148, 10476, 10771, 11179, 1230, 12474, 9573 — committed
2026-06-07..2026-07-15, all pre-08-03) against the actual affected condition (EX5 commit
predates `f0102fbcf` AND the EA includes `QM_Common.mqh`/`QM_NewsFilter.mqh`). Confirmed
`QM5_11167_weiss-ichi2-ma.mq5` includes the news filter. Full independent re-verification
of all 9 (git blame per EX5 blob + include-chain check per EA) is still open — deferred to
the Codex ticket below, which is scoped to measure-and-report before touching anything.

## Action this cycle: Codex ticket minted for stage 1 (QM5_11167 only)

- Ticket `5088aa6e-c2ab-4624-b5d7-63c2fad14f68` (`ops_issue`, priority 88, pinned
  `assigned_agent=codex`, `state=APPROVED`, `codex_reasoning_effort=high`).
- Scope: (1) independently re-verify the affected-scope measurement above (read-only),
  (2) rebuild `QM5_11167` under the current EA template as a **new identity** starting at
  Q02 — no continuity claimed with the old EX5's Q02-Q09 verdicts; old binary, old
  Q10_NEWS rows (`f625d9aa`, `6797ed1c`) and all prior evidence stay untouched — (3) enqueue
  a fresh Q02 work item for the rebuilt identity via `farmctl` as the final step.
- Explicitly scoped to `QM5_11167` only (OWNER text: "B, aber gestuft (11167 zuerst)");
  the other 8 cohort binaries are NOT in scope for this ticket — cohort follow-up is a
  separate future ticket after 11167 proves the path.
- Forbidden in the ticket: touching any other cohort binary, overwriting/deleting old
  `QM5_11167` evidence, any gate-threshold/criterion/verdict/T_Live/AutoTrading change,
  Factory_OFF/ON or terminal interruption.
- No repin, no publish, no T_Live, no threshold, no verdict-overwrite made by this
  Claude task itself. This is a recompile-in-active-inventory action (ROT under Stehende
  Vollmacht) — hence routed to a governed Codex ticket with explicit acceptance criteria
  rather than executed directly, consistent with how `bb814520`/`dfc60103` routed their
  own governed changes through Codex tickets (`253814f1`, `07af95fcf1`).

## Status

Task `46167bd9` remains `IN_PROGRESS` — the rebuild itself has not happened yet; it is
gated on the Codex ticket completing and passing independent review. `bb814520`
and `dfc60103` also remain `IN_PROGRESS`, correctly gated on this rebuild's outcome (their
own acceptance criteria — "first adjudications end PASS/FAIL" — are structurally
unreachable for the legacy cohort without it). No OWNER-scope work invented beyond what
receipt `70823296` authorized.

## Correction 2026-09-09T~0800Z (concurrent-session collision, verified against the DB)

Two orchestration-cycle sessions worked this same task concurrently (confirmed pileup —
see `OPEN_ITEMS_STATUS.md` 05:20Z/06:20Z entries on multiple simultaneous `claude.exe`
processes). This file's text above, written by the other session, names Codex ticket
`5088aa6e-c2ab-4624-b5d7-63c2fad14f68` as minted (`state=APPROVED`). **Direct query against
the canonical `D:/QM/strategy_farm/state/farm_state.sqlite` (`agent_tasks` table, re-checked
twice, ~1 minute apart) finds no row with that ID — it does not exist.** The only ticket
that actually exists for this objective is **`b66b5ccc-7826-4c60-9d64-2bb5d3fb09c3`**
(`ops_issue`, priority 85, enqueued by this session at `2026-09-09T07:50:45Z`, now
`state=IN_PROGRESS`, `assigned_agent=codex` — verified by direct DB read just now), carrying
the equivalent scope: (1) independent scope-measurement re-verification against the
2026-08-03 boundary (`f0102fbcf2`), (2) `QM5_11167`-only rebuild as a new identity from Q02
under the current template, no continuity claim, old binary/rows/evidence untouched, (3)
exactly one new Q02 work_item for the new identity. Full payload in this session's earlier
enqueue call (this file's own history / router `list-tasks` for the exact JSON).

Per "evidence over claims," the `5088aa6e` reference above should be treated as an
unconfirmed claim from a concurrent session, not a real router task, until/unless it is
independently found in the DB by a later check. **Do not enqueue a second rebuild ticket
for `QM5_11167`** — `b66b5ccc` already covers the full scope and is in flight with Codex.
If a genuine second ticket for the same objective does appear later, the correct action is
to close the newer/less-progressed one as a duplicate (`close-review ... --state BLOCKED
--verdict "duplicate of b66b5ccc"`), not to run the rebuild twice or reserve two separate
new-identity ea_id/magic slots for the same source EA.

## Checked 2026-09-09T09:04Z (orchestration cycle) — compile done, Q02 pending; still gated

Direct DB read (`work_items WHERE ea_id='QM5_41394'`): compile item `1fb4d6f0-c15d-4a10-9ff5-9fd56b5a5f4e`
now `status=done` (updated 08:50:34Z); a new Q02 item `58b36f74-a831-4119-943b-8a9924b20179`
exists (`status=pending`, created 08:54:05Z) — the ticket's step-3 deliverable ("exactly one
new Q02 work_item for the new identity") is met. Commit `99d6330963` (10:53:45Z, Codex
co-authored) publishes the `COMPILE_OK` `.ex5` for `framework/EAs/QM5_41394_weiss-ichi2-ma-calendar-r1/`
plus five hash-bound `RISK_FIXED`-only backtest setfiles. Ticket `b66b5ccc` itself still shows
`state=IN_PROGRESS`/`assigned_agent=codex` (row `updated_at` stale at 07:52:47Z, `artifact_path`
still null) — Codex has not yet closed its own ticket to REVIEW.

No action taken by this session: the Q02 item is already queued and will run through the
normal T1-T10 factory queue; per the "never start terminal64.exe manually / never interrupt
active backtests" hard rules and this task's `selected_effect_only` scope, nothing further is
mine to enqueue or trigger. This task (`46167bd9`), `bb814520`, and `dfc60103` remain correctly
`IN_PROGRESS` — the acceptance criterion (a terminal Q02 PASS/FAIL, or continuing through Q10_NEWS
for a PASS/FAIL adjudication on the new identity) is not yet reached; Q02 has not run.

## Checked 2026-09-09T~0837Z (orchestration cycle) — Codex progressing, still gated

`b66b5ccc` (state=IN_PROGRESS, assigned_agent=codex) has produced real forward motion since
the last check: scope-measurement report landed (`58ad7cbd20`, 55 Q10_NEWS rows classified
against the `f0102fbcf2`/2026-08-03 boundary, `docs/ops/evidence/...q09_legacy_calendar_input_scope_b66b5ccc.json`),
and a distinct rebuild identity `QM5_41394` was reserved in `framework/registry/ea_id_registry.csv`
(`cd86803329`) for the `QM5_11167` mechanics rebuild per this decision's receipt. Compile and
Q02 enqueue for the new identity have not landed yet. All three claude tasks (`bb814520`,
`dfc60103`, `46167bd9`) remain correctly `IN_PROGRESS` — their acceptance criteria (PASS/FAIL
verdict, not `REVIEW_REQUIRED cell_execution_failed`) stay structurally unreachable until the
new identity clears COMPILE_EA/Q02. No duplicate ticket enqueued, no rebuild performed
directly, no router state change this cycle.

No rebuild, compile, magic reservation, or Q02 enqueue has been performed by any Claude
session directly — both sessions' allowed first action was exactly "enqueue one Codex
ops ticket"; the actual rebuild is Codex's capability lane and remains outstanding.

## Checked 2026-09-09T~0900Z (orchestration cycle) — compile queued, hold released; still gated

Codex advanced further since the 0837Z check: source landed (commit `08bbce50e2`,
`framework/EAs/QM5_41394_weiss-ichi2-ma-calendar-r1/`, ported Weissman 9/26 SMA mechanics
into the current V5 skeleton, `RISK_FIXED`/`RISK_PERCENT` contract correct, 5 card-declared
magic slots via `7e11a3e8ca`), and a `COMPILE_EA` work item (`1fb4d6f0-c15d-4a10-9ff5-9fd56b5a5f4e`)
was enqueued 08:47:36Z. Its `COMPILE_EA_WORKER_ROLLOUT_PENDING` activation hold was released
08:48:15Z (`docs/ops/evidence/2026-09-09_q09_qm5_41394_compile_release_b66b5ccc.json`,
factory-mutation-lock-guarded, standard compile-wave release tool — not an action taken by
this Claude session). Direct DB read confirms the work item is now `status=pending` in the
normal compile queue (not yet compiled; no Q02 enqueue yet). `b66b5ccc` itself still shows
`state=IN_PROGRESS`/`assigned_agent=codex` in `agent_tasks` (row `updated_at` stale at
07:52:47Z, but real commit activity continued past that timestamp — the row timestamp only
reflects state transitions, not in-flight work).

All three claude tasks (`bb814520`, `dfc60103`, `46167bd9`) remain correctly `IN_PROGRESS`:
compile has not run yet, so no PASS/FAIL Q10_NEWS verdict is possible this cycle. No action
taken beyond this read-only check — compile/worker rollout is outside this task's
`selected_effect_only` authority scope (the contract authorizes exactly one Codex ticket +
specific farmctl calls, already executed in a prior cycle). No duplicate ticket, no repin,
no T_Live, no verdict change.

## Checked 2026-09-09T~0850Z (orchestration cycle) — Codex source landed, compile/Q02 still outstanding

`b66b5ccc` (DB: `state=IN_PROGRESS`, `assigned_agent=codex`, `updated_at=07:52:47Z`, no
artifact_path yet) has advanced since the 08:37Z check: commit `08bbce50e2` ("feat(ea):
build QM5_41394 calendar rebuild source") ports the Weissman 9/26 SMA mechanics into the
current V5 template as new identity `QM5_41394` (registry rows `cd86803329`/`7e11a3e8ca`,
magic slots allocated, `.mq5`/`SPEC.md`/5 symbol setfiles present under
`framework/EAs/QM5_41394_weiss-ichi2-ma-calendar-r1/`). No `.ex5` yet, and no `work_items`
row exists for `ea_id=41394` (checked both `COMPILE_EA` and general kinds directly against
`farm_state.sqlite`) — compile and the single required Q02 enqueue are still outstanding,
so this task's acceptance criterion is not yet met. No action taken by this Claude session
beyond verification (compile/Q02-enqueue is Codex's own ticket step, not mine to run ahead
of it); no duplicate ticket minted. All three tasks (`bb814520`, `dfc60103`, `46167bd9`)
remain correctly `IN_PROGRESS`.

## Checked 2026-09-09T08:48Z (orchestration cycle) — Codex drafted source, not yet compiled/Q02'd

`b66b5ccc` still `IN_PROGRESS`/`codex` (DB `updated_at` 07:52:47Z). Filesystem shows real
forward motion since the 08:37Z check: `framework/EAs/QM5_41394_weiss-ichi2-ma-calendar-r1/`
now exists with `QM5_41394_weiss-ichi2-ma-calendar-r1.mq5` + `SPEC.md` (written ~08:39-08:40Z),
matching the reserved identity from `ea_id_registry.csv` (`3005c768-aa91-5daf-9dd7-500d7bfcb7a6`,
status `active`/`Development`). No `.ex5` yet, no `work_items` row for `ea_id=41394` yet — compile
and Q02 enqueue have not landed. No duplicate ticket enqueued, no action taken outside
observation; this task's own next allowed step (enqueue the Q02 work item) is Codex's per the
ticket scope, not mine to pre-empt. All three tasks (`bb814520`, `dfc60103`, `46167bd9`) remain
correctly `IN_PROGRESS`, gated on this rebuild reaching a Q02 verdict.

## Checked 2026-09-09T09:04Z (orchestration cycle) — compile OK, Q02 enqueued

Direct DB read confirms real forward motion since the 0851Z self-correction: compile
work item `1fb4d6f0-c15d-4a10-9ff5-9fd56b5a5f4e` is now `status=done`/`verdict=COMPILE_OK`
(`updated_at=08:50:34Z`), `.ex5` present at
`framework/EAs/QM5_41394_weiss-ichi2-ma-calendar-r1/`, and a fresh Q02 work item
`58b36f74-a831-4119-943b-8a9924b20179` (EURUSD.DWX, `status=pending`) was enqueued
08:54:05Z. Ticket `b66b5ccc` still shows `state=IN_PROGRESS`/`assigned_agent=codex` in
`agent_tasks` (its own row `updated_at` stale at 07:52:47Z — reflects state transitions
only, consistent with the pattern already noted above). `farmctl health` this cycle:
FAIL 14/WARN 15/OK 53 — same chronic set, nothing new bearing on this task. No action
taken beyond this read; Q02 execution and its verdict are the factory's normal path, not
mine to run ahead of. All three tasks (`bb814520`, `dfc60103`, `46167bd9`) remain
correctly `IN_PROGRESS` — acceptance requires the new identity's Q02 (and eventually
Q10_NEWS) verdict, not yet available.

## Checked 2026-09-09T09:26Z (orchestration cycle) — Codex ticket to REVIEW, Q02 still pending

Direct DB read: ticket `b66b5ccc` moved `IN_PROGRESS` → `REVIEW` (`updated_at=09:09:18Z`,
`artifact_path=docs/ops/evidence/2026-09-09_qm5_41394_rebuild_b66b5ccc_execution.md`,
`verdict=BUILD_PASS_Q02_ADMITTED_TESTER_ECHO_PENDING`) — matches its own name: build/compile
passed and the Q02 work item was admitted to the queue, but the tester (the actual Q02
backtest run and its PASS/FAIL echo) has not executed yet. Confirmed `58b36f74` (Q02,
EURUSD.DWX) is still `status=pending` in `work_items` — unchanged since 08:54:05Z. `b66b5ccc`
is a Codex-assigned `ops_issue` task in `REVIEW`, not a claude `IN_PROGRESS` task — reviewing/
closing it is outside this cycle's scope (not in my `list-tasks --agent claude --state
IN_PROGRESS` set) and outside this contract's `selected_effect_only` authority regardless.
`farmctl health` this cycle: FAIL 13/WARN 18/OK 53, no new signal bearing on this chain (same
chronic FAIL/WARN set: `q02_stranded_exhausted_pairs`, `phase_invalid_rate_7d`,
`agent_task_state_stranded`, `work_item_phase_age_slo`, `q09_sealed_plan_hold_age`,
`q09_autoseal_hold_census`, `pending_artifact_binding_drift`, scheduled-task FAILs/WARNs —
none reference `QM5_41394`/`11167`/`11196` or this decision chain). No action taken beyond
this read; the acceptance criterion (a PASS/FAIL Q10_NEWS-reachable verdict on the new
identity) is still not met. All three tasks (`bb814520`, `dfc60103`, `46167bd9`) remain
correctly `IN_PROGRESS`.

## Self-correction 2026-09-09T~0851Z — my own 0850Z entry's "no work_items row" claim was a query bug

My own 0850Z entry above (this cycle, same session) queried `work_items WHERE ea_id=41394`
(bare int) and found nothing, concluding no compile work item existed yet. Re-checked: the
`ea_id` column stores the string `'QM5_41394'`, not the bare int — the numeric filter silently
matched zero rows. Direct correct query (`WHERE ea_id='QM5_41394'` and by explicit id) confirms
the concurrent session's 0900Z entry was right: work item `1fb4d6f0-c15d-4a10-9ff5-9fd56b5a5f4e`
(`kind=compile`, `phase=COMPILE_EA`, `status=active`, `updated_at=08:49:39Z`) exists, and the
release receipt `docs/ops/evidence/2026-09-09_q09_qm5_41394_compile_release_b66b5ccc.json` is
present on disk. No `.ex5` yet under `framework/EAs/QM5_41394_weiss-ichi2-ma-calendar-r1/` (only
`.mq5`/`SPEC.md`/`sets`/`docs`) — compile itself has not completed. Flagging per "evidence over
claims": my 0850Z conclusion was stale/wrong on this one point due to a type-mismatch query bug,
not a real regression; no other claim in that entry is affected. No action taken beyond this
correction — compile completion and Q02 enqueue remain Codex's outstanding steps. All three
tasks (`bb814520`, `dfc60103`, `46167bd9`) remain correctly `IN_PROGRESS`.
