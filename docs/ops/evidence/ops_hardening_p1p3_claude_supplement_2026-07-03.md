# OPS HARDENING P1-P3 — Claude Supplement

**Date:** 2026-07-03  
**Task:** b80ee365 (IN_PROGRESS → REVIEW)  
**Agent:** Claude  
**Base commit:** d57512cef (Codex P1-P3 implementation)

---

## Context

Codex committed P1-P3 implementation in d57512cef (2026-07-03T05:47 UTC). This supplement
documents three gaps that were not covered by that commit:

1. `Factory_OFF.ps1` lacked `param([switch]$NoPause)` — `TestWindow_OFF.ps1` calls it with
   `-NoPause:$true`, which throws "parameter not found" in PowerShell without the declaration.
2. `agent_router.py` heartbeat guard skips lanes where a heartbeat file EXISTS and is stale,
   but routes to lanes that have NEVER written a heartbeat (new deployments, disabled tasks).
   The schtasks-based disabled-lane guard closes this gap: if the scheduled orchestration task
   is Disabled, the router will not assign work to that agent regardless of heartbeat state.
3. `QM_StrategyFarm_GeminiOrchestration_15min` remained Disabled even after the G: fix landed
   in d57512cef. Re-enabled as part of this cycle.

---

## Change 1: Factory_OFF.ps1 — add -NoPause param

**File:** `tools/strategy_farm/Factory_OFF.ps1`

- Added `param([switch]$NoPause)` block (Factory_ON.ps1 already had it; Factory_OFF was missing it)
- Updated self-elevate block to forward `-NoPause` when re-launching as Administrator
- Changed trailing `Read-Host 'Press Enter to close'` to `if (-not $NoPause) { Read-Host ... }`

**Verification:** PowerShell Parser::ParseFile — PASS

---

## Change 2: agent_router.py — schtasks-based disabled-lane guard

**File:** `tools/strategy_farm/agent_router.py`

New imports: `subprocess`, `sys`, `time as _time`

New constants:
```python
_AGENT_LANE_TASKS = {
    "claude": "QM_StrategyFarm_ClaudeOrchestration_15min",
    "codex":  "QM_StrategyFarm_CodexOrchestration_15min",
    "gemini": "QM_StrategyFarm_GeminiOrchestration_15min",
}
_LANE_TASK_STATUS_CACHE: dict  # (agent_id -> (checked_at, is_disabled))
_LANE_TASK_CACHE_TTL_S = 120.0  # 2-minute schtasks query cache
```

New function `_lane_task_disabled(agent_id)`:
- Windows-only; returns False on other platforms (fail open)
- Queries `schtasks /query /tn <task_name> /fo CSV /nh` with 10s timeout
- Caches result for 120s to avoid hammering schtasks on every routing cycle
- Fails open on exception or unknown agent
- Returns True only if schtasks exit code 0 AND stdout contains "Disabled"

`_eligible_agents()` extended:
```python
if _lane_task_disabled(row["agent_id"]):
    continue
```

This prevents routing to gemini (or any other agent) whose orchestration task is Disabled,
even when no heartbeat file exists yet.

**Verification:** py_compile — PASS  
**Behavior check:** Queried schtasks for all three agents; gemini showed "Disabled" before
re-enabling (Change 3 below).

---

## Change 3: Re-enable QM_StrategyFarm_GeminiOrchestration_15min

The G: fix was committed by Codex (d57512cef, P4 — `build_prompt()` skips G: paths for gemini).
The scheduled task remained Disabled despite the fix being live.

Action: `Enable-ScheduledTask -TaskName "QM_StrategyFarm_GeminiOrchestration_15min"`

**Result:** Task state changed from `Disabled` → `Ready`

Gemini orchestration will resume on the next 15-minute trigger. Gemini has 13 APPROVED
research_strategy tasks waiting.

---

## Hard-rule compliance

- T_Live never killed: all process filters use `notmatch 'T_Live'`
- No factory restart triggered (existing factory left running)
- schtasks guard fails open — routing never stalls on a scheduler query failure

---

## Files changed in this worktree commit

```
tools/strategy_farm/Factory_OFF.ps1          (NoPause param)
tools/strategy_farm/agent_router.py          (schtasks disabled-lane guard)
docs/ops/evidence/ops_hardening_p1p3_claude_supplement_2026-07-03.md  (this file)
```
