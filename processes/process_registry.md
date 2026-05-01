# Process Registry

## Recently added

- 2026-05-01 — [`processes/19-gmail-link-intake.md`](19-gmail-link-intake.md) (Documentation-KM authoring; OWNER owns Phase 1 manual bridge; CEO owns triage of every brief; deferred Phase-2 Gmail Intake agent owner per [DL-043](../decisions/REGISTRY.md) Phase C if/when volume promotion criteria fire) — codifies link triage from `info@quantmechanica.com`: three access methods compared (human Chrome session + Claude extension recommended for Phase 1; read-only Gmail OAuth `gmail.readonly` + `gmail.labels` with `QM/Paperclip-Inbox` label-polling for deferred Phase 2; full Gmail API with send/modify forbidden at every phase), security boundary (no agent credential in Phase 1, label-gated opt-in in Phase 2, no attachment ingestion, no execution from a link, brief is the only payload that crosses to Git/Notion), redaction policy (sender → role label, names → role label, free-form body dropped, URL canonicalized after stripping tracking params + resolving redirect wrappers, attachments dropped, Gmail message-id off-Git), and dedupe rules (URL-key + thread-key, +1-sender suppression). Headline recommendation: **no agent today; manual bridge only; promote to lightweight on-demand agent only when ≥5 briefs/week for 2 consecutive weeks AND ≥50% conversion to downstream issues AND OWNER reports manual bridge as friction**. Companion canonical CEO link-brief template at [`docs/ops/CEO_LINK_BRIEF_TEMPLATE.md`](../docs/ops/CEO_LINK_BRIEF_TEMPLATE.md). Authored under [QUA-567](/QUA/issues/QUA-567); design rests on [DL-043](../decisions/REGISTRY.md) Phase C deferral. Distinct from Wave-6 Chief-of-Staff founder-comms scope frozen in [`docs/ops/PHASE_FINAL_FOUNDER_COMMS.md`](../docs/ops/PHASE_FINAL_FOUNDER_COMMS.md) — that role earns reply / draft authority; Gmail Intake never does.
- 2026-04-30 — [`processes/18-company-operating-system.md`](18-company-operating-system.md) (CEO + Chief of Staff + Documentation-KM) — codifies the Paperclip company reboot: small-team hiring gates, one-primary-skill-per-agent rule, model-tier/token control, lessons-to-process loop, and public-safe operating-model dashboard data. Companion plan: [`docs/ops/PAPERCLIP_COMPANY_REBOOT_PLAN_2026-04-30.md`](../docs/ops/PAPERCLIP_COMPANY_REBOOT_PLAN_2026-04-30.md). Issue packet: [`docs/ops/PAPERCLIP_COMPANY_REBOOT_ISSUES_2026-04-30.md`](../docs/ops/PAPERCLIP_COMPANY_REBOOT_ISSUES_2026-04-30.md).
- 2026-04-29 — [`processes/17-agent-runtime-health.md`](17-agent-runtime-health.md) (CEO detection + first-line; Documentation-KM post-incident codification) — covers hot-poll loops, stuck Codex/Claude sessions, bottleneck agents (≥2 P0 + low run rate), token-budget pressure, recursive self-wake. Authored by Board Advisor 2026-04-29 after Development recursive-wake incident; companion lesson `lessons-learned/2026-04-29_development_recursive_wake.md`. New escalation Class 6 added to [`12-board-escalation.md`](12-board-escalation.md). New "Paperclip platform semantics" knowledge-base section added below.
- 2026-04-28 — [`processes/16-backtest-execution-discipline.md`](16-backtest-execution-discipline.md) (Documentation-KM authoring; Pipeline-Operator owns Rules 1-4, 7; DevOps owns Rule 5 + co-owns Rule 7; Research owns Rule 6; CTO owns Rule 5 review-pass) — codifies the seven OWNER 2026-04-28 binding backtest rules (`.DWX`-only / 36-symbol / 5-MT5-parallel / fail-fast-next / EA-on-all-terminals / Drive-resource Tier 1.5 / fixed-risk set file). Binding source: [QUA-400](/QUA/issues/QUA-400) → [DL-038](../decisions/2026-04-28_seven_backtest_rules.md). Authored under [QUA-418](/QUA/issues/QUA-418).

## CEO Authority Boundaries

Per [DL-017](../decisions/REGISTRY.md) (hires) + [DL-023](../decisions/2026-04-27_ceo_autonomy_waiver_v2.md) (technical / operational / process v2) + [DL-032](../decisions/2026-04-27_ceo_autonomy_waiver_v3.md) (research source-queue ordering v3): CEO acts unilaterally on the classes listed below. OWNER's stated preference is bias to action, fewer interrupts. When ambiguous, CEO **acts**, then retroactively raises via successor DL-NNN if the call needs ratification.

### CEO-autonomous (no OWNER surfacing required)

1. **Hires** — DL-017. `requireBoardApprovalForNewAgents=false`.
2. **Technical implementation choices within the framework spec** — adapter choices, library structure, internal scripts, test harness shape, gitignore / artifact retention policy, Notion ↔ Git mirror layout, scheduler choice (Paperclip routine vs Windows Task), Linux / PowerShell tooling decisions.
3. **Operational decisions for non-T6 deploys** — file paths, scheduler windows, log rotation policy, retention windows, agent confirmation cadence, worktree layout, lock-file monitoring, bookkeeping cleanups (orphan-run cancellations, stuck-process terminations).
4. **Internal process choices** — heartbeat cadence, issue-tree shape, sub-issue spawning patterns, agent-vs-agent escalation rules, parallel-run rules.
5. **Research source-queue ordering** — which source Research extracts next within an already-ratified queue (Davey vs Chan first, JBM batch 3 vs 4, etc.). DL-032.
6. **Source-survey ratification** — accepting / rejecting / re-scoping a source-survey deliverable produced under DL-029. DL-032.
7. **SRC0N parent creation** — opening the next `SRC0N` parent issue when the current closes, including its child cohort skeleton. DL-032.
8. **Per-batch T3 source approval** — approving the per-batch T3 source bundle that hands off to Pipeline-Operator under DL-029's binding-sequential workflow. DL-032.

### Still requires OWNER surfacing (escalation list, v3-reframed)

1. **T6 anything** — OFF LIMITS without explicit OWNER approval (no code, no read, no inference). V5 hard rule.
2. **Live deploy** — first T6 deploy manifest, AutoTrading toggle, live-account credential touches, live capital exposure changes.
3. **True strategic direction** — kill V5 entirely, pivot to a different broker, change the goal-tier strategic outcome. (Source-queue ordering is *not* strategic direction; that's CEO's lane per DL-032.)
4. **Compliance / legal** — news-compliance variants (FTMO / 5ers / DXZ blackouts), broker-of-record changes, account-class transitions.
5. **Brand application** to public-facing artifacts that OWNER personally approves (logo, mascot, episode pack).
6. **Budget step-changes** — anything materially raising monthly token / compute spend beyond the existing operating envelope.
7. **V5 hard-rule boundary changes** — ML ban, Model 4, .DWX suffix, Friday Close default, magic-formula registry.

### Pre-flight rule for `paperclip-prompts/*.md` patches (DL-032)

When a prompt patch under `paperclip-prompts/*.md` aligns with an **existing** DL-NNN, the workflow is **either** pre-flight a `request_confirmation` to OWNER on the patch, **or** treat the commit as DL-aligned routine work that CEO can ship under broadened authority, citing the DL-NNN in the commit body. **Never commit-then-ask-after.** Once committed, hot-reload propagates the change to every wake of the affected agent and a retroactive confirmation is no longer a confirmation but a notification.

This rule applies only when a DL-NNN already exists. Brand-new prompt changes not yet covered by a DL stay in their existing surfacing path. OWNER manages the BASIS source-of-truth in either case.

## Issue Routing

Per [DL-031](../decisions/DL-031_projects_formalization_and_routing_convention.md): every new issue is created with `projectId` set. Authoritative goal-project hierarchy:

| Project | id | Status | Scope |
|---|---|---|---|
| **V5 Framework Implementation** | `71b6d994-70ba-4a28-bd62-732b42a9ea58` | in_progress | MQL5 framework + pipeline runners + build/test harness; repo-only (`C:\QM\repo`) |
| **V5 Pipeline Operations** | `ac8daa03-00ae-49fd-bd4a-f1283a075f83` | in_progress | T1-T5 factory: backtest runs, evidence, NO_REPORT, calibration, mirror integrity |
| **V5 Strategy Research** | `b2adcc7f-064f-47c7-8563-d1c917639231` | in_progress | Source extraction + Strategy Card authoring per DL-029 |
| **T6 Live Operations** | `2603d13a-8152-4514-987c-d9abee1c948f` | backlog | DXZ live deploy of approved EAs; OWNER-gated (manifest + AutoTrading-OFF) |

Goal: `4662e91e-8e9b-458e-9383-b1f67751965b` ("Build-in-public quant research factory"). All 4 projects roll up to it.

Heuristic — pick the project whose path the issue's deliverable touches:

- `framework/`, `infra/`, `paperclip-prompts/`, `decisions/`, `processes/`, `docs/`, `lessons-learned/`, `governance/`, agent prompt/instruction edits, learning-candidates → **V5 Framework Implementation**
- `D:\QM\mt5\T1`-T5, `D:\QM\reports\pipeline\`, `D:\QM\reports\ops\`, calibration JSON, runner outputs, NO_REPORT, .DWX symbol verification, silent-run / stale-lock recovery → **V5 Pipeline Operations**
- `strategy-seeds/`, source extraction, Strategy Card authoring → **V5 Strategy Research**
- `C:\QM\mt5\T6_Live`, deploy manifests, AutoTrading-OFF discipline → **T6 Live Operations** (OWNER-gated)

Cross-functional issues split: parent in primary project, children scoped to their owners' projects. If genuinely ambiguous, route to **V5 Framework Implementation** as meta-default and let the assignee re-route on triage. Authority: CEO unilateral on routing per DL-023.

## Execution Policies

Per [DL-030](../decisions/2026-04-27_execution_policies_v1.md): every issue created in scope of a stakes-bearing flow MUST carry an `executionPolicy` block at creation time (or via PATCH before `in_progress`). The runtime — not the agent — enforces the `in_progress → done` interception. The full JSON snippets (with concrete reviewer/approver participant identifiers) live in DL-030; this registry section is the role-level convention.

| Class | Flow | Scope test | Policy | Reviewer / Approver (role) | Wave 2 hire trigger |
|---|---|---|---|---|---|
| 1 | T6 deploy | `projectId` = T6 Live Operations, **or** title matches `^T6 deploy` (case-insensitive) | **Approval-only** | OWNER | n/a |
| 2 | Strategy Card extraction | `projectId` = V5 Strategy Research **and** issue is a Strategy Card (child of a Source-research parent per DL-029; source-extraction parents and the workflow-charter parent are exempt) | **Review-only** | Quality-Business when hired; interim: CEO with OWNER fallback (per DL-016) | swap participants to Quality-Business on Wave 2 hire |
| 3 | EA `_v2+` enhancement | `projectId` = V5 Framework Implementation **and** title matches `_v[0-9]+\b` | **Review-only** | Quality-Tech when hired; interim: CTO | swap participants to Quality-Tech on Wave 2 hire |
| 4 | All other issues | n/a (default) | Comment-required only (Paperclip default) | n/a | n/a |

`commentRequired: true` is independent of stages and remains on for every issue regardless of class.

**Class 1 layered relationship to DL-025.** Approval-only is layered on top of — not a substitute for — the V5 hard rule that **AutoTrading is OWNER-manual**. The runtime gate intercepts the `done` transition; the live-account toggle stays out of agent hands entirely.

**Sentinel role.** CEO scans for unpolicied issues in scope and PATCHes a policy in. Manual sweep until an automation routine is added.

**Self-review prevention.** The runtime excludes the original executor from the eligible reviewer/approver set. Class 2 lists OWNER as a fallback participant so CEO-authored strategy cards can still close while CEO holds the interim Quality-Business seat.

For the full JSON shape per class (including reviewer/approver participant identifiers), see [DL-030 § Implementation mechanism](../decisions/2026-04-27_execution_policies_v1.md).

## Factory Setup Standards

- MT5 factory terminals `T1`-`T5` must include an install-root `portable.txt` marker file (empty file) to prevent AppData split-brain when launched without explicit `/portable`.
- Canonical factory compile path: `D:\QM\mt5\T1\MetaEditor64.exe` (fallback: `D:\QM\mt5\T2\MetaEditor64.exe`). Consumers should use `framework/scripts/metaeditor_path.txt` or `infra/scripts/Resolve-MetaEditorPath.ps1` and avoid PATH-based discovery.

## Skills

V5 adopts Paperclip's Skills system per OWNER directive 2026-04-27 (see `decisions/2026-04-27_skills_adoption_v1.md`). Skills are reusable, token-efficient instruction bundles loaded on demand by agents. They do **not** override agent prompts in `paperclip-prompts/*.md` — they augment them. Hard rules stay in `CLAUDE.md` + agent prompts; skills are how-tos.

### Custom V5 Skills (authored by Doc-KM)

| Skill | Folder | Owner | Reviewer | Required for |
|---|---|---|---|---|
| `qm-validate-custom-symbol` | `skills/qm/qm-validate-custom-symbol/` | DevOps + Pipeline-Operator | Quality-Tech | Required: DevOps, Pipeline-Operator |
| `qm-strategy-card-extraction` | `skills/qm/qm-strategy-card-extraction/` | Research | CEO + Quality-Business | Required: Research |
| `qm-build-ea-from-card` | `skills/qm/qm-build-ea-from-card/` | Development (Codex) | CTO | Required: Development; Optional: CTO |
| `qm-run-pipeline-phase` | `skills/qm/qm-run-pipeline-phase/` | Pipeline-Operator | Quality-Tech | Required: Pipeline-Operator |
| `qm-t6-deploy-verification` | `skills/qm/qm-t6-deploy-verification/` | LiveOps (DevOps interim) | OWNER | Required: LiveOps; Optional: DevOps |
| `qm-zero-trades-recovery` | `skills/qm/qm-zero-trades-recovery/` | Strategy-Analyst + R-and-D + CEO + CTO | Quality-Tech | Required: Strategy-Analyst, R-and-D, CEO, CTO |

### Marketplace Skills (pinned external)

Pinned per `skills/marketplace/INDEX.md`. Each entry has source provenance + commit hash + assignment.

**Required (CTO to fill `commit_pin` on review):**

| Skill | Source | Assigned to |
|---|---|---|
| `anthropics/skills/skill-creator` | anthropics/skills | Documentation-KM, CTO |
| `anthropics/skills/pdf` | anthropics/skills | Research |
| `anthropics/skills/xlsx` | anthropics/skills | Pipeline-Operator, CTO |
| `obra/superpowers/verification-before-completion` | obra/superpowers | CEO, CTO, DevOps |
| `obra/superpowers/using-git-worktrees` | obra/superpowers | CTO, DevOps |
| `obra/superpowers/test-driven-development` | obra/superpowers | CTO, Development |
| `obra/superpowers/systematic-debugging` | obra/superpowers | DevOps |

**Optional (assign on demand):** see `skills/marketplace/INDEX.md` § Optional.

### Governance

- **Doc-KM** authors and maintains the inventory.
- **CTO** reviews each skill body for technical correctness before pin.
- **CEO** ratifies the assignment matrix.
- **OWNER** has veto on any external pin via request_confirmation.

### Pin lifecycle

A marketplace skill is **registered in Paperclip** only after:
1. CTO has filled `commit_pin: <SHA>` + `reviewed_at` + `reviewed_by: CTO`
2. CEO has ratified the assignment in the `INDEX.md` matrix
3. (For sensitive sources) OWNER has accepted a `request_confirmation` interaction

Until then, the entry sits in `INDEX.md` with `commit_pin: TBD` and is not visible to agents.

## Paperclip platform semantics

Knowledge-base entries for non-obvious Paperclip orchestrator behavior, captured from incidents. Update when a new platform quirk is observed.

### Heartbeat / cooldown / wake

| Field | What it does | What it does NOT do |
|---|---|---|
| `runtime_config.heartbeat.enabled` | Gates the **timer** heartbeat. `false` = no scheduled wake. | Does NOT prevent `wakeOnDemand` events from firing the agent. |
| `runtime_config.heartbeat.intervalSec` | Period of the timer heartbeat (when `enabled=true`). | Does NOT throttle event-driven wakes. |
| `runtime_config.heartbeat.cooldownSec` | Minimum gap between **timer** heartbeat fires. | Does NOT coalesce `wakeOnDemand` events. **Repeated wake-on-demand events fire the agent regardless of cooldown.** Verified 2026-04-29 against Development hot-poll incident. |
| `runtime_config.heartbeat.wakeOnDemand` | When `true`, agent wakes on issue-assignment, comment-event, or explicit `/wakeup` API call. | None of the cooldown / interval fields throttle these events. The only way to fully block event-driven wake is `wakeOnDemand: false` OR full agent `/pause`. |
| `runtime_config.heartbeat.maxConcurrentRuns` | Caps the number of simultaneous in-flight runs for the agent. | Does NOT prevent serial repeated runs from the same wake-event source. |

**Implication for hot-poll mitigation** (per `lessons-learned/2026-04-29_development_recursive_wake.md`):

- If an agent is recursively self-waking via its own comment posts, **lowering `cooldownSec` will not help**.
- Effective controls: `wakeOnDemand: false` (kills all event wake), `/pause` (full stop), or fix the recursive-wake source (comment-dedup + self-author filter).

### Agent lifecycle

| Action | API | Effect | Reversibility |
|---|---|---|---|
| `/pause` | `POST /api/agents/<id>/pause` | Cancels active runs, blocks new wakes (timer + on-demand). | `/resume` restores to prior runtime config. |
| `/resume` | `POST /api/agents/<id>/resume` | Lifts the pause. Agent resumes normal heartbeat behavior. | — |
| `/wakeup` | `POST /api/agents/<id>/wakeup` body `{source: 'on_demand'|'timer'|'assignment'|'automation', reason: '...'}` | Forces an immediate run if not paused and no active run for that agent. | One-shot. |
| Terminate | `PATCH /api/agents/<id>` with `status='terminated'` (or via `paperclip-terminate-agent` skill) | Marks agent retired. Heartbeats stop. History preserved (foreign-key constraints prevent hard-delete). | Re-hire creates a new agent with a new ID. |

### Confirmation interactions

- `kind='request_confirmation'` requires **board-only** auth to accept/reject (`assertBoard(req)` in routes). CEO cannot accept on OWNER's behalf via API. Board Advisor (`local-board` user) can.
- `kind='suggest_tasks'` accept can specify `selectedClientKeys: [...]` to pick which sub-tasks to spawn. Reject takes optional `reason: '...'`.
- Resolved interactions are immutable. To change a decision after acceptance, open a new interaction or DL-NNN.

### Issue ↔ Project routing

- Every new issue created from this point forward should carry `projectId` per [DL-031](../decisions/DL-031_projects_formalization_and_routing_convention.md).
- Project IDs in the registry: V5 Framework Implementation `71b6d994`, V5 Pipeline Operations `ac8daa03`, V5 Strategy Research `b2adcc7f`, T6 Live Operations `2603d13a`, Portfolio Factory V5 (umbrella) `26cdd201`.

### PC1-00 worktree-isolation pattern

Per `lessons-learned/2026-04-27_pc1-00_live_incident_qua-167.md`: any agent touching `framework/`, `infra/`, `processes/`, or other concurrent-write paths uses a per-agent worktree under `C:\QM\worktrees\<agent>\`. Board Advisor commits docs directly to `main` when no agent contention is expected (single-author edits).
