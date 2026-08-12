# build_ea worktree-vs-canonical-checkout race — QM5_1626 (2026-08-10)

## Finding

Router task `4ee453be` (`build_ea`, QM5_1626 hopwood-bermaui-stoch-h4, capacity-spilled
from Codex to Claude) was picked up **independently by two claude-orchestration slots**
at the same cycle (slots launched ~2026-08-10T21:00:06-07Z from the same scheduler
wake, all reading the same `IN_PROGRESS` list before either had finished):

- **claude-orchestration-3** (this session): built against the canonical checkout
  `C:/QM/repo` per the documented `build_ea` SOP
  (`tools/strategy_farm/prompts/codex_build_ea.md`,
  [[project_qm_build_ea_magic_precheck_block_2026-08-10]]). Commits `155d8fe76` /
  `7b4373240` / `f8ae0ad66` on `agents/board-advisor`. Compile PASS, build_check PASS,
  validate_spec_doc PASS, validate_build_guardrails PASS, 4 setfiles generated.
- **claude-orchestration-2**: initially attempted the same thing against
  `C:/QM/repo`, then — per its own cycle-log commit message
  (`8dc409568`, `agents/claude-orchestration-2` branch) — treated that as a
  **Worktree Discipline violation** (CLAUDE.md: "Agents work in `agents/<role>`
  worktrees, never directly on main"), reverted it, and rebuilt **inside its own
  worktree** `C:/QM/worktrees/claude-orchestration-2`, committing to branch
  `agents/claude-orchestration-2` (commit `aac51b3a8`).

**Root cause: the two governing rules conflict for this task type.** CLAUDE.md's
general Worktree Discipline says never commit build artifacts directly against the
canonical checkout. But the `build_ea` SOP requires the canonical checkout
specifically, because `D:/QM/mt5/T1..T10` terminal workers and
`framework/registry/*.csv` are wired to `C:/QM/repo/framework/EAs/...` — a worktree
copy of the same relative path is **invisible to the actual backtest pipeline** until
merged. claude-orchestration-2's build is well-formed MQL5 but operationally inert:
Q02 will never see it sitting in an unmerged worktree branch.

## Resolution taken this cycle

- Verified the canonical (`C:/QM/repo`) build is complete and correct (registries have
  exactly one set of magic rows for ea_id 1626 — 16260000-3 — no duplication on disk;
  `.ex5` compiles; 4 backtest setfiles present with `RISK_FIXED=1000`/`RISK_PERCENT=0`).
- Corrected router task `4ee453be`'s `artifact_path`/`verdict` to point at the
  canonical build and flagged the `agents/claude-orchestration-2` commit `aac51b3a8`
  as a duplicate that should **not** be merged (would either conflict with or
  double-allocate the same magic rows already live in `agents/board-advisor`).
- Did not touch the `claude-orchestration-2` worktree itself (out of scope, has
  unrelated dirty state from other work — not this session's to manage).

## Standing risk — not fixed, needs an owner decision

`build_ea` tasks routed to `claude` (the capacity-spill fallback path,
`target_agent_profile: codex`) have no per-task lease that's actually enforced across
the 3 concurrent claude-orchestration slots — the "30-minute spawn lease
(`agent_task:<task_id>`)" described in the orchestration prompt
(`tools/strategy_farm/run_agent_orchestration_task.py:114`) is aspirational text with
no implementation backing it (verified: no `agent_task:` lock file convention exists
anywhere in `tools/strategy_farm/`). This session improvised an ad-hoc file lock in
`D:/QM/strategy_farm/locks/agent_task_<task_id>.lock` for its own 3 tasks, but nothing
else in the fleet reads it — it only protects against this exact session re-entering,
not against a sibling slot racing the same task. Recommend either: (a) route
capacity-spilled `build_ea` explicitly to a single claude slot instead of "claude"
generically, or (b) implement a real per-task lock in `agent_router.py`'s IN_PROGRESS
transition (mirroring `acquire_lock`/`release_lock` in
`run_agent_orchestration_task.py:183-224`), or (c) explicitly document "capacity-spilled
build_ea always targets canonical `C:/QM/repo`, Worktree Discipline does not apply to
this task type" in CLAUDE.md so slot-2-style sessions don't self-correct into the wrong
checkout.
