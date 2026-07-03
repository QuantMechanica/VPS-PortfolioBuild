# Claude Lane: repo_edit / ops / repo Capability Grant

**Date**: 2026-07-03  
**Authority**: OWNER directive 2026-07-02 ("Sonnet kann auch Programmieraufgaben, die sonst fuer Codex sind, ausfuehren")  
**Reference**: DL-065 (Agent Capability Scopes), task e1fb9395  
**Evidence file**: this document  

## Action

Added the following capabilities to the claude headless lane in `DEFAULT_AGENT_REGISTRY`
(tools/strategy_farm/agent_router.py) and the live SQLite `agent_registry` table:

| Capability | Reason |
|---|---|
| `repo_edit` | Former codex coding tasks now route to claude Sonnet lane |
| `ops` | ops_issue task type requires `ops`; OWNER directive covers ops work |
| `tests` | Test writing is part of the coding scope |
| `repo` | ops_issue tasks created 2026-07-03 use `["code","repo","ops"]` as required caps |

## Before / After

**Before**: `["code", "research", "review", "strategy", "summary"]`  
**After**: `["code", "tests", "repo_edit", "repo", "ops", "research", "review", "strategy", "summary"]`

## Root Cause of Deadlock (3 cycles 2026-07-03)

Tasks `1a52d28d`, `d015e982`, `e1fb9395` required `["code", "repo", "ops"]`.
The router uses strict set membership (`required.issubset(capabilities)`).
Claude lacked `ops` and `repo`, so all three tasks bounced with `no_available_agent`
despite being explicitly assigned to claude.

The DB had already been updated by commit `ccca6cf13` (agents/board-advisor) adding
`repo_edit`, `tests`, `ops` — but not `repo`. Added `repo` in this cycle.

## Model Upgrade (from ccca6cf13)

Headless lane upgraded to `claude-sonnet-5` per OWNER directive 2026-07-03.

## Verification

```
python tools/strategy_farm/agent_router.py status
# shows claude capabilities: [..., "repo_edit", "repo", "ops", ...]

python tools/strategy_farm/agent_router.py route-many --max-routes 5
# no longer returns no_available_agent for ops_issue tasks assigned to claude
```
