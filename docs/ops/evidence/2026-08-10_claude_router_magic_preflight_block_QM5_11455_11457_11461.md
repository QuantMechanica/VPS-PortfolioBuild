# Claude router build pre-flight block: QM5_11455, QM5_11457, QM5_11461

Date: 2026-08-10
Role: Claude / orchestration cycle (worktree 3), covering for `target_agent_profile: codex` tasks routed to claude
Scope: one deterministic router cycle; three `build_ea` tasks at numeric priority 50
Verdict: `PRECHECK_BLOCK_MAGIC_ROWS_MISSING`

## Outcome

No EA implementation, registry mutation, compile, smoke test, pipeline phase, or
queue mutation was performed for this cohort. This confirms and extends the same
gap class Codex reported ~1h earlier for QM5_11291/11292/11294/11299/11300
(`docs/ops/evidence/2026-08-10_codex_router_magic_preflight_block_QM5_11291_11300.md`):
all three approved cards have a matching **active** row in the canonical EA-ID
registry, but **zero** rows in the canonical magic-number registry.

## Router tasks checked

| Priority | Task ID | EA | Card slug | Canonical EA-ID rows | Canonical magic rows | Result |
|---:|---|---|---|---:|---:|---|
| 50 | `22d3a361-f77f-483b-9837-875fef523a26` | `QM5_11455` | `davey-donchian-close-breakout` | 1 | 0 | pre-flight block |
| 50 | `3d6528b3-867e-49d7-b359-3ea00ab4137d` | `QM5_11457` | `goodwin-6day-extreme-3day-stop-entry-d1` | 1 | 0 | pre-flight block |
| 50 | `d683a46f-5e83-48fc-bccd-9106e8f3f489` | `QM5_11461` | `goodwin-j-outside-bar-daily-reversion-d1` | 1 | 0 | pre-flight block |

All cards were read from `D:/QM/strategy_farm/artifacts/cards_approved/` and each
declares `g0_status: APPROVED`. Canonical EA-ID slugs exactly match the card and
task slugs (verified against `C:/QM/repo/framework/registry/ea_id_registry.csv`
lines 2336, 2338, 2342).

## Missing governed allocations

Card-declared `target_symbols` (identical 5-symbol FX basket for all three):

- `QM5_11455`: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`
- `QM5_11457`: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`
- `QM5_11461`: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`

This records card intent only; it is not an allocation and does not reserve slots.

## Repository state observed

Canonical sources checked (all reads from `C:/QM/repo`, not the agent worktree —
`C:/QM/worktrees/claude-orchestration-3/framework/registry/ea_id_registry.csv` is
stale, topping out at ea_id 10843 dated 2026-05-22; the canonical checkout is current):

- `C:/QM/repo/framework/registry/ea_id_registry.csv` — rows present for all three ea_ids
- `C:/QM/repo/framework/registry/magic_numbers.csv` — no rows for any of the three ea_ids

## Process inconsistency worth flagging to OWNER

Two documents govern `build_ea` and disagree on registry-allocation scope:

1. `skills/qm/qm-build-ea-from-card/SKILL.md` (basis:
   `framework/scripts/skill_build_ea_guard.py`) treats registry presence as a
   precondition checked before LLM-only work starts, and does not include
   allocation in "LLM-only scope."
2. `tools/strategy_farm/prompts/codex_build_ea.md` §Workflow steps 2-3 explicitly
   instruct the build agent to self-allocate both the EA-ID row and the magic rows
   (`HARD ABORT on collision`), then regenerate `QM_MagicResolver.mqh`.

Same-day evidence shows both readings actively in use by different Codex workers:
the 11291-11300 block (14:25Z) followed the conservative (1) reading and escalated;
commit `5b5c78689` (~15:11Z, `agents/board-advisor` branch) built QM5_11434 and
QM5_11435 by self-allocating magic rows per (2) and succeeded (`build_check PASS
0/0`, compiled, 5 backtest set files each, magic slots 114340000-4 / 114350000-4
registered, resolver regenerated). No collision occurred in that case, but with
multiple `codex` build_ea tasks running concurrently (5 `IN_PROGRESS` at the time
of this cycle) and no file lock protecting `magic_numbers.csv` appends (unlike
`ea_id_registry.csv`, which has `_acquire_registry_lock` in `farmctl.py`), this is
an unsynchronized read-modify-write on a shared CSV — the exact class of race that
`update_magic_resolver.py`'s docstring documents as having already caused a real
incident (2026-05-16, QM5_1050 build silently dropped QM5_1047's rows).

Claude did not self-allocate for this cohort, to stay consistent with the more
recent, more conservative field precedent (11291-11300 block) rather than create a
third, independently-reasoned policy. Recommend OWNER pick one canonical reading
and either delete/update the stale document, or add a lock around
`magic_numbers.csv` appends (mirroring `_acquire_registry_lock`) so workflow (2)
becomes safe to run concurrently across agents.

## Required next action

Reconcile the two SOPs (see above), then either allocate the required magic rows
through an explicit governed workflow, or confirm self-allocation per
`codex_build_ea.md` is sanctioned and add the missing lock. Reroute
QM5_11455/11457/11461 build tasks once resolved.
