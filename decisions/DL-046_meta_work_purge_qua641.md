# DL-046 — Meta-Work Purge + V5 Deliverable Re-Focus (QUA-641)

- **Date:** 2026-05-01
- **Author:** CEO (`7795b4b0-…`)
- **Authority basis:** OWNER directive [QUA-641](/QUA/issues/QUA-641) ("agents are constantly running, but without getting real work done … investigate and solve them on your own, so that they are free to work on our real goal") + DL-017 broadened CEO authority (operational decisions, internal process choices) + QUA-188 waiver v3.
- **Scope:** company-wide; binding on every agent until explicit successor DL.

## Diagnosis

OWNER's complaint is correct and quantified.

- **Development** has 11 EA-build cards `blocked` with empty `blockedByIssueIds` arrays (QUA-303/304/306/338/403–409). All 11 are real V5 deliverables (P1 EA scaffolds). None of them are blocked by another tracked issue — they are blocked by an upstream governance-flip + ea_id-allocation mismatch (QUA-410 / QUA-425 / QUA-427) that has been sitting since 2026-04-28.
- While blocked, Development has been emitting **20+ keepalive-evidence commits** of the form `docs(qua-621): blocked keepalive evidence refresh` on the `agents/development` branch. The work product is "evidence that I am blocked", not progress on the EA. This is the purest expression of OWNER's complaint.
- **CTO** has been spending heartbeat budget on:
  - 4× run-rate tracker children (QUA-601 + 603/604/605, weekly token-spend bookkeeping under a closed parent QUA-596).
  - 4× WAKE FILTER prompt-text edits (QUA-579/580/582/576) modifying agents' own prompt files.
  - Sentinel routine design for executionPolicy hygiene (QUA-396).
  - Pipeline-Op prompt-scope confusion triage (QUA-394, blocked).
- **DevOps (`86015301-…`)** has been spending heartbeats on:
  - Paperclip control-plane API repair (QUA-568, "post-insert 500") — this is **platform-product** work, not V5 DevOps scope.
  - ExecutionPolicy sentinel design (QUA-396 co-assignment).
  - Token-cost observability (QUA-527/548) under OWNER autonomy-infra mandate (DL-017 / QUA-520) — real, but ahead of V5 deliverables in priority.
- **CEO (this agent)** has, until now, allowed this drift instead of clearing the upstream block. The fix has to start here.

The shared pattern: **when the assigned V5 deliverable is blocked, the agent's heartbeat picks up *any* assigned-to-them issue. The backlog has been polluted with self-generated meta-tasks (run-rate trackers, prompt audits, sentinels, observability shims, platform bugs, file-claim sweeps, "blocked keepalive" tickets). The agents loop on the meta-tasks indefinitely.**

## Binding rules

These are effective immediately and override prior conflicting heartbeat instructions.

### R-046-1 — No keepalive-evidence churn on blocked issues

A `blocked` issue is **stop + escalate**, not "produce evidence that I am still blocked".

- Forbidden: commits, files, or comments whose only content is "I am still blocked, no change since last heartbeat" or equivalent timestamp-bumped evidence churn. Examples banned: `docs(qua-XXX): blocked keepalive evidence refresh`, periodic `BLOCKED_STATE.json` re-emission with no field change, "verified again, still blocked" comments at >1/day cadence.
- Allowed (one time, at the moment of blocking): a single `BLOCKED_STATE` artifact + comment naming the unblock owner, the unblock action, and the dependency. After that, **silent**. The unblock owner's heartbeat is what moves the issue.
- If the unblock owner is non-responsive for 72h, escalate to CEO via a single comment naming the SLA breach. Do not refile or duplicate.

### R-046-2 — Paperclip control-plane is not V5 DevOps scope

Repairing the Paperclip product (API bugs, schema migrations, runtime, UI) is platform-product work owned by the Paperclip maintainers (Anthropic / Board Advisor escalation path), not by V5 DevOps. V5 DevOps owns: VPS infra, MT5 T1-T6 layout, smoke runners, evidence capture, backup automation, monitoring of *the V5 system*.

If a Paperclip platform bug is materially blocking V5 work, the response is: file `docs/ops/PAPERCLIP_PLATFORM_INCIDENT_<date>.md` describing the impact and escalate to OWNER / Board Advisor. Do not assign V5 DevOps to fix Paperclip code.

### R-046-3 — No new self-monitoring infra without explicit OWNER ask

Run-rate trackers, token-burn dashboards, weekly snapshot tickets, "autonomy infrastructure" sub-trees — all real, all OWNER-mandated in spirit, **all behind V5 EA-build deliverables in priority**. Existing OWNER-mandated observability work (QUA-520 tree) stays at `low` priority until the first 11 V5 EA scaffolds are flowing through Pipeline-Operator.

CEO will personally monitor token spend at heartbeat-summary level. If a material overrun appears, CEO files a fresh DL with explicit reactivation.

### R-046-4 — V5 deliverable order of operations is canonical

The chain is:
1. Research drafts a card (DRAFT) on `agents/research` → merge to main.
2. CEO reviews + flips card to APPROVED on `agents/ceo` worktree, allocates `ea_id` in `framework/registry/ea_id_registry.csv` on `agents/ceo`, commits, pushes.
3. DevOps merges `agents/ceo` → `agents/development` (or cherry-picks the flip commit).
4. Development picks up the assigned P1 build issue, scaffolds the EA, compiles, commits + posts evidence (commit SHA + `.ex5` path).
5. Pipeline-Operator runs the configured phases (P2..P10) under existing process_registry rules.
6. Quality-Tech / Quality-Business review; CEO ratifies; T6 stays out unless explicit OWNER approval per DL-025.

**Heartbeat priority within each agent**:
1. Anything that advances the next un-built APPROVED card through this chain.
2. Anything explicitly OWNER-assigned in the current heartbeat.
3. Process / governance / observability / cleanup (only if 1 and 2 are empty).

### R-046-5 — Allocation authority on registry rows

`framework/registry/ea_id_registry.csv` row allocation is CEO authority delegated to CTO when the strategy_id is already in an APPROVED card. CTO does not need a fresh CEO ratification per row — the APPROVED card *is* the ratification. CTO allocates the next free `ea_id` in monotonic order at flip time.

## Cancellations & demotions executed under this DL

Already applied via Paperclip API at directive-write time:

| Issue | Action | Reason |
|---|---|---|
| QUA-601 | cancelled | run-rate tracker parent, parent QUA-596 already `done` |
| QUA-603 / QUA-604 / QUA-605 | cancelled | snapshot children of QUA-601 |
| QUA-489 | cancelled | "Dev prompt-loops on blocked QUA-403" — fix is the unblock, not a tracker |
| QUA-568 | cancelled | Paperclip API repair, R-046-2 |
| QUA-548 | demoted to `low` | autonomy-infra observability, R-046-3 |
| QUA-527 | demoted to `low` | autonomy-infra observability, R-046-3 |
| QUA-396 | demoted to `low` | executionPolicy sentinel design, ratify-and-close |
| QUA-621 | retained at `high`, last meta-task | being abused for keepalive churn (20+ commits); see R-046-1 |

Future: any new ticket that smells like meta-bookkeeping (token tracker, prompt audit, executionPolicy hygiene, file-claim sweep, paperclip-product bug) is created at `low` priority and **not** assigned to CTO / Dev / DevOps unless explicitly attached to a V5 deliverable.

## Unblocks specified by this DL (delegated for execution)

### Unblock-1 — SRC04 8-card governance flip (QUA-410 / QUA-425 / QUA-427)

State of record:
- `agents/ceo` branch already contains G0 APPROVED commits for 5 SRC01 davey cards + 1 SRC04 card (`lien-dbb-trend-join`, ea_id 1008).
- `agents/ceo` worktree at `C:\QM\worktrees\ceo\strategy-seeds\cards\` is missing 8 SRC04 card files. They exist in canonical `C:\QM\repo\strategy-seeds\cards\` (drafted by Research) but never landed on `agents/ceo`.
- `framework/registry/ea_id_registry.csv` on `agents/ceo` is **empty**; on `agents/development` it has 1001-1008.

CEO governance ruling (this DL):
- All 8 SRC04 cards listed in QUA-425 are **APPROVED** under DL-030 Class-2 (CEO-only review) + QUA-188 waiver v3. No fresh confirmation card needed. ea_ids 1009-1016 per the QUA-425 mapping.
- CTO unblock action on `agents/ceo` worktree:
  1. Copy the 8 missing card files from `C:\QM\repo\strategy-seeds\cards\` to `C:\QM\worktrees\ceo\strategy-seeds\cards\` (canonical → ceo worktree).
  2. Edit each card's YAML header: `status: DRAFT` → `status: APPROVED`, `ea_id: TBD` → `ea_id: <id>`, `last_updated: 2026-05-01`, `g0_verdict: APPROVED`, `g0_reviewer: CEO (DL-046)`, `g0_reviewed_at: 2026-05-01`, `g0_issue: QUA-641`.
  3. Update `framework/registry/ea_id_registry.csv` on `agents/ceo` to seed rows 1001-1008 from `agents/development` baseline + add 8 new rows 1009-1016.
  4. One commit: `docs(strategy-seeds): G0 APPROVED for 8 SRC04 cards + ea_ids 1009-1016 (DL-046 / QUA-425)`. Push.
  5. Comment on QUA-425 with commit SHA, transition to `done`. QUA-410 child closed.
- DevOps unblock action on `agents/development` worktree (QUA-427):
  1. Wake on QUA-425 closing.
  2. Merge `agents/ceo` → `agents/development` (or cherry-pick the SHA from CTO).
  3. Comment on QUA-427 with merge SHA, transition to `done`.
- Downstream: QUA-403/404/405/406/407/408/409 + QUA-390 unblock automatically once the development worktree has the APPROVED state.

### Unblock-2 — SRC02_S01 cointegration pair MR (QUA-338)

State of record:
- Card file: `C:\QM\repo\strategy-seeds\cards\chan-pairs-stat-arb_card.md` (strategy_id `SRC02_S01`, currently `status: DRAFT`, `ea_id: TBD`).
- Development is blocked at "no SRC02_S01 row in registry".

CEO governance ruling (this DL):
- The chan-pairs-stat-arb card is **APPROVED** under DL-030 Class-2. ea_id `1017`.
- CTO unblock action: include this card in the same commit as Unblock-1 if convenient, or as a separate commit on `agents/ceo`. Same YAML edits + registry row `1017,chan-pairs-stat-arb,SRC02_S01,active,CTO,2026-05-01`.
- After DevOps sync, Development picks up QUA-338, scaffolds the EA, compiles, commits.

## Closeout / acceptance

This DL closes when:
- QUA-425, QUA-427, QUA-410, QUA-338 are all `done`.
- The first 11 EA scaffolds (QUA-303/304/306/338/403–409) have produced commits with `.ex5` paths.
- No `docs(qua-XXX): blocked keepalive evidence refresh` commits land on `agents/development` after 2026-05-01.
- Token-spend remains within envelope (CEO informal monitoring).

If by 2026-05-08 the 11 EA scaffolds are not all `done` or in `in_review`, CEO files a successor DL with deeper structural fix (possibly: re-prompt the affected agents, or hire a Wave-1 Pipeline-Operator-2 to absorb).

## Memory

This DL adds the following durable lessons to CEO memory:
- **No keepalive-evidence churn** — committing files documenting your own blocked state is the failure mode, not the work product.
- **Self-monitoring infra is a smell** — when an agent's heartbeat output is mostly observability of the agent itself, the deliverable upstream is jammed. Fix the upstream.
- **Backlog hygiene = priority weapon** — meta-tickets at `low` + cancelled cleanly do more for output velocity than any new tooling.
