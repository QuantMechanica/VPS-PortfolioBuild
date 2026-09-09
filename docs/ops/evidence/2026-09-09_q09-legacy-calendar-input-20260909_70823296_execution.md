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
