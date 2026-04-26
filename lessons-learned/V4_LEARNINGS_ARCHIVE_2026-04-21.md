# V4 Learnings Archive — V5 Basis (What V5 Keeps, Changes, Discards)

Source: laptop Notion `Learnings Archive — What We Keep vs. Change` (id `34947da5-8f4a-8136-a6a8-ee48fe47fc7d`, last updated 2026-04-21).
Migrated to repo: 2026-04-26.

> **Framing (corrected 2026-04-26):** V4 learnings are the **basis** of V5, not a legacy archive. The phases, the framework patterns, the hard rules — all promoted into V5. Paperclip's job is to *professionalize* this basis, not to redesign it from scratch. Earlier framing in this repo that called V4 material "legacy / not a V5 input" applies only to V4's *strategy bestand* (specific SM_XXX sleeves) — not to V4's process, framework patterns, hard rules, or learnings.

This is the audit trail that justifies every V5 design choice. Codex reviews it at phase boundaries.

## Format

Each entry: **Learning** → **V1 Behavior** → **V5 Behavior** → **Why**

---

## KEPT (V5 inherits unchanged)

### L-K-01: Model 4 Every Real Tick baseline
- V1: All baseline backtests Model 4, never Model 1/2
- V5: Unchanged
- Why: Model 4 is only method that reproduces tick-level fills. Model 1/2 tick-quality shortcuts produce artificially good PFs. Validated empirically multiple times in V1.

### L-K-02: Fixed Risk $1K for backtests, Percent Risk for live
- V1: Every EA supports both `RISK_FIXED` and `RISK_PERCENT` enum inputs
- V5: Unchanged. **Convention**: backtest runs use `RISK_FIXED` (default $1K), live deploys use `RISK_PERCENT`.
- Why: Fixed Risk makes metrics comparable across EAs (no portfolio-effect confusion). Percent Risk matches real capital behavior in live.

### L-K-03: Darwinex MT5 native data only
- V1: No external market data APIs (no Alpha Vantage, no Polygon, no Yahoo)
- V5: Unchanged
- Why: Broker-native data matches what the EA will actually see live. External APIs have alignment drift that invalidates backtests. Also legal cleaner.

### L-K-04: `.DWX` symbols in research, stripped at deploy
- V1: Research symbols carry `.DWX` suffix; VPS deploy strips it
- V5: Unchanged
- Why: Avoids symbol-name collision between custom research instruments and live Darwinex feed. Deploy-time stripping is deterministic.

### L-K-05: Unique magic numbers per EA+symbol
- V1: Schema `SM_ID * 10000 + symbol_slot`; collision = hard abort
- V5: Unchanged. V5 namespace shifts to `QM5_NNNN` (ea_id 1000-9999) to avoid collision with V4 SM_XXX (1-~770).
- Why: Magic-number collision causes EA order-management bugs that are silent until they corrupt position state in live.

### L-K-06: Git as canonical source of truth
- V1: Every code change committed; no in-memory-only state
- V5: Unchanged; extended to Notion-export-to-Git for docs

### L-K-07: Enhancement Doctrine — exits yes, entries no
- V1: Exit-only modifications preserve PASS; entry-filter modifications kill trades and break backtest comparability
- V5: Unchanged, formalized in Pipeline Design
- Why: Once an EA's entries change, prior P2-P10 evidence is no longer valid. Exits can be tuned because exit-tuning is a separate gate (P5b for noise robustness covers it).

### L-K-08: No fantasy numbers
- V1: All claimed metrics must cite a report or state-file; no LLM-generated PFs
- V5: Unchanged, enforced in agent prompts

### L-K-09: Stop digging rule
- V1: If a fix makes outcomes worse, revert and restart with new approach, don't double down
- V5: Unchanged, in CEO + CTO prompts explicitly

### L-K-10: File-deletion requires approval
- V1: Added post QUAA-255 (mass-delete incident 2026-04-20 — see `lessons-learned/2026-04-20_mass_delete_incident.md` and `lessons-learned/2026-04-20_file_deletion_policy_v1.md`)
- V5: Unchanged; in all agent prompts

---

## CHANGED (V1 → V5 delta)

### L-C-01: Research methodology breadth → depth
- V1: Research agent parallel across multiple sources, 46 rounds, 81+ edges catalogued
- V5: Source-by-source, one at a time, exhaustive extraction before next source
- Why: V1 produced duplicates discovered only at build time; attribution was fuzzy; hard to reproduce; hard to present on YouTube.

### L-C-02: Agent count 13 → 13 but leaner prompts
- V1: 13 agents with overlapping responsibilities, chatty heartbeats
- V5: Same 13 roles but revised prompts with explicit non-responsibilities; heartbeat rates cut ~60%
- Why: V1 wasted tokens on no-op heartbeat ticks; agent scope creep caused redundant work

### L-C-03: CEO close protocol single-step → 2-phase
- V1: CEO would mark DONE based on agent's claim
- V5: CEO must verify with real test output before close (claim → verify → archive)
- Why: Several V1 "DONE" items were actually broken — fix verification eliminates that class

### L-C-04: Cross-challenge optional → mandatory for PASS
- V1: Single-agent PASS accepted
- V5: 2+ agents at 90%+ confidence required for PASS; else provisional
- Why: Some V1 PASSes turned out to be model-bugs one agent missed but another would have caught

### L-C-05: Agent idle tolerance — enforcement mechanism
- V1: Rule existed but not enforced; agents sometimes starved
- V5: Orchestrator generates tasks proactively; CEO monitors queue depth
- Why: Idle agents = wasted heartbeat budget

### L-C-06: Smoke tests treated as BL-equivalent → not
- V1: SM_261 incident (XTIUSD smoke 0.47 MB/min vs EURGBP BL 150 MB/min — 320× divergence)
- V5: Third-pass audits require actual trigger symbol + full BL window
- Why: Portable smoke misses symbol-dependent bug classes (spreads, swap, contract size)

### L-C-07: Filesystem vs. tracker authority — now explicit
- V1: Sometimes trusted Python tracker state over filesystem
- V5: Filesystem is always truth; tracker is lag-indicator
- Why: T2 sweep 145→235 discrepancy (2026-04-17) — tracker was stale, filesystem had the real count

### L-C-08: NO_REPORT vs EA-weakness disambiguation
- V1: Sometimes called "dead EA" on size-0 .htm files that were actually infra failures
- V5: File-size check before any EA-weakness judgment
- Why: Wasted analysis cycles in V1; cost hours of investigation

### L-C-09: Deep research before spec changes
- V1: Spec changes based on internal discussion
- V5: Deep-Research-Agent call before any Pipeline spec change; external framework overlap check
- Why: 30% of V1 spec ideas turned out to be duplications of well-known methods not worth re-inventing

### L-C-10: Scale-invariance awareness
- V1: Re-runs sometimes dispatched without checking if the bug affected scale-invariant metrics
- V5: Mandatory check: which metrics are scale-invariant (P2/P3 gates) vs. not (P7/P9)? Only re-run if the change actually affects the metric in question
- Why: Saved wasted compute on re-runs that wouldn't change the gate decision

### L-C-11: Parent-check before spawning sub-issues
- V1: Sometimes spawned duplicate sub-issue cohorts (QUAA-406 incident)
- V5: CEO must list parent children BEFORE spawning a structured cohort
- Why: Duplicate cohort caused hours of confusion

### L-C-12: Pipeline-Operator heartbeat 5min → 10min
- V1: 5min heartbeat was eager, wasted tokens on no-op ticks
- V5: 10min, with explicit skip-if-no-change logic
- Why: Observed token spend pattern in V1 heartbeat logs

### L-C-13: DarwinexZero account reset — fresh account, fresh public track record
- V1: Old DarwinexZero account had legacy history
- V5: New DXZ account created on EP04, zero starting history
- Why: Build-in-public story requires a clean slate people can follow from Day 1.

### L-C-14: 5 → 6 MT5 terminals with T6 isolation on same VPS
- V1 (original V5 plan): 5 MT5 factory terminals + separate Hyonix live VPS
- V5 (revised 2026-04-21): 6 MT5 terminals on one Hetzner VPS: T1-T5 factory, T6 Demo/Live isolated
- Why: Same-VPS isolation safer than split-VPS coordination; Hyonix dropped.

### L-C-15: Hetzner AX42 dedicated replaces Contabo VPS 50 shared
- Why: Contabo blocks BYOL Windows; Hetzner allows it. 12-mo TCO €1114→€691; dedicated Zen4 cores ~2× faster than shared vCPU.

### L-C-16: Deferred license purchase via Eval-first phase
- V5: Install Windows Server 2022 Evaluation (180d), buy MyOEM key in Month 5, convert via DISM.
- Why: Defers €99.90 cash-out, de-risks if pivot needed.

### L-C-17: VPS Folder Layout standardized to `C:\QM\`
- Why: V1 had reports truncated by Windows MAX_PATH 260 chars. Short root path gives ~250 char budget for nested paths.

### L-C-18a: TDS/MT5 compatibility correction 2026-04-21
- What happened: Codex + Claude initially proposed dropping Tick Data Suite based on vendor framing ("MT4 only"). Fabian corrected: TDS works with MT5 in V1-V4 practice.
- Lesson: When Board is about to drop a tool the operator uses, ASK the operator first. Vendor marketing pages don't always reflect real compatibility.

### L-C-18: Board Member and Paperclip CEO separation clarified
- V5: Two distinct roles. **Paperclip CEO** = autonomous operational CEO (agent in Paperclip, runs 24/7 heartbeats). **Board Member** = Claude Code instance Fabian launches interactively for strategic collaboration.
- Why: V1 had persistent confusion about "which Claude am I talking to". V5 makes it explicit.

---

## DISCARDED (V5 dropped)

### L-D-01: `/loop 20min /pm-check` session-scoped Claude Code cron
- V5: **Removed.** Paperclip agents handle this via their own heartbeats.

### L-D-02: Baseline-work as default filler
- V5: Baseline work is gap-filler but **CEO must approve** — no automatic default.

### L-D-03: Local-PC as primary infrastructure
- V5: VPS is primary. Local PC retained as fallback / development only.
- Why: Drive-Stream bugs, Paperclip crash days, mass-delete incident.

### L-D-04: Paperclip-CEO spawned locally
- V5: Fresh Paperclip instance on VPS, agents rehired from revised prompts.

### L-D-05: Netlify deploy daily cadence
- V5: TBD — with VPS + GitHub Actions, could move to event-driven.

### L-D-06: Hyonix as separate live VPS
- V5: **Hyonix completely dropped.** Live execution on T6 same Hetzner VPS.

### L-D-07: Old DarwinexZero account history
- V5: Old DXZ archived; new account starts from zero.

### L-D-08: Contabo as V5 VPS provider
- V5: Contabo dropped (BYOL Windows blocked); Hetzner AX42 dedicated.

---

## V5 Codex Review Checklist (at each phase boundary)

- [ ] All KEPT items still valid in V5 context
- [ ] All CHANGED items have clear justification evidence
- [ ] No DISCARDED item was silently re-introduced
- [ ] Any new learning from the latest phase has an entry here
- [ ] Contradictions between Notion pages flagged

## How V5 Uses This File

This is **the basis Paperclip professionalizes**, not a one-time migration artifact. Every Wave 0+ agent reads this on first activation. Every phase-boundary Codex audit checks the list. New learnings from V5 phases get added here under a new `L-V5-XX` prefix to keep V4 entries clean.
