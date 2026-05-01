# DL-056 — Chief of Staff (OS-Controller scope) hire

**Date:** 2026-05-01
**Authority:** OWNER directive 2026-05-01 (verbal, via Board Advisor) + DL-017 (CEO/Board hire authority) + DL-052 (CoS naming clarification).
**Originating evidence:**
- Codex token quota exhaustion 2026-05-01 (recovery Tuesday 07:30 W. Europe) — caught zero days early because nobody was watching.
- DL-048 retired the unauthorized 2026-05-01 00:42 CoS hire (`bf24c2ae-...`) which had four-thing scope (org-chart + bottleneck reviews + hire recommendations + OS-Controller).
- QUA-684 D5 directive (token-burn watch ownership decision pending since QUA-639 D3).
- CEO chose **option (b)** under QUA-684 D5 at 2026-05-01 ~12:30Z (DL-055): unblock QUA-527 + name DevOps as token-burn watch owner. CEO's decision predates the Codex outage. DevOps is Codex-bound and offline until Tuesday 07:30 — option (b) alone leaves token-burn watch unowned for the next ~3.5 days.
- This decision is **option (a)** layered on top, per OWNER's explicit directive 2026-05-01: hire a Chief of Staff (Claude-side, runs during Codex outage), broader scope (agents + tokens + models, not only token snapshot infra). DL-055 and DL-056 are complementary, not conflicting: QUA-527 remains DevOps's infra deliverable; CoS oversees the data product that comes out of it (and continues working while DevOps is offline).

## Decision

Hire **Chief of Staff (OS-Controller scope)** as a new live agent. UUID: `38f933cd-557b-41ff-8498-30db273273ef` (created 2026-05-01 12:41 UTC).

| Field | Value |
|---|---|
| Name | `Chief-of-Staff` |
| Role enum | `general` (Paperclip API enum has no `cos` slot) |
| Title | Chief of Staff (OS-Controller scope) — agents, tokens, models watch |
| Adapter | `claude_local` |
| Model | `claude-sonnet-4-6` |
| Reports to | CEO (`7795b4b0-...`) |
| Heartbeat | 1 h with wake-on-demand |
| canCreateAgents | `false` |
| BASIS prompt | `paperclip-prompts/chief-of-staff.md` |
| Runtime prompt | `paperclip/data/instances/default/companies/03d4dcc8-.../agents/38f933cd-.../instructions/AGENTS.md` |

## Scope (binding, narrow)

Three responsibilities only:

1. **Agent roster hygiene** — placeholder/orphan/duplicate/stale-running detection. Recommend cleanups; CEO acts.
2. **Token-burn watch** — per-agent spend, daily run-rate, exhaustion forecast. Hard rule: forecast within 4 days = escalate this heartbeat.
3. **Model-selection oversight** — weekly audit of per-agent model fit; recommend changes to CEO.

## Hard constraints (binding)

- Distinct from the Wave-6 / Phase Final founder-comms CoS that remains DEFERRED per `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md` and DL-052. This role does NOT touch Gmail / browser / `info@quantmechanica.com`.
- NO trading authority. NO code authority. NO MQL5 edits. NO T6 anything.
- NO direct API agent-create or agent-retire. Recommend only.
- NO org-chart edits.
- NO issue creation unless DL-051 gate passes.
- NO heartbeat without semantic delta (DL-046).

## Why narrow

The unauthorized 2026-05-01 00:42 CoS retired by DL-048 had four-thing scope and produced zero work output before retirement. The risk vector was scope creep into CEO/Strategy-Analyst territory. This re-hire stays bounded to the three things actually load-bearing right now (and revealed by the Codex outage). Org-chart maintenance, weekly bottleneck review, hire recommendations remain CEO/Strategy-Analyst.

## Why Sonnet not Opus

This is a watch role: structured reporting, deterministic forecasting, anomaly detection. Sonnet is sufficient and cost-appropriate. Opus would be over-provisioned for token-monitoring work, which is itself the failure mode this role exists to detect.

## Cross-references

- DL-017 — CEO/Board hire authority basis
- DL-046 — Anti-theater principle (binding on this role)
- DL-051 — Housekeeping freeze (issue-creation gate this role must respect)
- DL-052 — CoS naming clarification
- DL-053 — CEO operating contract (this role's blocker-comments must conform)
- DL-054 — Anti-theater pass criteria (read but do not enforce)
- DL-048 — Retirement of the unauthorized predecessor
- DL-055 — CEO's option (b) on the same QUA-684 D5 decision; this DL-056 layers option (a) for full coverage during the Codex outage
- QUA-684 D5 — Originating directive for token-burn watch ownership decision
- QUA-665 D3 — DL-051 housekeeping-freeze companion
- `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md` — the deferred Wave-6 CoS plan (separate)

## Operational follow-ups

- CEO sets up worktree at `C:\QM\worktrees\chief-of-staff` per DL-028 isolation (branch `agents/chief-of-staff`).
- CEO opens a single rolling tracking issue assigned to this CoS for daily token + roster reports.
- First heartbeat after this commit lands should produce: roster audit (catching the 4 known stale dirs `bf24c2ae` / `d53f62f7` / duplicate DevOps `0e8f04e5` / `12c5c03f` / `9f2e41f3`), per-agent spend snapshot, forecast.

— Authored by Board Advisor at OWNER explicit directive, 2026-05-01.
