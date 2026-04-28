# Process Registry

## Active agents

Source-of-truth roster snapshot (live agent list authoritative: `paperclipai agent list`). V5 BASIS prompts are Git-canonical at [`paperclip-prompts/<role>.md`](../paperclip-prompts/) (OWNER-managed, do not edit). Wave/hire trigger detail: [`docs/ops/AGENT_SKILL_MATRIX.md`](../docs/ops/AGENT_SKILL_MATRIX.md) § Wave Hire Triggers and [`decisions/2026-04-27_v5_org_proposal.md`](../decisions/2026-04-27_v5_org_proposal.md).

**Active-agent count: 9** (Wave 0 + Wave 2). The V5 Org Proposal § 6 anti-sprawl 8-cap was explicitly waived **one-time** by OWNER on 2026-04-28 to seat Quality-Business as the 9th active agent (per [DL-039](../decisions/2026-04-28_quality_business_hire.md), [QUA-429](/QUA/issues/QUA-429)). The 8-cap remains in force for any further hires; the override does not extend to Wave 3+.

- **CEO**
  - Role: Strategic gating, issue routing, hires (DL-017), CEO ↔ CTO dialectic, OWNER escalation, governance ratification.
  - Adapter: claude_local (Claude Opus 4.7), heartbeat 30 min ([DL-034](../decisions/2026-04-28_ceo_heartbeat_30min.md)) + wake-on-demand on board/issue events.
  - Reports to: OWNER.
  - Source: [`paperclip-prompts/ceo.md`](../paperclip-prompts/ceo.md).
  - Agent ID: `7795b4b0-8ecd-46da-ab22-06def7c8fa2d`.

- **CTO**
  - Role: V5 framework spec authority, MQL5 code review, Hard Rules custodian, technical implementation choices within DL-023 broadened autonomy.
  - Adapter: codex_local (gpt-5.3-codex), heartbeat 1h review queue + wake-on-demand.
  - Reports to: CEO (organizationally), OWNER (strategically).
  - Source: [`paperclip-prompts/cto.md`](../paperclip-prompts/cto.md).
  - Agent ID: `241ccf3c-ab68-40d6-b8eb-e03917795878`.

- **Research**
  - Role: Source extraction, Strategy Card authoring per [DL-029](../decisions/DL-029_strategy_research_workflow.md) and [13-strategy-research.md](13-strategy-research.md), survey-pass synthesis.
  - Adapter: claude_local (Claude Opus 4.7), wake-on-demand (event-driven per BASIS).
  - Reports to: CEO.
  - Source: [`paperclip-prompts/research.md`](../paperclip-prompts/research.md).
  - Agent ID: `7aef7a17-d010-4f6e-a198-4a8dc5deb40d`.

- **Documentation-KM**
  - Role: Process registry + decisions registry + lessons-learned curation, Notion ↔ Git mirror, episode artifact packs, onboarding packs.
  - Adapter: claude_local (Claude Opus 4.7), heartbeat 2h Notion-sync fallback + wake-on-demand.
  - Reports to: CEO.
  - Source: [`paperclip-prompts/documentation-km.md`](../paperclip-prompts/documentation-km.md).
  - Agent ID: `8c85f83f-db7e-4414-8b85-aa558987a13e`.

- **DevOps**
  - Role: VPS infrastructure, Drive ↔ Git fence, MT5 portable-mode + factory deploy ([Rule 5](../decisions/2026-04-28_seven_backtest_rules.md)), monitoring scripts, set-file generator, disk policy enforcement.
  - Adapter: codex_local (gpt-5.3-codex), heartbeat hourly cron + wake-on-demand.
  - Reports to: CEO; Obs-SRE will absorb the monitoring slice on Wave 3.
  - Source: [`paperclip-prompts/devops.md`](../paperclip-prompts/devops.md).
  - Agent ID: `0e8f04e5-4019-45b0-951f-ca248cf82849`.

- **Pipeline-Operator**
  - Role: T1–T5 dispatch + de-dup ([15-pipeline-op-load-balancing.md](15-pipeline-op-load-balancing.md)), backtest-execution discipline ([16-backtest-execution-discipline.md](16-backtest-execution-discipline.md)), evidence capture, NO_REPORT recovery, EA Review gate enforcement at P1 → P2.
  - Adapter: codex_local (gpt-5.3-codex), heartbeat timer-driven + wake-on-demand.
  - Reports to: CEO.
  - Source: [`paperclip-prompts/pipeline-operator.md`](../paperclip-prompts/pipeline-operator.md).
  - Agent ID: `46fc11e5-7fc2-43f4-9a34-bde29e5dee3b`.

- **Quality-Tech** *(Wave 2 hire — landed 2026-04-28)*
  - Role: EA code audit (P2..P7); overfitting / DSR / MC / FDR / PBO checks; technical cross-challenge on CEO+CTO PASS decisions; sub-gate calibration first-pass once V5 EA distributions exist; EA Review-gate reviewer (DL-036 + DL-030 Class 3 named participant on Wave 2 swap).
  - Adapter: claude_local (Claude Opus 4.7), heartbeat event-driven + wake-on-demand.
  - Reports to: CTO.
  - Source: [`paperclip-prompts/quality-tech.md`](../paperclip-prompts/quality-tech.md).
  - Agent ID: `c1f90ba8-d637-46d9-8895-ead705bb4933`.

- **Development** *(Wave 2 hire — landed 2026-04-28)*
  - Role: V5 EA implementation in MQL5 from CEO-approved Strategy Cards; one-at-a-time discipline; CTO Review-only gate before Pipeline-Op smoke; commit-hash close-out per [DL-026](../decisions/DL-026_coding_agent_done_requires_commit_hash.md).
  - Adapter: codex_local (gpt-5.3-codex), heartbeat timer-driven + wake-on-demand.
  - Reports to: CTO.
  - Source: [`paperclip-prompts/development.md`](../paperclip-prompts/development.md).
  - Agent ID: `ebefc3a6-4a11-43a7-bd5d-c0baf50eb1f9`.

- **Quality-Business** *(Wave 2 hire — landed 2026-04-28; 9th-agent OWNER-override per [DL-039](../decisions/2026-04-28_quality_business_hire.md))*
  - Role: Strategy Card economic-thesis review (G0 second eye with CEO); portfolio-fit pre-screen; author-claim verification; PASS cross-challenge at P2; portfolio composition sanity (correlation, market/timeframe/style caps); DarwinexZero track-record stewardship; monthly business review to OWNER. Advisory verdicts only — does not dispatch work, edit code, or run backtests.
  - Adapter: claude_local (Claude Opus 4.7), heartbeat event-driven + 4h timer fallback (`intervalSec=14400`).
  - Reports to: CEO (organizationally), OWNER (strategically — monthly business review).
  - Source: [`paperclip-prompts/quality-business.md`](../paperclip-prompts/quality-business.md); hire issues [QUA-429](/QUA/issues/QUA-429), [QUA-438](/QUA/issues/QUA-438).
  - Agent ID: `f2c79849-a19e-4bc0-8737-438dd50ada64`.

Wave-plan status (per [`decisions/2026-04-27_v5_org_proposal.md`](../decisions/2026-04-27_v5_org_proposal.md) § 6 + the [DL-039](../decisions/2026-04-28_quality_business_hire.md) one-time override): **Wave 0** (CEO/CTO/Research/Documentation-KM) + **Wave 1** (DevOps/Pipeline-Operator) + **Wave 2** (Quality-Tech/Development/Quality-Business) all live. Pending: Wave 3 (Controlling, Observability-SRE), Wave 4 (LiveOps), Wave 5 (R-and-D). Chief of Staff is deferred indefinitely per `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md`.

## Execution Policies

Per [DL-030](../decisions/2026-04-27_execution_policies_v1.md): every issue created in scope of a stakes-bearing flow MUST carry an `executionPolicy` block at creation time (or via PATCH before `in_progress`). The runtime — not the agent — enforces the `in_progress → done` interception. The full JSON snippets (with concrete reviewer/approver participant identifiers) live in DL-030; this registry section is the role-level convention.

| Class | Flow | Scope test | Policy | Reviewer / Approver (role) | Wave 2 hire trigger |
|---|---|---|---|---|---|
| 1 | T6 deploy | `projectId` = T6 Live Operations, **or** title matches `^T6 deploy` (case-insensitive) | **Approval-only** | OWNER | n/a |
| 2 | Strategy Card extraction | `projectId` = V5 Strategy Research **and** issue is a Strategy Card (child of a Source-research parent per DL-029; source-extraction parents and the workflow-charter parent are exempt) | **Review-only** | **CEO + Quality-Business** (Wave 2 active per [DL-039](../decisions/2026-04-28_quality_business_hire.md), OWNER fallback retained per [DL-016](REGISTRY.md)) | shipped 2026-04-28 — DL-039 |
| 3 | EA `_v2+` enhancement | `projectId` = V5 Framework Implementation **and** title matches `_v[0-9]+\b` | **Review-only** | **Quality-Tech** (Wave 2 active — hire landed 2026-04-28; CTO retains fallback) | shipped 2026-04-28 |
| 4 | All other issues | n/a (default) | Comment-required only (Paperclip default) | n/a | n/a |

Class 2 / 3 transition note (per [DL-039](../decisions/2026-04-28_quality_business_hire.md) "What changes immediately" § 1): new Strategy Card and `_v[0-9]+` enhancement child issues created on/after 2026-04-28 carry the named Wave 2 reviewer (Quality-Business / Quality-Tech). Existing in-flight cards keep their original participants until close-out — CEO does not retroactively re-policy them.

`commentRequired: true` is independent of stages and remains on for every issue regardless of class.

**Class 1 layered relationship to DL-025.** Approval-only is layered on top of — not a substitute for — the V5 hard rule that **AutoTrading is OWNER-manual**. The runtime gate intercepts the `done` transition; the live-account toggle stays out of agent hands entirely.

**Sentinel role.** CEO scans for unpolicied issues in scope and PATCHes a policy in. Manual sweep until an automation routine is added.

**Self-review prevention.** The runtime excludes the original executor from the eligible reviewer/approver set. Class 2 lists OWNER as a fallback participant so CEO-authored strategy cards can still close while CEO holds the interim Quality-Business seat. Same fallback applies to Class 3 / DL-036 if CTO is ever the executor on an EA Review-gate issue.

For the full JSON shape per class (including reviewer/approver participant identifiers), see [DL-030 § Implementation mechanism](../decisions/2026-04-27_execution_policies_v1.md). DL-030 itself is **not** updated to name Wave 2 hires — DL-NNN docs are time-stamped records of the convention at decision time; this registry section reflects what is currently in force per [DL-026](../decisions/DL-026_coding_agent_done_requires_commit_hash.md) operational-doc precedence.

## Factory Setup Standards

- MT5 factory terminals `T1`-`T5` must include an install-root `portable.txt` marker file (empty file) to prevent AppData split-brain when launched without explicit `/portable`.

## Concurrent-Write Discipline / Worktree Isolation

Canonical decision: [DL-028](../decisions/DL-028_per_agent_worktree_isolation.md). Narrative source of record: [`lessons-learned/2026-04-27_pc1-00_live_incident_qua-167.md`](../lessons-learned/2026-04-27_pc1-00_live_incident_qua-167.md).

- Agents writing to `framework/`, `infra/`, or any other path under concurrent multi-agent write contention run from `C:\QM\worktrees\<agent-key>\` on branch `agents/<agent-key>`, **not** from the shared `C:\QM\repo\` root.
- All `git add` / `git commit` / `git push` on `C:\QM\repo\` go through `infra/scripts/Invoke-GitWithMutex.ps1` (Windows named mutex serializes across worktrees).
- Stale `index.lock` files older than 20 min are surfaced by scheduled task `QM_GitIndexLockMonitor_10min` (every 10 min); see `infra/monitoring/Invoke-GitIndexLockMonitor.ps1`.
- Worktree creation/repair is idempotent via `infra/scripts/Ensure-AgentWorktree.ps1`.
- Race detection: if an agent observes mid-edit on-disk drift, it **safety-stops** and posts an issue comment offering merge / use-existing / overwrite options (Stop-digging Hard Rule).

Out of scope for this rule: `T6_Live` (governed by DL-025 + `CLAUDE.md` § Hard Boundaries) and `paperclip-prompts/*.md` (OWNER-managed; agent prompts are Git-canonical). Exceptions to the worktree rule require a successor DL-NNN.

## Strategy Research Workflow

Canonical spec: [13-strategy-research.md](13-strategy-research.md). Parent directive: QUA-236 (OWNER 2026-04-27).

- Source → Strategy → Pipeline issue tree is binding. One parent per resource (`SRC<NN> — <citation>`); one sub-issue per strategy (`SRC<NN>_S<n> — <slug>`). First sub `todo`, rest `blocked`. Next sub unblocks only when the prior closes with a ready-or-killed verdict (P1 → P8 + Quality-Tech sign-off).
- One source actively worked at a time; one strategy from that source actively worked at a time. No parallel-source extraction.
- Strategy Cards live at `strategy-seeds/cards/<slug>_card.md` (slug allocated at extraction time; `ea_id` allocated at APPROVED → IN_BUILD). Card schema: `strategy-seeds/cards/_TEMPLATE.md` with mandatory fields `source_citations: []`, `strategy_type_flags: []`, and a `framework_alignment` section.
- Strategy-type vocabulary is mined from V4 (`strategy-seeds/strategy_type_flags.md` under QUA-244). No new flags invented in V5.
- Same-source enhancement via in-pipeline learning = `_v2` of same card (new row in § 13 Pipeline History). Different-source enhancement = new sub-issue under the new source's parent, new card. The test is *where the insight came from*.

## EA Enhancement Loop (`_v<n>` versioning)

Canonical spec: [14-ea-enhancement-loop.md](14-ea-enhancement-loop.md). Parent directive: QUA-236; authored under QUA-245.

- Trigger list is **closed**: (a) zero-trades backtest report = automatic send-back to Development; (b) "must re-test from P1" failures — input-rule change, parameter-set change beyond declared sweep bounds, news-mode change. Any other rebuild candidate escalates to CEO + CTO before `_v<n>` is created.
- Sweep selections within P3 bounds, re-runs at the same gate, and multi-seed variance checks are **not** enhancements — they continue under the existing version row.
- File versioning: EA build gains `_v2`, `_v3`, ... suffix (e.g. `QM5_NNNN_<slug>_v2.mq5`); `slug` and `ea_id` are stable across versions; magic-number rows do not change.
- `_v<n>` is treated as a NEW EA for backtesting: it re-runs P1 → P8 from scratch, no metric carry-forward from `_v<n-1>`.
- Card stays canonical at `strategy-seeds/cards/<slug>_card.md` (no `_v2` card files). Each version appends a `### v<n>` block to the card's § 13 Pipeline History, headed with the trigger.
- Only one version live at a time — `_v<n>` supersedes `_v<n-1>` at L7 → L8 promotion.

## Pipeline-Operator Load Balancing (T1-T5)

Canonical spec: [15-pipeline-op-load-balancing.md](15-pipeline-op-load-balancing.md). Parent directive: QUA-236; authored under QUA-246. Dispatch convention codified as [DL-035](../decisions/2026-04-28_pipeline_loadbalance_convention.md) (interim) under QUA-301 in response to OWNER 2026-04-28 audit ("all 5 MT5 instances should work in parallel").

- Allocation policy: **least-loaded round-robin with symbol-affinity tie-break** across `T1`-`T5`. One active scanner per terminal max. `T6` is out of write scope.
- Issue spawn convention: every backtest issue carries `target_terminal: T1 | T2 | T3 | T4 | T5 | any`. `any` is the default; Pipeline-Op picks least-loaded for `any` (DL-035).
- De-dup contract is binding: tuple `(ea_id, version, symbol, phase, sub_gate_config)` is **never** executed twice. Registry table at `D:\QM\reports\state\factory_run_dedup_v1.csv` with lock file at `factory_run_dedup_v1.lock`. Any rerun must change the `sub_gate_config` digest (e.g. CTO-approved `retry_tag`) producing a new tuple.
- Queue ledger (append-only): `D:\QM\reports\state\factory_run_queue_v1.jsonl`; dispatch state snapshot: `factory_dispatch_state_v1.json`. Flow: enqueue → preflight de-dup → claim → start → ack; failed/no-report/aborted states close the tuple (no silent re-queue under same tuple).
- Per-run evidence root: `D:\QM\reports\factory_runs\<ea_id>\<version>\<phase>\<symbol>\<run_key>\` with `dispatch.json`, `runner_stdout.log`, `runner_stderr.log`, `pid_snapshot.json`, `report_manifest.json`, `ack.json`.
- Disk policy: `>80 GB` free for normal operation; `<60 GB` is immediate CEO escalation. `NO_REPORT > 30%` per cohort is immediate CEO escalation.
- Filesystem-truth reconciliation runs before any stall/dead-EA claim; tracker JSON is advisory.
- Post-restart verification gate (state file readable, PIDs match live, T2/T3 script paths aligned, owner-overrides validated from file) must pass before resuming heartbeat work.
- T1-T5 parallel discipline (DL-035): all five terminals carry concurrent work whenever the queue can supply it; OWNER's parallel-fleet expectation is the binding floor.

## Backtest Execution Discipline (DL-038)

Canonical spec: [16-backtest-execution-discipline.md](16-backtest-execution-discipline.md). Ratifying decision: [DL-038](../decisions/2026-04-28_seven_backtest_rules.md). Parent directive: [QUA-400](/QUA/issues/QUA-400) (OWNER 2026-04-28 ~11:15 local — verbatim 7 rules). Process recording task: [QUA-426](/QUA/issues/QUA-426) (Doc-KM); DL recording task: [QUA-422](/QUA/issues/QUA-422) (CEO).

Seven binding rules govern every V5 backtest dispatch on T1–T5. T6 OFF LIMITS per [DL-025](../decisions/DL-025_t6_deploy_boundary_refinement.md).

| # | Rule | Owner | Sibling sub-issue |
|---|---|---|---|
| 1 | `.DWX`-only — never native broker symbols | Pipeline-Op | [QUA-421](/QUA/issues/QUA-421) (matrix dispatcher) |
| 2 | 36-symbol matrix per EA per phase | Pipeline-Op (Quality-Tech sets PASS-N) | [QUA-421](/QUA/issues/QUA-421) |
| 3 | T1–T5 parallel discipline (binding floor, not soft target) | Pipeline-Op + DevOps (Rule 5 dependency) | covered by Rule 5 deploy + [DL-035](../decisions/2026-04-28_pipeline_loadbalance_convention.md) |
| 4 | Fail-fast — phase failure unblocks next SRC sibling | Pipeline-Op + CEO confirm | [QUA-421](/QUA/issues/QUA-421) |
| 5 | Every EA on all 5 terminals — `framework/scripts/deploy_ea_to_all_terminals.ps1` mandatory step of build close | DevOps; CTO Review-only gate | [QUA-412](/QUA/issues/QUA-412) (DevOps deploy rollout) + [QUA-424](/QUA/issues/QUA-424) (CTO retroactive review) |
| 6 | Drive `QuantMechanica` = Tier 1.5 concept resource — never V4 backtest results, cite ORIGINAL sources | Research; CEO at card review | [QUA-423](/QUA/issues/QUA-423) (SOURCE_QUEUE survey-pass) |
| 7 | `RISK_FIXED` set-file mandatory per dispatch (`<EA>_<symbol>_<TF>_backtest.set`) | DevOps generator + Pipeline-Op gate | [QUA-419](/QUA/issues/QUA-419) (gen_setfile.ps1 + dispatch refusal) |

Hard-fail rejects: `BACKTEST_REJECTED_NATIVE_SYMBOL` (Rule 1), `BACKTEST_REJECTED_NO_SETFILE` (Rule 7), missing-deploy hash mismatch (Rule 5). EA Review prerequisite under [DL-036](../decisions/2026-04-28_ea_review_gate.md) (additive to [DL-030](../decisions/2026-04-27_execution_policies_v1.md) Class 3). Strategy-research workflow upstream: [13-strategy-research.md](13-strategy-research.md). Enhancement-loop boundary: [14-ea-enhancement-loop.md](14-ea-enhancement-loop.md).

## EA Review Gate (DL-036, additive to DL-030 Class 3)

Canonical decision: [DL-036](../decisions/2026-04-28_ea_review_gate.md). Recording task: QUA-301. Parent driver: QUA-297 (OWNER 2026-04-28 audit — "EA should also be reviewed, then backtests can start").

- **Scope test (title regex, anchored, case-sensitive):** `^SRC\d+_S\d+ — .* \(APPROVED card → P1\.\.P10 pipeline run\)$`. Examples: `SRC03_S2 — Trend MA Cross (APPROVED card → P1..P10 pipeline run)`.
- **Policy:** Review-only `executionPolicy` with single participant `agentId: "241ccf3c-ab68-40d6-b8eb-e03917795878"` (CTO, interim). On Wave 2 hire, CEO PATCHes participants to Quality-Tech agent id; the swap is identical to (and batched with) the DL-030 Class 3 swap.
- **Pipeline-Op binding rule:** Pipeline-Op may NOT P2-baseline an EA whose parent SRC0N_Sn issue's Review stage is `pending`. P1 sanity runs (compile + zero-trades probe) are allowed without Review-stage clearance; the boundary is the **P1 → P2 transition**, not "any backtest run".
- **Self-review prevention:** the runtime excludes the original executor from being selected as reviewer. CTO is rarely the executor on SRC0N_Sn issues, so collisions are unlikely; if CTO ever is the executor, CEO PATCHes a fallback participant in (mirrors DL-030 Class 2 fallback).
- **Sentinel sweep:** CEO heartbeat scans for in-scope unpolicied issues and PATCHes a policy in (DL-030 sentinel role).
- **Relationship to DL-030 Class 3:** DL-036 is **additive**. DL-030 Class 3 catches `_v[0-9]+` enhancement rebuilds; DL-036 catches the first `_v1` baseline run for an APPROVED card. Together they close the loop on every EA → backtest pathway.
- **In-flight enforcement (2026-04-28):** 5 PATCHes already applied by CEO this heartbeat — QUA-277 / 278 / 279 / 280 / 281.

> **Reconciliation note.** The full DL-030 Execution Policies section (Classes 1–4) is now merged into this branch above (under "Execution Policies"); see QUA-441 for the merge commit. The parallel content from `main` (CEO Authority Boundaries, Issue Routing) is still pending merge into `agents/docs-km` and tracked separately. This DL-036 subsection stays inline as the canonical reference for the EA Review gate; on a future reconciliation pass, DL-036 can fold into the Execution Policies table as **Class 5** (or extend Class 3's scope test) — whichever is cleaner at the time.
