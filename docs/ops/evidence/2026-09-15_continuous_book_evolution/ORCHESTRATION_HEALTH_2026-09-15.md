# AI Orchestration Health — MEASURED (2026-09-15)

Follow-up directive §18 (orchestration health) + §16 (Kimi runs) + §15 (Kimi telemetry) +
§17 (research capacity); master §35 (Claude-lane fan-out). Read-only snapshot ~18:0xZ on the
canonical VPS. Truth precedence: runtime/SQLite/filesystem over docs. Every number below is
reproducible from `D:/QM/reports/state/orchestration_health.json`
(`qm.orchestration-health/v1`, built by `tools/strategy_farm/orchestration_health_readmodel.py`).

## Headline (3 lines)
1. **Routing is correct** (40/40 recent routed tasks; capability ⊆ lane) and the **fan-out
   fix is landed** (`agent_task_exec:*` owner-scoped leases + `--max-sessions 1` live), so no
   new double-claim can occur; the two pre-fix collided rows (`3e0c8b83`, `42a437a4`) remain
   IN_PROGRESS with expired NULL-owner router leases and are the disposition plan's only
   in-progress items.
2. **Review independence is currently DEGRADED**: 4 of the 5 latest completed critiques ran
   **same-vendor** (`cross_vendor=false`, claude critiquing a claude creator) because the
   Codex and agy critic lanes are quota-gated. This was surfaced in each receipt; it is now
   also surfaced in Mission Control via the new read-model (the §18 / item-4 fix).
3. **Kimi is fully operational**: telemetry is real (`usage_source=managed_usage_endpoint`,
   fetch ok, bounded refresh, `last_ok` reuse) and two sealed research artifacts exist
   (QM-RESEARCH-2026-0001/0002). Research is unblocked (guard `allowed=true`, scratch on C:).
   Overall health = **AMBER** (quota flags on three lanes + same-vendor critics + stale backlog).

---

## Per-lane state

| Lane | Registry | Task states (current) | Quota posture |
|---|---|---|---|
| **claude** | enabled, max_par 3, caps code/ops/review/strategy/summary/… | PASSED 185 · PIPELINE 36 · APPROVED 26 · FAILED 20 · IN_PROGRESS 2 · RECYCLE 1 · BLOCKED 1 | **THROTTLED** — weekly 96% (hard ceiling ≥90%), 5h 31%; `CLAUDE_DISABLED.flag` (set 2026-09-15T12:38Z, earlier 10:38Z); router `enabled:false`. Week reset 2026-09-17T22:00Z. |
| **codex** | enabled, max_par 5 | PASSED 921(+46 wt) · FAILED 146(+6) · PIPELINE 68(+51 wt) · APPROVED 68 · BLOCKED 40 · TODO 1 · OPS_FIX 1 | **HOLD-THROTTLE** — weekly 80% at 47% elapsed (+33pts, proj EOW ~170%); `CODEX_LOW_TOKENS.flag` (2026-09-12T18:38Z); budget line anchor 80% → target 92% at reset 2026-09-19T08:29Z. |
| **gemini (agy)** | enabled, max_par 2 | PASSED 65 · FAILED 49 · PIPELINE 32 · BLOCKED 28 · RECYCLE 1 | **UNKNOWN / EXPIRED** — `agy_quota.json ok:false`, HTTP 401 UNAUTHENTICATED, `token_expired:true` (expiry 2026-09-15T10:40+02); `AGY_LOW_QUOTA.flag` (2026-09-15T10:40Z). Needs **OWNER Antigravity relogin** (OWNER-lane action, already known). |
| **kimi** | enabled, max_par 1, research caps only | (no agent_tasks rows; runs via router/orchestration lane) | **NORMAL** — `usage_source=managed_usage_endpoint`, fetch ok, day 6/120, week 6/600, real rolling-5h/7d 0.0/0.0, plan Allegro. No `KIMI_LOW_QUOTA.flag`. |
| **owner** | declared-but-disabled (enabled:false, max_par 0) | video/decision-bound rows held `awaiting_human_lane:owner` | Human lane; scarce seat; nothing routed to it that a seat could do. |

Task-state totals across all lanes: PASSED 1319 · TODO 326 · FAILED 251 · PIPELINE 219 ·
APPROVED 102 · BLOCKED 73 · RECYCLE 10 · OPS_FIX_REQUIRED 6 · IN_PROGRESS 2.

## Throughput (last 7 days) — reached APPROVED, by lane × day
Method: `updated_at` last-transition proxy for `state=APPROVED` (the deterministic best
available signal). **Caveats:** a task later advanced past APPROVED (→PIPELINE/PASSED) no
longer carries APPROVED, so this UNDER-counts; a **bulk `updated_at` re-touch on 2026-09-12**
contaminates that day; the `agent_task_transition_ledger` is a partial action log (69 rows, ends
2026-09-12), not a full move history.

| Day | claude | codex | (unassigned) |
|---|---|---|---|
| 2026-09-12 | — | 54 (bulk-touch contaminated) | — |
| 2026-09-13 | 8 | 9 | 1 |
| 2026-09-14 | 12 | — | 7 |
| 2026-09-15 | 6 | 5 | — |

Signal: the claude authoring lane cleared ~26 APPROVED over 09-13→09-15 even while throttled
(headless Sonnet builds run on the separate cheap quota); codex clears steadily under its budget
line. No lane is head-blocked at the review gate right now (0 rows in REVIEW).

## Stale tasks
- **IN_PROGRESS beyond lease TTL (30 min): 2** — `3e0c8b83` (fan-out remediation ticket) and
  `42a437a4` (FTMO demo-v2 census). Both hold router `agent_task:*` leases that **expired
  2026-09-15T11:02:32Z** with `owner_pid=NULL`; both are the documented pre-fix collision
  (see master §35). Disposition: reconcile per `42a437a4`'s own RECYCLE→merge verdict, then
  the rows move forward; they are not a new incident.
- **TODO older than 14 days: 308** of 326 (189 are 60–90 days old). Concentrated in the
  legacy `build_ea` volume backlog — see `STALE_TASKS_DISPOSITION_2026-09-15.md`.
- **BLOCKED: 73**, 69 aged 14–30 days, almost all `PRECONDITION_HOLD_*_MAGIC/REGISTRY` on
  `build_ea` candidate rows (16 are OWNER-retired ea_ids).

## Double claims / fan-out fix state (master §35)
- The fix (`agent_task_exec:<id>` owner-scoped leases claimed by the launcher before spawn +
  prompt hard-pin + M2 drain chaining + M1 fail-closed candidate query) is **present at HEAD**
  (`run_agent_orchestration_task.py`: `_run_claude_session_chains`, `acquire_task_exec_lease`,
  `claim_task_exec_leases`, `QM_ASSIGNED_TASK_ID`).
- **Not yet exercised on the live DB**: `spawn_leases` holds **0** `agent_task_exec:*` rows and
  **31** router `agent_task:*` rows, all `owner_pid=NULL` (route-time only, by design; they
  never gated sibling sessions). Reason: the claude orchestration lane has not spawned under the
  new scheme because it is quota-disabled since ~10:38Z **and** the scheduled task is now
  `--max-sessions 1` (interim mitigation, verified live). With 1 session per launcher there is no
  sibling to collide with, so the defect cannot recur meanwhile.
- **Before/after ~13:5xZ fix**: the last multi-slot claude run was `2026-09-15T09:45Z`
  (slot1+slot2+slot3 logs present) — that was BEFORE the fix landed AND before the quota-disable;
  the 10:32Z window produced the two colliding IN_PROGRESS rows. **No claude orchestration run
  has occurred after the fix landed** (lane disabled), so a live post-fix zero-collision run
  cannot yet be demonstrated — it will be the first exit criterion when the lane is re-raised to
  `--max-sessions 3` after the fix is confirmed.

## Critic-chain independence (the §18 / item-4 finding + fix)
From the 5 task-bound critique receipts under `D:/QM/strategy_farm/state/agent_chain/tasks/`:

| chain / task | creator | critic | cross_vendor | verdict |
|---|---|---|---|---|
| 9e0fb916 | claude | **agy** | **true** | UNPARSED |
| 42a437a4 | claude | claude:opus | **false** | REJECT |
| c30eebc8 | claude | claude:opus | **false** | GAPS |
| d2849e93 | claude | claude:opus | **false** | GAPS |
| dc7f0545 | claude | claude:opus | **false** | GAPS |

- **4/5 completed critiques ran same-vendor** (`same_vendor_share=0.80`, `independence_degraded=true`).
  Mechanism (from `seat_trace`): for a claude-created deliverable the critic candidate order is
  `[codex:terra, claude:opus, agy:default]`; **codex is skipped `codex_low_tokens_flag`** and
  **agy is skipped `agy_low_quota_flag`**, so the only open seat is the same-vendor last-resort
  `claude:opus` (recorded with `note: "same-vendor fallback: different model, cross_vendor=false"`).
  `critic_fallback_used=0` (no intra-chain seat replacement in these five).
- This is a **quota-driven independence reduction, not a code defect**: `agent_chain.open_critic_seats`
  still enforces the hard invariant (Kimi never critiques Kimi) and records `cross_vendor` truthfully.
- **Item-4 verification & fix:** the reduction was already surfaced **in the receipt**
  (`plan.critic.cross_vendor=false`, per-stage `cross_vendor`, the same-vendor note). It was **not**
  surfaced in Mission Control. It now is — `orchestration_health.json` computes
  `cross_vendor_false / same_vendor_share / independence_degraded` and raises the health flag
  `critic_same_vendor:4/5`, and `mission_control_v2_data.build_contract` binds
  `orchestration_health` verbatim. No further code change is warranted in `agent_chain` itself.

## Quota-flag time-on
| Flag | Kind | On since | State |
|---|---|---|---|
| `CLAUDE_DISABLED.flag` | lane gate | 2026-09-15T12:38Z (earlier 10:38Z) | ON — weekly hard ceiling |
| `CODEX_LOW_TOKENS.flag` | lane gate | 2026-09-12T18:38Z | ON — budget-line hold |
| `AGY_LOW_QUOTA.flag` | lane gate | 2026-09-15T10:40Z | ON — token expired (OWNER relogin) |
| `KIMI_LOW_QUOTA.flag` | lane gate | — | absent (Kimi NORMAL) |
| `CLAUDE_BURN_AUTHORIZED.flag` / `CODEX_BURN_AUTHORIZED.flag` | informational | 2026-08-24 / 08-22 | expired/inert |

Three of four AI critic/execution lanes carry a live quota gate right now, which is exactly why
review independence collapsed to same-vendor (only claude was an open critic seat).

## Routing correctness
Sample of the 40 most recently routed tasks: **40 OK / 0 mismatch**. Every assigned lane's
registry capabilities cover its task-type + payload `required_capabilities`. `ops_issue` rows
route to claude/codex (both hold `code`+`ops`); `review_strategy`/`research_strategy` to the
research-capable lanes. Registry code, router runtime and the vault Annex agree
(`registry_contract.ok:true`).

## Kimi telemetry final state (§15)
`kimi_quota_state.json` (`qm.kimi-quota/v1`): `fetch_status=ok`,
`source=api.kimi.com/coding/v1/usages`, `usage_source=managed_usage_endpoint`,
`refresh_calls=1`, `refresh_last_utc=2026-09-15T15:36:12Z`, `last_ok` block present (reused by
the governor within a 7 h window between bounded refreshes), plan Allegro, rolling-5h/7d
`used_ratio` 0.0/0.0, monthly `null` (endpoint omits `limit_month_*` on a near-idle Allegro
account). Local 40/200 caps were reclassified to a `runaway_guard` (120/600) so real capacity
wins. **Mission Control now shows actual Kimi capacity, not artificial local call counts** —
directive §15 target reached. (Fallback path retained: any fetch failure → `local_ledger_fallback`.)

## Kimi actually runs (§16 checklist — all YES)
Lane enabled (governor NORMAL; `QM_StrategyFarm_KimiOrchestration_15min` installed 2026-09-15) ·
real campaign ran (CAMP-2026-0001, Kimi 932 s live) · artifact produced
(QM-RESEARCH-2026-0001, sealed `research_source.verify ok`) · criticised cross-provider
(creator Kimi / critic Claude, `cross_vendor=true`) · sealed (verdict REVISE≠REJECT) · produced a
mechanical hypothesis (**H-CW** cash-window index continuation, minted into successor
QM-RESEARCH-2026-0002) **and** a durable negative finding · visible in
`experiment_memory_ledger.jsonl` (9 rows) + `research_state.json` (1 campaign). **Honest caveat:**
the cross-vendor critic was Fable inline (a different vendor than the Kimi creator), not a spawned
headless seat, because all three non-Kimi critic lanes were quota-gated on 2026-09-15
(`critic_fallback_used=true` recorded); re-running through a spawned non-Kimi seat once a critic
lane is off quota-hold is the standing next-experiment item.

## Research resource capacity final state (§17)
`research_guard()` live: **allowed=true**. Scratch root `C:\QM\repo\artifacts\research_datasets`
(46.3 GB free vs 20 GB floor), not on the factory drive; factory floor (60 GB, single-sourced
from `config/factory_disk_policy.v1.json`) applies only when scratch is on D:; RAM 30 GB free;
CPU pause threshold 97%; max 2 worker processes. The old flat `D:<80 GB` block (which the
tester-cache purge parked D: below permanently) is replaced by the measured guard, so research is
no longer indefinitely blocked and MT5 headroom is not threatened.

---

## What was fixed in this slice
1. New deterministic read-model `orchestration_health_readmodel.py` →
   `D:/QM/reports/state/orchestration_health.json` (`qm.orchestration-health/v1`), wired into the
   existing 15-min read-model runner (`book_evolution_runner.py readmodels`) — no new task.
2. `mission_control_v2_data.build_contract` now binds `orchestration_health` verbatim
   (EVIDENCE_MISSING tolerant), so the same-vendor-critic independence reduction and the quota /
   stale / double-claim signals are visible in Mission Control — the §18 item-4 fix.
3. Stale-task disposition PLAN + gated dry-run applier (see `STALE_TASKS_DISPOSITION_2026-09-15.md`).

## What genuinely needs OWNER / orchestrator action
- **OWNER:** Antigravity (agy) relogin to clear the expired token (restores the agy critic seat →
  restores cross-vendor review independence). Already a known OWNER-lane item.
- **Orchestrator:** (a) reconcile the two collided IN_PROGRESS rows per `42a437a4`'s merge verdict;
  (b) once the fan-out fix is confirmed, re-raise `QM_StrategyFarm_ClaudeOrchestration_15min` to
  `--max-sessions 3` and confirm a live zero-collision run; (c) decide the legacy `build_ea` cohort
  disposition (275 PARK candidates) — see the disposition plan. None of these weaken a gate,
  qualification, or touch T_Live.
