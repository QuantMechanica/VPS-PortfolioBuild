# repo_dirty_build_guard diagnostic — exact paths, no blanket commit

Task: `a7392dc6-89fa-4c95-ae55-76df10ddda9f`. Request: run the actual dirty-guard
diagnostic to get the exact 3 stale EA path names (not a guess), cross-check the
124 `LANE_EVIDENCE_PENDING_COMMIT` / 73 `COMPILE_OUTPUT_PENDING_COMMIT` paths
against the ASTRA takeover evidence before assuming they're safe to commit, and
clear both classes only through their documented governed mechanism (no
`git add -A`).

## Method

Ran the identical classifier the `ftmo_claude_chat_delivery` pulse uses, read-only,
against the canonical checkout:

```
cd C:/QM/repo && python -X utf8 -c "
import sys; sys.path.insert(0, 'tools/strategy_farm')
import ftmo_owner_status_pulse as p
print(p.collect_git())"
```

`collect_git()` (`tools/strategy_farm/ftmo_owner_status_pulse.py:452-503`) only
calls `git status --porcelain --untracked-files=all` and `git rev-parse` — no
write. HEAD `1deb14d4de`, 200 dirty entries total.

## Result — counts match the pulse exactly

| class | count |
|---|---|
| `LANE_EVIDENCE_PENDING_COMMIT` | 124 |
| `COMPILE_OUTPUT_PENDING_COMMIT` | 73 |
| `ORPHAN` (actually build-blocking) | 3 |
| `LIVE_SESSION` / in-flight | 0 |

## The exact 3 ORPHAN (build-blocking) paths

```
framework/EAs/QM5_1537_aa-vol-sma10/calendar/QM5_1537_monthly_sleeves_v3.csv            (1261 min old, ~21h; no build-bridge log activity for this EA)
framework/EAs/QM5_1537_aa-vol-sma10/calendar/QM5_1537_monthly_sleeves_v3.manifest.json   (1261 min old)
framework/EAs/QM5_1537_aa-vol-sma10/calendar/QM5_1537_monthly_sleeves_v3.sources.csv     (1261 min old)
```

All three are non-generated, non-evidence files under one EA (`QM5_1537`), aged
past `DIRTY_ORPHAN_MIN` with no recent live build log naming that EA directory —
`classify_dirty_path` correctly calls them `ORPHAN`. These are the 3 paths the
pulse's "blocks 2 builds" line refers to. Whoever last edited `QM5_1537`'s
calendar sleeves needs to finish and let its own session/build-lane commit it,
or abandon the edit; this is not evidence or a compile output and is outside
this task's governed-commit scope.

## COMPILE_OUTPUT_PENDING_COMMIT (73) — not an allowlist gap, pump hasn't swept

73 files across 24 distinct `framework/EAs/QM5_*/sets/*.set` paths, ages 1261–
10196 minutes (~21h to ~7.1 days). All match `_generated_ea_artifact_kind` ==
`generated_setfile`, which `_is_auto_committable_factory_artifact`
(`farmctl.py:22849`) already allowlists — unlike the 2026-09-19 incident
(`docs/ops/evidence/2026-09-19_dirty_guard_recurring_generator_allowlist/README.md`),
this is **not** a missing-allowlist-entry defect.

The governed mechanism is the factory pump's own per-cycle auto-commit sweep
(`_auto_commit_build_artifacts` / `_plan_artifact_auto_commit` in `farmctl.py`),
triggered off `work_items` `COMPILE_EA` `COMPILE_OK` receipts — not a manual
`git commit` by any agent. `docs/ops/evidence/2026-09-26_astra_takeover/takeover_status.json`
records `"FACTORY_ACTIVE": 0` at its last snapshot (2026-09-27T12:31Z), and the
ASTRA README documents a deliberate research-first posture that has kept pump
cycles sparse — consistent with up to 7 days of unswept setfiles. Forcing a
manual commit here would bypass the pump's own receipt-gated sweep; the correct
fix is confirming pump cadence/health, not committing from this task.

## LANE_EVIDENCE_PENDING_COMMIT (124) — breakdown confirms the requester's caution was right

| top-level evidence dir | count | ownership |
|---|---:|---|
| `docs/ops/evidence/build_attempts/**` | 76 | `build_source_quarantine.py` quarantine manifests (`*.attempt.json`/`*.patch`), one subdir per EA — a general build-lane safety mechanism, not scoped to a single `agent_task` |
| `docs/ops/evidence/2026-09-26_astra_takeover/**` | 35 | live ASTRA sub-task evidence, dated through research-continuation checkpoints in README.md up to 2026-10-01 |
| `docs/ops/evidence/task_3f7d4023-23bc-4e46-a1c4-9688068fa550/**` | 8 | explicitly open ASTRA-spawned task (QM5_10122 input repair, per the takeover README) |
| `docs/ops/evidence/2026-10-01_qm1537_refresh_202610/**`, `2026-09-26_qm5_11263_sealed_input_rebuild/**`, `task_affea503-.../**` | 5 | other task-scoped evidence dirs |

Cross-checked against `docs/ops/evidence/2026-09-26_astra_takeover/README.md`
and `takeover_status.json`: the 35 ASTRA-prefixed files belong to an actively
continuing takeover (Q04 replay holds still active, Q08 independent review
queued, research-continuation entries dated through 2026-10-01) — exactly the
"in-flight evidence, needs its own governed receipt/close-review" case the task
warned about. The 8 `task_3f7d4023` files belong to another explicitly-open
task from the same README. None of the 124 is a generic, safe-to-batch-commit
set — each belongs either to an open task's own close-review (per
`classify_dirty_path`'s own doc comment: "untracked research/review evidence
which close-review commits by task-scoped pathspec") or to the build-quarantine
mechanism.

One gap worth flagging: `docs/ops/evidence/build_attempts/` (76 of the 124) is
covered by neither `ARTIFACT_COMMIT_ALLOWLIST` nor `_generated_recurring_doc_kind`
in `farmctl.py` — structurally the same "whack-a-mole allowlist gap" class as
the 2026-09-19 fix. Confirming and closing that gap means editing `farmctl.py`
in the canonical checkout, which is out of scope for this task (this session's
launcher instructions forbid writing to `C:/QM/repo`) and is a separate,
reviewable code change, not a commit of the pending evidence files themselves.

## Why no commit was made

1. This session's launcher mandate is explicit: never write to `C:/QM/repo`
   (a prior half-applied edit there caused a governed-enqueue SyntaxError on
   2026-09-26). Clearing any of these 200 paths means committing inside that
   exact checkout.
2. Independent of that constraint, 119 of the 124 `LANE_EVIDENCE_PENDING_COMMIT`
   files belong to other open tasks (ASTRA takeover sub-tasks, `task_3f7d4023`,
   build-quarantine) that own their own close-review — committing them from
   here would be exactly the blanket, non-task-scoped commit the request said
   not to do.
3. The 73 `COMPILE_OUTPUT_PENDING_COMMIT` files are correctly cleared only by
   the pump's receipt-gated auto-commit sweep, not a manual commit.

No `git add` / `git commit` was executed in `C:/QM/repo` by this task.

## Before / after

| | before | after |
|---|---:|---:|
| dirty files total | 200 | 200 (unchanged — diagnostic only, by design) |
| `LANE_EVIDENCE_PENDING_COMMIT` | 124 | 124 |
| `COMPILE_OUTPUT_PENDING_COMMIT` | 73 | 73 |
| `ORPHAN` (build-blocking) | 3 | 3 |

## Recommended next steps (for OWNER / router, not self-assigned here)

1. Confirm factory pump cadence/health; once a pump cycle runs with `FACTORY_ACTIVE`
   > 0, its own auto-commit sweep should clear the 73 aged setfiles without any
   manual commit.
2. Open a scoped follow-up to add `docs/ops/evidence/build_attempts/` to
   `farmctl.py`'s generated/evidence allowlist classification (same fix shape as
   the 2026-09-19 precedent) if this evidence class is meant to be pump-committed
   rather than per-task.
3. Route the 3 `QM5_1537` ORPHAN paths to whoever owns that EA's calendar-sleeve
   edit, to finish/commit or abandon it and release the 2 blocked builds.
