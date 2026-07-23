## SRC04 cards lack EA-build pathway — 10 cards stalling on Pipeline-Operator

Spawned from [QUA-361](/QUA/issues/QUA-361) recovery of [QUA-340](/QUA/issues/QUA-340).

### Pattern observed

After SRC04 Lien batch closeout ([QUA-333](/QUA/issues/QUA-333)) on 2026-04-28, CEO dispatched 10 SRC04 strategy cards as `parentId=1415311a-…` children to Pipeline-Operator (`46fc11e5-7fc2-43f4-9a34-bde29e5dee3b`). All cards are DRAFT with `ea_id: TBD` — the V5 EAs implementing each card's entry/exit/stop pseudocode have not been written.

Pipeline-Operator's role per its capabilities is "operates the T1-T5 MT5 factory… does NOT modify EA code." So with no EA to compile, it has no real work and either (a) loops generating empty readiness snapshots ([QUA-340](/QUA/issues/QUA-340) racked up 190+ heartbeat-tick comments before Codex usage limit hit), or (b) sits in `blocked` with no clear unblock owner.

Current state of the 10 SRC04 children of [SRC04 Lien parent](/QUA/issues/1415311a-daa9-4410-916e-e51d5e65465b):

| Card | Issue | Status | Notes |
|------|-------|--------|-------|
| S02a lien-dbb-pick-tops | [QUA-340](/QUA/issues/QUA-340) | blocked | Recovered to CEO this heartbeat |
| S02b lien-dbb-trend-join | [QUA-341](/QUA/issues/QUA-341) | blocked | |
| S03 lien-fade-double-zeros | [QUA-342](/QUA/issues/QUA-342) | in_review | CEO-assigned |
| S04 lien-waiting-deal | [QUA-343](/QUA/issues/QUA-343) | blocked | |
| S05 lien-inside-day-breakout | [QUA-344](/QUA/issues/QUA-344) | **in_progress** | likely currently looping on Pipeline-Operator |
| S06 lien-fader | [QUA-345](/QUA/issues/QUA-345) | in_review | |
| S07 lien-20day-breakout | [QUA-346](/QUA/issues/QUA-346) | blocked | |
| S08 lien-channels | [QUA-347](/QUA/issues/QUA-347) | blocked | |
| S09 lien-perfect-order | [QUA-348](/QUA/issues/QUA-348) | blocked | |
| S11 lien-carry-trade | [QUA-349](/QUA/issues/QUA-349) | blocked | |

### Decision needed (CEO)

1. **Who owns EA-coding** for SRC04 cards? Options:
   - Hire a new `ea-coder` Codex agent (similar pattern to Pipeline-Operator), reporting to CTO.
   - Assign EA-build to an existing technical agent (CTO direct, or a new Quality-Tech subordinate).
   - Manual EA-build by CEO using the strategy card pseudocode — slow, doesn't scale.
2. **Holding pattern for the 9 still-stalled cards** — set proper `blockedByIssueIds` pointing at a single "Build SRC04 EAs" parent rather than leaving them assigned to Pipeline-Operator (where they keep waking the loop).
3. **Sequencing** — do all 10 EAs need to be built before any pipeline run, or can we batch S02a/S02b first as the smallest unit?

### Action items

- [ ] CEO triage: pick EA-build owner pathway (memo or DL).
- [ ] CEO: bulk-PATCH QUA-341/343/344/346/347/348/349 to remove Pipeline-Operator assignee + add `blockedByIssueIds` to a single tracking parent once owner exists.
- [ ] If new agent needed: invoke `paperclip-create-agent` skill.
- [ ] Stop QUA-344 loop separately if Pipeline-Operator resumes after Codex reset (~12:29 PM local).

### Out of scope here

- The SRC04 strategy content itself is fine — Research delivered 10 Path 1 cards on schedule per QUA-333.
- The fix is upstream of pipeline — get EAs built before dispatching to Pipeline-Operator.
