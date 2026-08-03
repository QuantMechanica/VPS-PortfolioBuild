# Pre-spawn quota gate — task 9dd1f1f8

Date: 2026-08-03

Router task: `9dd1f1f8-cd92-42e6-87de-b030a73f8ac6`

Verdict: **READY_FOR_REVIEW — RECYCLE ESCALATION DELTA COMPLETE**

## Outcome

A config-driven quota gate now decides Codex/Claude work before both router
assignment and 15-minute CLI spawn. It consumes weekly utilization, weekly
window elapsed, and the provider's five-hour utilization when present. It does
not gate MT5 backtests or other deterministic work.

Implementation commits on canonical `agents/board-advisor`:

- `347b96367` — quota policy, gate engine, router/wrapper/governor integration,
  model/effort selection, tests, and runbook.
- `30da53056` — guarded the existing `G:/My Drive` availability probe so the
  SYSTEM orchestration lane cannot fail before command construction.
- `24eeac2cc` — binds review rejection to exactly one higher configured model/
  effort tier, persists the escalation audit, and prevents duplicate escalation
  on a stale-lease reroute.

Registered `main` evidence publication: `847df630a`.

The scheduled tasks `QM_StrategyFarm_AgentRouter_5min`,
`QM_StrategyFarm_{Codex,Claude}Orchestration_15min`, and
`QM_StrategyFarm_QuotaGovernor` all execute the canonical `C:/QM/repo` files, so
the committed decision points are on their registered runtime paths.

## Binding inputs and supersession

The routed payload initially cited the 2026-07-28 blanket Codex `max` rule.
While this task was active, OWNER-approved commit `3e5cb409d` added
`docs/ops/CODEX_BRIEF_2026-08-03_effort_model_matrix.md`, explicitly binding to
this ticket and superseding blanket-max for the 5x-plan era.

The JSON policy encodes that matrix:

- Codex `max`: contracts, fail-closed/runtime-decision changes, root-cause
  forensics, adjudications.
- Codex `high`: ordinary tested code, EA builds, evidence tooling.
- Codex `medium`: mechanical edits, census/report scripts, doc mirroring.
- Claude: Sonnet by default; Opus only through deliberate task payload field
  `claude_headless_model: opus` (or the existing explicit environment override).

This ticket selects `gpt-5.6-sol` / `max` because its payload contains
fail-closed and decision-bound quota-gate work. The actual command slice was:

```text
-m gpt-5.6-sol -c model_reasoning_effort="max"
```

Utilization can allow or defer a task, but never lowers the already selected
model/effort tier.

## Recycle escalation binding

The review rejection identified one missing binding principle: a rejected run
must retry exactly one tier higher. That path is now deterministic and uses the
existing bounded `recycle_count` written by `close_review_task` and preserved by
the `RECYCLE -> TODO` transition.

- Codex tier order is read from policy (`medium -> high -> max`). The retry is
  `max(class_tier, prior_run_tier + 1)`, capped at `max`.
- Claude tier order is read from policy (`sonnet -> opus`), so a rejected
  Sonnet run retries on Opus and then remains capped.
- `quota_tier_escalation` records recycle count, base tier, prior run tier,
  selected tier, cap state, and disposition in the task payload. The same
  object is exposed under `last_gate.tier_escalation` in the one-line headroom
  contract.
- The handled recycle count prevents a lease-expiry reroute of the same attempt
  from consuming a second tier. Non-recycled tasks retain their class-selected
  tier unchanged.
- Router-owned `quota_gate` audit text is excluded from class marker matching;
  otherwise the field name itself would incorrectly make every recycled Codex
  task `max` before the escalation rule was evaluated.

## Gate policy

Policy source: `tools/strategy_farm/config/agent_quota_gate.v1.json`.

| Class | Weekly used max | Pace diff max (`used - elapsed`) | Five-hour used max | Missing/stale |
|---|---:|---:|---:|---|
| research | 65% | -5 points | 50% | deny |
| build | 78% | 0 points | 65% | deny |
| ops/review | 95% | +15 points | 90% | allow |

Additional rules:

- State freshness: 30 minutes.
- OWNER priority: `priority >= 70` bypasses class thresholds.
- Hard exhaustion: weekly `>=98%` or reported five-hour `>=95%`; this blocks
  even OWNER-priority work.
- Ops/review is explicitly allowed whenever weekly pace has surplus, below hard
  exhaustion.
- `backtest`, `backtest_*`, `deterministic`, and `deterministic_*` return ALLOW
  before state or policy reads. This remains true even if the policy file is
  unavailable.

## Acceptance mapping

1. `agent_router.route_once` evaluates every eligible Codex/Claude candidate
   before acquiring `agent_task:<task_id>` and records the accepted decision in
   task payload. Quota-blocked research no longer hides lower-priority ops work;
   the former 25-row scan cap was removed and covered by regression test.
2. `run_agent_orchestration_task.run_agent` evaluates assigned and compatible
   unrouted candidates before `run_agent_slot` can acquire a slot or start a CLI.
   Claude session count is capped to allowed-task count.
3. Thresholds and model/effort classes live in repo JSON, not routing literals.
4. `quota_governor._agent_metrics` now persists `five_hour_used_pct` when the
   provider supplies it. On the verification snapshot Codex reported no
   five-hour window; Claude reported 10%.
5. `D:/QM/reports/state/quota_headroom_summary.json` is atomically written as
   single-line `qm.quota_headroom.v1` JSON with Codex/Claude used and remaining
   weekly percentages plus the last gate decision and invocation profile.
6. `agent_router status` exposes that small contract as `quota_headroom`.

Live evaluation for this task at verification time:

```json
{
  "allowed": true,
  "reason": "pace_surplus_continuity",
  "codex_weekly_used_pct": 26.0,
  "codex_weekly_elapsed_pct": 33.5,
  "codex_five_hour_used_pct": null,
  "selected_model": "gpt-5.6-sol",
  "selected_reasoning_effort": "max"
}
```

## Decision-bound files

The following files change runtime decisions and therefore required the `max`
tier for this implementation/review:

- `tools/strategy_farm/quota_spawn_gate.py`
- `tools/strategy_farm/config/agent_quota_gate.v1.json`
- `tools/strategy_farm/agent_router.py`
- `tools/strategy_farm/run_agent_orchestration_task.py`
- `tools/strategy_farm/quota_governor.py`

Documentation/tests changed alongside them:

- `docs/ops/QUOTA_GOVERNOR_AND_FACTORY_RECOVERY_2026-06-21.md`
- `tools/strategy_farm/tests/test_quota_spawn_gate.py`
- `tools/strategy_farm/tests/test_agent_orchestration_lock.py`

## Verification

Original focused command:

```powershell
python -m pytest -q `
  tools/strategy_farm/tests/test_antigravity_backend_contract.py `
  tools/strategy_farm/tests/test_strategy_farm_package_imports.py `
  tools/strategy_farm/tests/test_quota_spawn_gate.py `
  tools/strategy_farm/tests/test_agent_orchestration_lock.py `
  tools/strategy_farm/tests/test_agent_router.py `
  tools/strategy_farm/tests/test_quota_window_consumers.py
```

Result: `48 passed in 37.91s`.

Recycle-delta focused command:

```powershell
python -m pytest -q `
  tools/strategy_farm/tests/test_antigravity_backend_contract.py `
  tools/strategy_farm/tests/test_strategy_farm_package_imports.py `
  tools/strategy_farm/tests/test_quota_spawn_gate.py `
  tools/strategy_farm/tests/test_agent_orchestration_lock.py `
  tools/strategy_farm/tests/test_agent_router.py `
  tools/strategy_farm/tests/test_agent_router_state_exits.py `
  tools/strategy_farm/tests/test_quota_window_consumers.py
```

Result: `73 passed in 11.17s`.

The added regressions prove first recycle `medium -> high`, second recycle
remaining capped at `max`, Claude `sonnet -> opus`, non-recycled tier stability,
task-payload persistence, headroom persistence, and single-count close-review
reconciliation.

Also passed:

- `python -m py_compile` for the gate, governor, router, and orchestration
  wrapper.
- `git diff --check` for every implementation/test/runbook path.
- Local Codex CLI parse check with
  `codex exec -c 'model_reasoning_effort="max"' --help` (exit 0, no model spawn).
- Actual-state gate evaluation and one-line headroom-contract parse.

## Safety and scope

- No terminal, terminal worker, MT5 backtest, `T_Live`, or AutoTrading action was
  started, stopped, or changed.
- No pipeline phase or pipeline verdict was created.
- Existing unrelated EA/framework working-tree changes in `C:/QM/repo` were
  deliberately left unstaged and uncommitted by these commits.
- The optional `G:` company-reference drive was unavailable to the originating
  headless Codex worktree; the local charter/profitability docs and routed
  payload were used, followed by the later binding OWNER matrix commit.
