# Stale-Task Disposition PLAN (2026-09-15) — §18 backlog hygiene

A disposition of the **326 TODO + 73 BLOCKED = 399 stale `agent_tasks` rows** as of
2026-09-15. This is a **plan**, not an execution: the auditor does not write the farm DB.
The orchestrator applies it via `tools/strategy_farm/session_tools/apply_stale_task_dispositions.py`
using the sanctioned `agent_router.py` verbs.

- Deterministic plan CSV (regenerable, read-only):
  `docs/ops/evidence/2026-09-15_continuous_book_evolution/stale_task_disposition_plan_2026-09-15.csv`
- Classifier + gated applier: `tools/strategy_farm/session_tools/apply_stale_task_dispositions.py`

## Disposition classes (deterministic rules)
Each row is classified from `task_type` + `verdict`/`payload` + created-age + priority + required
skills. Justification per row is in the CSV `reason` column.

1. **COMMISSION** — route to a lane by capability, because the row is active and its lane can
   execute it.
2. **PARK** — move to BLOCKED with a reason; the row is not currently actionable (missing
   precondition, throttled research, aged backlog) or is a candidate awaiting an OWNER cohort call.
3. **CLOSE** — move to a terminal state (FAILED) with an appended verdict, because the row is
   superseded by OWNER-DEC-CBE-20260915 (Way-to-25 / global-drain doctrine) or executes a prior
   OWNER retirement. CLOSE **appends** a verdict; it never deletes an existing verdict/trade stream.
4. **KEEP** — recent or prioritised; leave in the queue.

## Rule table
| Match | Disposition | Target | Rationale |
|---|---|---|---|
| payload/verdict names "Way to 25" / global-drain / drain-first | CLOSE | FAILED | CBE §3 abolished both as goals |
| `required_skills` has `video_analysis` | PARK | owner | `awaiting_human_lane:owner` (agy has no video tool) |
| `task_type=review_ea` | COMMISSION | claude | review closure is Claude's exclusive duty; head-blocks the lane |
| `build_ea` + verdict "OWNER-retire…" | CLOSE | FAILED | executes a prior OWNER retirement (candidate guard applies) |
| `build_ea` BLOCKED + `PRECONDITION_HOLD…MAGIC/REGISTRY` | PARK | BLOCKED | ordered magic-allocation precondition, not a CBE supersession |
| `build_ea` TODO + age>30d + prio<50 | PARK | BLOCKED | legacy volume-era backlog; CBE trigger is a qualified pool, not build volume |
| `build_ea` recent / prio≥50 | KEEP | — | actively relevant |
| `ops_issue`/`triage_failure` + `owner_decision_execution` skill | PARK | owner | decision-bound |
| `ops_issue`/`triage_failure` age>30d | PARK | BLOCKED | aged ops backlog → explicit re-triage |
| `ops_issue`/`triage_failure` recent | COMMISSION | codex | ops+code lane |
| `research_strategy` age>30d | PARK | BLOCKED | research throttled unless ready-card reservoir <5 |
| `research_strategy` recent | COMMISSION | gemini | agy research lane |
| else | KEEP | — | no rule matched |

## Measured result of the classifier (399 rows)
| Disposition | Count | Breakdown |
|---|---|---|
| **PARK** | 275 | build_ea TODO legacy 227 · build_ea BLOCKED precondition 40 · ops_issue aged 5 · research aged 1 · triage aged 1 · research BLOCKED 1 |
| **KEEP** | 59 | build_ea TODO recent/prio 47 · build_ea BLOCKED recent 12 |
| **COMMISSION** | 49 | review_ea→claude 22 · ops_issue→codex 15 · triage→codex 5 · research→gemini 6 · ops BLOCKED 1 |
| **CLOSE** | 16 | build_ea OWNER-retired ea_ids 16 |

(No literal "Way-to-25"/drain-doctrine tickets survive in the backlog text, so CLOSE is driven by
the OWNER-retired ea_ids, not the abolished-doctrine keyword — an honest result of measuring
rather than assuming.)

## Safety rails (never relaxed)
- **Candidate guard.** `build_ea` rows are candidate-pool members (candidate-pool definition is
  ROT). A PARK of a build_ea row is skipped unless the orchestrator passes
  `--allow-candidate-park`; a CLOSE of a build_ea row is skipped unless `--allow-candidate-close`
  (a stricter, separate opt-in). By default the applier touches only the **non-candidate** rows
  (COMMISSION of review/ops/research + the ops/research PARKs) — 116 rows — and skips all 283
  build_ea PARK/CLOSE rows. The orchestrator opts in per run for the candidate cohort.
- **No verdict/stream deletion.** CLOSE/PARK use `agent_router.py update-task`, which appends a
  verdict; existing verdicts, trade streams and dated evidence are untouched.
- **Canonical checkout enforced.** `agent_router` refuses mutations outside `C:/QM/repo`, so
  `--apply` runs from the canonical repo, never a worktree.
- **The auditor did not write the DB.** Only `--classify` (read-only) was run to produce the CSV.

## Commands for the orchestrator
```powershell
cd C:/QM/repo
# (1) regenerate the plan from live DB (read-only)
python tools/strategy_farm/session_tools/apply_stale_task_dispositions.py --classify `
  --out docs/ops/evidence/2026-09-15_continuous_book_evolution/stale_task_disposition_plan_2026-09-15.csv
# (2) dry-run (prints the exact agent_router commands; candidate guard active)
python tools/strategy_farm/session_tools/apply_stale_task_dispositions.py `
  --plan docs/ops/evidence/2026-09-15_continuous_book_evolution/stale_task_disposition_plan_2026-09-15.csv
# (3) apply the SAFE non-candidate dispositions first (COMMISSION + ops/research PARK)
python tools/strategy_farm/session_tools/apply_stale_task_dispositions.py `
  --plan .../stale_task_disposition_plan_2026-09-15.csv --apply
# (4) after an OWNER/orchestrator cohort decision, apply the legacy build_ea PARKs
python tools/strategy_farm/session_tools/apply_stale_task_dispositions.py `
  --plan .../stale_task_disposition_plan_2026-09-15.csv --apply --allow-candidate-park
# (5) only if confirmed: close the OWNER-retired build_ea rows
python tools/strategy_farm/session_tools/apply_stale_task_dispositions.py `
  --plan .../stale_task_disposition_plan_2026-09-15.csv --apply --allow-candidate-close
```

## Item genuinely needing an OWNER/orchestrator decision
The **275-row legacy `build_ea` PARK cohort** is the one economically meaningful call: these are
volume-era builds (mostly 60–90 days old, priority <50) created under the abolished Way-to-25
doctrine. Under CBE the book trigger is a *qualified pool*, not build volume, so continuing to
carry them as live TODO clutters the board and the router. Recommendation: PARK them (reversible —
BLOCKED with a clear reason; a re-enqueue restores any that a future qualified-pool need wants),
rather than KEEP (false backlog) or CLOSE (premature loss of candidate identity). This is a
board-hygiene action, not a candidate-pool redefinition, but because it touches candidate rows in
bulk it is gated behind the orchestrator's explicit `--allow-candidate-park` opt-in.
