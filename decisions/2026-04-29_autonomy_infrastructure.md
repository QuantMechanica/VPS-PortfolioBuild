# DL-042 — Autonomy Infrastructure (4-piece delivery)

**Date:** 2026-04-29
**Authority basis:** DL-023 (CEO broadened-authority waiver v2) class 4 — internal process choices: runtime detectors, BASIS prompt patches, observability tooling, Doc-KM mirror cadence.
**Originating directive:** OWNER 2026-04-29 ~22:10 local (Vienna), verbatim: *"als issue an CEO! Löse das alles ein für alle mal!"* — relayed by Board Advisor.
**Recording task:** [QUA-520](/QUA/issues/QUA-520) (parent OWNER directive + recording task).

## Decision

Close the gap between **documented runtime-health architecture** (`processes/17-agent-runtime-health.md`, lessons-learned 2026-04-29) and **executing automation**. Pipeline-Op produced the same hot-poll loop pattern as Development 12 hours after we documented the lesson — the architecture is sound, the active automation is not running.

CEO opens four child issues under [QUA-520](/QUA/issues/QUA-520) to deliver the four missing pieces in parallel:

| Child | Owner | Project | Priority | Card |
|---|---|---|---|---|
| **A** Runtime health scan (PowerShell + psql, 5 detectors, 15-min schtasks) | DevOps (CTO review-only) | V5 Framework | critical | [QUA-522](/QUA/issues/QUA-522) |
| **B** 13-prompt BASIS self-author wake filter audit + patch | CTO | V5 Framework | critical | [QUA-523](/QUA/issues/QUA-523) |
| **C** Token-cost observability (daily snapshot + 70/80/95% alarms) | DevOps | V5 Framework | high | [QUA-524](/QUA/issues/QUA-524) |
| **D** Doc-KM catch-up (mirror processes 17/12/registry + lesson; open 13 per-prompt sub-issues for Child B) | Doc-KM | V5 Framework | high | [QUA-525](/QUA/issues/QUA-525) |

## Detector specs (Child A canonical)

1. **Hot-poll** — `runs_last_hour > 50 AND issues_done_last_hour < 5` per agent → `POST /api/agents/<id>/pause` + open follow-up to CTO.
2. **Stuck-session** — `error >30 min` OR `last_heartbeat_at >2h` while `wakeOnDemand=true` → open issue assigned CEO with terminate-rehire recommendation.
3. **Bottleneck** — `≥2 P0 in_progress` AND `<5 runs/4h` targeting them → sharper-wake comment + on-demand wake assignee.
4. **Token-budget** — `weekly_run_count × 4 > 90% provider cap` → throttle timer-heartbeats company-wide + open OWNER notification.
5. **Recursive-wake** — `≥10 byte-identical comments` on same issue in 60 min from same author → `POST /api/agents/<id>/pause` + open follow-up.

All five run pure-PowerShell + psql (no AI cost during detector execution). Output JSON to `D:\QM\reports\ops\runtime_health_<date>.json`.

## Self-author wake filter (Child B canonical text)

```
WAKE FILTER (binding):
When woken via `comment_added` event, check the source comment's author.
If author == self, exit immediately without posting any new comment.
This filter prevents recursive self-wake loops (see lessons-learned/2026-04-29_development_recursive_wake.md).
```

Applied to all 13 `paperclip-prompts/*.md` via the agents/<urlKey> worktree pattern (PC1-00). DL-NNN per patch (or per documented exemption — agents that never post comments, or have comment-events disabled).

## Token economics

~95% of this work is non-AI execution (Windows scheduled tasks, SQL queries, PowerShell). Codex/Claude agents only consumed for the 13 prompt patches (Child B) and the Doc-KM Notion mirror (Child D). Estimated incremental token spend < 5k per child.

## Boundary

T6 OFF LIMITS as ever. Detectors must skip any agent or issue tagged T6 / T6-deploy / live-account.

## Acceptance for QUA-520 parent

- [x] Children A, B, C, D opened with assignees + acceptance criteria (this DL).
- [ ] Children closed (runtime scan running, prompts patched, token observability live, QUA-514 done).
- [ ] Development resumed (after QUA-372 fix lands).
- [ ] Pipeline-Op resumed (after recursive-wake patched same way).
- [ ] All 6 pending OWNER interactions resolved (CEO disposition comments posted; clerk-flip falls to OWNER).

## OWNER interaction triage (recorded for audit)

Per the agent-instructions protocol "API gates accept/reject to board users only — record the disposition as a comment, do not block delivery on the card flip":

| Interaction | Issue | Disposition | Comment |
|---|---|---|---|
| `6a568ce7` | [QUA-284](/QUA/issues/QUA-284) chan-pairs-stat-arb | **REJECT** (OUT_OF_V5_SCOPE per QUA-400) | issue cancelled |
| `125b4079` | [QUA-432](/QUA/issues/QUA-432) QB Reputable Source Criteria v1 | **ACCEPT** | comment posted |
| `f34300d1` | [QUA-433](/QUA/issues/QUA-433) QB Monthly Business Review template | **ACCEPT** | comment posted |
| `d780ef3c` | [QUA-231](/QUA/issues/QUA-231) V5 rewrite of process 08 | **ACCEPT** (sequence after Child D) | comment posted |
| `926a1230` | [QUA-230](/QUA/issues/QUA-230) V5 rewrite of process 05 | **ACCEPT** (sequence after Child D) | comment posted |
| `2c23bf27` | [QUA-511](/QUA/issues/QUA-511) stale-run lock cleanup | **ACCEPT** | comment posted |

## Cross-links

- DL-023 (CEO broadened-authority v2) — authority basis.
- DL-040 (token-discipline throttle) — token-budget detector (Child A #4) and observability output (Child C) feed back into DL-040's heartbeat-tuning decisions.
- DL-041 (DevOps restart) — establishes retire+rehire as default `codex_local` recovery; the runtime-health stuck-session detector (Child A #2) automates that diagnosis going forward.
- `processes/17-agent-runtime-health.md` — canonical detector specs (Doc-KM authored 2026-04-29 morning).
- `lessons-learned/2026-04-29_development_recursive_wake.md` — root-cause writeup; canonical citation for Child B wake-filter patch.

## Status

SUBSTANTIALLY LANDED 2026-05-01 — engineering and observability all delivered; only board-manual unpause of Development + Pipeline-Operator remains.

## 2026-05-01 update — post-blackout completion

CEO was offline 2026-04-30 ~05:09Z–22:04Z due to Claude monthly cap exhaustion ([QUA-520#comment-c3799f12](/QUA/issues/QUA-520#comment-c3799f12-72af-4289-8b0c-94dfe01b88e5), Board Advisor stand-down). Codex agents drove Children A/B/C in parallel during the blackout. CEO resumed 2026-05-01 22:04Z and routed the remaining Doc-KM blockers, then triaged the consolidated state.

### Child outcomes (canonical IDs in **bold**)

| Child | Canonical | Status | Notes |
|---|---|---|---|
| **A** Runtime health scan | **[QUA-521](/QUA/issues/QUA-521)** | done | Hardened in commit `cd1c8aea`, `Run-RuntimeHealthScan.ps1` + `QM_RuntimeHealthScan_15min` schtask wired. [QUA-522](/QUA/issues/QUA-522) parallel done. |
| **B** 13-prompt self-author filter | **[QUA-523](/QUA/issues/QUA-523)** | done | All 13 BASIS prompts patched with `WAKE FILTER (binding)` (commits 5a929834+). [QUA-526](/QUA/issues/QUA-526) parallel `in_review` — needs `local-board` UI approval. |
| **C** Token-cost observability | **[QUA-524](/QUA/issues/QUA-524)** | done | `Test-TokenCostBudget.ps1` + 70/80/95 alarms + daily snapshot at `D:\QM\reports\ops\token_usage_<date>.json`. [QUA-527](/QUA/issues/QUA-527) parallel `changes_requested` from CTO — needs DevOps re-submit (Notion-mirror prerequisite is now satisfied via [QUA-585](/QUA/issues/QUA-585)). |
| **D** Doc-KM catch-up | **[QUA-528](/QUA/issues/QUA-528)** | done | Notion mirror push complete: 4 pages CREATED for `processes/17`, `processes/12`, `process_registry`, `lessons-learned/2026-04-29_development_recursive_wake` ([QUA-585](/QUA/issues/QUA-585) at 2026-04-30T22:12Z). 13 per-prompt fan-out children opened ([QUA-572](/QUA/issues/QUA-572)…QUA-584) for CTO. [QUA-525](/QUA/issues/QUA-525) cancelled (superseded by QUA-528). |

### Companion fixes that landed alongside the four pieces

- **Server-side recursive-wake fix** — [QUA-372](/QUA/issues/QUA-372) commit `d71071e5a5957ec1a7c146ba55f49148b70434c4`: comment dedup (10-min same-author-same-body suppression) + self-author wake filter on `comment_added` events. This is the *server-side* belt-and-suspenders for Child B's *agent-side* prompt patches.
- **Notion MCP restoration** — Doc-KM reported `mcp__claude_ai_Notion__*` tools disconnected on first post-blackout heartbeat; CEO opened [QUA-586](/QUA/issues/QUA-586) (DevOps) which DevOps shipped `done` in 11 minutes. Confirmed via `notion-fetch` on test page.
- **Stale execution lock recovery** on [QUA-545](/QUA/issues/QUA-545) — cleared `checkoutRunId=69763d07` via PATCH-only assignee cycle (memory `paperclip_stale_execution_lock_cycle.md`).

### OWNER interaction triage (closed)

All 6 pending interactions verified resolved by `local-board` / Board-Advisor parallel resolution:

- [QUA-284](/QUA/issues/QUA-284) `cancelled`, interaction rejected (chan-pairs-stat-arb out of V5 scope per QUA-400)
- [QUA-432](/QUA/issues/QUA-432) `done`, interaction accepted (QB Reputable Source Criteria v1)
- [QUA-433](/QUA/issues/QUA-433) `done` (QB Monthly Business Review template)
- [QUA-231](/QUA/issues/QUA-231) `done`, interaction accepted (V5 process 08 rewrite)
- [QUA-230](/QUA/issues/QUA-230) `done`, interaction accepted (V5 process 05 rewrite)
- [QUA-511](/QUA/issues/QUA-511) `done`, interaction accepted (stale-run lock cleanup)

### Remaining blocker — board-only

Both `Development` (paused 2026-04-29T10:08Z) and `Pipeline-Operator` (paused 2026-04-29T20:21Z) are still paused. CEO created [board approval bf956583](/QUA/approvals/bf956583-eca8-43ea-8753-88396e7dd31e) requesting resume; `local-board` approved at 2026-04-30T22:18Z. Verified governance: the approval record is **authorization-only** — board user must take a separate manual unpause action in the UI. CEO/CTO `/api/agents/<id>/resume` returns `403 Board access required` even with `approvalId` in body. Captured as feedback memory `paperclip_resume_agent_is_board_only.md`.

### Final acceptance state

- [x] Children A, B, C, D opened with assignees + acceptance criteria.
- [x] Children A (QUA-521), B (QUA-523), C (QUA-524), D (QUA-528) closed `done`.
- [ ] Development resumed — pending board manual unpause (approval bf956583 already `approved`).
- [ ] Pipeline-Op resumed — same.
- [x] All 6 pending OWNER interactions resolved.
- [x] DL-042 (this document) summarizing the four-piece autonomy delivery.

### Lessons added to memory during this delivery

- `paperclip_blackout_block_not_silent.md` — in a Claude monthly-cap blackout, PATCH the in-flight issue to `blocked`; silent-exit doesn't stop continuation re-fires.
- `paperclip_resume_agent_is_board_only.md` — agent-resume is board-user-only; even an approved `request_board_approval` is record-only.
