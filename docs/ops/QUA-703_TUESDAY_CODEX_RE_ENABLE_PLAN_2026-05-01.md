# QUA-703 — Tuesday Codex re-enable plan (2026-05-05 ~05:30 UTC / 07:30 W. Europe)

**Filed:** 2026-05-01 by CEO `7795b4b0`.
**Authority:** Board Advisor recommendation on QUA-684 (comment 92a65482, 2026-05-01T14:25Z) + DL-056 § Scope #3 (model-selection oversight).
**Tracking issue:** [QUA-703](/QUA/issues/QUA-703).

## Pre-validation done 2026-05-01 (CEO this heartbeat)

- `codex --version` → `codex-cli 0.125.0` ✓
- `codex exec --model gpt-5-codex "echo ok"` → CLI initialized cleanly with `model=gpt-5-codex` ✓
- `codex exec --model gpt-5-codex-mini "echo ok"` → CLI initialized cleanly with `model=gpt-5-codex-mini` ✓

Both downgrade SKUs are valid in the local Codex CLI catalog (v0.125.0). No fallback needed at validation time. **Re-validate Tuesday morning** — Codex API + quota state may have changed; CLI accepting model string ≠ API accepting it under quota constraints.

## Per-agent plan (execute Tuesday, in sequence)

| # | Agent | UUID | Action(s) | Verify after |
|---|---|---|---|---|
| 1 | CTO | `241ccf3c-ab68-40d6-b8eb-e03917795878` | KEEP `gpt-5.3-codex`; PATCH `runtimeConfig.heartbeat.enabled=true` | First successful heartbeat run + framework gate decision quality unchanged |
| 2 | Development | `ebefc3a6-4a11-43a7-bd5d-c0baf50eb1f9` | KEEP `gpt-5.3-codex`; PATCH heartbeat enabled; ALSO unpause (currently `pausedAt: 2026-04-29T10:08:30Z`) — OWNER-class via Class-2 escalation | First successful EA build / compile |
| 3 | Pipeline-Operator | `46fc11e5-7fc2-43f4-9a34-bde29e5dee3b` | TRY `gpt-5-codex-mini`; PATCH heartbeat enabled; ALSO unpause (currently `pausedAt: 2026-04-29T20:21:39Z`) — OWNER-class via Class-2 escalation | First successful tester launch + JSON parse |
| 4 | DevOps | `86015301-1a40-4216-9ded-398f09f02d26` | TRY `gpt-5-codex`; **DO NOT** re-enable heartbeat (stays paused per QUA-702 root-cause prereq). Re-enable only after QUA-671 signal-file refresh logic patched | n/a until QUA-671 fix lands |

## Sequencing rationale

- **Agents 2 + 3 need unpause first** (paused 2026-04-29). Unpause is OWNER-class per `feedback_agent_pause_unpause_owner_only.md`. CEO files Class-2 escalation Tuesday morning if not already resolved by Board Advisor.
- **Agent 4 (DevOps)** stays paused even after Tuesday until the refresh-script root-cause fix lands. QUA-702 documents the resume condition (gate on semantic delta). Model PATCH can still be applied while paused — model only takes effect on next run.
- **Agent 1 (CTO)** is unpaused and just needs heartbeat re-enabled.

## Execution commands (templates)

### Model PATCH (agents 3 + 4 — downgrades)

```bash
curl -X PATCH http://localhost:3100/api/agents/<UUID> \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -d '{"adapterConfig":{"model":"<NEW_MODEL>"}}'
```

### Heartbeat enable (agents 1 + 2 + 3)

```bash
curl -X PATCH http://localhost:3100/api/agents/<UUID> \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -d '{"runtimeConfig":{"heartbeat":{"enabled":true,"cooldownSec":60,"intervalSec":1800,"wakeOnDemand":true,"maxConcurrentRuns":5}}}'
```

Partial PATCH preserves siblings per `feedback_paperclip_agent_config_patch_works.md`.

## Pre-Tuesday checklist (CEO heartbeat that picks this up)

1. **Re-validate** `codex exec --model gpt-5-codex "echo ok"` and `codex exec --model gpt-5-codex-mini "echo ok"` actually produce real output (not just init banner — pipe a tiny prompt and check for response).
2. **GET each agent** to confirm current state (`pausedAt`, `model`, `heartbeat.enabled`).
3. **For agents needing unpause**: file Class-2 escalation to OWNER (or check if already done).
4. **Apply PATCHes** in the per-agent table order.
5. **Verify** with subsequent GET (200 + field stuck).
6. **Post results comment** with each PATCH response excerpt + first heartbeat run id.
7. **Notify CoS** on QUA-699 — model-fit audit input updated.
8. **Close QUA-703** `done` with the verification evidence.

## Reversibility

If Pipeline-Op (`gpt-5-codex-mini`) or DevOps (`gpt-5-codex`) produces low-quality output post-Tuesday, single PATCH back to `gpt-5.3-codex`. No persistent state lost.

```bash
# Rollback PATCH
curl -X PATCH http://localhost:3100/api/agents/<UUID> \
  -d '{"adapterConfig":{"model":"gpt-5.3-codex"}}'
```

## Cross-references

- [QUA-684](/QUA/issues/QUA-684) comment 92a65482 (Board Advisor recommendation, 2026-05-01T14:25Z)
- [QUA-702](/QUA/issues/QUA-702) (DevOps pause `done`; root-cause prereq for DevOps heartbeat re-enable)
- [QUA-699](/QUA/issues/QUA-699) (CoS rolling tracker; model-fit audit input)
- DL-056 § Scope #3 (model-selection oversight)
- `feedback_paperclip_agent_config_patch_works.md` (PATCH pattern)
- `feedback_agent_pause_unpause_owner_only.md` (Class-2 escalation route for unpause)

[gate-test] DL-051 R-051-1 (4) real incident with evidence (Codex outage already fired; Tuesday is the recovery action).
