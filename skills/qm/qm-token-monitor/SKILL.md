---
name: qm-token-monitor
description: >
  Use when running a token-spend heartbeat for QuantMechanica V5 — reading agent
  spentMonthlyCents, computing daily run-rate, forecasting budget exhaustion, and
  posting ALERT or rollup comments on the routine-assigned task. Don't use for
  model selection, adapter changes, agent lifecycle decisions, or any work outside
  the token-surveillance role.
owner: Token-Controller
reviewer: Chief-of-Staff
last-updated: 2026-05-08
basis: >
  C:/QM/paperclip/data/instances/default/companies/03d4dcc8-4cea-4133-9f68-90c0d99628fb/agents/bd089fcb-ee8f-46d8-bc89-f8614e8e7a1e/instructions/AGENTS.md
  + C:/QM/repo/framework/registry/token_budget.json
---

# qm-token-monitor

Token-spend surveillance heartbeat procedure for the QuantMechanica V5 Paperclip company. Exists to prevent the org-cap failure mode observed on 2026-05-08, when all agents flipped `status=error` simultaneously due to an unforecast Anthropic org-level monthly cap exhaustion.

## When to use

- Every heartbeat (60-minute timer) as Token-Controller
- On any explicit CoS or CEO request for a spend audit

## When NOT to use

- Model selection or adapter changes → escalate to CoS
- Agent pause, resume, hire, or retire → escalate to CoS or OWNER
- Any action that would require PATCH or POST on another agent
- Code, strategy, or trading decisions

---

## Heartbeat Procedure

### Step 1 — Fetch agent roster + spend

```sh
GET http://127.0.0.1:3100/api/companies/03d4dcc8-4cea-4133-9f68-90c0d99628fb/agents
Authorization: Bearer $PAPERCLIP_API_KEY
```

Capture per agent:
- `id`, `name`, `role`
- `spentMonthlyCents` (current MTD spend in US cents)
- `lastHeartbeatAt` (ISO timestamp of last activity)
- `status` (`running` / `paused` / `error`)
- `adapterType` (`claude_local` vs `codex_local`)

### Step 2 — Load previous snapshot

Read `C:/QM/worktrees/token-controller/state/spend_baseline.json`.

If the file is absent (first run / cold start): proceed to Step 3 using proxy estimation (see Cold-Start).

Schema:
```json
{
  "recorded_at": "<ISO>",
  "agents": {
    "<agent-id>": {
      "spentMonthlyCents": 0,
      "lastHeartbeatAt": "<ISO>"
    }
  }
}
```

### Step 3 — Load budget limits

Read `C:/QM/repo/framework/registry/token_budget.json`.

Key fields:
- `adapters.claude_local.per_agent_monthly_budget_cents` — per-agent cap for Claude agents (default 5000 ¢)
- `adapters.codex_local.per_agent_monthly_budget_cents` — per-agent cap for Codex agents (default 3000 ¢)
- `company.monthly_budget_cents` — org-wide hard cap (default 30000 ¢)
- `escalation_window_days` — alert threshold (default 4 days)
- `per_agent_overrides` — individual agent overrides (CEO=8000 ¢, Research=6000 ¢)

If the file is absent: draft replacement values using the defaults above, then create a child issue assigned to CoS (`38f933cd-557b-41ff-8498-30db273273ef`) with the draft as the issue body. Continue the heartbeat using the defaults.

### Step 4 — Compute per-agent run-rate

For each agent where a previous snapshot exists:

```
hours_elapsed = (now - snapshot.recorded_at) in hours
delta_cents   = current.spentMonthlyCents - snapshot.spentMonthlyCents
daily_rate_cents = (delta_cents / hours_elapsed) * 24
```

Clamp `daily_rate_cents` to 0 if delta is negative (billing reset or anomaly — log as anomaly; do not alert on negative delta).

**Cold-start proxy** (no prior snapshot):
```
calendar_days_elapsed = day_of_month (minimum 1)
proxy_rate_cents      = spentMonthlyCents / calendar_days_elapsed
```
Flag output as `proxy-estimated` — this understates recent spikes; treat as conservative lower bound.

### Step 5 — Compute days-to-exhaustion

For each agent:
```
budget_cents     = per_agent_overrides[id] ?? adapter_default_budget
remaining_cents  = budget_cents - current.spentMonthlyCents
days_to_exhaust  = remaining_cents / daily_rate_cents
```

If `daily_rate_cents == 0`: `days_to_exhaust = Infinity` (mark `OK`).

Org-wide totals:
```
total_spend_cents  = sum(spentMonthlyCents) for claude_local agents only
total_daily_rate   = sum(daily_rate_cents) for claude_local agents
org_days_to_exhaust = (company.monthly_budget_cents - total_spend_cents) / total_daily_rate
```

**Codex blind spot:** `codex_local` agents (CTO, Development, Pipeline-Operator, DevOps) do not surface spend via `spentMonthlyCents` in the Paperclip API. Caveat all org totals as "claude-only" until Codex spend tracking is wired.

### Step 6 — Save updated snapshot

Write current state to `C:/QM/worktrees/token-controller/state/spend_baseline.json` using the schema from Step 2. Set `recorded_at` to current UTC ISO timestamp. **Always write this file before posting any comment.**

### Step 7 — Threshold evaluation

Derive status per agent:

| Condition | Status |
|---|---|
| `days_to_exhaust > 7` | `OK` |
| `7 ≥ days_to_exhaust > 4` | `WARN` |
| `days_to_exhaust ≤ 4` | `ALERT` |
| `status = paused` | `PAUSED` |
| No budget configured | `N/A` |

**ALERT action** (any agent or org-wide `days_to_exhaust ≤ escalation_window_days`):
1. Post an ALERT comment on your current routine task (see Output Bar).
2. Create a child issue assigned to CoS (`38f933cd-557b-41ff-8498-30db273273ef`):
   - Title: `ALERT: [AgentName] token exhaustion in [N] days`
   - Body: agent ID, current spend (¢), daily rate (¢/d), budget limit (¢), forecast exhaustion date (ISO)

Org-level ALERT supersedes all per-agent warnings in priority.

**Silence discipline:** if no agent is ALERT or WARN, and this is not the daily-rollup time (08:00 W. Europe local), exit without posting any comment.

### Step 8 — Daily rollup (08:00 W. Europe local only)

Post a rollup table comment on the current routine task:

```
| Agent | Model | Spend MTD (¢) | Daily Rate (¢/d) | Days to Exhaust | Status |
|-------|-------|--------------|-----------------|-----------------|--------|
| CEO   | Opus  | 120          | 12.0            | 240             | OK     |
...
| TOTAL (claude-only) | — | 480 | 48.0 | 250 | OK |
```

Include: caveat line `Note: codex_local agent spend not captured (CTO, Development, Pipeline-Operator, DevOps).`

---

## Output Bar

### ALERT comment format

```
**ALERT — Token exhaustion forecast**

Agent: [Name] (`[UUID]`)
Adapter: [claude_local | codex_local]
MTD spend: [X] ¢ / [budget] ¢ ([pct]%)
Daily run-rate: [Y] ¢/d
Forecast exhaustion: [ISO date] ([N] days)

Action taken: child issue [QUA-NNN] created + assigned to CoS.
```

### Final heartbeat summary line (always include at end of any comment posted)

```
Heartbeat [UTC ISO]: [N] agents checked, [X] ALERT, [Y] WARN, [Z] OK. State file updated.
```

**Not acceptable:**
- Rollup with no data table
- ALERT that does not name agent, rate, and days
- Missing state file update
- "All clear" comment outside the scheduled daily rollup

---

## Escalation Chain

| Condition | Action |
|---|---|
| Any agent ALERT (≤4 d) | Post ALERT comment + create child issue → CoS |
| `token_budget.json` absent | Draft replacement + create child issue → CoS |
| Org-cap approaching | Org-level ALERT child issue → CoS (supersedes per-agent) |
| Model selection concern | Comment in routine task → escalate to CoS |

Never post on other agents' issue threads. Never PATCH or POST on agents.

---

## References

- `C:/QM/repo/framework/registry/token_budget.json` — budget limits and thresholds
- `C:/QM/worktrees/token-controller/state/spend_baseline.json` — rolling spend snapshot
- `C:/QM/paperclip/data/instances/default/companies/03d4dcc8-4cea-4133-9f68-90c0d99628fb/agents/bd089fcb-ee8f-46d8-bc89-f8614e8e7a1e/instructions/AGENTS.md` — authoritative agent spec
- DL-056 — CoS hire (defines escalation_window_days and alert routing)
- 2026-05-08 org-cap event — the failure mode this skill exists to prevent
