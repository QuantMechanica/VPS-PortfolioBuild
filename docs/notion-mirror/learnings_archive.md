<!--
AUTO-GENERATED MIRROR — DO NOT EDIT.
Source: Notion page 34947da58f4a8136a6a8ee48fe47fc7d
Title: Learnings Archive — What We Keep vs. Change
Mirrored: 2026-04-30T23:00:00Z by Documentation-KM (QUA-622 nightly sync; previous refresh 2026-04-27T11:24:00Z under QUA-151)
Editing surface: Notion. Direct edits will be overwritten by the next sync.
Manifest: infra/notion-sync/manifest.yaml
NOTE: lessons-learned/ in the repo is the Git-canonical operational lessons
store. This mirror is the public/board snapshot.
-->

# Learnings Archive — What We Keep vs. Change

**This is the audit trail that justifies every V5 design choice.** Codex reviews this at phase boundaries.

## Format

Each entry: **Learning** → **V1 Behavior** → **V5 Behavior** → **Why**

---

## KEPT (Unchanged)

### L-K-01: Model 4 Every Real Tick baseline

**V1:** All baseline backtests Model 4, never Model 1/2
**V5:** Unchanged
**Why:** Model 4 is only method that reproduces tick-level fills; Model 1/2 tick-quality shortcuts produce artificially good PFs. This was validated empirically multiple times in V1.

### L-K-02: Fixed Risk $1K for backtests, Percent Risk for live

**V1:** Every EA supports both `RISK_FIXED` and `RISK_PERCENT` enum inputs
**V5:** Unchanged
**Why:** Fixed Risk makes metrics comparable across EAs (no portfolio-effect confusion). Percent Risk matches real capital behavior in live.

### L-K-03: Darwinex MT5 native data only

**V1:** No external market data APIs (no Alpha Vantage, no Polygon, no Yahoo)
**V5:** Unchanged
**Why:** Broker-native data matches what the EA will actually see live. External APIs have alignment drift that invalidates backtests. Also legal cleaner.

### L-K-04: `.DWX` symbols in research, stripped at deploy

**V1:** Research symbols carry `.DWX` suffix; VPS deploy strips it
**V5:** Unchanged
**Why:** Avoids symbol-name collision between custom research instruments and live Darwinex feed. Deploy-time stripping is deterministic.

### L-K-05: Unique magic numbers per EA+symbol

**V1:** Schema `SM_ID * 10000 + symbol_slot`; collision = hard abort
**V5:** Unchanged
**Why:** Magic-number collision causes EA order-management bugs that are silent until they corrupt position state in live.

### L-K-06: Git as canonical source of truth

**V1:** Every code change committed; no in-memory-only state
**V5:** Unchanged; extended to Notion-export-to-Git for docs

### L-K-07: Enhancement Doctrine — exits yes, entries no

**V1:** Exit-only modifications preserve PASS; entry-filter modifications kill trades and break backtest comparability
**V5:** Unchanged, formalized in Pipeline Design

### L-K-08: No fantasy numbers

**V1:** All claimed metrics must cite a report or state-file; no LLM-generated PFs
**V5:** Unchanged, enforced in agent prompts

### L-K-09: Stop digging rule

**V1:** If a fix makes outcomes worse, revert and restart with new approach, don't double down
**V5:** Unchanged, in CEO + CTO prompts explicitly

### L-K-10: File-deletion requires approval

**V1:** Added post QUAA-255 (mass-delete incident 2026-04-20)
**V5:** Unchanged; in all agent prompts

---

## CHANGED (V1 → V5 delta)

### L-C-01: Research methodology breadth → depth

**V1:** Research agent parallel across multiple sources, 46 rounds, 81+ edges catalogued
**V5:** Source-by-source, one at a time, exhaustive extraction before next source
**Why:** V1 produced duplicates discovered only at build time; attribution was fuzzy; hard to reproduce; hard to present on YouTube. See **Research Methodology V2** page.

### L-C-02: Agent count 13 → 13 but leaner prompts

**V1:** 13 agents with overlapping responsibilities, chatty heartbeats
**V5:** Same 13 roles but revised prompts with explicit non-responsibilities; heartbeat rates cut ~60%
**Why:** V1 wasted tokens on no-op heartbeat ticks; agent scope creep caused redundant work

### L-C-03: CEO close protocol single-step → 2-phase

**V1:** CEO would mark DONE based on agent's claim
**V5:** CEO must verify with real test output before close (claim → verify → archive)
**Why:** Several V1 "DONE" items were actually broken — fix verification eliminates that class

### L-C-04: Cross-challenge optional → mandatory for PASS

**V1:** Single-agent PASS accepted
**V5:** 2+ agents at 90%+ confidence required for PASS; else provisional
**Why:** Some V1 PASSes turned out to be model-bugs one agent missed but another would have caught

### L-C-05: Agent idle tolerance (always 3+ tasks) — enforcement mechanism

**V1:** Rule existed but not enforced; agents sometimes starved
**V5:** Orchestrator generates tasks proactively; CEO monitors queue depth
**Why:** Idle agents = wasted heartbeat budget

### L-C-06: Smoke tests treated as BL-equivalent → not

**V1:** SM_261 incident (XTIUSD smoke 0.47 MB/min vs EURGBP BL 150 MB/min — 320x divergence)
**V5:** Third-pass audits require actual trigger symbol + full BL window
**Why:** Portable smoke misses symbol-dependent bug classes (spreads, swap, contract size)

### L-C-07: Filesystem vs. tracker authority — now explicit

**V1:** Sometimes trusted Python tracker state over filesystem
**V5:** Filesystem is always truth; tracker is lag-indicator
**Why:** T2 sweep 145→235 discrepancy (2026-04-17) — tracker was stale, filesystem had the real count

### L-C-08: NO_REPORT vs EA-weakness disambiguation

**V1:** Sometimes called "dead EA" on size-0 .htm files that were actually infra failures
**V5:** File-size check before any EA-weakness judgment
**Why:** Wasted analysis cycles in V1; cost hours of investigation

### L-C-09: Deep research before spec changes

**V1:** Spec changes based on internal discussion
**V5:** Deep-Research-Agent call before any Pipeline spec change; external framework overlap check
**Why:** 30% of V1 spec ideas turned out to be duplications of well-known methods not worth re-inventing

### L-C-10: Scale-invariance awareness

**V1:** Re-runs sometimes dispatched without checking if the bug affected scale-invariant metrics
**V5:** Mandatory check: which metrics are scale-invariant (P2/P3 gates) vs. not (P7/P9)? Only re-run if the change actually affects the metric in question
**Why:** Saved wasted compute on re-runs that wouldn't change the gate decision

### L-C-11: Parent-check before spawning sub-issues

**V1:** Sometimes spawned duplicate sub-issue cohorts (QUAA-406 incident)
**V5:** CEO must list parent children BEFORE spawning a structured cohort
**Why:** Duplicate cohort caused hours of confusion

### L-C-12: Pipeline-Operator heartbeat 5min → 10min

**V1:** 5min heartbeat was eager, wasted tokens on no-op ticks
**V5:** 10min, with explicit skip-if-no-change logic
**Why:** Observed token spend pattern in V1 heartbeat logs

### L-C-13: DarwinexZero account reset — fresh account, fresh public track record

**V1:** Old DarwinexZero account had legacy history that would confuse the "fresh start" narrative
**V5:** New DXZ account created on EP04, zero starting history, becomes V5's canonical public track record
**Why:** Build-in-public story requires a clean slate people can follow from Day 1; mixing old performance data into the new narrative undermines credibility.

### L-C-14: 5 → 6 MT5 terminals with T6 isolation on same VPS

**V1 (original V5 plan):** 5 MT5 factory terminals + separate Hyonix live VPS
**V5 (revised 2026-04-21):** 6 MT5 terminals on one Contabo VPS: T1-T5 factory (Pipeline-Operator), T6 Demo/Live (LiveOps, isolated). Hyonix dropped.
**Why:** Codex T6 Runbook argues same-VPS isolation is safer than split-VPS coordination; Fabian confirmed Hyonix is fully dropped. Risk-coupling mitigations are enforced in LiveOps prompt (T6 priority class, T1-T5 sweep pausing on T6 resource pressure, no Strategy Tester in T6).

---

## DISCARDED

### L-D-01: `/loop 20min /pm-check` session-scoped Claude Code cron

**V1:** Human-Claude had /loop crons for PM check and dashboard
**V5:** **Removed.** Paperclip agents handle this via their own heartbeats. Duplication caused contradictions between the two systems.
**Why:** RECOVERY.md 2026-04-18 already flagged these as obsolete post-cutover; V5 formalizes the removal.

### L-D-02: Baseline-work as default filler

**V1:** When no higher-phase candidates, baseline-work was default
**V5:** Baseline work is still gap-filler but **CEO must approve** — no automatic default
**Why:** Sometimes higher-value work (research, meta-analysis, content) was more useful than more baseline

### L-D-03: Local-PC as primary infrastructure

**V1:** Fabian's personal PC was the runtime
**V5:** VPS is primary. Local PC retained as fallback / development only.
**Why:** Drive-Stream bugs, Paperclip crash days, mass-delete incident. Remote infra is more reliable.

### L-D-04: Paperclip-CEO spawned locally

**V1:** Local Paperclip instance with 11+ agents
**V5:** Fresh Paperclip instance on VPS, agents rehired from revised prompts
**Why:** Old Paperclip had accumulated state debt; fresh install is cleaner and videographable

### L-D-05: Netlify deploy daily cadence

**V1:** Netlify once/day (evening) with hourly local updates
**V5:** TBD — with VPS + GitHub Actions, could move to event-driven
**Why:** Still being designed; will formalize in Website Relaunch phase

### L-D-06: Hyonix as separate live VPS

**V1 (original V5 plan):** Hyonix live VPS retained for P9 live execution (~€30-60/mo ongoing)
**V5 (revised 2026-04-21):** **Hyonix completely dropped.** Live execution runs on T6 on the same Contabo VPS. No budget allocation for Hyonix.
**Why:** Fabian directive 2026-04-21. Simplifies ops, reduces monthly spend, removes coordination between two VPS environments. Same-VPS coupling risk is mitigated via T6 isolation discipline (Codex T6 Runbook + revised LiveOps prompt).

### L-D-07: Old DarwinexZero account history

**V1:** DXZ account had existing history pre-V5
**V5:** **Old DXZ account archived/dropped.** V5 uses a new DXZ account with new account number starting from zero capital and zero history.
**Why:** Clean track record for Build-in-Public narrative; mixing V1-V4 history into V5 public story would confuse audience and weaken credibility.

### L-D-08: Contabo as V5 VPS provider

**V1 (original V5 plan):** Contabo Cloud VPS 50 as primary VPS, BYOL Windows license from MyOEM
**V5 (revised 2026-04-21):** **Contabo dropped.** Reason: Contabo official policy blocks BYOL Windows licenses (*"Due to Microsoft licensing rules, a custom Windows license cannot be used"* — Contabo support docs). Applies to both VPS and Dedicated offerings.
**Why:** Would have forced €58.50/mo Contabo Windows rental = €1114/12mo TCO, or illegal/unsupported install risk. Pivot to Hetzner AX42 enables legal BYOL via KVM install, saves €423 over 12 months, gives dedicated Zen4 cores instead of shared vCPU.

---

## CHANGED 2026-04-21 (Hetzner Pivot)

### L-C-15: Hetzner AX42 dedicated replaces Contabo VPS 50 shared

**Original V5:** Contabo Cloud VPS 50 (16 vCPU shared, 64 GB, 600 GB NVMe), €412.20 prepaid 12-mo
**Revised V5:** Hetzner AX42 dedicated (8C/16T Ryzen 7 PRO 8700G Zen4, 64 GB DDR5 ECC, 2×512 GB NVMe RAID1), €46/mo + €39 setup, monthly billing
**Why:**

- Contabo blocks BYOL Windows (L-D-08)
- Hetzner dedicated allows BYOL via KVM install
- Dedicated Zen4 cores run MT5 Tester ~2× faster per core than Contabo shared vCPU
- RAID1 disk redundancy on dedicated NVMe
- DDR5 ECC RAM instead of non-ECC shared
- No prepay lock-in, can cancel monthly
- 12-mo TCO drops €1114 → €691 (€423 saved)
- First-month cash-out drops €471 → €85 (better liquidity)

### L-C-16: Deferred license purchase via Eval-first phase

**Original V5:** Buy MyOEM license upfront in EP02
**Revised V5:** Install Windows Server 2022 Evaluation Edition (180-day free, renewable to 360d). Buy MyOEM key in Month 5 when setup is proven. Convert Eval → Standard via DISM.
**Why:**

- Eval is fully functional, identical to Standard
- Defers €99.90 cash-out by 4-5 months
- De-risks: if setup fails or we pivot, no sunk license cost
- Test-then-commit aligns with Build-in-Public caution

### L-C-17: VPS Folder Layout standardized to C:\QM\

**Original V5:** No specific folder layout defined
**Revised V5:** Everything under `C:\QM\` (repo, paperclip, mt5, trackers, drive, logs, tmp). Short path avoids Windows MAX_PATH 260-char limit observed in V1 MetaQuotes deep paths.
**Why:** V1 had reports truncated by MAX_PATH. Short root path gives ~250 chars budget for nested paths, prevents silent corruption.

### L-C-18a: TDS/MT5 compatibility correction 2026-04-21

**What happened:** Codex and Claude-Assistant initially proposed dropping Tick Data Suite from V5 based on TDS vendor website framing ("only integrates with MT4") and listed price €549 lifetime.

**Fabian's correction:** TDS is functional with MT5 in practice; Fabian has an active license and has used it in V1–V4 with MT5 + Darwinex successfully.

**Corrective action:** TDS restored to V5 plan. EP04 covers license-move from local PC to VPS. Renewal decision deferred 1–4 weeks.

**Lesson for future:** When Board is about to drop a tool the operator uses, ASK the operator first. Vendor marketing pages don't always reflect real compatibility. Document practical experience as an evidence source equal to vendor docs.

### L-C-18: Board Member and Paperclip CEO separation clarified

**Original V5:** Ambiguous whether Claude-Assistant-on-VPS IS the Paperclip CEO or parallel
**Revised V5:** Two distinct roles. **Paperclip CEO** = autonomous operational CEO (agent in Paperclip, runs 24/7 heartbeats, makes gate decisions). **Board Member** = Claude Code instance Fabian launches interactively when he needs strategic collaboration. Board Member has its own CLAUDE.md at `C:\QM\repo\CLAUDE.md`.
**Why:** V1 had persistent confusion about "which Claude am I talking to" — V5 makes it explicit. Different escalation protocols, different authorities, different session cadences.

---

## Codex Review Checklist

At each phase boundary, Codex audits:

- [ ] All KEPT items still valid in V5 context
- [ ] All CHANGED items have clear justification evidence
- [ ] No DISCARDED item was silently re-introduced
- [ ] Any new learning from the latest phase has an entry here
- [ ] Contradictions between Notion pages flagged

## Sub-pages (Notion-side)

- [2026-04-29 — Development recursive self-wake hot-poll](https://www.notion.so/35247da58f4a81c595cdd3f1ba6d62c3)
