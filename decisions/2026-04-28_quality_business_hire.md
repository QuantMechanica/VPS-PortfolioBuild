# DL-039 — Quality-Business Hire (9th-Agent Override + G0 Review Reroute)

**Date:** 2026-04-28
**Authority:** OWNER directive 2026-04-28 ~12:30 local (relayed via Board Advisor); CEO unilateral under DL-017 (hires) + DL-023 (broadened authority v2). 9th-agent cap from CEO V5 Org Proposal § 6 explicitly overridden by OWNER.
**Originating issue:** [QUA-429](/QUA/issues/QUA-429)
**Recording issue:** [QUA-429](/QUA/issues/QUA-429) (this same issue carries the disposition; no separate recording task — directive→action was same heartbeat).

## Decision

Hired **Quality-Business** as the V5 second-eye reviewer on Strategy Cards. QB is the 9th active agent, exceeding the 8-agent anti-sprawl cap from CEO V5 Org Proposal § 6 — OWNER explicitly waived that cap on this directive ("Hire right now please and reroute those tasks to him. CEO can approve. We should get things going!").

**Canonical agent:** `0ab3d743-e3fb-44e5-8d35-c05d0d78715d` (urlKey `quality-business-2`, name `Quality-Business 2` — auto-suffixed because the failed first hire had already claimed `quality-business`; see "Race-condition note" below).

**Adapter / runtime:**

- `claude_local`, model `claude-opus-4-7` (cache-friendly long-form economic-thesis reasoning; matches Research's adapter).
- `cwd: C:\QM\worktrees\quality-business` (per-agent worktree under DL-027; QB does not write source — verdicts are issue comments — but the worktree gives QB its own scratch space for review notes).
- Heartbeat (after QUA-444 patch): `enabled=false, wakeOnDemand=true, maxConcurrentRuns=1` — purely event-driven (wake on assignment / mention). No timer fallback; G0 review is reactive, not periodic.
- Reports to CEO (`reportsTo: 7795b4b0-8ecd-46da-ab22-06def7c8fa2d`); strategically reports to OWNER via monthly business review.
- Instructions sourced from BASIS `paperclip-prompts/quality-business.md` (V5 BASIS, migrated from Notion 2026-04-26).

## Charter (advisory + economic, never sole gate)

QB is **the second eye, not the sole gate**. APPROVED requires CEO **and** QB. Per BASIS:

1. **G0 Strategy Card portfolio-fit review** with CEO — pre-screens cards before Development burns P1 build cycles.
2. **Economic-thesis depth check** — "Is this strategy's edge plausible vs known market microstructure?"
3. **Author-claim verification** — does the source's performance claim hold up under skeptical reading?
4. **PASS cross-challenge at P2** — mandatory 2-agent check on PASS decisions; QB's lens is business/strategic, not technical.
5. **Portfolio-fit checks at P9** — when first PASS-eligible EA reaches P9, QB partners with OWNER on portfolio inclusion.
6. **Monthly business review** to OWNER (first Monday).

QB does **not** edit code, edit prompts, run backtests, dispatch work, or unilaterally reject Strategy Cards (proposes; CEO decides). QB does not touch T6 ever.

## Reroute on landing — G0 review queue

Per QUA-429, CEO routed the following to QB on hire (rollup issue [QUA-438](/QUA/issues/QUA-438), `assigneeAgentId=0ab3d743-e3fb-44e5-8d35-c05d0d78715d`):

| Source | Cards routed to QB |
|---|---|
| **SRC02 Chan QT** | `chan-pairs-stat-arb_card.md` (QUA-284) — note the QUA-429 task said "8 cards" but only S01 is currently in Chan-QT scope; the broader chan-AT inventory belongs to SRC05 below |
| **SRC03 Williams** | QUA-314 (S01 williams-vol-bo) — card file not yet on disk; QB to flag missing-card to Research |
| **SRC04 Lien** (S03 already P1-shipped, skip) | QUA-341, QUA-343, QUA-344, QUA-345, QUA-346, QUA-347, QUA-348, QUA-349 + `lien-dbb-pick-tops_card.md` (no QUA-issue ref yet) |
| **SRC05 Chan AT WS** | QUA-352 in_review; cards arrive over heartbeats — QB watches and verdicts as each lands. The 12 `chan-at-*` cards already on disk fall here. |

**Excluded from QB review:** SRC01 Davey 5 cards — already CEO interim-APPROVED at QUA-276; proceed through Development without retroactive QB. New cards from SRC02+ get QB review going forward.

**Verdict format** (per BASIS):

- `APPROVED` (with edge mechanism + portfolio-fit + author-claim notes)
- `REJECTED — <thin-thesis|unfalsifiable-claim|duplicate-archetype|source-non-reputable|over-concentration>` with reason + suggested next
- `NEEDS_CLARIFICATION — <ask>` with specific question

CEO retains G0 final-approval authority — QB is the second eye, not the sole gate.

## Race-condition + retired-hire note (canonical agent corrected)

This DL note's earlier revision named `f2c79849-a19e-4bc0-8737-438dd50ada64` as canonical. That was wrong; this revision flips it. Truth:

1. **CEO heartbeat 12:52Z** submitted `agent-hires` for QB and got `f2c79849`. The hire payload was built via Python `json.dumps` with the literal Windows path `"C:\\QM\\repo"` for `cwd`; in the JSON-on-the-wire serialisation the `\r` in `\repo` was interpreted as a carriage return, so the agent landed with `cwd=C:\QMepo` (ENOENT). The first run failed at process spawn.
2. **Parallel run** (likely Board Advisor or a sibling CEO heartbeat) detected the broken hire and re-hired QB at `2026-04-28T12:54:47Z` with the corrected, worktree-isolated cwd. Because the urlKey `quality-business` was already claimed by the broken hire, the new agent got auto-suffixed urlKey `quality-business-2` and name `Quality-Business 2` — the canonical agent on this DL.
3. **Recovery (QUA-440):** broken hire `f2c79849` was renamed to `Quality-Business (RETIRED 2026-04-28)`, urlKey rotated to `quality-business-retired-2026-04-28`, heartbeat fully disabled (`enabled=false, wakeOnDemand=false, maxConcurrentRuns=0`). Inert; board deletion needed to fully purge it (CEO lacks DELETE-agent permission). QUA-432 (and other QB-routed issues misattributed to the retired id) were reassigned to `0ab3d743`.

**Lessons logged to memory:**

- `feedback_hire_cwd_json_escape.md`: Windows `cwd` in `adapterConfig` must be `\\`-escaped (or use `/`). A single `\r`/`\n`/`\t` silently corrupts the path. Build the JSON payload with the path expressed as either forward-slashes or `\\\\`-doubled when going through Python `json.dumps`.
- `feedback_hire_runtime_wakeondemand.md`: `paperclip-create-agent` ships `runtimeConfig.heartbeat.wakeOnDemand=false` by default; PATCH to `true` post-hire or the agent never wakes. QB2 was stranded for ~30 min until this was patched (QUA-444 cascade).
- Earlier hires-discovery lesson stands: list existing agents with `includeInactive=true` before creating, since the default `agent-configurations` list filters out idle agents that have never run, and that filtering masks both QB and Quality-Tech.

## Cross-links

- **DL-017 ↔ DL-039.** DL-039 is the second hire materialised under DL-017's CEO hire-approval waiver (after Wave 1 hires DL-013/DL-014). The 9th-agent override is OWNER-additional to DL-017 — DL-017 covers "CEO can hire", QUA-429 OWNER directive covers "specifically QB, specifically now, even past the 8-cap".
- **DL-029 ↔ DL-039.** DL-029's research workflow names the Research → QB → Development gate; DL-039 fills the QB seat that gate had been waiting on. With QB live, the gate is no longer interim-CEO-only.
- **DL-030 ↔ DL-039.** DL-030 names QB as the Wave 2 named reviewer on Class 2 (Strategy Card Review-only) issues. DL-039 transitions Class 2 from "interim CEO + Board Advisor" to "CEO + Quality-Business" as participants on new cards. (Existing in-flight cards keep their current participants until close-out.)

## What changes immediately

1. New Strategy Card child issues in V5 Strategy Research (project `b2adcc7f-064f-47c7-8563-d1c917639231`) get `executionPolicy.participants` set to `[CEO, QB]` instead of `[CEO, Board Advisor]`. Existing in-flight cards: not retroactively repolicied.
2. CEO ceases to be sole G0-approver; QB AGREE-or-DISAGREE binds.
3. CEO V5 Org Proposal § 6 active-agent count: 8 → 9. Anti-sprawl rule remains in force for further hires; this is a one-time OWNER override.

## What does not change

- T6 boundary (OFF LIMITS for QB).
- Statistical / overfit / PBO review at P7 stays Quality-Tech's lane.
- CTO EA-vs-Card technical review stays CTO's lane.
- DL-026 commit-hash-in-close-out rule still applies to Development (not QB; QB doesn't ship code).
- DL-029 binding-sequential research workflow unchanged.

## Verification

- `GET /api/companies/{companyId}/agents` (default list) returns canonical `0ab3d743-e3fb-44e5-8d35-c05d0d78715d` (`Quality-Business 2`, urlKey `quality-business-2`, status `idle`, `reportsTo=CEO`, adapter `claude_local`, model `claude-opus-4-7`, cwd `C:\QM\worktrees\quality-business`).
- Same call returns retired `f2c79849-a19e-4bc0-8737-438dd50ada64` (`Quality-Business (RETIRED 2026-04-28)`, urlKey `quality-business-retired-2026-04-28`, heartbeat fully disabled, cwd `C:\QMepo` — ENOENT).
- [QUA-438](/QUA/issues/QUA-438) created and assigned to canonical QB with the SRC02-SRC05 G0 backlog dispatched.
- Forward G0 verdicts already landed on QUA-340, QUA-346, QUA-348, QUA-349 (and others) showing `0ab3d743` posting `APPROVED` advisory pre-screens, with CEO co-signing under DL-030 Class-2 Review-only execution policy. Live two-eye protocol confirmed.
- Doc-KM follow-up tracked separately to update `processes/process_registry.md` § "Active agents" and to backfill DL-030 participants table to name QB explicitly.
