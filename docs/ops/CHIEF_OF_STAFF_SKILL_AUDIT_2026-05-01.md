# Chief of Staff — Per-Agent Skill Audit + One-Skill-per-Agent Migration Plan

**Author:** Chief-of-Staff (38f933cd-557b-41ff-8498-30db273273ef)
**Date:** 2026-05-01
**Parent issues:** QUA-696 / QUA-698
**Authority:** OWNER directive 2026-05-01 + DL-056 § "Agent roster hygiene"
**Status:** v1 — pending CEO request_confirmation + OWNER ratification

---

## Data note — Day-1 constraint

`spentMonthlyCents: 0` for all 10 agents in the live API roster as of 2026-05-01T12:48Z (company age ~5 days; Codex outage 2026-05-01 compressed empirical data further). Token-burn projections in Section 3 are **analytical estimates** based on:

- AGENTS.md line counts → token approximations (25 tokens/line average)
- Heartbeat frequency from each agent's declared schedule
- Claude Sonnet 4.6 pricing: $3.00/MTok input, $15.00/MTok output
- Codex pricing assumed equivalent for parity (actual may differ)

These are directional projections. Replace with empirical data after 7 days of production operation.

---

## Section 1 — Current State Audit

Live API roster cross-referenced with filesystem at
`C:/QM/paperclip/data/instances/default/companies/03d4dcc8-4cea-4133-9f68-90c0d99628fb/agents/`.

**Roster match:** 10 agents in API, 10 UUIDs in filesystem (`_drafts` dir excluded). No orphan dirs.
No unfilled `{{agentName}}` template variables found. No duplicate agents (name+role+prompt).

| Agent | UUID | API Status | Adapter | AGENTS.md Lines | Inferred Skill Count | Heartbeat Freq | Anomalies |
|---|---|---|---|---|---|---|---|
| CEO | 7795b4b0 | running | claude_local | 124 | 7 | hourly + event | none |
| CTO | 241ccf3c | running | codex_local | 101 | 6 | hourly + event | none |
| Research | 7aef7a17 | idle | claude_local | 115 | 7 | event-driven | none |
| Development | ebefc3a6 | running | codex_local | 76 | 2 | event-driven | **pauseReason=manual + status=running** |
| Pipeline-Operator | 46fc11e5 | running | codex_local | 107 | 5 | every 10 min | **pauseReason=manual + status=running** |
| Quality-Business | 0ab3d743 | idle | claude_local | 139 | 5 | event-driven | none |
| Quality-Tech | c1f90ba8 | idle | claude_local | 75 | 6 | event-driven | none |
| DevOps | 86015301 | running | codex_local | 95 | 7 | hourly + event | none |
| Documentation-KM | 8c85f83f | idle | claude_local | 81 | 6 | 2h timer + event | none |
| Chief-of-Staff | 38f933cd | running | claude_local | 94 | 3 | hourly + event | none |

**Roster anomalies (per CoS mandate — pre-existing, tracked on rolling CoS issue):**
- **Development** (ebefc3a6): `status=running`, `pauseReason=manual`, `pausedAt=2026-04-29T10:08:30Z`
- **Pipeline-Operator** (46fc11e5): `status=running`, `pauseReason=manual`, `pausedAt=2026-04-29T20:21:39Z`

Both are soft-paused; status field inconsistency is a roster-hygiene flag, not a blocker for this audit.

**Skill enumeration per agent:**

| Agent | Skills identified in AGENTS.md | Skill count |
|---|---|---|
| CEO | Strategic leadership; delegation orchestration; agent hiring (paperclip-create-agent); memory management (para-memory); source-queue ordering; approval/confirmation gating; cross-functional conflict resolution | 7 |
| CTO | Tech spec writing from Strategy Cards; EA code review (Card vs code); pipeline architecture; R&D proposal approval; Hard Rules enforcement; scale-invariance gating | 6 |
| Research | Source mining (books, papers, blogs, video); PDF reading + extraction; YouTube transcript extraction; web article extraction; Strategy Card authoring; research-queue management; deep-research pre-check for CTO | 7 |
| Development | MQL5 EA implementation; V5 framework integration | 2 |
| Pipeline-Operator | MT5 terminal management (T1-T5); backtest execution; aggregator loop management; chain-watcher execution; terminal respawn + state-file heartbeat | 5 |
| Quality-Business | G0 economic-thesis review; author-claim verification; portfolio-fit check (P9); PASS cross-challenge (P2); monthly business review writing | 5 |
| Quality-Tech | Code audit (P2); overfitting detection (P3); walk-forward fidelity (P5); Monte Carlo / sensitivity (P6); DSR/PBO statistical validation (P7); sub-gate calibration | 6 |
| DevOps | VPS setup scripts; MT5 layout maintenance; Paperclip deploy tooling; backup automation; monitoring alerts; website snapshot export (public-data pipeline); Drive-sync/git isolation | 7 |
| Documentation-KM | Notion page maintenance; Notion→Git nightly sync; YouTube show notes drafting; Learnings Archive maintenance; onboarding pack preparation; process registry maintenance | 6 |
| Chief-of-Staff | Agent roster hygiene; token-burn watch; model-selection oversight | 3 |

---

## Section 2 — Skill Atomization Proposal

### 2a. Research (7 skills → 4-agent subtree) — PRIORITY: HIGH

OWNER explicitly named this in the QUA-696 directive.

```
Research-Lead  (parent — retains existing UUID, renamed + prompt updated)
├── Research-PDF-Reader        (skill: PDF / ebook → structured extract → Card fragment)
├── Research-YouTube-Watcher   (skill: video transcript → structured extract → Card fragment)
└── Research-Web-Crawler       (skill: web article / blog post → structured extract → Card fragment)
```

**Research-Lead responsibilities post-split:**
- Source queue management (propose to CEO, receive approvals)
- Strategy Card assembly from sub-agent extracts
- Source Completion Report
- CEO/CTO clarification answers
- Sub-agent dispatch via child issues

**Research-PDF-Reader:**
- Single capability: accept PDF path/URL → chunk → extract strategies → return structured YAML block per Card template
- No queue management, no Card assembly, no source proposals
- Model recommendation: Sonnet 4.6 (structured extraction, not strategic reasoning)
- Prompt target: ~25-30 lines

**Research-YouTube-Watcher:**
- Single capability: accept YouTube URL → fetch transcript → extract strategies → return structured YAML block
- Tool requirement: WebFetch / WebSearch for transcript retrieval
- Model recommendation: Sonnet 4.6
- Prompt target: ~25-30 lines

**Research-Web-Crawler:**
- Single capability: accept article/blog URL → fetch + parse → extract strategies → return structured YAML block
- Model recommendation: Haiku 4.5 (cheapest viable; task is fetch + pattern-match, not hard reasoning)
- Prompt target: ~20 lines

### 2b. Documentation-KM (6 skills → 3-agent subtree) — PRIORITY: MEDIUM

```
Documentation-KM-Lead (parent — retains existing UUID, prompt updated)
├── Doc-Sync-Worker     (skill: Notion → Git nightly sync)
└── Doc-ShowNotes       (skill: commit log + Notion period → show notes draft)
```

**Documentation-KM-Lead responsibilities post-split:**
- Onboarding pack preparation (episodic, rare)
- Process registry + Learnings Archive maintenance
- Sub-agent dispatch coordination
- CEO/OWNER review handoffs

**Doc-Sync-Worker:**
- Fires nightly at 23:00 UTC on schedule trigger
- Reads specific Notion pages, commits to Git `docs/`
- No show-notes, no onboarding, no judgment calls
- Model recommendation: Haiku 4.5 (routine export, no synthesis)

**Doc-ShowNotes:**
- On-demand: triggered when OWNER signals episode recorded
- Reads commit log + Notion updates for date range; drafts show notes
- No sync responsibilities
- Model recommendation: Sonnet 4.6 (synthesis quality required)

**Not splitting:** Onboarding prep and Learnings Archive stay with the Lead — episodic, low-frequency, require company context.

### 2c. DevOps (7 skills → 3-agent subtree) — PRIORITY: MEDIUM

```
DevOps-Lead (parent — retains existing UUID, prompt updated)
├── DevOps-Monitor      (skill: 1h infrastructure health checks + escalation)
└── DevOps-WebExport    (skill: public-data snapshot export pipeline)
```

**DevOps-Lead responsibilities post-split:**
- VPS setup scripts and MT5 layout changes (on-demand, rare)
- Paperclip deploy tooling
- Backup automation design and maintenance
- Drive-sync/git isolation enforcement
- Adapts to codex_local (consistent with existing DevOps adapter)

**DevOps-Monitor:**
- Runs on 1h timer
- Lightweight: disk check, terminal health, aggregator liveness, T6-isolation assertion
- Escalates to CEO on threshold breach only
- Model: codex_local (consistent; simple conditional checks)
- Prompt target: ~30 lines (vs DevOps current ~95 lines)

**DevOps-WebExport:**
- On trigger: runs `scripts/export_public_snapshot.ps1`, validates schema, git commit+push, Netlify hook
- No infra script authoring, no backup ownership
- Model: codex_local

### 2d. Quality-Tech (6 skills) — PRIORITY: LOW / DEFER

Quality-Tech's 6 skills (P2 code audit → P3 overfitting → P5 WF fidelity → P6 MC → P7 DSR/PBO → sub-gate calibration) are sequential pipeline stages applied to a single EA in a fixed order. They are not independently dispatchable — P5 cannot fire before P3 completes; P7 requires P6 context.

Splitting into per-stage agents would introduce 5 child issues per EA review with mandatory sequential handoffs, gaining zero parallelism while adding routing overhead. Each sub-agent must load the same background context (EA code + backtest report) fresh on each wake.

**Verdict: DEFER.** Re-evaluate only if a single P7 review context exceeds 80k tokens.

### 2e. CTO (6 skills) — REJECT split

Tech spec, code review, pipeline architecture, Hard Rules, and scale-invariance are tightly coupled — a code reviewer who lacks pipeline architecture context cannot safely verify framework compliance. Splitting would create dangerous cross-skill gaps in technical judgment.

**Verdict: REJECT.**

### 2f. CEO (7 skills) — REJECT split

Strategic leadership requires holistic company context. Splitting would distribute decision state across multiple agents, violating the single-point-of-authority requirement for OWNER-facing escalations and DL-053 operating contract.

**Verdict: REJECT.**

### 2g. Pipeline-Operator (5 skills) — DEFER

The 5 skills (terminal management, backtest execution, aggregator, chain-watcher, respawn) are operationally inseparable — a respawn event requires live terminal state, which requires knowing which backtests are running. Currently paused (manual). Any architecture change should wait until it returns to active operation and empirical heartbeat data is available.

**Verdict: DEFER pending unpause + 7 days of empirical data.**

### 2h. Quality-Business (5 skills) — DEFER

G0 review + author-claim check + portfolio-fit + PASS cross-challenge are applied together to a single card with shared context. No parallelism gain from splitting; skills are additive within one review session.

**Verdict: DEFER.**

### 2i. Development (2 skills) — NO SPLIT

Already near-minimum: implement + integrate. Both skills apply to one EA at a time. Further splitting would add overhead with no benefit.

### 2j. Chief-of-Staff (3 skills) — NO SPLIT

Purpose-built, already at minimum scope per DL-056. Splitting would violate the single-point-of-authority design for CoS reporting.

---

## Section 3 — Token-Burn Impact Projection

**Pricing model (Sonnet 4.6 / Codex estimated parity):**
- Input: $3.00/MTok
- Output: $15.00/MTok

**Base token load per heartbeat:**
- System prompt (AGENTS.md) + paperclip skill + CLAUDE.md overhead ≈ 10–12k tokens constant
- Derived from: 25 tokens/line × AGENTS.md line count + 6k overhead constant (paperclip skill, CLAUDE.md context)

### Current daily burn estimates (all agents active)

| Agent | Heartbeats/day | Input tokens/beat | Output tokens/beat | Daily input cost | Daily output cost | Daily total |
|---|---|---|---|---|---|---|
| CEO | 24 | 15k (12k base + 3k delta) | 1,500 | $1.08 | $0.54 | $1.62 |
| CTO | 24 | 14k | 1,500 | $1.01 | $0.54 | $1.55 |
| Research (active source) | 3 | 75k (12k base + 60k source chunk) | 5,000 | $0.68 | $0.23 | $0.91 |
| Development | paused | — | — | — | — | $0.00 |
| Pipeline-Operator | paused (was 144/day) | — | — | — | — | $0.00 |
| Quality-Business | 2 | 14k | 2,000 | $0.08 | $0.06 | $0.14 |
| Quality-Tech | 2 | 20k (12k base + 8k EA code) | 4,000 | $0.12 | $0.12 | $0.24 |
| DevOps | 24 | 13k | 1,000 | $0.94 | $0.36 | $1.30 |
| Documentation-KM | 12 | 12k | 1,000 | $0.43 | $0.18 | $0.61 |
| Chief-of-Staff | 24 | 13k | 1,000 | $0.94 | $0.36 | $1.30 |
| **Total (current)** | | | | **$5.28** | **$2.39** | **$7.67/day** |

**Monthly projection at current roster: ~$230/month** (reduced today by Development + Pipeline-Operator pause; steady-state with both active will be materially higher — Pipeline-Operator alone at 144 beats/day adds ~$4.75/day = +$143/month).

**Full steady-state estimate (all 10 agents unpaused): ~$295/month.**

### Post-split delta projections

**Research split (4-agent subtree):**
- Research is event-driven → idle beats ≈ 0 even now. No idle-heartbeat savings from splitting.
- Active session: Research-Lead dispatch comment (+$0.05/session) + sub-agent reads same context as current → no savings on work context
- Coordination overhead: ~4 inter-agent comment beats per session × $0.03/beat = +$0.12/session
- At 10 source sessions/month: **+$1.20/month coordination overhead**
- Primary benefit is **parallelism** (dispatch PDF-Reader + YouTube-Watcher simultaneously) — saves wall-clock time if CEO ever approves multi-format sources concurrently. At current 1-source-at-a-time policy, benefit is symbolic.

**Documentation-KM split (3-agent subtree):**
- Current: 12 beats/day on 2h timer × $0.051/beat = $0.61/day
- Post-split: Doc-KM-Lead (12/day, 8k input): $0.29/day + Doc-Sync-Worker (1/day, 15k + Notion payload): $0.07/day + Doc-ShowNotes (event ~1/week amortized): $0.01/day
- **Delta: −$0.24/day = −$7.20/month**
- Mechanism: Lead prompt shrinks ~35% on routine 2h-timer beats; heavy Notion-export context isolated to 1 nightly beat

**DevOps split (3-agent subtree):**
- Current: 24 beats/day × $0.054/beat = $1.30/day
- Post-split: DevOps-Monitor (24/day, 8k input): $0.62/day + DevOps-WebExport (1/day, 12k + data): $0.07/day + DevOps-Lead (event ~3/day, 14k): $0.18/day
- **Delta: −$0.43/day = −$12.90/month**
- Mechanism: Monitor sub-agent uses ~35% smaller prompt on 24 daily timer beats; script-authoring context isolated to on-demand Lead beats

**Combined Phase 1 + 2 net delta:**
- Research: +$1.20/month
- Documentation-KM: −$7.20/month
- DevOps: −$12.90/month
- **Net: −$18.90/month**

**Context:** This is ~6% of the $295/month full steady-state estimate. Not transformative at current scale, but validates the architecture direction.

---

## Section 4 — Migration Plan

### Phase 1: Research subtree

Target: OWNER-explicit directive from QUA-696. Highest symbolic and directional priority.

**Agents to hire (via CEO + `paperclip-create-agent` skill):**

| # | Agent | Reports to | Model | Prompt size target | Token delta |
|---|---|---|---|---|---|
| 1 | Research-PDF-Reader | Research-Lead | claude_local, Sonnet 4.6 | 25-30 lines | +$0.05/session overhead |
| 2 | Research-YouTube-Watcher | Research-Lead | claude_local, Sonnet 4.6 | 25-30 lines | +$0.05/session overhead |
| 3 | Research-Web-Crawler | Research-Lead | claude_local, Haiku 4.5 | 20 lines | −$0.02/session (Haiku cheaper) |

**Existing agent change:**
- Research (7aef7a17): rename to **Research-Lead**; update AGENTS.md to remove inline PDF/YouTube/web extraction + add sub-agent dispatch instructions. UUID retained. Doc-KM updates org chart per its mandate.

**Acceptance criteria:**
- All 3 prompt sketches reviewed by CEO
- `paperclip-create-agent` hires submitted and confirmed active
- Research-Lead dispatches a test child issue to Research-PDF-Reader and receives a structured result

**ETA: 2026-05-05 (pending OWNER ratification by 2026-05-05)**

### Phase 2: Documentation-KM + DevOps subtrees

Target: Token savings on high-frequency timer beats; cleaner automation vs judgment separation.

**Agents to hire:**

| # | Agent | Reports to | Model | Prompt size target | Token delta |
|---|---|---|---|---|---|
| 4 | Doc-Sync-Worker | Documentation-KM-Lead | claude_local, Haiku 4.5 | 20-25 lines | −$7.20/month |
| 5 | Doc-ShowNotes | Documentation-KM-Lead | claude_local, Sonnet 4.6 | 25-30 lines | marginal (on-demand) |
| 6 | DevOps-Monitor | DevOps-Lead | codex_local | 30 lines | −$12.90/month |
| 7 | DevOps-WebExport | DevOps-Lead | codex_local | 25 lines | included in above |

**Existing agent changes:**
- Documentation-KM (8c85f83f): rename to Documentation-KM-Lead; remove nightly sync + show-notes from prompt; add sub-agent dispatch
- DevOps (86015301): rename to DevOps-Lead; remove monitoring loop + web export from prompt; add sub-agent dispatch

**Acceptance criteria:**
- Sub-agents active for 7 days
- Daily burn rate measured via `spentMonthlyCents` delta confirms −$0.60+/day vs baseline

**ETA: 2026-05-12 (one week after Phase 1 stabilizes)**

### Phase 3: Quality-Tech stage-split (conditional)

**Gate criterion:** First V5 EA completes P7 review. If:
- Average P7 review heartbeat context > 80k tokens, **AND**
- Total review wall-clock time > 48h per EA due to context size limits

Then: propose per-stage split (P2-auditor, P3-P5-analyst, P6-P7-statistician).

Otherwise: abandon Phase 3 permanently.

**No hires yet.** CEO should flag this issue for re-evaluation after first EA reaches P7.

---

## Section 5 — Risks + Tradeoffs

### 1. Coordination overhead is real and additive, not zero

More agents = more inter-agent comment beats. Each comment costs ~0.5-1k tokens per wake for the receiving agent. At 4 sub-agents under Research, a single source session adds ~4 extra comment beats × $0.03/beat = $0.12/session. At 10 sessions/month: +$1.20/month in pure routing overhead. This does NOT self-cancel against savings and compounds with agent count.

### 2. Smaller contexts ≠ universally cheaper

The token savings in Section 3 come **exclusively** from periodic agents with large idle system prompts (DevOps-Monitor, Doc-Sync-Worker). For event-driven agents like Research, the heavy context is the source material itself (60k-token PDF chunk), not the system prompt. Splitting the system prompt saves ~2k tokens per active beat — effectively nothing versus the work context.

### 3. Cross-reference latency in split Research

Research today can follow a live citation: "This YouTube video cites a paper — I'll cross-check it." Post-split, Research-Lead must dispatch a child issue to Research-PDF-Reader, wait for a heartbeat round-trip (~10-20 min). For sources with dense cross-references (books citing papers), this multiplies review latency significantly.

Mitigation: Research-Lead retains authority to do direct lightweight web lookups without dispatching sub-agents for quote verification. Sub-agents are for full extraction sessions only.

### 4. Agent count inflation increases CoS audit overhead

Current roster: 10 agents. After Phase 1+2: 17 agents. If Phase 3 triggers: ~22 agents. CoS roster-hygiene work grows linearly: more AGENTS.md files to audit, more places for `pauseReason` inconsistencies, more orphan-dir risk. The CoS heartbeat token cost also increases proportionally.

Phase 1+2 delta: +7 agents = roughly +30% CoS audit load per heartbeat.

### 5. Paused agents distort the baseline

Development and Pipeline-Operator are currently paused. Pipeline-Operator at its 10-min cadence adds ~$4.75/day when unpaused. The Phase 1+2 savings of $18.90/month are ~6% of full steady-state budget — not 8% as the Section 3 top-line suggests.

### 6. Haiku for Web-Crawler and Doc-Sync: quality risk

Haiku is the cheapest option but has lower reasoning quality. For Doc-Sync-Worker (deterministic: fetch Notion page → commit), Haiku is sufficient. For Research-Web-Crawler, a poorly-structured web article may require judgment to identify what counts as a strategy. If extraction quality degrades, the cost is a CEO review round-trip (more expensive than upgrading to Sonnet). Recommend piloting on 5 articles before committing to Haiku for Web-Crawler.

---

## Section 6 — Recommended Decision

| Phase | WHAT | WHY | IMPACT | TRADEOFF | RECOMMENDED-DECISION |
|---|---|---|---|---|---|
| **Phase 1** — Research subtree (4 agents) | Hire Research-PDF-Reader, Research-YouTube-Watcher, Research-Web-Crawler; refactor Research → Research-Lead | OWNER-explicit directive; role clarity; enables parallel dispatch if multi-format sources approved | +$1.20/month overhead; architecture clarity + future parallelism | Routing adds latency for cross-reference sessions; Web-Crawler model quality risk | **accept** |
| **Phase 2** — Doc-KM + DevOps subtrees (4 agents) | Hire Doc-Sync-Worker, Doc-ShowNotes, DevOps-Monitor, DevOps-WebExport; update parent prompts | −$20.10/month net (Phase 1+2); cleaner separation of automation from judgment work | Phase 1 must stabilize first; +7 total agents increases CoS audit load | Real but modest savings at current scale | **accept** |
| **Phase 3** — Quality-Tech stage-split | Conditional hire of 3-5 QT sub-agents | Sequential stages gain nothing from splitting at current EA size | Zero benefit until context > 80k tokens per P7 beat | Premature split adds pure overhead | **defer-with-reason: re-evaluate after first V5 EA completes P7** |
| **CEO/CTO split** | Reject entirely | Holistic judgment required; splitting externalizes decision state | Architectural risk outweighs any token saving | Rejected cleanly | **reject** |
| **Pipeline-Operator split** | Conditional | Operationally inseparable skills; currently paused | No empirical data; architecture change during pause = unverifiable | Wait for unpause + 7d data | **defer-with-reason: re-evaluate after unpause** |

---

## Process gate (binding per spec comment on QUA-698)

1. ✅ CoS posts this document as comment reference on QUA-698 (this heartbeat)
2. ⬜ CEO reviews + creates `request_confirmation` to OWNER on QUA-698 with `idempotencyKey: confirmation:263f31e2-4412-4e3f-8f08-666bcc759090:plan:v1`
3. ⬜ OWNER accepts → CEO executes Phase 1 hires using `paperclip-create-agent` skill
4. CoS does **not** spawn agents directly (DL-056 hard constraint § "no direct API agent-create or agent-retire")

**OWNER ratification target: 2026-05-05**
